# Invoke-HardwareHashOperation

A PowerShell solution for extracting Windows Autopilot hardware hashes and exporting them for device enrollment in Microsoft Intune. Designed for use during OS deployment, from Windows PE boot media, or as a standalone technician tool.

---

## Table of Contents

- [The Problem](#the-problem)
- [How This Solves It](#how-this-solves-it)
- [Overview](#overview)
- [Requirements](#requirements)
- [Required Tools](#required-tools)
- [Quick Start](#quick-start)
- [Parameters](#parameters)
- [Usage Examples](#usage-examples)
- [Webhook Payload](#webhook-payload)
- [Directory Structure](#directory-structure)
- [Deployment Scenarios](#deployment-scenarios)
- [Log Locations](#log-locations)
- [Troubleshooting](#troubleshooting)

---

## The Problem

Getting a Windows device enrolled in Intune and associated with an Autopilot profile should be simple. In practice, it isn't.

Microsoft provides no flexible, out-of-the-box tooling for hardware hash extraction and upload at scale. The process they document asks IT teams to:

1. **Manually extract** the hardware hash from each device — typically by running a PowerShell script or `OA3Tool.exe` on a booted machine and collecting the output.
2. **Manually upload** the resulting CSV to the Intune portal (one file at a time, per device or per batch).
3. **Manually assign** an Autopilot deployment profile to each imported device, or wait for dynamic group membership to eventually resolve.

For a single device, this is tedious. For hundreds of devices during a new site rollout, an annual hardware refresh, or a break-fix rotation, it becomes a serious operational bottleneck. IT administrators end up:

- Walking to each machine (or booting from USB), running a script, and copying a CSV off to a file share.
- Logging into the Intune portal, navigating to Autopilot device import, uploading the CSV, and waiting for processing.
- Verifying each device received the correct profile and group tag — and fixing the ones that didn't.
- Repeating the entire process when something goes wrong or a device is reimaged.

There is no native way to go from "hash extracted on a device" to "device registered in Autopilot" without manual portal interaction or writing your own Microsoft Graph integration from scratch.

---

## How This Solves It

`Invoke-HardwareHashOperation` eliminates the manual steps by handling everything from hash extraction to delivery in a single, automatable operation.

**On the device side**, the script:
- Extracts the hardware hash using `OA3Tool.exe`, decodes it, and builds a standards-compliant Autopilot CSV — all in one execution.
- Exports the CSV locally, to USB, or both — no manual file handling required.
- Optionally sends the full device payload (hardware hash, serial number, system information, TPM data) as structured JSON to a **webhook endpoint**.

**On the automation side**, the webhook capability is where the real value lies. Instead of uploading CSVs to the Intune portal, you point the script at a workflow automation platform — **[Zapier](https://zapier.com)**, **[n8n](https://n8n.io)**, **[ActivePieces](https://www.activepieces.com)**, or any system that can receive an HTTP POST — and let the workflow handle the rest:

```
Device boots → Script runs → Webhook fires → Workflow receives payload
    → Stores hash in a database via REST API
    → Imports device into Autopilot via Microsoft Graph
    → Assigns profile and group tag automatically
```

This completely removes the Intune portal from the equation. The device is registered, tagged, and profile-assigned without a human ever opening a browser. The workflow can also log the event, notify a Slack/Teams channel, update an asset management system, or trigger any other downstream action.

**The result:** What used to be a multi-step, per-device manual process becomes a single script execution that triggers a fully automated pipeline — whether you're imaging one laptop at a bench or deploying a fleet from a warehouse.

---

## Overview

`Invoke-HardwareHashOperation` extracts the Windows Autopilot hardware hash from a device using the OA3Tool utility and exports it in the Microsoft Autopilot-compatible CSV format. It supports:

- Export to a local path or default location
- Export to all detected removable USB drives
- Sending full device information to a webhook endpoint (for automation with tools such as n8n, Zapier, or Azure Functions)
- Execution in both Windows PE and full Windows environments

A PSBootstrapper executable (`Invoke-HardwareHashOperation.exe`) is included and handles PowerShell execution policy and administrator elevation automatically — making it the simplest way to run the script, especially in WinPE or technician scenarios.

In Windows PE, the script automatically registers `PCPKsp.dll` to enable TPM-based hash collection.

> **Note:** The `WinPE-SecureStartup` optional component must be present in your boot image for Self-Deploying Autopilot profiles to work. Without it, the hardware hash is collected but TPM data is incomplete.

---

## Requirements

| Requirement | Details |
|---|---|
| PowerShell | 5.0 or higher |
| OS | Windows 10/11 or Windows PE |
| Privileges | Administrator (script self-elevates if needed) |
| Tools | `OA3Tool.exe` and `PCPKsp.dll` — must be obtained separately (see [Required Tools](#required-tools)) |
| Network | Required only for `-SendWebhook` |

---

## Required Tools

The binaries required by this script cannot be redistributed and are therefore **not included** in this repository. You must obtain them separately from the Windows ADK and place them in the correct locations before running the script.

### OA3Tool.exe

`OA3Tool.exe` is part of the **Windows Assessment and Deployment Kit (Windows ADK)**.

1. Download the ADK installer from Microsoft:
   **https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install**
2. Run the installer and select the **Deployment Tools** feature (a full install is not required).
3. After installation, locate the tool at:
   ```
   C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Licensing\OA3\oa3tool.exe
   ```
4. Copy `oa3tool.exe` into:
   ```
   Toolkit\Tools\X64\oa3tool.exe
   ```

### PCPKsp.dll

`PCPKsp.dll` is the Platform Crypto Provider KSP used to access TPM data during hash extraction. It is a standard Windows system file and does not need to be placed in the Tools folder when running on a full Windows installation (the script finds it automatically in `System32`).

It is only required in `Toolkit\Tools\X64\` when running in **Windows PE without the `WinPE-SecureStartup` optional component**. In that case:

1. Copy `PCPKsp.dll` from any Windows 10/11 x64 system:
   ```
   C:\Windows\System32\PCPKsp.dll
   ```
2. Place it in:
   ```
   Toolkit\Tools\X64\PCPKsp.dll
   ```

> **Recommended alternative:** Add the `WinPE-SecureStartup` optional component to your WinPE boot image via the ADK WinPE add-on. This makes `PCPKsp.dll` available in the WinPE `System32` folder automatically and is required for Self-Deploying Autopilot profile support regardless.

---

## Quick Start

**Using the PSBootstrapper executable (recommended):**

```cmd
REM Harvest hash only
Invoke-HardwareHashOperation.exe

REM Export CSV to default location
Invoke-HardwareHashOperation.exe -Export

REM Export to USB drives
Invoke-HardwareHashOperation.exe -ExportToRemovableDisk

REM Export to USB drives and send to webhook
Invoke-HardwareHashOperation.exe -ExportToRemovableDisk -SendWebhook -WebhookURI "https://api.example.com/autopilot"
```

**Using PowerShell directly:**

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File ".\Invoke-HardwareHashOperation.ps1" -Export
```

---

## Parameters

| Parameter | Alias | Type | Description |
|---|---|---|---|
| `-Export` | `-E` | Switch | Exports the hardware hash CSV to the path set by `-ExportPath`, or the default path if omitted. |
| `-ExportPath` | `-EP` | FileInfo | Destination path for the CSV file. Defaults to `Content\HardwareHashes\<SerialNumber>.csv`. |
| `-ExportToRemovableDisk` | `-ETRD` | Switch | Exports the CSV to all detected, ready removable USB drives at `<Drive>:\HardwareHashes\<SerialNumber>.csv`. |
| `-Overwrite` | `-O` | Switch | Overwrites an existing CSV at the target path. Without this, existing files are skipped. |
| `-SendWebhook` | `-SWH` | Switch | POSTs device and hardware hash data as JSON to the URI specified by `-WebhookURI`. |
| `-WebhookURI` | `-WHURI` | URI | The webhook endpoint URI. Required when using `-SendWebhook`. |
| `-WebhookHeaders` | `-WHHeaders`, `-Headers` | String | HTTP headers for the webhook request as a **JSON string**. Example: `'{"Authorization": "Bearer <token>"}'` |
| `-ExcludeSystemInformation` | `-ESI` | Switch | Restricts the webhook payload to only Autopilot CSV fields (serial, hash, group tag, assigned user), omitting decoded hardware inventory. |
| `-LogDirectory` | `-LogDir`, `-LogPath` | DirectoryInfo | Custom log output directory. Auto-determined from environment if not specified. |
| `-ContinueOnError` | — | Switch | Suppresses terminating errors, allowing the script to continue past non-critical failures. |

---

## Usage Examples

### Extract only (no export)

```powershell
.\Invoke-HardwareHashOperation.ps1
```

Extracts and decodes the hardware hash. No CSV is written unless `-Export` or `-ExportToRemovableDisk` is specified.

---

### Export to default path

```powershell
.\Invoke-HardwareHashOperation.ps1 -Export
```

Saves the CSV to `Content\HardwareHashes\<SerialNumber>.csv` relative to the script directory.

---

### Export to custom path with overwrite

```powershell
.\Invoke-HardwareHashOperation.ps1 -Export -ExportPath "C:\Autopilot\DeviceHash.csv" -Overwrite
```

---

### Export to removable USB drives

```powershell
.\Invoke-HardwareHashOperation.ps1 -ExportToRemovableDisk -Overwrite
```

Detects all ready removable drives and writes `<Drive>:\HardwareHashes\<SerialNumber>.csv` to each.

---

### Send to webhook

```powershell
.\Invoke-HardwareHashOperation.ps1 -SendWebhook -WebhookURI "https://api.example.com/autopilot"
```

Sends a full JSON payload (hardware hash + decoded hardware inventory) to the endpoint.

---

### Send to webhook with authentication headers

```powershell
.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://api.example.com/autopilot" `
    -WebhookHeaders '{"Authorization": "Bearer YOUR_TOKEN", "x-api-key": "abc123"}'
```

> **Important:** `-WebhookHeaders` must be a JSON string, not a PowerShell hashtable.

---

### Send minimal webhook payload (Autopilot fields only)

```powershell
.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://api.example.com/autopilot" `
    -WebhookHeaders '{"Authorization": "Bearer YOUR_TOKEN"}' `
    -ExcludeSystemInformation
```

---

### Combined: export to USB and send webhook

```powershell
.\Invoke-HardwareHashOperation.ps1 `
    -Export `
    -ExportToRemovableDisk `
    -Overwrite `
    -SendWebhook `
    -WebhookURI "https://api.example.com/autopilot"
```

---

### Task Sequence (SCCM / MDT)

```cmd
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%ScriptRoot%\Invoke-HardwareHashOperation.ps1" -ExportToRemovableDisk -ContinueOnError
```

---

## Webhook Payload

When `-SendWebhook` is used **without** `-ExcludeSystemInformation`, the JSON payload includes:

| Section | Fields |
|---|---|
| Autopilot | `Device Serial Number`, `Windows Product ID`, `Hardware Hash`, `Group Tag`, `Assigned User` |
| Hardware | `SmbiosSystem*`, `CPU`, `RAM`, `TPM` (structured), `GPUs` (array), `Disks` (array) |
| Security | `SecuredCoreCriteria` (nested object with TPM 2.0, Secure Boot, HVCI, etc.) |
| Asset Management | `Manufacturer`, `Model`, `SystemID`, `SerialNumber`, `ChassisTypeNumber`, `ChassisTypeName`, `ChassisTypeGroup` |

**AssetManagement notes:**
- Lenovo devices: `Model` and `SystemID` fields are automatically swapped to reflect the correct human-readable model name.
- `ChassisTypeGroup` is resolved to `Desktop`, `Laptop`, or `Server` based on the SMBIOS chassis type.

When `-ExcludeSystemInformation` is specified, only the Autopilot CSV fields are sent.

**Task Sequence variables read (when running inside a task sequence):**

| Variable | Maps To |
|---|---|
| `EntraIDGroupTag` | `Group Tag` in the CSV and webhook payload |
| `EntraIDAssignedUser` | `Assigned User` in the CSV and webhook payload |

---

## Directory Structure

```
Invoke-HardwareHashOperation/
│
├── Invoke-HardwareHashOperation.ps1    # Main script
├── Invoke-HardwareHashOperation.exe    # PSBootstrapper (handles elevation & execution policy)
├── README.md
│
├── Content/
│   ├── HardwareHashes/                 # Default CSV export location
│   └── OA3Results/                     # Temporary OA3Tool XML output
│
├── Docs/                               # Extended documentation
│   ├── CHANGELOG.md
│   ├── DEPLOYMENT_GUIDE.md
│   └── TECHNICAL_DOCUMENTATION.md
│
└── Toolkit/
    ├── Toolkit.ps1                     # Core toolkit (dot-sourced by main script)
    ├── Functions/                      # Reusable function library
    ├── Libraries/
    ├── Modules/                        # PowerShell modules
    └── Tools/
        ├── X64/
        │   ├── OA3Tool.exe            # !! Obtain from Windows ADK — not included !!
        │   ├── PCPKsp.dll             # !! Copy from Windows System32 if needed in WinPE !!
        │   ├── OA3.cfg                # OA3Tool configuration (included)
        │   └── input.xml              # OA3Tool input template (included)
        └── X86/                        # 32-bit equivalents
```

---

## Deployment Scenarios

### USB Technician Tool

Boot or log in to a device, run the executable from a USB drive:

```cmd
Invoke-HardwareHashOperation.exe -ExportToRemovableDisk -Overwrite
```

The CSV is written back to the USB at `<Drive>:\HardwareHashes\<SerialNumber>.csv`.

---

### Windows PE Boot Media

Add the folder to your WinPE image and call from `startnet.cmd` or manually:

```cmd
X:\Deploy\Invoke-HardwareHashOperation.exe -ExportToRemovableDisk -Overwrite
```

Ensure the `WinPE-SecureStartup` component is included in the image for full TPM support.

---

### SCCM / MDT Task Sequence

Add a **Run PowerShell Script** step:

- **Script:** `Invoke-HardwareHashOperation.ps1`
- **Parameters:** `-ExportToRemovableDisk -ContinueOnError`

The script reads `EntraIDGroupTag` and `EntraIDAssignedUser` task sequence variables automatically if set.

---

### Webhook Automation (n8n / Azure Functions / Zapier)

```powershell
.\Invoke-HardwareHashOperation.ps1 `
    -SendWebhook `
    -WebhookURI "https://yourapp.azurewebsites.net/api/RegisterDevice" `
    -WebhookHeaders '{"x-functions-key": "YOUR_FUNCTION_KEY"}'
```

The structured JSON payload is suitable for direct ingestion by asset management systems or Intune automation workflows.

---

## Log Locations

| Environment | Log Path |
|---|---|
| Full Windows | `C:\Windows\Logs\Software\Invoke-HardwareHashOperation\` |
| Windows PE (MDT) | `X:\MININT\SMSOSD\OSDLOGS\Invoke-HardwareHashOperation\` |
| Windows PE (SCCM) | `X:\Windows\Temp\SMSTSLog\Invoke-HardwareHashOperation\` |
| Task Sequence | `%_SMSTSLogPath%\Invoke-HardwareHashOperation\` |

Log files are automatically rotated — only the 3 most recent are retained.

---

## Troubleshooting

### Hardware hash is empty
- Verify `OA3Tool.exe` and `OA3.cfg` are present in `Toolkit\Tools\X64\` (or `X86\`).
- Confirm TPM is enabled and functional in BIOS/UEFI.
- In WinPE, confirm `WinPE-SecureStartup` is included in the boot image.
- Review the log file for OA3Tool exit codes and output.

### PCPKsp.dll registration fails (WinPE only)
- Confirm `PCPKsp.dll` is present in `Toolkit\Tools\X64\`.
- Ensure the WinPE image includes the `WinPE-SecureStartup` component.

### Access Denied
- Use `Invoke-HardwareHashOperation.exe` — it self-elevates automatically.
- If running the `.ps1` directly, launch PowerShell as Administrator.

### Webhook request fails
- Verify network and internet connectivity from the device.
- Confirm the `-WebhookURI` is correct and reachable.
- Check that `-WebhookHeaders` is a valid JSON string (not a hashtable).
- Review proxy or firewall rules that may block outbound HTTPS.

---

## License

See [LICENSE](LICENSE) for details.
