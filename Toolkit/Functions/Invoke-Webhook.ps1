## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Invoke-WebhookRequest
Function Invoke-WebhookRequest
    {
        <#
          .SYNOPSIS
          Sends HTTP webhook requests with optional device information payload.

          .DESCRIPTION
          This function sends HTTP webhook requests to remote endpoints with customizable headers,
          methods, and body content. It can automatically gather and include comprehensive device
          information (hardware, OS, network) in the webhook payload, making it ideal for device
          registration, inventory, or monitoring scenarios.

          Key Features:
          - Supports custom HTTP methods (GET, POST, PUT, DELETE, etc.)
          - Customizable HTTP headers for authentication
          - Optional automatic device information gathering
          - JSON payload formatting
          - Detailed logging of request and response
          - Error handling with ContinueOnError support

          .PARAMETER WebhookURI
          The URI of the webhook endpoint where the request will be sent. Must be a valid HTTP or HTTPS URL.

          Alias: WHURI, URI
          Type: System.URI
          Required: True

          Example: "https://api.example.com/webhook/devices"

          .PARAMETER WebhookHeaders
          A dictionary of custom HTTP headers to include in the request. Commonly used for authentication
          tokens, API keys, or custom headers required by the endpoint.

          Alias: WHH, Headers
          Type: System.Collections.Specialized.OrderedDictionary
          Required: False

          Example: @{"Authorization" = "Bearer TOKEN"; "X-API-Key" = "YOUR_KEY"}

          .PARAMETER WebhookMethod
          The HTTP method to use for the request. Defaults to POST if not specified.

          Alias: WRM, Method
          Type: Microsoft.PowerShell.Commands.WebRequestMethod
          Required: False
          Valid Values: Get, Post, Put, Delete, Head, Options, Trace, Patch
          Default: Post

          .PARAMETER WebhookBody
          A custom body payload to send with the request. Will be converted to JSON format automatically.
          If specified, this takes precedence over IncludeDefaultWebhookBody.

          Alias: WHB, Body
          Type: System.Collections.Specialized.OrderedDictionary
          Required: False

          .PARAMETER IncludeDefaultWebhookBody
          When specified, automatically gathers comprehensive device information and includes it in the
          webhook body. Collects OS details, hardware specs, BIOS info, CPU, memory, and more.

          Alias: IDWHB, DefaultBody
          Type: Switch
          Required: False

          .PARAMETER WebhookContentType
          The content type header for the request. Defaults to "application/json" if not specified.

          Alias: WHCT, ContentType
          Type: System.String
          Required: False
          Default: "application/json"

          .PARAMETER OutputRawResponse
          When specified, returns the raw Invoke-WebRequest response object instead of just the parsed content.

          Type: Switch
          Required: False

          .PARAMETER ContinueOnError
          Suppresses terminating errors and allows execution to continue even if the webhook request fails.

          Type: Switch
          Required: False

          .EXAMPLE
          # Basic webhook with custom body
          $InvokeWebhookRequestParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $InvokeWebhookRequestParameters.WebhookURI = "https://api.example.com/webhook"
              $InvokeWebhookRequestParameters.WebhookHeaders = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                  $InvokeWebhookRequestParameters.WebhookHeaders.Authorization = "Bearer YourAuthorizationToken"
              $InvokeWebhookRequestParameters.WebhookMethod = [Microsoft.Powershell.Commands.Webrequestmethod]::Post
              $InvokeWebhookRequestParameters.WebhookBody = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                  $InvokeWebhookRequestParameters.WebhookBody.DeviceID = "12345"
                  $InvokeWebhookRequestParameters.WebhookBody.Status = "Active"
              $InvokeWebhookRequestParameters.WebhookContentType = "application/json"
              $InvokeWebhookRequestParameters.OutputRawResponse = $False
              $InvokeWebhookRequestParameters.ContinueOnError = $False
              $InvokeWebhookRequestParameters.Verbose = $True

          $InvokeWebhookRequestResult = Invoke-WebhookRequest @InvokeWebhookRequestParameters
          Write-Output -InputObject ($InvokeWebhookRequestResult)

          Description:
          Sends a custom JSON payload to a webhook endpoint with bearer token authentication.

          .EXAMPLE
          # Webhook with automatic device information
          $InvokeWebhookRequestParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $InvokeWebhookRequestParameters.WebhookURI = "https://api.example.com/devices"
              $InvokeWebhookRequestParameters.WebhookHeaders = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                  $InvokeWebhookRequestParameters.WebhookHeaders.Authorization = "Bearer YourAuthorizationToken"
              $InvokeWebhookRequestParameters.WebhookMethod = [Microsoft.Powershell.Commands.Webrequestmethod]::Post
              $InvokeWebhookRequestParameters.IncludeDefaultWebhookBody = $True
              $InvokeWebhookRequestParameters.WebhookContentType = "application/json"
              $InvokeWebhookRequestParameters.OutputRawResponse = $False
              $InvokeWebhookRequestParameters.ContinueOnError = $False
              $InvokeWebhookRequestParameters.Verbose = $True

          $InvokeWebhookRequestResult = Invoke-WebhookRequest @InvokeWebhookRequestParameters
          Write-Output -InputObject ($InvokeWebhookRequestResult)

          Description:
          Automatically gathers device information (hardware, OS, BIOS, etc.) and sends it to the webhook.

          .EXAMPLE
          # Simple webhook call with minimal parameters
          $Result = Invoke-WebhookRequest -WebhookURI "https://api.example.com/ping" -IncludeDefaultWebhookBody

          Description:
          Simplest form - sends device information to endpoint using default POST method and JSON content type.

          .EXAMPLE
          # Webhook with API key authentication
          $Headers = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $Headers.'X-API-Key' = "your-api-key-here"
              $Headers.'X-Client-ID' = "client-12345"

          $Body = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $Body.Event = "DeviceRegistration"
              $Body.Timestamp = (Get-Date).ToString("o")

          $Result = Invoke-WebhookRequest -WebhookURI "https://api.example.com/events" -WebhookHeaders $Headers -WebhookBody $Body

          Description:
          Sends a custom event with API key authentication using custom headers.

          .EXAMPLE
          # Using from Invoke-HardwareHashOperation.ps1 with PSBootstrapper
          # This example shows how the function is called from the main script

          $InvokeWebhookRequestParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $InvokeWebhookRequestParameters.WebhookURI = $WebhookURI
              $InvokeWebhookRequestParameters.WebhookHeaders = $WebhookHeaders
              $InvokeWebhookRequestParameters.IncludeDefaultWebhookBody = $True
              $InvokeWebhookRequestParameters.ContinueOnError = $ContinueOnError.IsPresent

          $Result = Invoke-WebhookRequest @InvokeWebhookRequestParameters

          Description:
          Integration example showing how the main script uses this function to send device data.

          .EXAMPLE
          # GET request to retrieve data
          $Result = Invoke-WebhookRequest -WebhookURI "https://api.example.com/devices/status" -WebhookMethod Get -OutputRawResponse

          Description:
          Performs a GET request and returns the raw response object for detailed inspection.

          .NOTES
          Author: Function Author
          Version: 1.0
          Requirements:
          - PowerShell 3.0 or higher
          - Network connectivity to webhook endpoint
          - Valid authentication credentials (if required by endpoint)

          The function automatically formats the body as JSON and logs all request/response details.
          When IncludeDefaultWebhookBody is used, comprehensive device information is gathered including:
          - Operating System details (name, version, architecture, release ID)
          - Hardware information (manufacturer, model, serial number, BIOS version, UUID)
          - CPU details (model, speed, cores)
          - Memory capacity
          - UEFI Secure Boot status
          - Timezone information

          .LINK
          https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest

          .LINK
          https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod
        #>
        
        [CmdletBinding(ConfirmImpact = 'Low')]
       
        Param
          (                                                    
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [Alias('WHURI', 'URI')]
              [System.URI]$WebhookURI,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WHH', 'Headers')]
              [System.Collections.Specialized.OrderedDictionary]$WebhookHeaders,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WRM', 'Method')]
              [Microsoft.PowerShell.Commands.WebRequestMethod]$WebhookMethod,
              
              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WHB', 'Body')]
              [System.Collections.Specialized.OrderedDictionary]$WebhookBody,

              [Parameter(Mandatory=$False)]
              [Alias('IDWHB', 'DefaultBody')]
              [Switch]$IncludeDefaultWebhookBody,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WHCT', 'ContentType')]
              [System.String]$WebhookContentType,
              
              [Parameter(Mandatory=$False)]
              [Switch]$OutputRawResponse,

              [Parameter(Mandatory=$False)]
              [Switch]$ContinueOnError        
          )
                    
        Begin
          {
              Try
                {
                    $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
                    [ScriptBlock]$GetCurrentDateTimeLogFormat = {([DateTime]::UtcNow).ToString($DateTimeLogFormat)}

                    $TextInfo = (Get-Culture).TextInfo
                    $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

                    [ScriptBlock]$ErrorHandlingDefinition = {
                                                                Param
                                                                  (
                                                                      [Int16]$Severity,
                                                                      [Boolean]$ContinueOnError
                                                                  )
                                                                                                                
                                                                $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $ExceptionPropertyDictionary.Message = $_.Exception.Message
                                                                  $ExceptionPropertyDictionary.Category = $_.Exception.ErrorRecord.FullyQualifiedErrorID
                                                                  $ExceptionPropertyDictionary.Script = Try {[System.IO.Path]::GetFileName($_.InvocationInfo.ScriptName)} Catch {$Null}
                                                                  $ExceptionPropertyDictionary.LineNumber = $_.InvocationInfo.ScriptLineNumber
                                                                  $ExceptionPropertyDictionary.LinePosition = $_.InvocationInfo.OffsetInLine
                                                                  $ExceptionPropertyDictionary.Code = $_.InvocationInfo.Line.Trim()

                                                                $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

                                                                ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
                                                                  {
                                                                      Switch ($Null -ine $ExceptionProperty.Value)
                                                                        {
                                                                            {($_ -eq $True)}
                                                                              {
                                                                                  $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
                                                                              }
                                                                        }   
                                                                  }

                                                                $LogMessageParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $LogMessageParameters.Message = $ExceptionMessageList -Join ' '
                                                                  $LogMessageParameters.Verbose = $True
                              
                                                                Switch ($Severity)
                                                                  {
                                                                      {($_ -in @(1))} {Write-Verbose @LogMessageParameters}
                                                                      {($_ -in @(2))} {Write-Warning @LogMessageParameters}
                                                                      {($_ -in @(3))} {Write-Error @LogMessageParameters}
                                                                  }

                                                                Switch ($ContinueOnError)
                                                                  {
                                                                      {($_ -eq $False)}
                                                                        {                  
                                                                            Throw
                                                                        }
                                                                  }
                                                            }
                    
                    #Determine the date and time we executed the function
                      $FunctionStartTime = ([DateTime]::UtcNow)
                    
                    [String]$FunctionName = $MyInvocation.MyCommand
                    [System.IO.FileInfo]$InvokingScriptPath = $MyInvocation.PSCommandPath
                    [System.IO.DirectoryInfo]$InvokingScriptDirectory = $InvokingScriptPath.Directory.FullName
                    $FunctionPath = [System.IO.FileInfo][System.IO.Path]::Combine($InvokingScriptDirectory.FullName, 'Functions', "$($FunctionName).ps1")
                    [System.IO.DirectoryInfo]$FunctionDirectory = "$($FunctionPath.Directory.FullName)"
                    
                    $WriteLogMessage.Invoke(0, @("Function `'$($FunctionName)`' is beginning. Please Wait..."))
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      $DebugPreference = 'Continue'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $WriteLogMessage.Invoke(0, @("Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"))

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {Try {"-$($_.Key):$($_.Value.GetType().Name)"} Catch {"-$($_.Key):Unknown"}}
                    $WriteLogMessage.Invoke(0, @("Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"))

                    $WriteLogMessage.Invoke(0, @("Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"))

                    $WebhookRequestResult = $Null

                    Try {$Null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Powershell.Commands')} Catch {$Null}
                                        
                    #Set default parameter values
                      Switch ($True)
                        {
                            {([String]::IsNullOrEmpty($WebhookMethod) -eq $True) -or ([String]::IsNullOrWhiteSpace($WebhookMethod) -eq $True)}
                              {
                                  [Microsoft.PowerShell.Commands.WebRequestMethod]$WebhookMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
                              }

                            {([String]::IsNullOrEmpty($WebhookContentType) -eq $True) -or ([String]::IsNullOrWhiteSpace($WebhookContentType) -eq $True)}
                              {
                                  [System.String]$WebhookContentType = "application/json"
                              }
                        }
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
                }
              Finally
                {
                    
                }
          }

        Process
          {           
              Try
                {   
                    $InvokeWebRequestParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'       
                      $InvokeWebRequestParameters.UseBasicParsing = $True
	                    $InvokeWebRequestParameters.Uri = $WebhookURI.OriginalString
                      $InvokeWebRequestParameters.Method = $WebhookMethod
	                    $InvokeWebRequestParameters.UseDefaultCredentials = $True
	                    $InvokeWebRequestParameters.DisableKeepAlive = $False
	                    $InvokeWebRequestParameters.TimeoutSec = 900
	                    $InvokeWebRequestParameters.ContentType = $WebhookContentType
                      $InvokeWebRequestParameters.Verbose = $False

                    Switch (($Null -ine $WebhookHeaders) -and ($WebhookHeaders.Keys.Count -gt 0))
                      {
                          {($_ -eq $True)}
                            {
                                $InvokeWebRequestParameters.Headers = $WebhookHeaders
                            }
                      }
                    
                    Switch ($IncludeDefaultWebhookBody.IsPresent)
                      {
                          {($_ -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("Attempting to gather hardware details. Please Wait..."))
                                
                                $Bios = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_Bios" -Property * -Verbose:$False
                                $ComputerSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_ComputerSystem" -Property * -Verbose:$False
                                $OperatingSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_OperatingSystem" -Property * -Verbose:$False
                                $MSSystemInformation = Try {Get-CIMInstance -Namespace "root\WMI" -ClassName "MS_SystemInformation" -Property * -Verbose:$False} Catch {$Null}
                                $ComputerSystemProduct = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_ComputerSystemProduct' -Verbose:$False
                                $SystemEnclosure = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_SystemEnclosure' -Verbose:$False
                                $Timezone = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_Timezone' -Verbose:$False
                                $Processor = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_Processor' -Verbose:$False
                                $PhysicalMemory = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_PhysicalMemory' -Verbose:$False

                                $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()

                                $WebhookBodyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $WebhookBodyDictionary.OperatingSystemDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                    $WebhookBodyDictionary.OperatingSystemDetails.ComputerName = $ComputerSystem.Name.ToUpper()
                                    $WebhookBodyDictionary.OperatingSystemDetails.Caption = $OperatingSystem.Caption -ireplace '(Microsoft\s+)?', ''
                                    $WebhookBodyDictionary.OperatingSystemDetails.Architecture = $OSArchitecture
                                    $WebhookBodyDictionary.OperatingSystemDetails.Version = $WebhookBodyDictionary.OperatingSystemDetails.Version = $OperatingSystem.Version
                                    $WebhookBodyDictionary.OperatingSystemDetails.ReleaseID = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'DisplayVersion', $Null)
                                    $WebhookBodyDictionary.OperatingSystemDetails.ProductType = $OperatingSystem.ProductType
                                    $WebhookBodyDictionary.OperatingSystemDetails.SKU = $OperatingSystem.OperatingSystemSKU
                                    $WebhookBodyDictionary.OperatingSystemDetails.Language = (Get-Culture).Name
                                    $WebhookBodyDictionary.OperatingSystemDetails.Timezone = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                      $WebhookBodyDictionary.OperatingSystemDetails.Timezone.Name = $Timezone.StandardName
                                      $WebhookBodyDictionary.OperatingSystemDetails.Timezone.Caption = $Timezone.Caption
                                  $WebhookBodyDictionary.HardwareDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                    $WebhookBodyDictionary.HardwareDetails.Manufacturer = $MSSystemInformation.SystemManufacturer
                                    $WebhookBodyDictionary.HardwareDetails.Model = $MSSystemInformation.SystemProductName
                                    $WebhookBodyDictionary.HardwareDetails.SerialNumber = $BIOS.SerialNumber
                                    $WebhookBodyDictionary.HardwareDetails.BIOSVersion = $MSSystemInformation.BIOSVersion
                                    $WebhookBodyDictionary.HardwareDetails.UUID = $ComputerSystemProduct.UUID
                                    $WebhookBodyDictionary.HardwareDetails.BaseboardManufacturer = $MSSystemInformation.BaseBoardManufacturer
                                    $WebhookBodyDictionary.HardwareDetails.BaseboardProduct = $MSSystemInformation.BaseBoardProduct
                                    $WebhookBodyDictionary.HardwareDetails.BaseboardVersion = $MSSystemInformation.BaseBoardVersion
                                    $WebhookBodyDictionary.HardwareDetails.ChassisTypes = $SystemEnclosure.ChassisTypes
                                    $WebhookBodyDictionary.HardwareDetails.SKU = $MSSystemInformation.SystemSKU
                                    $WebhookBodyDictionary.HardwareDetails.UEFISecureBootStatus = 'Disabled'
                                    $WebhookBodyDictionary.HardwareDetails.CPU = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                      $WebhookBodyDictionary.HardwareDetails.CPU.Model = $Processor[0].Name
                                      $WebhookBodyDictionary.HardwareDetails.CPU.MaximumClockSpeedInGHz = [System.Math]::Round(($Processor[0].MaxClockSpeed / 1000), 2)
                                      $WebhookBodyDictionary.HardwareDetails.CPU.PhysicalCores = $Processor[0].NumberOfCores
                                      $WebhookBodyDictionary.HardwareDetails.CPU.LogicalCores = $Processor[0].NumberOfLogicalProcessors
                                    $WebhookBodyDictionary.HardwareDetails.MemoryInGB = [System.Math]::Round(($PhysicalMemory | Measure-Object -Property 'Capacity' -Sum).Sum / 1GB, 2)

                                $WindowsUBR = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'UBR', $Null)

                                $UEFISecureBootStatus = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\State', 'UEFISecureBootEnabled', $Null)

                                Switch ($True)
                                  {
                                      {([String]::IsNullOrEmpty($WindowsUBR) -eq $False) -and ([String]::IsNullOrWhiteSpace($WindowsUBR) -eq $False)}
                                        {
                                            $WebhookBodyDictionary.OperatingSystemDetails.Version = "$($WebhookBodyDictionary.OperatingSystemDetails.Version).$($WindowsUBR)"
                                        }

                                      {([String]::IsNullOrEmpty($UEFISecureBootStatus) -eq $False) -and ([String]::IsNullOrWhiteSpace($UEFISecureBootStatus) -eq $False)}
                                        {
                                            Switch ($UEFISecureBootStatus)
                                              {
                                                  {($_ -in @(1))}
                                                    {
                                                        $WebhookBodyDictionary.HardwareDetails.UEFISecureBootStatus = 'Enabled'
                                                    }

                                                  Default
                                                    {
                                                        $WebhookBodyDictionary.HardwareDetails.UEFISecureBootStatus = 'Disabled'
                                                    }
                                              }
                                        }
                                  }
                            }
                      }
                    
                    Switch ($True)
                      {
                          {($Null -ine $WebhookBody) -and ($WebhookBody.Keys.Count -gt 0)}
                            {
                                $WebhookBodyContent = $WebhookBody | ConvertTo-JSON -Depth 10 -Compress:$True -Verbose:$False
                                              
                                $InvokeWebRequestParameters.Body = $WebhookBodyContent

                                Break
                            }

                          {($Null -ine $WebhookBodyDictionary) -and ($WebhookBodyDictionary.Keys.Count -gt 0)}
                            {
                                $WebhookBodyContent = $WebhookBodyDictionary | ConvertTo-JSON -Depth 10 -Compress:$True -Verbose:$False
                                              
                                $InvokeWebRequestParameters.Body = $WebhookBodyContent

                                Break
                            }
                      }

                    $WriteLogMessage.Invoke(0, @("Attempting to send the specified web request. Please Wait..."))

                    $WriteLogMessage.Invoke(0, @("Endpoint: $($WebhookURI.OriginalString)"))

                    $WriteLogMessage.Invoke(0, @("Port: $($WebhookURI.Port)"))

                    $WriteLogMessage.Invoke(0, @("Method: $($InvokeWebRequestParameters.Method)"))

                    $WriteLogMessage.Invoke(0, @("Request Body Content Length: $($WebhookBodyContent.Length)"))

                    Switch (([String]::IsNullOrEmpty($WebhookBodyContent) -eq $False) -and ([String]::IsNullOrWhiteSpace($WebhookBodyContent) -eq $False))
                      {
                          {($_ -eq $True)}
                            {
                                $WebhookBodyLogMessage = $InvokeWebRequestParameters.Body | ConvertFrom-JSON -Verbose:$False | ConvertTo-JSON -Depth 10 -Compress:$False -Verbose:$False
                                  
                                $WriteLogMessage.Invoke(0, @("Body: $($WebhookBodyLogMessage)"))
                            }
                      }

                    $InvokeWebRequestResult = Invoke-WebRequest @InvokeWebRequestParameters

                    $WriteLogMessage.Invoke(0, @("Status Code: $($InvokeWebRequestResult.StatusCode)"))

                    $WriteLogMessage.Invoke(0, @("Status Description: $($InvokeWebRequestResult.StatusDescription)"))

                    $WriteLogMessage.Invoke(0, @("Response Content Length: $($InvokeWebRequestResult.Content.Length)"))

                    Switch (([String]::IsNullOrEmpty($InvokeWebRequestResult.Content) -eq $False) -and ([String]::IsNullOrWhiteSpace($InvokeWebRequestResult.Content) -eq $False))
                      {
                          {($_ -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("Web Request Response: `r`n`r`n$($InvokeWebRequestResult.Content | ConvertFrom-JSON -Verbose:$False | ConvertTo-JSON -Depth 10 -Compress:$False -Verbose:$False)"))
                            }
                      }

                    Switch ($OutputRawResponse.IsPresent)
                      {
                          {($_ -eq $True)}
                            {
                                $WebhookRequestResult = $InvokeWebRequestResult
                            }

                          Default
                            {
                                Switch (([String]::IsNullOrEmpty($InvokeWebRequestResult.Content) -eq $False) -and ([String]::IsNullOrWhiteSpace($InvokeWebRequestResult.Content) -eq $False))
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $WebhookRequestResult = ($InvokeWebRequestResult.Content | ConvertFrom-JSON -Verbose:$False)
                                        }

                                      Default
                                        {
                                            $WebhookRequestResult = $InvokeWebRequestResult
                                        }
                                  }
                            }
                      }
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
                }
              Finally
                {
                    
                }
          }
        
        End
          {                                        
              Try
                {
                    #Determine the date and time the function completed execution
                      $FunctionEndTime = ([DateTime]::UtcNow)

                      $WriteLogMessage.Invoke(0, @("Execution of $($FunctionName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"))

                    #Log the total script execution time  
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $WriteLogMessage.Invoke(0, @("Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"))
                    
                    $WriteLogMessage.Invoke(0, @("Function `'$($FunctionName)`' is completed."))
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
                }
              Finally
                {
                    Write-Output -InputObject ($WebhookRequestResult)
                }
          }
    }
#endregion