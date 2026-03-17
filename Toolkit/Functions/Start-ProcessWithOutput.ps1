#region Start-ProcessWithOutput
Function Start-ProcessWithOutput
  {
      <#
          .SYNOPSIS
          Executes external processes with comprehensive output capture, timeout management, and parsing capabilities.

          .DESCRIPTION
          This function provides advanced process execution capabilities beyond the standard Start-Process cmdlet.
          It captures standard output and error streams in memory, supports execution timeouts, allows standard
          input injection, and can parse output using regular expressions. The function is ideal for executing
          command-line tools and capturing their output for further processing.

          Key Features:
          - Captures StandardOutput and StandardError streams in memory
          - Execution timeout with configurable check intervals
          - Standard input stream writing for interactive processes
          - Regular expression parsing of output into structured objects
          - Exit code validation with customizable acceptable codes
          - Process priority control
          - Secure argument logging (obfuscates sensitive parameters)
          - Comprehensive logging of execution details

          Note: This function keeps all output in memory. For processes that generate large amounts of output
          (>100MB), consider alternative approaches to avoid memory issues.

          .PARAMETER FilePath
          The full path or name of the executable to run. If only a filename is provided, it must be in the
          system PATH or current directory.

          Alias: FP
          Type: String
          Required: True

          Example: "cmd.exe", "C:\Tools\MyTool.exe"

          .PARAMETER WorkingDirectory
          The working directory for the process. If the directory doesn't exist, it will be created automatically.
          If not specified, uses the current directory.

          Alias: WD
          Type: System.IO.DirectoryInfo
          Required: False

          .PARAMETER ArgumentList
          An array of arguments to pass to the executable. Arguments are automatically joined with spaces.

          Alias: AL
          Type: String[]
          Required: False

          Example: @('/c', 'ipconfig', '/all')

          .PARAMETER AcceptableExitCodeList
          An array of exit codes considered successful. Use '*' to accept any exit code. If not specified,
          defaults to @('0', '3010').

          Alias: AECL
          Type: String[]
          Required: False
          Default: @('0', '3010')

          Example: @('0', '1', '3010', '*')

          .PARAMETER WindowStyle
          The window style for the process. Only used when CreateNoWindow is not specified.

          Alias: WS
          Type: String
          Required: False
          Valid Values: Normal, Hidden, Minimized, Maximized
          Default: Hidden

          .PARAMETER CreateNoWindow
          When specified, creates the process without a window. Takes precedence over WindowStyle parameter.

          Alias: CNW
          Type: Switch
          Required: False

          .PARAMETER ExecutionTimeout
          Maximum time to wait for process completion. If exceeded, the process is forcibly terminated.

          Alias: ET
          Type: System.Timespan
          Required: False

          Example: [System.TimeSpan]::FromMinutes(5)

          .PARAMETER ExecutionTimeoutInterval
          How often to check if the process has exceeded the timeout. Only used when ExecutionTimeout is specified.
          Defaults to 15 seconds if not specified.

          Alias: ETI
          Type: System.Timespan
          Required: False
          Default: [System.TimeSpan]::FromSeconds(15)

          .PARAMETER StandardInputObjectList
          An array of objects to write to the process's standard input stream. Useful for interactive processes
          that require input.

          Alias: SIO
          Type: System.Object[]
          Required: False

          .PARAMETER ParsingExpression
          A regular expression pattern to parse the standard output and error streams. The regex should use
          named capture groups to extract structured data.

          Alias: StandardOutputParsingExpression, SOPE, PE
          Type: Regex
          Required: False

          Example: "(?:\s+)(?<PropertyName>.+)(?:\s+\:\s+)(?<PropertyValue>.+)"

          .PARAMETER SecureArgumentList
          When specified, obfuscates the argument list in log output. Use this when arguments contain sensitive
          information like passwords or API keys.

          Alias: SAL
          Type: Switch
          Required: False

          .PARAMETER LogOutput
          When specified, logs the standard output and error streams. Automatically enabled if the process
          returns an unacceptable exit code.

          Alias: LO
          Type: Switch
          Required: False

          .PARAMETER ContinueOnError
          Suppresses terminating errors and allows execution to continue even if the process fails.

          Alias: COE
          Type: Switch
          Required: False

          .EXAMPLE
          # Simple command execution with output capture
          $Result = Start-ProcessWithOutput -FilePath 'cmd.exe' -ArgumentList '/c', 'ipconfig', '/all' -CreateNoWindow -LogOutput -Verbose
          Write-Host $Result.StandardOutput

          Description:
          Executes ipconfig and captures the output. The StandardOutput property contains the command results.

          .EXAMPLE
          # Command with timeout
          $Result = Start-ProcessWithOutput -FilePath 'ping.exe' -ArgumentList 'google.com', '-n', '10' -ExecutionTimeout ([System.TimeSpan]::FromSeconds(30)) -CreateNoWindow

          Description:
          Executes ping with a 30-second timeout. If the command doesn't complete in time, it's forcibly terminated.

          .EXAMPLE
          # Parsing structured output with regex
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $StartProcessWithOutputParameters.FilePath = "dsregcmd.exe"
              $StartProcessWithOutputParameters.WorkingDirectory = "$([System.Environment]::SystemDirectory)"
              $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                  $StartProcessWithOutputParameters.ArgumentList.Add('/status')
              $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
              $StartProcessWithOutputParameters.WindowStyle = "Hidden"
              $StartProcessWithOutputParameters.Priority = "Normal"
              $StartProcessWithOutputParameters.ParsingExpression = "(?:\s+)(?<PropertyName>.+)(?:\s+\:\s+)(?<PropertyValue>.+)"
              $StartProcessWithOutputParameters.LogOutput = $True
              $StartProcessWithOutputParameters.ExecutionTimeout = [Timespan]::FromMinutes(1)
              $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [Timespan]::FromSeconds(30)
              $StartProcessWithOutputParameters.Verbose = $True

          $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters
          Write-Output -InputObject ($StartProcessWithOutputResult)

          Description:
          Executes dsregcmd.exe and parses the output using regex to extract property name/value pairs.

          .EXAMPLE
          # Secure execution with sensitive arguments
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $StartProcessWithOutputParameters.FilePath = "myapp.exe"
              $StartProcessWithOutputParameters.ArgumentList = @('/username', 'admin', '/password', 'SecretP@ssw0rd')
              $StartProcessWithOutputParameters.AcceptableExitCodeList = @('0')
              $StartProcessWithOutputParameters.CreateNoWindow = $True
              $StartProcessWithOutputParameters.SecureArgumentList = $True
              $StartProcessWithOutputParameters.LogOutput = $True
              $StartProcessWithOutputParameters.Verbose = $True

          $Result = Start-ProcessWithOutput @StartProcessWithOutputParameters

          Description:
          Executes a command with sensitive arguments. The SecureArgumentList parameter obfuscates the
          arguments in log output to protect credentials.

          .EXAMPLE
          # Interactive process with standard input
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $StartProcessWithOutputParameters.FilePath = "diskpart.exe"
              $StartProcessWithOutputParameters.StandardInputObjectList = @('list disk', 'exit')
              $StartProcessWithOutputParameters.AcceptableExitCodeList = @('0')
              $StartProcessWithOutputParameters.CreateNoWindow = $True
              $StartProcessWithOutputParameters.LogOutput = $True

          $Result = Start-ProcessWithOutput @StartProcessWithOutputParameters

          Description:
          Executes diskpart with commands sent to standard input, useful for interactive command-line tools.

          .EXAMPLE
          # Used in Invoke-HardwareHashOperation.ps1 to register PCPKsp.dll
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

          Description:
          Real-world example from the main script showing how to register a DLL in Windows PE environment.

          .EXAMPLE
          # Used in Invoke-HardwareHashOperation.ps1 to run OA3Tool
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $StartProcessWithOutputParameters.FilePath = $OA3ToolPath.FullName
              $StartProcessWithOutputParameters.WorkingDirectory = [System.IO.Path]::Combine($ContentDirectory.FullName, 'OA3Results')
              $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                  $StartProcessWithOutputParameters.ArgumentList.Add("/Report")
                  $StartProcessWithOutputParameters.ArgumentList.Add("/ConfigFile=`"$($OA3CFGPath.FullName)`"")
                  $StartProcessWithOutputParameters.ArgumentList.Add("/NoKeyCheck")
              $StartProcessWithOutputParameters.AcceptableExitCodeList = @('0')
              $StartProcessWithOutputParameters.CreateNoWindow = $True
              $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromSeconds(30)
              $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(5)
              $StartProcessWithOutputParameters.LogOutput = $True
              $StartProcessWithOutputParameters.ContinueOnError = $False
              $StartProcessWithOutputParameters.Verbose = $True

          $OA3ToolExecutionResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

          Description:
          Real-world example showing how the main script uses this function to extract hardware hash using OA3Tool.

          .EXAMPLE
          # Accept any exit code
          $Result = Start-ProcessWithOutput -FilePath 'myapp.exe' -AcceptableExitCodeList @('*') -CreateNoWindow

          Description:
          Executes a process and accepts any exit code as successful. Useful for tools with non-standard exit codes.

          .NOTES
          Author: Function Author
          Version: 1.0
          Requirements:
          - PowerShell 3.0 or higher
          - Appropriate permissions to execute the target process

          Return Object Properties:
          - ExitCode: The process exit code
          - ExitCodeAsHex: Exit code in hexadecimal format
          - ExitCodeAsInteger: Exit code as integer
          - ExitCodeAsDecimal: Exit code as decimal string
          - ProcessObject: The process object with details
          - StandardOutput: The standard output stream content
          - StandardOutputObject: Parsed output (if ParsingExpression used)
          - StandardError: The standard error stream content
          - StandardErrorObject: Parsed errors (if ParsingExpression used)

          Performance Considerations:
          - All output is kept in memory; avoid for processes with >100MB output
          - Timeout checks occur at ExecutionTimeoutInterval frequency
          - Process priority can be adjusted to minimize system impact

          .LINK
          https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process

          .LINK
          https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process
      #>
      
      [CmdletBinding(DefaultParameterSetName = 'WindowStyle')] 
        Param
          (        
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [Alias('FP')]
              [String]$FilePath,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WD')]
              [System.IO.DirectoryInfo]$WorkingDirectory,
                
              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [Alias('AL')]
              [String[]]$ArgumentList,

              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [Alias('AECL')]
              [String[]]$AcceptableExitCodeList,

              [Parameter(Mandatory=$False, ParameterSetName = 'WindowStyle')]
              [ValidateNotNullOrEmpty()]
              [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
              [Alias('WS')]
              [String]$WindowStyle,

              [Parameter(Mandatory=$False, ParameterSetName = 'CreateNoWindow')]
              [Alias('CNW')]
              [Switch]$CreateNoWindow,

              [Parameter(Mandatory=$False)]
              [Alias('NW')]
              [Switch]$NoWait,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [ValidateSet('AboveNormal', 'BelowNormal', 'High', 'Idle', 'Normal', 'RealTime')]
              [Alias('P')]
              [String]$Priority,

              [Parameter(Mandatory=$False)]
              [Alias('ET')]
              [System.Timespan]$ExecutionTimeout,

              [Parameter(Mandatory=$False)]
              [Alias('ETI')]
              [System.Timespan]$ExecutionTimeoutInterval,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('SIO')]
              [System.Object[]]$StandardInputObjectList,
              
              [Parameter(Mandatory=$False)]
              [AllowEmptyString()]
              [AllowNull()]
              [Alias('StandardOutputParsingExpression', 'SOPE', 'PE')]
              [Regex]$ParsingExpression,

              [Parameter(Mandatory=$False)]
              [Alias('SAL')]
              [Switch]$SecureArgumentList,

              [Parameter(Mandatory=$False)]
              [Alias('LO')]
              [Switch]$LogOutput,

              [Parameter(Mandatory=$False)]
              [Alias('COE')]
              [Switch]$ContinueOnError
          )
                  
      Try
        {
            $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
            [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
            

            

            
            $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
              $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

            #Determine the date and time we executed the function
            $FunctionStartTime = (Get-Date)
            
            [String]$CmdletName = $MyInvocation.MyCommand.Name
            
            $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is beginning. Please Wait..."))
      
            #Define Default Action Preferences
              $ErrorActionPreference = 'Stop'
              
            [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
            $WriteLogMessage.Invoke(0, @("Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"))

            $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"))

            $WriteLogMessage.Invoke(0, @("Parameter Set Name: $($PSCmdlet.ParameterSetName)"))

            #Set default parameter values (If necessary)
              Switch ($True)
                {
                    {([String]::IsNullOrEmpty($WindowStyle) -eq $True) -or ([String]::IsNullOrWhiteSpace($WindowStyle) -eq $True)}
                      {
                          [String]$WindowStyle = 'Hidden'
                      }

                    {([String]::IsNullOrEmpty($Priority) -eq $True) -or ([String]::IsNullOrWhiteSpace($Priority) -eq $True)}
                      {
                          [String]$Priority = 'Normal'
                      }

                    {($Null -ine $ExecutionTimeout)}
                      {
                          Switch ($Null -ieq $ExecutionTimeoutInterval)
                            {
                                {($_ -eq $True)}
                                  {
                                      $ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(15)
                                  }
                            }
                      }
                }

            [ScriptBlock]$GetTimeSpanMessage = {
                                                    Param
                                                      (
                                                          [System.TimeSpan]$InputObject
                                                      )

                                                    $InputObjectMessageBuilder = New-Object -TypeName 'System.Text.StringBuilder'

                                                    $InputObjectProperties = $InputObject | Select-Object -Property @('Days', 'Hours', 'Minutes', 'Seconds', 'Milliseconds')
                                        
                                                    $InputObjectPropertyNameList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'

                                                    ($InputObjectProperties.PSObject.Properties | Where-Object {($_.Value -gt 0)}).Name | ForEach-Object {($InputObjectPropertyNameList.Add($_))}

                                                    $InputObjectPropertyNameListUpperBound = $InputObjectPropertyNameList.ToArray().GetUpperBound(0)
                                        
                                                    For ($InputObjectPropertyNameListIndex = 0; $InputObjectPropertyNameListIndex -lt $InputObjectPropertyNameList.Count; $InputObjectPropertyNameListIndex++)
                                                      {
                                                          $InputObjectPropertyName = $InputObjectPropertyNameList[$InputObjectPropertyNameListIndex]
                                              
                                                          $InputObjectPropertyValue = $InputObject.$($InputObjectPropertyName)

                                                          Switch ($True)
                                                            {
                                                                {($InputObjectPropertyNameList.Count -gt 1) -and ($InputObjectPropertyNameListIndex -eq $InputObjectPropertyNameListUpperBound)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append('and ')
                                                                  }
                                                    
                                                                {($InputObjectPropertyValue -eq 1)}
                                                                  {                                                          
                                                                      $Null = $InputObjectMessageBuilder.Append("$($InputObjectPropertyValue) $($InputObjectPropertyName.TrimEnd('s').ToLower())")
                                                                  }

                                                                {($InputObjectPropertyValue -gt 1)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append("$($InputObjectPropertyValue) $($InputObjectPropertyName.ToLower())")
                                                                  }

                                                                {($InputObjectPropertyNameList.Count -gt 1) -and ($InputObjectPropertyNameListIndex -ne $InputObjectPropertyNameListUpperBound)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append(', ')
                                                                  }
                                                            }
                                                      }

                                                    $OutputObject = $InputObjectMessageBuilder.ToString()
                                        
                                                    Switch ($InputObjectMessageBuilder.Length -gt 0)
                                                      {
                                                          {($_ -eq $True)}
                                                            { 
                                                                $OutputObject = $InputObjectMessageBuilder.ToString()
                                                            }

                                                          Default
                                                            {
                                                                $OutputObject = 'N/A'
                                                            }
                                                      }
                                        
                                                    Write-Output -InputObject ($OutputObject)
                                                }

            [ScriptBlock]$WriteStandardOutputStream = {
                                                          Param
                                                            (
                                                                [System.Object[]]$StandardInputObjectList,
                                                                [Switch]$SecureArgumentList
                                                            )
                                                          
                                                          Switch (($Null -ine $StandardInputObjectList) -and ($StandardInputObjectList.Count -gt 0))
                                                            {
                                                                {($_ -eq $True)}
                                                                  {
                                                                      $StandardInputObjectListCounter = 1
                                    
                                                                      For ($StandardInputObjectListIndex = 0; $StandardInputObjectListIndex -lt $StandardInputObjectList.Count; $StandardInputObjectListIndex++)
                                                                        {
                                                                            Try
                                                                              {
                                                                                  $StandardInputObject = $StandardInputObjectList[$StandardInputObjectListIndex]

                                                                                  Switch ($SecureArgumentList.IsPresent)
                                                                                    {
                                                                                        {($_ -eq $True)}
                                                                                          {
                                                                                              $ObfuscationCharacter = '*'

                                                                                              $ObfuscationCharacterCount = Get-Random -Minimum 5 -Maximum 20

                                                                                              $ObfuscationValue = $ObfuscationCharacter.PadRight($ObfuscationCharacterCount, $ObfuscationCharacter)
                                    
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to write standard input object $($StandardInputObjectListCounter) of $($StandardInputObjectList.Count) to the standard input stream for process ID $($Process.ID). Please Wait..."))

                                                                                              $WriteLogMessage.Invoke(0, @("Object Value: $($ObfuscationValue)"))
                                                                                          }

                                                                                        Default
                                                                                          {
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to write standard input object $($StandardInputObjectListCounter) of $($StandardInputObjectList.Count) to the standard input stream for process ID $($Process.ID). Please Wait..."))

                                                                                              $WriteLogMessage.Invoke(0, @("Object Value: $($StandardInputObject)"))
                                                                                          }
                                                                                    }

                                                                                  $Null = $Process.StandardInput.WriteLine($StandardInputObject)
                                                                              }
                                                                            Catch
                                                                              {
                                                                                  $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                    $ExceptionPropertyDictionary.Add('Message', $_.Exception.Message)
                                                                                    $ExceptionPropertyDictionary.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                                                    $ExceptionPropertyDictionary.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                                                    $ExceptionPropertyDictionary.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                                                    $ExceptionPropertyDictionary.Add('Code', $_.InvocationInfo.Line.Trim())

                                                                                  $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

                                                                                  ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
                                                                                    {
                                                                                        $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
                                                                                    }

                                                                                  $WriteLogMessage.Invoke(2, @("$($ExceptionMessageList -Join ' ')"))
                                                                              }
                                                                            Finally
                                                                              {
                                                                                  $StandardInputObjectListCounter++
                                                                              }     
                                                                        }  
                                                                  }
                                                            }
                                                      }
            
            $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $OutputObjectProperties.ExitCode = -1
              $OutputObjectProperties.ExitCodeAsHex = $Null
              $OutputObjectProperties.ExitCodeAsInteger = $Null
              $OutputObjectProperties.ExitCodeAsDecimal = $Null
              $OutputObjectProperties.ProcessObject = $Null
              $OutputObjectProperties.StandardOutput = $Null
              $OutputObjectProperties.StandardOutputObject = $Null
              $OutputObjectProperties.StandardError = $Null
              $OutputObjectProperties.StandardErrorObject = $Null
        
            $Process = New-Object -TypeName 'System.Diagnostics.Process'
              $Process.StartInfo.FileName = $FilePath
              $Process.StartInfo.UseShellExecute = $False          
              $Process.StartInfo.RedirectStandardOutput = $True
              $Process.StartInfo.RedirectStandardError = $True
              $Process.StartInfo.RedirectStandardInput = $True

            Switch ($True)
              {
                  {([String]::IsNullOrEmpty($WorkingDirectory) -eq $False) -and ([String]::IsNullOrWhiteSpace($WorkingDirectory) -eq $False)}
                    {
                        Switch ($True)
                          {
                              {([System.IO.Directory]::Exists($WorkingDirectory) -eq $False)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Attempting to create the non-existing process working directory. Please Wait..."))

                                    $WriteLogMessage.Invoke(0, @("Path: $($WorkingDirectory.FullName)"))
                                    
                                    $Null = [System.IO.Directory]::CreateDirectory($WorkingDirectory.FullName)
                                }
                          }
                        
                        $Process.StartInfo.WorkingDirectory = $WorkingDirectory.FullName
                    }
              }
                  
            Switch ($PSCmdlet.ParameterSetName)
              {
                  {($_ -iin @('CreateNoWindow'))}
                    {
                        $Process.StartInfo.CreateNoWindow = $True
                    }

                  {($_ -iin @('WindowStyle'))}
                    {
                        $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::"$($WindowStyle)"     
                    }
              }
 
            Switch (($Null -ieq $AcceptableExitCodeList) -or ($AcceptableExitCodeList.Count -eq 0))
              {
                  {($_ -eq $True)}
                    {
                        $DefaultExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $DefaultExitCodeList.Add('0')
                          $DefaultExitCodeList.Add('3010')
                        
                        $AcceptableExitCodeList = $DefaultExitCodeList.ToArray()     
                    }
              }
            
            $CommandExecutionMessageBuilder = New-Object -TypeName 'System.Text.StringBuilder'
            
            $Null = $CommandExecutionMessageBuilder.Append('Attempting to execute the following command:')          
            $Null = $CommandExecutionMessageBuilder.Append(' ')
            $Null = $CommandExecutionMessageBuilder.Append($Process.StartInfo.FileName)
            
            Switch (($Null -ine $ArgumentList) -and ($ArgumentList.Count -gt 0))
              {
                  {($_ -eq $True)}
                    {
                        $Process.StartInfo.Arguments = $ArgumentList -Join ' '

                        Switch ($SecureArgumentList.IsPresent)
                          {
                              {($_ -eq $True)}
                                {
                                    $ObfuscationCharacter = '*'

                                    $ObfuscationCharacterCount = Get-Random -Minimum 5 -Maximum ($Process.StartInfo.Arguments.Length)

                                    $ObfuscationValue = $ObfuscationCharacter.PadRight($ObfuscationCharacterCount, $ObfuscationCharacter)
                                    
                                    $Null = $CommandExecutionMessageBuilder.Append(' ')   
                                    $Null = $CommandExecutionMessageBuilder.Append($ObfuscationValue)
                                }

                              Default
                                {
                                    $Null = $CommandExecutionMessageBuilder.Append(' ')   
                                    $Null = $CommandExecutionMessageBuilder.Append($Process.StartInfo.Arguments)
                                }
                          } 
                    }
              }
              
            $WriteLogMessage.Invoke(0, @("$($CommandExecutionMessageBuilder.ToString())"))

            $WriteLogMessage.Invoke(0, @("Acceptable Exit Code List: $($AcceptableExitCodeList -Join '; ')"))

            Switch ($NoWait.IsPresent)
              {
                  {($_ -eq $True)}
                    { 
                        $Null = $Process.Start()

                        $WriteLogMessage.Invoke(0, @("Skipping the execution wait for process ID $($Process.ID)."))

                        $WriteLogMessage.Invoke(0, @("[ProcessName: $([System.IO.Path]::GetFileName($Process.Path))] [ID: $($Process.ID)] [Version: $($Process.FileVersion)] [Description: $($Process.Description)] [Path: $($Process.Path)] "))

                        $Null = $WriteStandardOutputStream.InvokeReturnAsIs($StandardInputObjectList, $SecureArgumentList.IsPresent)

                        $OutputObjectProperties.StandardOutput = $Null
                        $OutputObjectProperties.StandardError = $Null
                    }

                  Default
                    {
                        Switch ($Null -ieq $ExecutionTimeout)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("A timeout was not specified for process ID $($Process.ID)."))

                                    $WriteLogMessage.Invoke(0, @("The wait for process ID $($Process.ID) termination will be indefinite."))
                                }

                              Default
                                {                                    
                                    $ProcessTimeoutStopWatch = New-Object -TypeName 'System.Diagnostics.StopWatch'
                                    
                                    $Null = $ProcessTimeoutStopWatch.Start()
                                }
                          }

                        $Null = $Process.Start()
                        
                        Switch ($Process.PriorityClass -ine $Priority)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Attempting to change the process priority class for process ID $($Process.ID) from `"$($Process.PriorityClass)`" to `"$($Priority)`". Please Wait..."))
                        
                                    $Null = $Process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::"$($Priority)" 
                                }
                          }

                        $WriteLogMessage.Invoke(0, @("[ProcessName: $([System.IO.Path]::GetFileName($Process.Path))] [ID: $($Process.ID)] [Version: $($Process.FileVersion)] [Description: $($Process.Description)] [Path: $($Process.Path)] "))

                        $WriteLogMessage.Invoke(0, @("Process Start Time: $($Process.StartTime.ToString($DateTimeLogFormat))"))

                        Switch ($Null -ine $ExecutionTimeout)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Process Timeout Time: $($Process.StartTime.AddTicks($ExecutionTimeout.Ticks).ToString($DateTimeLogFormat))"))

                                    $WriteLogMessage.Invoke(0, @("Process Timeout Duration: $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))"))
                                }
                          }

                        $Null = $WriteStandardOutputStream.InvokeReturnAsIs($StandardInputObjectList, $SecureArgumentList.IsPresent)
                        
                        $OutputObjectProperties.StandardOutput = $Process.StandardOutput.ReadToEndAsync()
                        $OutputObjectProperties.StandardError = $Process.StandardError.ReadToEndAsync()

                        $ProcessTimeOutLoopCondition = {$Process.HasExited -eq $False}
                        
                        :ProcessTimeoutLoop While ($ProcessTimeOutLoopCondition.InvokeReturnAsIs() -eq $True)
                          {
                              $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has been running for $($GetTimeSpanMessage.InvokeReturnAsIs($ProcessTimeoutStopWatch.Elapsed))."))

                              Switch ($Null -ine $ExecutionTimeout)
                                { 
                                    {($_ -eq $True)}  
                                      {
                                          Switch ($ProcessTimeoutStopWatch.Elapsed.TotalMilliseconds -le $ExecutionTimeout.TotalMilliseconds)
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has not exceeded the maximum timeout duration of $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))."))
                                                  }

                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has exceeded the maximum timeout duration of $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))."))
                                          
                                                      Try
                                                        {
                                                            $WriteLogMessage.Invoke(0, @("Attempting to forcibly terminate the process ID $($Process.ID). Please Wait..."))
                                                                        
                                                            $Null = $Process.Kill()

                                                            Switch ($?)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) was forcibly terminated successfully."))
                                                                    }
                                                              }
                                                        }
                                                      Catch
                                                        {
                                                            $WriteLogMessage.Invoke(2, @("$($_.Exception.Message)"))
                                                        }
                                          
                                                      Break ProcessTimeoutLoop
                                                  }
                                            }
                                      }
                                }

                              $WriteLogMessage.Invoke(0, @("Checking again in another $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeoutInterval)). Please Wait..."))
                                          
                              $Null = Start-Sleep -Milliseconds ($ExecutionTimeoutInterval.TotalMilliseconds)
                          }
                                                
                        $OutputObjectProperties.ExitCode = Try {$Process.ExitCode} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsHex = Try {'0x' + [System.Convert]::ToString($OutputObjectProperties.ExitCode, 16).PadLeft(8, '0').ToUpper()} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsInteger = Try {$OutputObjectProperties.ExitCodeAsHex -As [Int]} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsDecimal = Try {[System.Convert]::ToString($OutputObjectProperties.ExitCodeAsHex, 10)} Catch {$Null}

                        $ExitCodeMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            
                        $Null = $OutputObjectProperties.GetEnumerator() | Where-Object {($_.Key -imatch '(^ExitCode.*$)')} | Sort-Object -Property @('Key') | ForEach-Object {$ExitCodeMessageList.Add("[$($_.Key): $($_.Value)]")}
            
                        $ProcessExecutionTimespan = New-TimeSpan -Start ($Process.StartTime) -End ($Process.ExitTime)

                        $OutputObjectProperties.ProcessObject = $Process | Select-Object -Property @('*') -ExcludeProperty @('ExitCode', 'StandardInput', 'StandardOutput', 'StandardError', 'SafeHandle', 'Threads', 'StartInfo')

                        $WriteLogMessage.Invoke(0, @("Process Exit Time: $($Process.ExitTime.ToString($DateTimeLogFormat))"))

                        #Dispose of the process object
                          Try {$Null = $Process.Dispose()} Catch {}
                                                                        
                        $WriteLogMessage.Invoke(0, @("The command execution took $($GetTimeSpanMessage.InvokeReturnAsIs($ProcessExecutionTimespan))."))

                        Switch (($AcceptableExitCodeList -icontains '*') -or ($OutputObjectProperties.ExitCode.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsHex.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsInteger.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsDecimal.ToString() -iin $AcceptableExitCodeList))
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("The command execution was successful. $($ExitCodeMessageList -Join ' ')"))
                                    
                                    [Boolean]$CommandExecutionErrorOccured = $False
                                }

                              {($_ -eq $False)}
                                {
                                    $WriteLogMessage.Invoke(2, @("The command execution was unsuccessful. $($ExitCodeMessageList -Join ' ')"))

                                    $ErrorMessage = "The command execution was unsuccessful. $($ExitCodeMessageList -Join ' ')"
                                    $Exception = [System.Exception]::New($ErrorMessage)        
                                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::New($Exception, [System.Management.Automation.ErrorCategory]::InvalidResult.ToString(), [System.Management.Automation.ErrorCategory]::InvalidResult, $Process)
                                    
                                    [Boolean]$CommandExecutionErrorOccured = $True
                                }
                          }
     
                        Switch (([String]::IsNullOrEmpty($ParsingExpression) -eq $False) -and ([String]::IsNullOrWhiteSpace($ParsingExpression) -eq $False))
                          {
                              {($_ -eq $True)}
                                {
                                    $RegexOptions = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
                                      $RegexOptions.Add('IgnoreCase')
                                      $RegexOptions.Add('Multiline')

                                    $Regex = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList @($ParsingExpression, $RegexOptions.ToArray())
                                                
                                    $OutputStreamDictionary = New-Object -TypeName 'System.Collections.Generic.Dictionary[[String], [String]]'
                                      $OutputStreamDictionary.Add('StandardOutput', $OutputObjectProperties.StandardOutput)
                                      $OutputStreamDictionary.Add('StandardError', $OutputObjectProperties.StandardError)

                                    ForEach ($OutputStream In $OutputStreamDictionary.GetEnumerator())
                                      {   
                                          Switch (([String]::IsNullOrEmpty($OutputStream.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($OutputStream.Value) -eq $False))
                                            {
                                                {($_ -eq $True)}
                                                  {                                                      
                                                      $WriteLogMessage.Invoke(0, @("Attempting to parse the `"$($OutputStream.Key)`" property value. Please Wait..."))

                                                      $WriteLogMessage.Invoke(0, @("Regular Expression: $($ParsingExpression)"))

                                                      $WriteLogMessage.Invoke(0, @("Regular Expression Options: $($RegexOptions -Join ', ')"))

                                                      $OutputStreamRegexResult = $Regex.IsMatch($OutputStream.Value)

                                                      Switch ($OutputStreamRegexResult)
                                                        {
                                                            {($_ -eq $True)}
                                                              {
                                                                  $RegexMatchList = $Regex.Matches($OutputStream.Value)

                                                                  $WriteLogMessage.Invoke(0, @("The `"$($OutputStream.Key)`" property value matches the regular expression. $($RegexMatchList.Count) matches were found."))

                                                                  $OutputObjectProperties."$($OutputStream.Key)Object" = $RegexMatchList
                                                              }

                                                            Default
                                                              {
                                                                  $WriteLogMessage.Invoke(0, @("The `"$($OutputStream.Key)`" property value does not match the regular expression."))

                                                                  $OutputObjectProperties."$($OutputStream.Key)Object" = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.Match]'     
                                                              }
                                                        }            
                                                  }

                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Skipping the parsing of the `"$($OutputStream.Key)`" property value because it is blank."))
                                                  }
                                            }
                                      }
                                }
                          }
                          
                        $Null = $ProcessTimeoutStopWatch.Stop()
            
                        $Null = $ProcessTimeoutStopWatch.Reset()  
                    }
              }                               
        }
      Catch
        {
            $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $ExceptionPropertyDictionary.Add('Message', $_.Exception.Message)
              $ExceptionPropertyDictionary.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
              $ExceptionPropertyDictionary.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
              $ExceptionPropertyDictionary.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
              $ExceptionPropertyDictionary.Add('Code', $_.InvocationInfo.Line.Trim())

            $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

            ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
              {
                  $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
              }

            $WriteLogMessage.Invoke(2, @("$($ExceptionMessageList -Join ' ')"))
        }
      Finally
        {                           
            $OutputObjectProperties.StandardOutput = Try {$OutputObjectProperties.StandardOutput.Result} Catch {$Null}
            $OutputObjectProperties.StandardError = Try {$OutputObjectProperties.StandardError.Result} Catch {$Null}
            
            $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)
            
            Switch (($LogOutput.IsPresent -eq $True) -or ($LogOutput -eq $True) -or ($CommandExecutionErrorOccured -eq $True))
              {
                  {($_ -eq $True)}
                    {
                        ForEach ($Property In $OutputObject.PSObject.Properties)
                          {
                              Switch ($Property.Name)
                                {
                                    {($_ -iin @('StandardOutput', 'StandardError'))}
                                      {
                                          Switch (([String]::IsNullOrEmpty($Property.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($Property.Value) -eq $False))
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("$($Property.Name): $($Property.Value)"))
                                                  }
                                                  
                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("$($Property.Name): N/A"))
                                                  }
                                            }
                                      }
                                }
                          }
                    }
              }
    
            Try
              {
                  Switch ($NoWait.IsPresent)
                    {
                        {($_ -eq $False)}
                          {
                              Switch ($Process.HasExited)
                                {
                                    {($_ -eq $False)}
                                      {
                                          $WriteLogMessage.Invoke(0, @("Attempting to forcibly terminate the process ID $($Process.ID). Please Wait..."))
            
                                          $Null = Try {$Process.CancelErrorRead()} Catch {}
                                          $Null = Try {$Process.CancelOutputRead()} Catch {}
                                          $Null = Try {$Process.Kill()} Catch {}
                                          $Null = Try {$Process.Dispose()} Catch {}
                                      }
                                }
                          }
                    }
              }
            Catch
              {
                  
              }

            #Determine the date and time the function completed execution
              $FunctionEndTime = (Get-Date)

              $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"))

            #Log the total script execution time  
              $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

              $WriteLogMessage.Invoke(0, @("Function execution took $($GetTimeSpanMessage.InvokeReturnAsIs($FunctionExecutionTimespan))."))
            
            $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is completed."))
            
            Switch ($CommandExecutionErrorOccured)
              {
                  {($_ -eq $True)}
                    {
                        Write-Output -InputObject ($OutputObject)
                                    
                        If ($ContinueOnError.IsPresent -eq $False) {$PSCmdlet.ThrowTerminatingError($ErrorRecord)}
                    }
                                
                  Default
                    {
                        Write-Output -InputObject ($OutputObject)
                    }                                
              }
        }
  }
#endregion