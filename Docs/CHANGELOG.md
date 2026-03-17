# Changelog

All notable changes to the Invoke-HardwareHashOperation project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-XX

### Added
- Initial release of Invoke-HardwareHashOperation
- Main script (`Invoke-HardwareHashOperation.ps1`) for hardware hash extraction
- PSBootstrapper executable (`Invoke-HardwareHashOperation.exe`) for simplified execution
- Comprehensive toolkit infrastructure (`Toolkit/Toolkit.ps1`)
- `Invoke-WebhookRequest` function for webhook integration
- `Start-ProcessWithOutput` function for process execution with output capture
- Support for Windows PE and full Windows environments
- Automatic PCPKsp.dll registration in Windows PE
- Export to removable USB drives functionality
- Webhook integration for remote device registration
- Comprehensive logging with automatic rotation (keeps 3 most recent logs)
- Network connectivity detection and validation
- Self-elevation for administrator privileges
- Support for custom export paths
- Overwrite protection with optional override
- Task Sequence environment detection (SCCM/MDT)
- Automatic log directory determination based on environment
- Hardware information gathering and logging
- Exit code management with categorized ranges

### Documentation
- Comprehensive README.md with quick start guide
- Technical documentation (TECHNICAL_DOCUMENTATION.md)
- Quick reference guide (QUICK_REFERENCE.md)
- Deployment guide for various scenarios (DEPLOYMENT_GUIDE.md)
- Inline documentation for all scripts and functions
- Parameter descriptions with examples
- PSBootstrapper usage examples

### Tools Included
- OA3Tool.exe (X64) for hardware hash extraction
- PCPKsp.dll (X64) for TPM provider in WinPE
- OA3.cfg configuration file
- Input.xml template

### Features
- **Hardware Hash Extraction**: Reliable extraction using OA3Tool
- **Multiple Export Options**: Local, USB drives, network shares
- **Webhook Support**: Send device information to remote endpoints
- **Environment Detection**: Automatic detection of WinPE, Task Sequence, Full OS
- **Logging**: Detailed execution logs with timestamps
- **Error Handling**: Comprehensive error handling with ContinueOnError support
- **CSV Format**: Microsoft Autopilot-compatible CSV output
- **Network Validation**: Connectivity testing before webhook operations

### Deployment Scenarios Supported
- SCCM/ConfigMgr Task Sequences
- MDT Deployments
- WinPE Boot Media
- Intune Win32 Apps
- USB Technician Tools
- Standalone execution

### Requirements
- PowerShell 5.0 or higher
- Windows 10/11 or Windows PE
- Administrator privileges
- TPM 2.0 enabled (for hardware hash extraction)

---

## [Unreleased]

### Planned Features
- Support for bulk device processing
- Integration with Microsoft Graph API for direct Intune upload
- GUI interface for technician use
- Support for additional hardware hash formats
- Enhanced webhook retry logic with exponential backoff
- Multi-language support
- Custom CSV field mapping
- Integration with ServiceNow and other ITSM platforms

### Under Consideration
- Linux/macOS support for webhook functionality
- PowerShell 7+ optimization
- Docker container for webhook receiver
- REST API for centralized collection
- Real-time dashboard for collection monitoring

---

## Version History

### Version Numbering

This project uses Semantic Versioning:
- **MAJOR** version for incompatible API changes
- **MINOR** version for added functionality in a backwards compatible manner
- **PATCH** version for backwards compatible bug fixes

### Release Notes Format

Each release includes:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes

---

## How to Contribute

If you'd like to contribute to this project:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## Support

For issues, questions, or feature requests:
- Open an issue in the repository
- Check existing documentation in the `Docs/` folder
- Review the troubleshooting section in `QUICK_REFERENCE.md`

---

**Maintained By**: IT Operations Team  
**Project Start Date**: 2025  
**License**: See LICENSE file for details

