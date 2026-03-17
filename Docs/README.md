# Invoke-HardwareHashOperation

A comprehensive PowerShell solution for extracting and managing Windows Autopilot hardware hashes. This toolkit is designed for IT professionals managing device enrollment in Microsoft Intune/Autopilot environments.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Usage Examples](#usage-examples)
- [Parameters](#parameters)
- [Functions](#functions)
- [Deployment Scenarios](#deployment-scenarios)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

**Invoke-HardwareHashOperation** is a PowerShell-based solution that extracts Windows Autopilot hardware hashes from devices and exports them in the Microsoft Autopilot CSV format. The solution includes a PSBootstrapper executable (`Invoke-HardwareHashOperation.exe`) that simplifies execution by handling PowerShell execution policies and elevation automatically.

### Key Capabilities

- ✅ Extract hardware hash using OA3Tool utility
- ✅ Export to CSV in Autopilot-compatible format
- ✅ Automatic export to removable USB drives
- ✅ Send device information via webhook
- ✅ Works in Windows PE and full Windows environments
- ✅ Comprehensive logging with automatic rotation
- ✅ Network connectivity validation
- ✅ Self-elevation for administrator privileges

## ✨ Features

### Hardware Hash Extraction
- Utilizes OA3Tool.exe for reliable hardware hash extraction
- Automatic PCPKsp.dll registration in Windows PE environments
- Validates hardware hash before export

### Export Options
- **Local Export**: Save to specified path or default location
- **Removable Drive Export**: Automatically detect and export to all USB drives
- **Webhook Integration**: Send device information to remote endpoints

### Logging & Monitoring
- Automatic log file creation with timestamps
- Log rotation (keeps 3 most recent logs)
- Detailed execution tracking
- Network connectivity logging

### Environment Detection
- Windows PE detection
- Task Sequence environment detection (SCCM/MDT)
- Automatic log path determination based on environment

## 📦 Requirements

### System Requirements
- **Operating System**: Windows 10/11 or Windows PE
- **PowerShell**: Version 5.0 or higher
- **Privileges**: Administrator rights (script will self-elevate if needed)
- **Network**: Required only for webhook functionality

### Included Components
- `Invoke-HardwareHashOperation.ps1` - Main script
- `Invoke-HardwareHashOperation.exe` - PSBootstrapper executable
- `Toolkit/` - Supporting functions and modules
- `Toolkit/Tools/X64/` - OA3Tool.exe, PCPKsp.dll, and configuration files
- `Toolkit/Tools/X86/` - 32-bit tools (if needed)

## 🚀 Quick Start

### Method 1: Using PSBootstrapper (Recommended)

The easiest way to run the script is using the included executable:

```cmd
# Basic execution
Invoke-HardwareHashOperation.exe

# Export to removable drives
Invoke-HardwareHashOperation.exe -ExportToRemovableDisk

# With webhook
Invoke-HardwareHashOperation.exe -SendWebhook -WebhookURI "https://api.example.com/devices"
```

### Method 2: Direct PowerShell Execution

```powershell
# Basic execution
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Invoke-HardwareHashOperation.ps1"

# With parameters
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -Overwrite
```

### Method 3: Task Sequence / Deployment

```cmd
# SCCM/MDT Task Sequence
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptRoot%\Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
```

## 📁 Directory Structure

```
Invoke-HardwareHashOperation/
│
├── Invoke-HardwareHashOperation.ps1    # Main script
├── Invoke-HardwareHashOperation.exe    # PSBootstrapper executable
├── README.md                            # This file
│
├── Content/                             # Output directory
│   ├── HardwareHashes/                 # Default CSV export location
│   └── Place_Additional_Tools_Here.txt
│
├── Docs/                                # Documentation
│   └── Place_Guides_Here.txt
│
└── Toolkit/                             # Supporting infrastructure
    ├── Toolkit.ps1                     # Core toolkit (dot-sourced by main script)
    │
    ├── Functions/                      # Reusable functions
    │   ├── Invoke-Webhook.ps1         # Webhook functionality
    │   └── Start-ProcessWithOutput.ps1 # Process execution helper
    │
    ├── Modules/                        # PowerShell modules
    │   └── PlaceModulesHere.txt
    │
    └── Tools/                          # External utilities
        ├── All/                        # OS-agnostic tools
        ├── X64/                        # 64-bit tools
        │   ├── OA3Tool.exe            # Hardware hash extraction tool
        │   ├── PCPKsp.dll             # TPM provider for WinPE
        │   ├── OA3.cfg                # OA3Tool configuration
        │   └── input.xml              # OA3Tool input file
        └── X86/                        # 32-bit tools
```

## 💡 Usage Examples

### Example 1: Basic Hardware Hash Extraction

```powershell
# Extract and save to default location
.\Invoke-HardwareHashOperation.ps1
```

**Output**: `Content\HardwareHashes\<SerialNumber>.csv`

### Example 2: Export to USB Drive

```powershell
# Export to default location AND all removable USB drives
.\Invoke-HardwareHashOperation.ps1 -ExportToRemovableDisk
```

### Example 3: Custom Export Path

```powershell
# Export to specific location
.\Invoke-HardwareHashOperation.ps1 -ExportPath "D:\Autopilot\DeviceHash.csv" -Overwrite
```

### Example 4: Webhook Integration

```powershell
# Send device information to webhook endpoint
$Headers = @{
    "Authorization" = "Bearer YOUR_TOKEN_HERE"
    "Content-Type" = "application/json"
}

.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://api.example.com/autopilot/devices" `
    -WebhookHeaders $Headers `
    -ExportToRemovableDisk
```

### Example 5: Using PSBootstrapper in WinPE

```cmd
REM Simple execution in WinPE
X:\Deploy\Invoke-HardwareHashOperation.exe -ExportToRemovableDisk
```

### Example 6: Task Sequence Integration

```cmd
REM SCCM/MDT Task Sequence Step
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%ScriptRoot%\Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
```

## 📝 Parameters

### Main Script Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ExportPath` | FileInfo | No | Custom export path for CSV file |
| `ExportToRemovableDisk` | Switch | No | Export to all detected USB drives |
| `SendWebhook` | Switch | No | Enable webhook functionality |
| `WebhookURI` | URI | No | Webhook endpoint URL |
| `WebhookHeaders` | Dictionary | No | Custom HTTP headers for webhook |
| `Overwrite` | Switch | No | Overwrite existing CSV files |
| `LogDirectory` | DirectoryInfo | No | Custom log directory |
| `ContinueOnError` | Switch | No | Continue on non-critical errors |

### Parameter Aliases

- `ExportPath`: `EP`
- `WebhookURI`: `WHURI`
- `WebhookHeaders`: `WHHeaders`, `Headers`
- `LogDirectory`: `LogDir`, `LogPath`

## 🔧 Functions

### Invoke-WebhookRequest

Sends HTTP webhook requests with device information.

**Location**: `Toolkit\Functions\Invoke-Webhook.ps1`

**Key Features**:
- Automatic device information gathering
- Custom HTTP headers support
- JSON payload formatting
- Comprehensive logging

**Example**:
```powershell
$Result = Invoke-WebhookRequest `
    -WebhookURI "https://api.example.com/devices" `
    -IncludeDefaultWebhookBody `
    -Verbose
```

### Start-ProcessWithOutput

Executes external processes with output capture and timeout management.

**Location**: `Toolkit\Functions\Start-ProcessWithOutput.ps1`

**Key Features**:
- Standard output/error capture
- Execution timeout support
- Regular expression parsing
- Secure argument logging

**Example**:
```powershell
$Result = Start-ProcessWithOutput `
    -FilePath "oa3tool.exe" `
    -ArgumentList "/Report" `
    -ExecutionTimeout ([TimeSpan]::FromSeconds(30)) `
    -LogOutput
```

## 🎯 Deployment Scenarios

### Scenario 1: USB Drive Collection

**Use Case**: Technician collects hardware hashes on USB drive during device setup.

```cmd
Invoke-HardwareHashOperation.exe -ExportToRemovableDisk -Overwrite
```

**Result**: CSV file saved to USB drive at `<DriveLetter>:\HardwareHashes\<SerialNumber>.csv`

### Scenario 2: SCCM/MDT Task Sequence

**Use Case**: Automatic hash collection during OS deployment.

**Task Sequence Step**:
- **Type**: Run PowerShell Script
- **Script**: `Invoke-HardwareHashOperation.ps1`
- **Parameters**: `-ExportToRemovableDisk -ContinueOnError`

### Scenario 3: Webhook to Azure Function

**Use Case**: Automatically register devices in Intune via webhook.

```powershell
$Headers = @{"x-functions-key" = "YOUR_FUNCTION_KEY"}

.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://yourapp.azurewebsites.net/api/RegisterDevice" `
    -WebhookHeaders $Headers
```

### Scenario 4: Windows PE Boot Media

**Use Case**: Standalone hardware hash collection from boot media.

1. Add script and tools to WinPE image
2. Boot device from media
3. Run: `X:\Deploy\Invoke-HardwareHashOperation.exe -ExportToRemovableDisk`

## 🔍 Troubleshooting

### Common Issues

#### Issue: "PCPKsp.dll not found"
**Solution**: Ensure `Toolkit\Tools\X64\PCPKsp.dll` exists. The script automatically registers it in WinPE.

#### Issue: "Hardware hash is empty"
**Solution**: 
- Verify OA3Tool.exe and OA3.cfg are present
- Check that TPM is enabled in BIOS
- Review logs in `Content\Logs` or `%TEMP%\SMSTSLog`

#### Issue: "Access Denied"
**Solution**: Run with administrator privileges. The PSBootstrapper executable handles elevation automatically.

#### Issue: "Webhook request failed"
**Solution**:
- Verify network connectivity
- Check webhook URI is correct
- Validate authentication headers
- Review firewall/proxy settings

### Log Locations

| Environment | Log Path |
|-------------|----------|
| Full Windows | `C:\Windows\Logs\Software\Invoke-HardwareHashOperation\` |
| Windows PE (MDT) | `X:\MININT\SMSOSD\OSDLOGS\Invoke-HardwareHashOperation\` |
| Windows PE (SCCM) | `X:\Windows\Temp\SMSTSLog\Invoke-HardwareHashOperation\` |
| Task Sequence | `%_SMSTSLogPath%\Invoke-HardwareHashOperation\` |

## 📚 Additional Resources

- [Windows Autopilot Documentation](https://docs.microsoft.com/en-us/mem/autopilot/)
- [Add devices to Autopilot](https://docs.microsoft.com/en-us/mem/autopilot/add-devices)
- [Autopilot device registration](https://docs.microsoft.com/en-us/mem/autopilot/enrollment-autopilot)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📄 License

This project is provided as-is for use in Windows Autopilot deployment scenarios.

---

**Version**: 1.0  
**Last Updated**: 2025  
**Author**: Script Author

For questions or support, please open an issue in the repository.

