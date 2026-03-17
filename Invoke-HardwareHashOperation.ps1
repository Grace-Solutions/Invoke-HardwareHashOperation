#Requires -Version 5

<#
    .SYNOPSIS
    Extracts and exports Windows Autopilot hardware hash information for device enrollment.

    .DESCRIPTION
    Extracts the Windows Autopilot hardware hash from a device using OA3Tool and exports it in the
    Microsoft Autopilot-compatible CSV format. Supports export to a custom path, removable USB drives,
    and sending full device information via webhook. Works in both Windows PE and full Windows environments.

    The script self-elevates to administrator if not already running elevated. In Windows PE, it
    automatically registers PCPKsp.dll to enable TPM-based hash collection.

    .PARAMETER Export
    Triggers export of the hardware hash CSV to the path specified by -ExportPath (or the default path
    if -ExportPath is omitted). Must be combined with -ExportPath or used alone for the default location.
    Alias: E

    .PARAMETER ExportPath
    Destination file path for the hardware hash CSV. When -Export is used without this parameter, the
    CSV is saved to "Content\HardwareHashes\<SerialNumber>.csv" relative to the script directory.
    Alias: EP

    .PARAMETER ExportToRemovableDisk
    Exports the hardware hash CSV to all detected, ready removable USB drives. The CSV is placed at
    "<Drive>:\HardwareHashes\<SerialNumber>.csv" on each drive. Can be combined with -Export.
    Alias: ETRD

    .PARAMETER Overwrite
    Overwrites an existing CSV at the target path. Without this switch, existing files are left unchanged.
    Alias: O

    .PARAMETER SendWebhook
    Sends device and hardware hash information as a JSON POST request to the URI specified by -WebhookURI.
    Requires active network and internet connectivity. The payload includes decoded hardware inventory
    (CPU, RAM, GPU, Disk, TPM, Secured Core, SMBIOS fields, and a structured AssetManagement block)
    unless -ExcludeSystemInformation is also specified.
    Alias: SWH

    .PARAMETER WebhookURI
    The URI of the webhook endpoint. Required when -SendWebhook is specified.
    Alias: WHURI

    .PARAMETER WebhookHeaders
    Custom HTTP headers for the webhook request, supplied as a valid JSON string.
    Example: '{"Authorization": "Bearer <token>", "x-api-key": "abc123"}'
    Aliases: WHHeaders, Headers

    .PARAMETER ExcludeSystemInformation
    When combined with -SendWebhook, restricts the webhook payload to only the Autopilot CSV fields
    (serial number, hardware hash, group tag, assigned user), omitting all decoded hardware inventory data.
    Alias: ESI

    .PARAMETER LogDirectory
    Custom directory for log output. If omitted, the log path is determined automatically based on the
    current environment (Full Windows, Windows PE, or Task Sequence).
    Aliases: LogDir, LogPath

    .PARAMETER ContinueOnError
    Suppresses terminating errors and allows the script to continue past non-critical failures.

    .EXAMPLE
    .\Invoke-HardwareHashOperation.ps1 -Export

    Extracts the hardware hash and saves the CSV to the default location
    (Content\HardwareHashes\<SerialNumber>.csv).

    .EXAMPLE
    .\Invoke-HardwareHashOperation.ps1 -Export -ExportPath "C:\Autopilot\DeviceHash.csv" -Overwrite

    Extracts and exports the hardware hash to a custom path, overwriting any existing file.

    .EXAMPLE
    .\Invoke-HardwareHashOperation.ps1 -ExportToRemovableDisk -Overwrite

    Exports the hardware hash CSV to all detected removable USB drives, overwriting existing files.

    .EXAMPLE
    .\Invoke-HardwareHashOperation.ps1 -SendWebhook -WebhookURI "https://api.example.com/autopilot"

    Sends full device information (hardware hash + decoded hardware inventory) to a webhook endpoint.

    .EXAMPLE
    .\Invoke-HardwareHashOperation.ps1 -SendWebhook -WebhookURI "https://api.example.com/autopilot" -WebhookHeaders '{"Authorization": "Bearer YOUR_TOKEN"}' -ExcludeSystemInformation

    Sends only Autopilot hash fields to the webhook with a bearer token, excluding hardware inventory data.

    .EXAMPLE
    Invoke-HardwareHashOperation.exe -Export -ExportToRemovableDisk -SendWebhook -WebhookURI "https://api.example.com/autopilot" -Overwrite

    Uses the PSBootstrapper executable (handles elevation automatically) to export to the default path,
    all USB drives, and send a webhook.

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%ScriptRoot%\Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError

    Task sequence usage - exports to removable drives and continues execution even if errors occur.

    .NOTES
    Requirements:
    - PowerShell 5.0 or higher
    - Administrator privileges (script will self-elevate if needed)
    - OA3Tool.exe — obtain from the Windows ADK (Deployment Tools feature) and place in Toolkit\Tools\X64\
      Download: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
      ADK path:  C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Licensing\OA3\oa3tool.exe
    - PCPKsp.dll — only required in Toolkit\Tools\X64\ when running in WinPE without the WinPE-SecureStartup
      optional component. Copy from C:\Windows\System32\PCPKsp.dll on any Windows 10/11 x64 system.
      On full Windows and WinPE images that include WinPE-SecureStartup, the script finds it automatically.
    - Network connectivity (only required for -SendWebhook)

    In Windows PE, the WinPE-SecureStartup optional component should be present in the boot image.
    Without it, hardware hashes can still be collected, but Self-Deploying Autopilot profiles will NOT
    work because TPM information cannot be fully harvested in Windows PE without this component.

    Log files are automatically rotated, retaining only the 3 most recent logs.

    .LINK
    https://learn.microsoft.com/en-us/autopilot/add-devices

    .LINK
    https://learn.microsoft.com/en-us/autopilot/

    .LINK
    https://mikemdm.de/2023/01/29/can-you-create-a-autopilot-hash-from-winpe-yes/

    .LINK
    https://oofhours.com/2022/06/03/breaking-down-the-windows-autopilot-hardware-hash/
#>

[CmdletBinding(SupportsShouldProcess=$True)]
  Param
    (        	     
        [Parameter(Mandatory=$False)]
        [Alias('E')]
        [Switch]$Export,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('EP')]
        [System.IO.FileInfo]$ExportPath,
        
        [Parameter(Mandatory=$False)]
        [Alias('ETRD')]
        [Switch]$ExportToRemovableDisk,

        [Parameter(Mandatory=$False)]
        [Alias('O')]
        [Switch]$Overwrite,

        [Parameter(Mandatory=$False)]
        [Alias('SWH')]
        [Switch]$SendWebhook,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('WHURI')]
        [System.URI]$WebhookURI,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('WHHeaders', 'Headers')]
        [System.String]$WebhookHeaders,

        [Parameter(Mandatory=$False)]
        [Alias('ESI')]
        [Switch]$ExcludeSystemInformation,
            
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('LogDir', 'LogPath')]
        [System.IO.DirectoryInfo]$LogDirectory,
            
        [Parameter(Mandatory=$False)]
        [Switch]$ContinueOnError
    )

Function Test-ProcessElevationStatus
    {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList ($Identity)
        $Result = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        Write-Output -InputObject ($Result)
    }

Switch (Test-ProcessElevationStatus)
  {
      Default
        {
            Try
              {
                  #region Define Default Action Preferences
                    $Script:DebugPreference = 'SilentlyContinue'
                    $Script:ErrorActionPreference = 'Stop'
                    $Script:VerbosePreference = 'SilentlyContinue'
                    $Script:WarningPreference = 'Continue'
                    $Script:ConfirmPreference = 'None'
                    $Script:WhatIfPreference = $False
                  #endregion
                
                  #region Set the default exit code for the script (By default, the script will exit with an exit code of 0)
                    [System.Environment]::ExitCode = 0
                  #endregion

                  #region Initialize Toolkit (This operation loads functions, modules, and variables into the current session, so if you do not see a variable defined below, it is because it is defined in the Toolkit)  
                    Try 
                      {
                          [System.IO.FileInfo]$ToolkitScriptPath = "$([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition))\Toolkit\Toolkit.ps1"

                          . "$($ToolkitScriptPath.FullName)" -CallingScriptInvocationInfo ($MyInvocation) -CallingScriptParameterSetName ($PSCmdlet.ParameterSetName)
                      }
                    Catch
                      {
                          [System.Environment]::ExitCode = 6000

                          Throw
                      }    
                  #endregion

                  #region Set default parameter values
                    Switch ($True)
                      {
                          {($Export.IsPresent -eq $True) -and ([System.String]::IsNullOrEmpty($ExportPath) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($ExportPath) -eq $True)}
                            {
                                $ExportPath = [System.IO.FileInfo][System.IO.Path]::Combine($ContentDirectory.FullName, 'HardwareHashes', "$($Bios.SerialNumber).csv")
                            }
                      }
                  #endregion

                  #region Perform Script Actions
                    
                    #region Harvest and optionally export the hardware hash to a removable flash drive
                      Switch ($IsWindowsPE)
                        {
                            {($_ -eq $True)}
                              {
                                  $PCPKSPList = Get-ChildItem -Path @([System.Environment]::SystemDirectory, $ToolsDirectory_OSArchSpecific.FullName) -Filter 'PCPKsp.dll' -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])} | Sort-Object -Property @('LastWriteTime') -Descending

                                  $PCPKSPListCount = ($PCPKSPList | Measure-Object).Count

                                  Switch ($PCPKSPListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $PCPKSPPath = $PCPKSPList | Select-Object -First 1

                                              $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                              $StartProcessWithOutputParameters.FilePath = 'rundll32.exe'
	                                              $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                              $StartProcessWithOutputParameters.ArgumentList.Add("`"$($PCPKSPPath.FullName)`",DllInstall")
	                                              $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
	                                              $StartProcessWithOutputParameters.CreateNoWindow = $True
	                                              $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromSeconds(30)
	                                              $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(5)
	                                              $StartProcessWithOutputParameters.LogOutput = $True
	                                              $StartProcessWithOutputParameters.ContinueOnError = $False
	                                              $StartProcessWithOutputParameters.Verbose = $True

                                              $PCPKSPRegistrationResult = Start-ProcessWithOutput @StartProcessWithOutputParameters
                                          }
                                    }
                              }
                        }

                      $OA3ToolPath = [System.IO.FileInfo][System.IO.Path]::Combine($ToolsDirectory_OSArchSpecific.FullName, 'oa3tool.exe')

                      $OA3CFGPath = [System.IO.FileInfo][System.IO.Path]::Combine($OA3ToolPath.Directory.FullName, 'OA3.cfg')

                      Switch (($OA3ToolPath.Exists -eq $True) -and ($OA3CFGPath.Exists -eq $True))
                        {
                            {($_ -eq $True)}
                              {
                                  $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                  $StartProcessWithOutputParameters.FilePath = $OA3ToolPath.FullName
                                    $StartProcessWithOutputParameters.WorkingDirectory = [System.IO.Path]::Combine($CallingScriptTemporaryDirectory.FullName, 'OA3Results')
	                                  $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                  $StartProcessWithOutputParameters.ArgumentList.Add("/Report")
                                      $StartProcessWithOutputParameters.ArgumentList.Add("/ConfigFile=`"$($OA3CFGPath.FullName)`"")
                                      $StartProcessWithOutputParameters.ArgumentList.Add("/NoKeyCheck")
	                                  $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
	                                  $StartProcessWithOutputParameters.CreateNoWindow = $True
	                                  $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromSeconds(30)
	                                  $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(5)
	                                  $StartProcessWithOutputParameters.LogOutput = $True
	                                  $StartProcessWithOutputParameters.ContinueOnError = $False
	                                  $StartProcessWithOutputParameters.Verbose = $True

                                  $ExistingHardwareHashXMLList = Try {Get-ChildItem -Path ($StartProcessWithOutputParameters.WorkingDirectory) -Filter '*.xml' -Recurse -Force -ErrorAction SilentlyContinue} Catch {$Null}
                                                                
                                  $ExistingHardwareHashXMLListCount = ($ExistingHardwareHashXMLList | Measure-Object).Count
                                
                                  $ExistingHardwareHashXMLListCounter = 1
                                
                                  For ($ExistingHardwareHashXMLListIndex = 0; $ExistingHardwareHashXMLListIndex -lt $ExistingHardwareHashXMLListCount; $ExistingHardwareHashXMLListIndex++)
                                    {
                                        Try
                                          {
                                              $ExistingHardwareHashXML = $ExistingHardwareHashXMLList[$ExistingHardwareHashXMLListIndex]

                                              $WriteLogMessage.Invoke(0, @("Attempting to delete existing hardware hash XML $($ExistingHardwareHashXMLListCounter) of $($ExistingHardwareHashXMLListCount). Please Wait...", "Path: $($ExistingHardwareHashXML.FullName)"))

                                              $Null = [System.IO.File]::Delete($ExistingHardwareHashXML.FullName)
                                          }
                                        Catch
                                          {
                                            
                                          }
                                        Finally
                                          {
                                              $ExistingHardwareHashXMLListCounter++
                                          }
                                    }
                                
                                  $PauseScriptExecution.Invoke(([System.TimeSpan]::FromSeconds(2)))
                                
                                  $HardwareHashRetrievalResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                  $PauseScriptExecution.Invoke(([System.TimeSpan]::FromSeconds(2)))

                                  Switch ($HardwareHashRetrievalResult.ExitCode -iin @($StartProcessWithOutputParameters.AcceptableExitCodeList))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $OA3XMLPath = Get-ChildItem -Path ($StartProcessWithOutputParameters.WorkingDirectory) -Filter '*.xml' -Force -Verbose -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])} | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -First 1

                                              Switch (($Null -ine $OA3XMLPath) -and ($OA3XMLPath.Exists -eq $True))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $OA3XMLContent = [System.IO.File]::ReadAllText($OA3XMLPath.FullName, $TextEncoder)

                                                          $OA3XMLDocument = New-Object -TypeName 'System.XML.XMLDocument'
                                                            $OA3XMLDocument.LoadXml($OA3XMLContent)

                                                          $HardwareHashNode = $OA3XMLDocument.SelectSingleNode('/Key/HardwareHash')

                                                          $HardwareHash = $HardwareHashNode.'#text'

                                                          $HardwareHashExists = ([System.String]::IsNullOrEmpty($HardwareHash) -eq $False) -and ([System.String]::IsNullOrWhiteSpace($HardwareHash) -eq $False)

                                                          $WriteLogMessage.Invoke(0, @("Hardware Hash Exists: $($HardwareHashExists)"))
                                                        
                                                          Switch ($HardwareHashExists)
                                                            {
                                                                {($_ -eq $True)}
                                                                  {
                                                                      $WriteLogMessage.Invoke(0, @("Hardware Hash: $($HardwareHash)"))

                                                                      $DecodedHardwareHashProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                        $DecodedHardwareHashProperties['HardwareHash'] = $HardwareHash

                                                                      $WriteLogMessage.Invoke(0, @("Attempting to decode hardware hash. Please Wait..."))

                                                                      $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                                                      $StartProcessWithOutputParameters.FilePath = $OA3ToolPath.FullName
                                                                        $StartProcessWithOutputParameters.WorkingDirectory = [System.IO.Path]::Combine($CallingScriptTemporaryDirectory.FullName, 'OA3Results')
	                                                                      $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                          $StartProcessWithOutputParameters.ArgumentList.Add("/decodehwhash:`"$($HardwareHash)`"")
	                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
	                                                                      $StartProcessWithOutputParameters.CreateNoWindow = $True
	                                                                      $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromSeconds(30)
	                                                                      $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(5)
	                                                                      $StartProcessWithOutputParameters.LogOutput = $True
	                                                                      $StartProcessWithOutputParameters.ContinueOnError = $True
	                                                                      $StartProcessWithOutputParameters.Verbose = $True

                                                                      $HardwareHashDecodeResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                                                      Switch ($HardwareHashDecodeResult.ExitCode -iin @($StartProcessWithOutputParameters.AcceptableExitCodeList))
                                                                        {
                                                                            {($_ -eq $True)}
                                                                              {
                                                                                  Try
                                                                                    {
                                                                                        $HardwareHashDecodedXMLContent = $HardwareHashDecodeResult.StandardOutput.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object {($_ -imatch '.*\<.*\>')} | Out-String
                                                                                  
                                                                                        Switch (([System.String]::IsNullOrEmpty($HardwareHashDecodedXMLContent) -eq $False) -and ([System.String]::IsNullOrWhiteSpace($HardwareHashDecodedXMLContent) -eq $False))
                                                                                          {
                                                                                              {($_ -eq $True)}
                                                                                                {
                                                                                                    $HardwareHashDecodedXMLDocument = New-Object -TypeName 'System.XML.XMLDocument'
                                                                                                      $HardwareHashDecodedXMLDocument.LoadXml($HardwareHashDecodedXMLContent)
                                                                                  
                                                                                                    $DecodedHardwareHashNodeList = $HardwareHashDecodedXMLDocument.SelectNodes('/HardwareReport/HardwareInventory/p')

                                                                                                    $DecodedHardwareHashNodeListCount = ($DecodedHardwareHashNodeList | Measure-Object).Count

                                                                                                    $WriteLogMessage.Invoke(0, @("Found $($DecodedHardwareHashNodeListCount) decoded hardware hash properties."))

                                                                                                    Switch ($DecodedHardwareHashNodeListCount -gt 0)
                                                                                                      {
                                                                                                          {($_ -eq $True)}
                                                                                                            {                                                                                                                
                                                                                                                For ($DecodedHardwareHashNodeListIndex = 0; $DecodedHardwareHashNodeListIndex -lt $DecodedHardwareHashNodeListCount; $DecodedHardwareHashNodeListIndex++)
                                                                                                                  {
                                                                                                                      $DecodedHardwareHashNode = $DecodedHardwareHashNodeList[$DecodedHardwareHashNodeListIndex]

                                                                                                                      $DecodedHardwareHashNodePropertyName = $DecodedHardwareHashNode.n -replace '\s*\([^)]*\)', ''

                                                                                                                      $DecodedHardwareHashNodePropertyValue = $DecodedHardwareHashNode.v

                                                                                                                      $DecodedHardwareHashProperties["$($DecodedHardwareHashNodePropertyName)"] = $DecodedHardwareHashNodePropertyValue

                                                                                                                      $WriteLogMessage.Invoke(0, @("$($DecodedHardwareHashNodePropertyName): $($DecodedHardwareHashNodePropertyValue)"))
                                                                                                                  }
                                                                                                            }
                                                                                                      }
                                                                                                }
                                                                                          }
                                                                                    }
                                                                                  Catch
                                                                                    {
                                                                                        $ErrorHandlingDefinition.Invoke($Error[0], 2, $True)
                                                                                    }
                                                                                  Finally
                                                                                    {
                                                                                        
                                                                                    }
                                                                              }
                                                                        }
                                                                      
                                                                      $WriteLogMessage.Invoke(0, @("Attempting to build the Autopilot hardware hash CSV object. Please Wait..."))

                                                                      $HardwareHashObjectList = New-Object -TypeName 'System.Collections.Generic.List[System.Management.Automation.PSObject]'
                                                                    
                                                                      $HardwareHashObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                        $HardwareHashObjectProperties.'Device Serial Number' = $Bios.SerialNumber.ToUpper()
                                                                        $HardwareHashObjectProperties.'Windows Product ID' = ''
                                                                        $HardwareHashObjectProperties.'Hardware Hash' = $HardwareHash
                                                                        $HardwareHashObjectProperties.'Group Tag' = ''
                                                                        $HardwareHashObjectProperties.'Assigned User' = ''

                                                                      Switch ($IsRunningTaskSequence)
                                                                        {
                                                                            {($_ -eq $True)}
                                                                              {
                                                                                  Switch ($True)
                                                                                    {
                                                                                        {($TSVariableTable.Contains('EntraIDGroupTag') -eq $True) -and (([System.String]::IsNullOrEmpty(($TSVariableTable.'EntraIDGroupTag')) -eq $False) -and ([System.String]::IsNullOrWhiteSpace(($TSVariableTable.'EntraIDGroupTag')) -eq $False))}
                                                                                          {
                                                                                              $HardwareHashObjectProperties.'Group Tag' = $TSVariableTable.'EntraIDGroupTag'
                                                                                          }

                                                                                        {($TSVariableTable.Contains('EntraIDAssignedUser') -eq $True) -and (([System.String]::IsNullOrEmpty(($TSVariableTable.'EntraIDAssignedUser')) -eq $False) -and ([System.String]::IsNullOrWhiteSpace(($TSVariableTable.'EntraIDAssignedUser')) -eq $False))}
                                                                                          {
                                                                                              $HardwareHashObjectProperties.'Assigned User' = $TSVariableTable.'EntraIDAssignedUser'
                                                                                          }
                                                                                    }
                                                                              }
                                                                        }
                                                                      				
                                                                      $HardwareHashObject = New-Object -TypeName 'System.Management.Automation.PSObject' -Property ($HardwareHashObjectProperties)

                                                                      $HardwareHashObjectList.Add($HardwareHashObject)

                                                                      Switch ($Null -ine $HardwareHashObjectList)
                                                                        {
                                                                            {($_ -eq $True)}
                                                                              {
                                                                                  $WriteLogMessage.Invoke(0, @("Attempting to build the Autopilot hardware hash CSV content. Please Wait..."))
                                                                                
                                                                                  $HardwareHashCSVObject = $HardwareHashObjectList | ConvertTo-CSV -Delimiter ',' -NoTypeInformation
                                                                                
                                                                                  $HardwareHashCSVContent = $HardwareHashCSVObject -ireplace '(\")', '' | Out-String
                                                                                
                                                                                  $HardwareHashCSVExportPathList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.FileInfo]'
                                                                                    
                                                                                  Switch ($True)
                                                                                    {
                                                                                        {($Export.IsPresent)}
                                                                                          {
                                                                                              $HardwareHashCSVExportPathList.Add($ExportPath.FullName)
                                                                                          }
                                                                                        
                                                                                        {($ExportToRemovableDisk.IsPresent)}
                                                                                          {
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to retrieve the list of available drives. Please Wait..."))
                                                                                            
                                                                                              $DriveList = [System.IO.DriveInfo]::GetDrives()

                                                                                              $DriveListCount = ($DriveList | Measure-Object).Count

                                                                                              $WriteLogMessage.Invoke(0, @("Available Drive Count: $($DriveListCount)"))

                                                                                              Switch ($DriveListCount -gt 0)
                                                                                                {
                                                                                                    {($_ -eq $True)}
                                                                                                      {
                                                                                                          $WriteLogMessage.Invoke(0, @("Attempting to filter the list of available drives for removable drives. Please Wait..."))
                                                                                            
                                                                                                          $RemovableDriveList = $DriveList | Where-Object {($_.DriveType -iin @('Removable')) -and ($_.IsReady -eq $True) -and ($_.TotalSize -gt 0) -and (([String]::IsNullOrEmpty($_.Name) -eq $False) -or ([String]::IsNullOrEmpty($_.RootDirectory) -eq $False))}
                                                                                            
                                                                                                          $RemovableDriveListCount = ($RemovableDriveList | Measure-Object).Count

                                                                                                          $WriteLogMessage.Invoke(0, @("Removable Drive List Count: $($RemovableDriveListCount)"))

                                                                                                          Switch ($RemovableDriveListCount -gt 0)
                                                                                                            {
                                                                                                                {($_ -eq $True)}
                                                                                                                  {
                                                                                                                      $RemovableDriveListCounter = 1
                                                                                                                    
                                                                                                                      For ($RemovableDriveListIndex = 0; $RemovableDriveListIndex -lt $RemovableDriveListCount; $RemovableDriveListIndex++)
                                                                                                                        {
                                                                                                                            Try
                                                                                                                              {
                                                                                                                                  $WriteLogMessage.Invoke(0, @("Attempting to process removable drive $($RemovableDriveListCounter) of $($RemovableDriveListCount). Please Wait..."))
                                                                                                                                
                                                                                                                                  $RemovableDrive = $RemovableDriveList[$RemovableDriveListIndex]

                                                                                                                                  $RemovableDriveLogMessageList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                                                
                                                                                                                                  ForEach ($RemovableDriveProperty In $RemovableDrive.PSObject.Properties)
                                                                                                                                    {
                                                                                                                                        $RemovableDriveLogMessageList.Add("[$($RemovableDriveProperty.Name): $($RemovableDriveProperty.Value)]")
                                                                                                                                    }
                                                                                                                                
                                                                                                                                  $WriteLogMessage.Invoke(0, @("$($RemovableDriveLogMessageList -Join ' ')"))

                                                                                                                                  $RemovableDriveHardHashExportPath = [System.IO.FileInfo][System.IO.Path]::Combine($RemovableDrive.RootDirectory, 'HardwareHashes', "$($Bios.SerialNumber.ToUpper()).csv")

                                                                                                                                  $WriteLogMessage.Invoke(0, @("Removable Drive Export Path: $($RemovableDriveHardHashExportPath.FullName)"))
                                                                                                                                
                                                                                                                                  $HardwareHashCSVExportPathList.Add($RemovableDriveHardHashExportPath.FullName)
                                                                                                                              }
                                                                                                                            Catch
                                                                                                                              {
                                                                                                                                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $True)
                                                                                                                              }
                                                                                                                            Finally
                                                                                                                              {
                                                                                                                                  $RemovableDriveListCounter++
                                                                                                                              }
                                                                                                                        }
                                                                                                                  }
                                                                                                            }
                                                                                                      }
                                                                                                }
                                                                                          }
                                                                                    }
                                                                                  
                                                                                  $HardwareHashCSVExportPathListCount = ($HardwareHashCSVExportPathList | Measure-Object).Count

                                                                                  $HardwareHashCSVExportPathListCounter = 1
                                                                                
                                                                                  For ($HardwareHashCSVExportPathListIndex = 0; $HardwareHashCSVExportPathListIndex -lt $HardwareHashCSVExportPathListCount; $HardwareHashCSVExportPathListIndex++)
                                                                                    {
                                                                                         Try
                                                                                          {
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to process hardware hash CSV $($HardwareHashCSVExportPathListCounter) of $($HardwareHashCSVExportPathListCount). Please Wait..."))

                                                                                              $HardwareHashCSVExportPath = $HardwareHashCSVExportPathList[$HardwareHashCSVExportPathListIndex]
                                                                                              
                                                                                              $WriteLogMessage.Invoke(0, @("Hardware Hash CSV Export Path: $($HardwareHashCSVExportPath.FullName)", "Hardware Hash CSV Export Path Exists: $($HardwareHashCSVExportPath.Exists)", "Overwrite: $($Overwrite.IsPresent)"))

                                                                                              Switch (([System.IO.File]::Exists($HardwareHashCSVExportPath.FullName) -eq $False) -or ($Overwrite.IsPresent -eq $True))
                                                                                                {
                                                                                                    {($_ -eq $True)}
                                                                                                      {
                                                                                                          $WriteLogMessage.Invoke(0, @("Attempting to process export hash CSV $($HardwareHashCSVExportPathListCounter) of $($HardwareHashCSVExportPathListCount). Please Wait..."))

                                                                                                          If ($HardwareHashCSVExportPath.Directory.Exists -eq $False) {$Null = $HardwareHashCSVExportPath.Directory.Create()}
                                                                                              
                                                                                                          $Null = [System.IO.File]::WriteAllText($HardwareHashCSVExportPath.FullName, $HardwareHashCSVContent, $TextEncoder)
                                                                                                      }
                                                                                                }
                                                                                          }
                                                                                        Catch
                                                                                          {
                                                                                              $ErrorHandlingDefinition.Invoke($Error[0], 2, $True)
                                                                                          }
                                                                                        Finally
                                                                                          {
                                                                                              $HardwareHashCSVExportPathListCounter++
                                                                                          }
                                                                                    }
                                                                              }
                                                                        }
                                                                  }
                                                            }
                                                      }
                                                }
                                          }
                                    }
                              }
                        }
                      #endregion
                                            
                      #region Send a webhook to automate the hardware hash upload and/or verification (Something like N8N or Zapier)
                        $WriteLogMessage.Invoke(0, @("Send Webhook: $($SendWebhook.IsPresent)"))
                                                                  
                        Switch ($SendWebhook.IsPresent)
                          {
                              {($_ -eq $True)}
                                {            
                                    $IsNetworkConnected = $GetNetworkConnectionInformation.Invoke()
                                    
                                    $IsInternetConnected = $TestNetworkConnectivity.Invoke('https://www.google.com')
                            
                                    Switch (($IsNetworkConnected -eq $True) -and ($IsInternetConnected -eq $True))
                                      {
                                          {($_ -eq $True)}
                                            {
                                                $WriteLogMessage.Invoke(0, @("The conditions for sending a webhook (HTTP Web Request) were met."))
                                                
                                                $WebhookHeaderObject = $WebhookHeaders | ConvertFrom-JSON
                                                
                                                $WebhookHeaderDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                  
                                                $Null = $WebhookHeaderObject.PSObject.Properties | ForEach-Object {$WebhookHeaderDictionary[$_.Name] = ($_.Value)}
                                                                                                
                                                Switch ($ExcludeSystemInformation.IsPresent)
                                                  {
                                                      {($_ -eq $True)}
                                                        {
                                                            $WebRequestBodyObject = $HardwareHashObjectProperties
                                                        }
                                          
                                                      Default
                                                        {
                                                            $WebRequestBodyObject = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                                                            #region Normalize decoded hardware hash properties for downstream asset management systems
                                                            $GPUDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                                                            $DiskDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                                                            $SecuredCoreCriteriaDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                                                            ForEach ($DecodedHardwareHashProperty In $DecodedHardwareHashProperties.GetEnumerator())
                                                              {
                                                                  $DecodedHardwareHashPropertyName = $DecodedHardwareHashProperty.Key

                                                                  $DecodedHardwareHashPropertyValue = $DecodedHardwareHashProperty.Value

                                                                  Switch ($True)
                                                                    {
                                                                        #region Group GPU properties (Gpu1.Model, Gpu2.Manufacturer, etc.) into a dictionary keyed by GPU index
                                                                        {($DecodedHardwareHashPropertyName -imatch '^Gpu([0-9]+)\.')}
                                                                          {
                                                                              $Null = $DecodedHardwareHashPropertyName -imatch '^Gpu([0-9]+)\.(.+)$'

                                                                              $GPUIndex = $Matches[1]

                                                                              $GPUPropertyName = $Matches[2]

                                                                              Switch (([String]::IsNullOrEmpty($GPUIndex) -eq $False) -and ([String]::IsNullOrEmpty($GPUPropertyName) -eq $False))
                                                                                {
                                                                                    {($_ -eq $True)}
                                                                                      {
                                                                                          Switch ($GPUDictionary.Contains($GPUIndex))
                                                                                            {
                                                                                                {($_ -eq $False)}
                                                                                                  {
                                                                                                      $GPUDictionary[$GPUIndex] = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                  }
                                                                                            }

                                                                                          $GPUDictionary[$GPUIndex][$GPUPropertyName] = $DecodedHardwareHashPropertyValue
                                                                                      }
                                                                                }
                                                                          }
                                                                        #endregion

                                                                        #region Group Disk properties (Disk1.DiskCapacity, Disk1.DiskType, etc.) into a dictionary keyed by Disk index
                                                                        {($DecodedHardwareHashPropertyName -imatch '^Disk([0-9]+)\.')}
                                                                          {
                                                                              $Null = $DecodedHardwareHashPropertyName -imatch '^Disk([0-9]+)\.(.+)$'

                                                                              $DiskIndex = $Matches[1]

                                                                              $DiskPropertyName = $Matches[2]

                                                                              Switch (([String]::IsNullOrEmpty($DiskIndex) -eq $False) -and ([String]::IsNullOrEmpty($DiskPropertyName) -eq $False))
                                                                                {
                                                                                    {($_ -eq $True)}
                                                                                      {
                                                                                          Switch ($DiskDictionary.Contains($DiskIndex))
                                                                                            {
                                                                                                {($_ -eq $False)}
                                                                                                  {
                                                                                                      $DiskDictionary[$DiskIndex] = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                  }
                                                                                            }

                                                                                          $DiskDictionary[$DiskIndex][$DiskPropertyName] = $DecodedHardwareHashPropertyValue
                                                                                      }
                                                                                }
                                                                          }
                                                                        #endregion

                                                                        #region Group SecuredCoreCriteria properties (SecuredCoreCriteria.TPM20, etc.) into a nested dictionary
                                                                        {($DecodedHardwareHashPropertyName -imatch '^SecuredCoreCriteria\.')}
                                                                          {
                                                                              $Null = $DecodedHardwareHashPropertyName -imatch '^SecuredCoreCriteria\.(.+)$'

                                                                              $SecuredCoreCriteriaPropertyName = $Matches[1]

                                                                              Switch ([String]::IsNullOrEmpty($SecuredCoreCriteriaPropertyName) -eq $False)
                                                                                {
                                                                                    {($_ -eq $True)}
                                                                                      {
                                                                                          $SecuredCoreCriteriaDictionary[$SecuredCoreCriteriaPropertyName] = $DecodedHardwareHashPropertyValue
                                                                                      }
                                                                                }
                                                                          }
                                                                        #endregion

                                                                        #region Parse TPMVersion compound string into a structured TPM object
                                                                        {($DecodedHardwareHashPropertyName -ieq 'TPMVersion')}
                                                                          {
                                                                              $TPMDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                $TPMDictionary['Raw'] = $DecodedHardwareHashPropertyValue

                                                                              $TPMSegments = $DecodedHardwareHashPropertyValue -split '\s*-(?=[A-Za-z])'

                                                                              ForEach ($TPMSegment In $TPMSegments)
                                                                                {
                                                                                    $TPMSegmentParts = $TPMSegment -split ':', 2

                                                                                    Switch ($TPMSegmentParts.Count -eq 2)
                                                                                      {
                                                                                          {($_ -eq $True)}
                                                                                            {
                                                                                                $TPMDictionary[$TPMSegmentParts[0].Trim()] = $TPMSegmentParts[1].Trim().Trim("'")
                                                                                            }
                                                                                      }
                                                                                }

                                                                              $WebRequestBodyObject['TPM'] = $TPMDictionary
                                                                          }
                                                                        #endregion

                                                                        #region Normalize property names with spaces (e.g., 'TPM EkPub' becomes 'TPMEkPub')
                                                                        {($DecodedHardwareHashPropertyName -imatch '\s')}
                                                                          {
                                                                              $NormalizedPropertyName = $DecodedHardwareHashPropertyName -replace '\s', ''

                                                                              $WebRequestBodyObject[$NormalizedPropertyName] = $DecodedHardwareHashPropertyValue
                                                                          }
                                                                        #endregion

                                                                        #region All other properties pass through as-is
                                                                        Default
                                                                          {
                                                                              $WebRequestBodyObject[$DecodedHardwareHashPropertyName] = $DecodedHardwareHashPropertyValue
                                                                          }
                                                                        #endregion
                                                                    }
                                                              }

                                                            #region Build the GPUs array from the grouped GPU dictionary
                                                            Switch ($GPUDictionary.Count -gt 0)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $GPUList = New-Object -TypeName 'System.Collections.Generic.List[System.Collections.Specialized.OrderedDictionary]'

                                                                        ForEach ($GPUEntry In $GPUDictionary.GetEnumerator())
                                                                          {
                                                                              $GPUList.Add($GPUEntry.Value)
                                                                          }

                                                                        $WebRequestBodyObject['GPUs'] = $GPUList
                                                                    }
                                                              }
                                                            #endregion

                                                            #region Build the Disks array from the grouped Disk dictionary
                                                            Switch ($DiskDictionary.Count -gt 0)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $DiskList = New-Object -TypeName 'System.Collections.Generic.List[System.Collections.Specialized.OrderedDictionary]'

                                                                        ForEach ($DiskEntry In $DiskDictionary.GetEnumerator())
                                                                          {
                                                                              $DiskList.Add($DiskEntry.Value)
                                                                          }

                                                                        $WebRequestBodyObject['Disks'] = $DiskList
                                                                    }
                                                              }
                                                            #endregion

                                                            #region Add the SecuredCoreCriteria nested object
                                                            Switch ($SecuredCoreCriteriaDictionary.Count -gt 0)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $WebRequestBodyObject['SecuredCoreCriteria'] = $SecuredCoreCriteriaDictionary
                                                                    }
                                                              }
                                                            #endregion
                                                            
                                                            #region Add additional custom fields   
                                                            $WebRequestBodyObject.AssetManagement = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                              $WebRequestBodyObject.AssetManagement.Manufacturer = $WebRequestBodyObject.SmbiosSystemManufacturer
                                                              $WebRequestBodyObject.AssetManagement.Model = $WebRequestBodyObject.SmbiosSystemProductName
                                                              $WebRequestBodyObject.AssetManagement.SystemID = $WebRequestBodyObject.SmbiosSystemVersion
                                                              $WebRequestBodyObject.AssetManagement.SerialNumber = $WebRequestBodyObject.SmbiosSystemSerialNumber
                                                                
                                                            Switch ($WebRequestBodyObject.AssetManagement.Manufacturer)
                                                              {
                                                                  {($_ -imatch '.*(LENOVO).*')}
                                                                    {
                                                                        $WebRequestBodyObject.AssetManagement.Model = $WebRequestBodyObject.SmbiosSystemVersion
                                                                        $WebRequestBodyObject.AssetManagement.SystemID = $WebRequestBodyObject.SmbiosSystemProductName
                                                                    }
                                                              }
                                                              
                                                            $SystemEnclosure = Get-CIMInstance -Namespace 'root\CIMv2' -ClassName 'Win32_SystemEnclosure' -Property '*'

                                                            $WebRequestBodyObject.AssetManagement.ChassisTypeNumber = $SystemEnclosure.ChassisTypes[0]
                                                            $WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Unknown'
                                                            $WebRequestBodyObject.AssetManagement.ChassisTypeGroup = 'Unknown'

                                                            Switch ($WebRequestBodyObject.AssetManagement.ChassisTypeNumber)
                                                              {
                                                                  {($_ -eq 1)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Other'}
                                                                  {($_ -eq 2)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Unknown'}
                                                                  {($_ -eq 3)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Desktop'}
                                                                  {($_ -eq 4)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Low Profile Desktop'}
                                                                  {($_ -eq 5)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Pizza Box'}
                                                                  {($_ -eq 6)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Mini Tower'}
                                                                  {($_ -eq 7)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Tower'}
                                                                  {($_ -eq 8)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Portable'}
                                                                  {($_ -eq 9)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Laptop'}
                                                                  {($_ -eq 10)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Notebook'}
                                                                  {($_ -eq 11)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Hand Held'}
                                                                  {($_ -eq 12)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Docking Station'}
                                                                  {($_ -eq 13)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'All in One'}
                                                                  {($_ -eq 14)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Sub Notebook'}
                                                                  {($_ -eq 15)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Space-Saving'}
                                                                  {($_ -eq 16)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Lunch Box'}
                                                                  {($_ -eq 17)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Main System Chassis'}
                                                                  {($_ -eq 18)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Expansion Chassis'}
                                                                  {($_ -eq 19)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'SubChassis'}
                                                                  {($_ -eq 20)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Bus Expansion Chassis'}
                                                                  {($_ -eq 21)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Peripheral Chassis'}
                                                                  {($_ -eq 22)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Storage Chassis'}
                                                                  {($_ -eq 23)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Rack Mount Chassis'}
                                                                  {($_ -eq 24)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Sealed-Case PC'}
                                                                  {($_ -eq 30)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Tablet'}
                                                                  {($_ -eq 31)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Convertible'}
                                                                  {($_ -eq 32)} {$WebRequestBodyObject.AssetManagement.ChassisTypeName = 'Detachable'}
                                                              }

                                                            Switch ($WebRequestBodyObject.AssetManagement.ChassisTypeNumber)
                                                              {
                                                                  {($_ -in @(3, 4, 5, 6, 7, 13, 15, 16, 24))} {$WebRequestBodyObject.AssetManagement.ChassisTypeGroup = 'Desktop'}
                                                                  {($_ -in @(8, 9, 10, 11, 12,14, 30, 31, 32))} {$WebRequestBodyObject.AssetManagement.ChassisTypeGroup = 'Laptop'}
                                                                  {($_ -in @(17, 18, 19, 20, 21, 22, 23))} {$WebRequestBodyObject.AssetManagement.ChassisTypeGroup = 'Server'}
                                                              }
                                                            #endregion
                                                              
                                                            #endregion
                                                        }
                                                  }
                                                  
                                                $WebRequestBodyObjectAsJSON = $WebRequestBodyObject | ConvertTo-JSON -Depth 10 -Compress:$True
                                        
                                                $InvokeWebRequestParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                  $InvokeWebRequestParameters.UseBasicParsing = $True
                                                  $InvokeWebRequestParameters.Uri = $WebhookURI
                                                  $InvokeWebRequestParameters.Method = 'Post'
                                                  $InvokeWebRequestParameters.UseDefaultCredentials = $True
                                                  $InvokeWebRequestParameters.UserAgent = $CallingScriptPath.BaseName
                                                  $InvokeWebRequestParameters.TimeoutSec = 30
                                                  $InvokeWebRequestParameters.Headers = $WebhookHeaderDictionary
                                                  $InvokeWebRequestParameters.Body = $WebRequestBodyObjectAsJSON
                                                  $InvokeWebRequestParameters.ContentType = "application/json"
                                                  $InvokeWebRequestParameters.Verbose = $False
                                                  
                                                $WriteLogMessage.Invoke(0, @("Attempting to send a webhook to the specified destination. Please Wait...", "URL: $($WebhookURI.OriginalString)", "Method: $($InvokeWebRequestParameters.Method.ToString())", "User Agent: $($InvokeWebRequestParameters.UserAgent)", "ContentType: $($InvokeWebRequestParameters.ContentType)"))

                                                $InvokeWebRequestResult = Invoke-WebRequest @InvokeWebRequestParameters
                                                
                                                $WriteLogMessage.Invoke(0, @("Status Code: $($InvokeWebRequestResult.StatusCode)", "Status Description: $($InvokeWebRequestResult.StatusDescription)", "Response Content Length: $($InvokeWebRequestResult.Content.Length)"))

                                                Switch (([String]::IsNullOrEmpty($InvokeWebRequestResult.Content) -eq $False) -and ([String]::IsNullOrWhiteSpace($InvokeWebRequestResult.Content) -eq $False))
                                                  {
                                                      {($_ -eq $True)}
                                                        {                                                            
                                                            $WebRequestResponseContent = $InvokeWebRequestResult.Content | ConvertFrom-JSON -Verbose:$False | ConvertTo-JSON -Depth 10 -Compress:$False -Verbose:$False
                                                            
                                                            $WriteLogMessage.Invoke(0, @("Web Request Response: `r`n`r`n$($WebRequestResponseContent)"))
                                                        }
                                                  }
                                            }

                                          Default
                                            {
                                                $WriteLogMessage.Invoke(2, @("The conditions for sending a webhook (HTTP Web Request) were not met. No further action will be taken."))
                                            }
                                      }
                                }
                          }
                      #endregion
              }
            Catch
              {
                  #region Perform error handling actions
                    $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                  #endregion
              }
            Finally
              {                
                  #region Perform finalization actions
                    $FinalizationActions.Invoke()
                  #endregion
              }
        }

      {($_ -eq $False)}
        {
            [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"

            #$CurrentExecutionPolicy = Get-ExecutionPolicy -Scope Process

            $CurrentExecutionPolicy = 'Bypass'

            $ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $ArgumentList.Add("-ExecutionPolicy $($CurrentExecutionPolicy)")
              $ArgumentList.Add('-NonInteractive')
              $ArgumentList.Add('-NoProfile')
              $ArgumentList.Add('-NoLogo')
              $ArgumentList.Add('-NoExit')
              $ArgumentList.Add('-Command')   
              $ArgumentList.Add("`"`& {. `"$($ScriptPath.FullName)`"")

            $MyInvocation.UnboundArguments.GetEnumerator() | ForEach-Object {$ArgumentList.Add("-$($_.Key) @($($_.Value | ForEach-Object {`"$($_)`"}))")}
            
            $PSBoundParameters.GetEnumerator() | ForEach-Object {$ArgumentList.Add("-$($_.Key) @($($_.Value | ForEach-Object {`"$($_)`"}))")}

            $ArgumentListTargetIndex = $ArgumentList.Count - 1

            $ArgumentListIndexItem = $ArgumentList[$ArgumentListTargetIndex]

            $Null = $ArgumentList.RemoveAt($ArgumentListTargetIndex)

            $Null = $ArgumentList.Insert($ArgumentListTargetIndex, ($ArgumentListIndexItem + ';'))

            $ArgumentList.Add("[System.Environment]::Exit((`$LASTEXITCODE -Bor [Int](-Not `$? -And -Not `$LASTEXITCODE)))}`"")

            $ScriptInterpreterList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
              $ScriptInterpreterList.Add('powershell.exe')
              $ScriptInterpreterList.Add('pwsh.exe')
              
            :ScriptInterpreterListLoop ForEach ($ScriptInterpreter In $ScriptInterpreterList)
              {
                  $ScriptInterpreterObject = Try {Get-Command -Name ($ScriptInterpreter) -ErrorAction SilentlyContinue} Catch {$Null}
                  
                  Switch ($Null -ine $ScriptInterpreterObject)
                    {
                        {($_ -eq $True)}
                          {
                              $Null = Start-Process -FilePath ($ScriptInterpreterObject.Path) -WorkingDirectory "$($Env:Temp.TrimEnd('\'))" -ArgumentList ($ArgumentList.ToArray()) -WindowStyle Normal -Verb RunAs -PassThru

                              Break ScriptInterpreterListLoop
                          }
                    }
              }
        }
  }