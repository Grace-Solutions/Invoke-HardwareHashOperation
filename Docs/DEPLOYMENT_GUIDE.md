# Deployment Guide - Invoke-HardwareHashOperation

## Overview

This guide provides step-by-step instructions for deploying the Invoke-HardwareHashOperation solution in various enterprise scenarios.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Package Preparation](#package-preparation)
3. [Deployment Method 1: SCCM/ConfigMgr](#deployment-method-1-sccmconfigmgr)
4. [Deployment Method 2: MDT](#deployment-method-2-mdt)
5. [Deployment Method 3: WinPE Boot Media](#deployment-method-3-winpe-boot-media)
6. [Deployment Method 4: Intune](#deployment-method-4-intune)
7. [Deployment Method 5: USB Technician Tool](#deployment-method-5-usb-technician-tool)
8. [Webhook Integration](#webhook-integration)
9. [Testing & Validation](#testing--validation)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **Target Devices**:
  - Windows 10 version 1809 or later
  - Windows 11 (all versions)
  - TPM 2.0 enabled in BIOS/UEFI
  - UEFI boot mode (recommended)

- **Deployment Infrastructure**:
  - SCCM/ConfigMgr (if using SCCM method)
  - MDT (if using MDT method)
  - Windows ADK (for WinPE customization)
  - Network connectivity (for webhook scenarios)

### Required Files

Ensure your package contains:
```
Invoke-HardwareHashOperation/
├── Invoke-HardwareHashOperation.ps1
├── Invoke-HardwareHashOperation.exe
├── Toolkit/
│   ├── Toolkit.ps1
│   ├── Functions/
│   │   ├── Invoke-Webhook.ps1
│   │   └── Start-ProcessWithOutput.ps1
│   └── Tools/
│       └── X64/
│           ├── OA3Tool.exe
│           ├── PCPKsp.dll
│           ├── OA3.cfg
│           └── input.xml
```

---

## Package Preparation

### Step 1: Download and Extract

1. Download the package
2. Extract to a working directory
3. Verify all files are present

### Step 2: Customize Configuration (Optional)

**Modify OA3.cfg** (if needed):
```xml
<?xml version="1.0" encoding="utf-8"?>
<OA3ToolConfig>
  <ReportMode>true</ReportMode>
  <NoKeyCheck>true</NoKeyCheck>
  <OutputFormat>XML</OutputFormat>
</OA3ToolConfig>
```

### Step 3: Test Locally

```powershell
# Test on a sample device
.\Invoke-HardwareHashOperation.ps1 -Verbose

# Verify CSV output
Get-Content ".\Content\HardwareHashes\*.csv"
```

---

## Deployment Method 1: SCCM/ConfigMgr

### Option A: Task Sequence Step

#### 1. Create Package

1. Open ConfigMgr Console
2. Navigate to: **Software Library** > **Application Management** > **Packages**
3. Right-click **Packages** > **Create Package**
4. Configure:
   - **Name**: Autopilot Hardware Hash Collection
   - **Description**: Extracts and exports Autopilot hardware hash
   - **Manufacturer**: Your Organization
   - **Version**: 1.0
   - **This package contains source files**: ✅ Checked
   - **Source folder**: `\\Server\Share\Invoke-HardwareHashOperation`

#### 2. Create Program

1. In the package, create a new program:
   - **Name**: Extract Hardware Hash
   - **Command line**: 
     ```cmd
     powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
     ```
   - **Run**: Hidden
   - **Program can run**: Whether or not a user is logged on
   - **Run mode**: Run with administrative rights

#### 3. Distribute Content

1. Right-click package > **Distribute Content**
2. Select distribution points
3. Monitor distribution status

#### 4. Add to Task Sequence

1. Open your OSD Task Sequence
2. Add step: **Run Command Line** or **Run PowerShell Script**
3. Configure:
   - **Name**: Collect Autopilot Hardware Hash
   - **Package**: Select your package
   - **Command line**: 
     ```cmd
     powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
     ```
   - **Success codes**: 0 3010

**Recommended Placement**: After "Setup Windows and ConfigMgr" step

---

### Option B: Standalone Application

#### 1. Create Application

1. Navigate to: **Software Library** > **Application Management** > **Applications**
2. Right-click **Applications** > **Create Application**
3. Select **Manually specify the application information**
4. Configure:
   - **Name**: Autopilot Hardware Hash Collector
   - **Publisher**: Your Organization
   - **Software Version**: 1.0

#### 2. Add Deployment Type

1. Add deployment type: **Script Installer**
2. Configure:
   - **Content location**: `\\Server\Share\Invoke-HardwareHashOperation`
   - **Installation program**:
     ```cmd
     Invoke-HardwareHashOperation.exe -ExportToRemovableDisk
     ```
   - **Uninstall program**: (leave blank)
   - **Detection method**: Custom script
   
   **Detection Script** (PowerShell):
   ```powershell
   # Check if hardware hash CSV exists
   $SerialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
   $CSVPath = "C:\ProgramData\Autopilot\$SerialNumber.csv"
   
   If (Test-Path $CSVPath) {
       Write-Host "Detected"
   }
   ```

#### 3. Deploy Application

1. Right-click application > **Deploy**
2. Select collection
3. Configure:
   - **Purpose**: Required
   - **Deployment options**: Download content from distribution point and run locally
   - **User experience**: Install for system, whether or not a user is logged on

---

## Deployment Method 2: MDT

### Step 1: Import Application

1. Open MDT Deployment Workbench
2. Navigate to: **Deployment Share** > **Applications**
3. Right-click **Applications** > **New Application**
4. Select: **Application with source files**
5. Configure:
   - **Publisher**: Your Organization
   - **Application Name**: Autopilot Hardware Hash Collector
   - **Source directory**: `C:\Temp\Invoke-HardwareHashOperation`
   - **Destination directory**: Invoke-HardwareHashOperation

### Step 2: Configure Application

- **Command line**:
  ```cmd
  powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
  ```
- **Working directory**: `%DEPLOYROOT%\Applications\Invoke-HardwareHashOperation`

### Step 3: Add to Task Sequence

1. Open your task sequence
2. Add step: **Install Application**
3. Select: **Autopilot Hardware Hash Collector**
4. Place after: **Install Operating System**

### Step 4: Update Deployment Share

1. Right-click deployment share > **Update Deployment Share**
2. Select: **Completely regenerate the boot images**
3. Wait for completion

---

## Deployment Method 3: WinPE Boot Media

### Step 1: Mount WinPE Image

```powershell
# Create working directory
New-Item -Path "C:\WinPE_Custom" -ItemType Directory -Force

# Copy base WinPE
Copy-Item "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" `
    -Destination "C:\WinPE_Custom\winpe.wim"

# Mount image
New-Item -Path "C:\WinPE_Custom\Mount" -ItemType Directory -Force
Mount-WindowsImage -ImagePath "C:\WinPE_Custom\winpe.wim" -Index 1 -Path "C:\WinPE_Custom\Mount"
```

### Step 2: Add Script to Image

```powershell
# Create directory in WinPE
New-Item -Path "C:\WinPE_Custom\Mount\Deploy" -ItemType Directory -Force

# Copy script files
Copy-Item "C:\Source\Invoke-HardwareHashOperation\*" `
    -Destination "C:\WinPE_Custom\Mount\Deploy\" -Recurse -Force
```

### Step 3: Add Startup Script (Optional)

Create `C:\WinPE_Custom\Mount\Windows\System32\startnet.cmd`:
```cmd
@echo off
wpeinit
echo.
echo ========================================
echo Autopilot Hardware Hash Collector
echo ========================================
echo.
echo Insert USB drive and press any key...
pause
X:\Deploy\Invoke-HardwareHashOperation.exe -ExportToRemovableDisk
echo.
echo Collection complete! Press any key to exit...
pause
wpeutil shutdown
```

### Step 4: Commit and Create ISO

```powershell
# Unmount and save
Dismount-WindowsImage -Path "C:\WinPE_Custom\Mount" -Save

# Create bootable ISO
$OSCDImgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
$BootData = "2#p0,e,bC:\WinPE_Custom\fwfiles\etfsboot.com#pEF,e,bC:\WinPE_Custom\fwfiles\efisys.bin"

& $OSCDImgPath -m -o -u2 -udfver102 -bootdata:$BootData `
    "C:\WinPE_Custom\Mount" "C:\WinPE_Custom\AutopilotCollector.iso"
```

### Step 5: Create Bootable USB

```powershell
# Format USB drive (replace E: with your drive letter)
Format-Volume -DriveLetter E -FileSystem FAT32 -NewFileSystemLabel "AutopilotPE"

# Copy WinPE files
Copy-Item "C:\WinPE_Custom\Mount\*" -Destination "E:\" -Recurse -Force
```

---

## Deployment Method 4: Intune

### Step 1: Package as Win32 App

1. Create IntuneWin package:
   ```powershell
   # Download IntuneWinAppUtil
   # https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
   
   .\IntuneWinAppUtil.exe `
       -c "C:\Source\Invoke-HardwareHashOperation" `
       -s "Invoke-HardwareHashOperation.exe" `
       -o "C:\Output"
   ```

### Step 2: Upload to Intune

1. Navigate to: **Apps** > **Windows** > **Add**
2. Select: **Windows app (Win32)**
3. Upload `.intunewin` file
4. Configure:
   - **Name**: Autopilot Hardware Hash Collector
   - **Publisher**: Your Organization
   - **Install command**:
     ```cmd
     Invoke-HardwareHashOperation.exe -ExportPath "%ProgramData%\Autopilot\HardwareHash.csv"
     ```
   - **Uninstall command**: `cmd.exe /c`
   - **Install behavior**: System
   - **Detection rules**: Custom script
   
   **Detection Script**:
   ```powershell
   $CSVPath = "$env:ProgramData\Autopilot\HardwareHash.csv"
   If (Test-Path $CSVPath) {
       Write-Host "Detected"
       Exit 0
   }
   Exit 1
   ```

### Step 3: Assign to Devices

1. Go to **Assignments**
2. Add group: **All Devices** or specific group
3. Save

---

## Deployment Method 5: USB Technician Tool

### Step 1: Prepare USB Drive

1. Format USB drive (FAT32 or NTFS)
2. Create folder structure:
   ```
   E:\
   ├── AutopilotCollector\
   │   └── (Copy all script files here)
   └── HardwareHashes\
       └── (CSV files will be saved here)
   ```

### Step 2: Create Launcher Script

Create `E:\CollectHash.cmd`:
```cmd
@echo off
echo ========================================
echo Autopilot Hardware Hash Collector
echo ========================================
echo.
cd /d "%~dp0AutopilotCollector"
Invoke-HardwareHashOperation.exe -ExportPath "%~dp0HardwareHashes\%COMPUTERNAME%.csv" -Overwrite
echo.
echo Collection complete!
echo CSV saved to: %~dp0HardwareHashes\%COMPUTERNAME%.csv
echo.
pause
```

### Step 3: Usage Instructions

1. Insert USB drive into target device
2. Run `E:\CollectHash.cmd` as administrator
3. Wait for completion
4. CSV file saved to `E:\HardwareHashes\`

---

## Webhook Integration

### Azure Function Setup

#### 1. Create Azure Function

```csharp
// C# Azure Function example
[FunctionName("RegisterAutopilotDevice")]
public static async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req,
    ILogger log)
{
    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JsonConvert.DeserializeObject(requestBody);
    
    // Process device information
    string serialNumber = data?.HardwareDetails?.SerialNumber;
    string manufacturer = data?.HardwareDetails?.Manufacturer;
    string model = data?.HardwareDetails?.Model;
    
    log.LogInformation($"Received device: {serialNumber} - {manufacturer} {model}");
    
    // Store in database or forward to Intune API
    // ... your logic here ...
    
    return new OkObjectResult(new { status = "success", deviceId = serialNumber });
}
```

#### 2. Configure Script

```powershell
$Headers = @{
    "x-functions-key" = "YOUR_FUNCTION_KEY"
}

.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://yourapp.azurewebsites.net/api/RegisterAutopilotDevice" `
    -WebhookHeaders $Headers
```

---

## Testing & Validation

### Pre-Deployment Testing

1. **Test on sample device**:
   ```powershell
   .\Invoke-HardwareHashOperation.ps1 -Verbose
   ```

2. **Verify CSV format**:
   ```powershell
   $CSV = Import-Csv ".\Content\HardwareHashes\*.csv"
   $CSV | Format-Table
   ```

3. **Test USB export**:
   ```powershell
   .\Invoke-HardwareHashOperation.ps1 -ExportToRemovableDisk -Verbose
   ```

4. **Test webhook** (if applicable):
   ```powershell
   .\Invoke-HardwareHashOperation.ps1 -SendWebhook -WebhookURI "https://webhook.site/your-unique-url"
   ```

### Post-Deployment Validation

1. **Check logs**:
   ```powershell
   Get-ChildItem "C:\Windows\Logs\Software\Invoke-HardwareHashOperation" -Recurse
   ```

2. **Verify CSV content**:
   - Device Serial Number populated
   - Hardware Hash is base64 string
   - No empty required fields

3. **Import to Intune**:
   - Test import with sample CSV
   - Verify device appears in Autopilot devices

---

## Troubleshooting

See `QUICK_REFERENCE.md` for detailed troubleshooting steps.

---

**Deployment Guide Version**: 1.0  
**Last Updated**: 2025  
**Maintained By**: IT Operations Team

