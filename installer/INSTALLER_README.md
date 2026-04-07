# Fleet Manager Desktop Installer

## Building the Installer

### Prerequisites
- Node.js 18+
- npm or yarn
- Windows: Windows 10+ SDK (for Windows builds)
- macOS: Xcode Command Line Tools (for Mac builds)

### Build Steps

1. **Install dependencies:**
   ```bash
   cd installer
   npm install
   ```

2. **Build for Windows:**
   ```bash
   npm run dist:win
   ```
   Output: `release/Fleet Manager Desktop Setup.exe`

3. **Build for macOS:**
   ```bash
   npm run dist:mac
   ```
   Output: `release/Fleet Manager Desktop.dmg`

## System Requirements

### Minimum Requirements
- **OS:** Windows 10/11 or macOS 10.15+
- **RAM:** 4 GB (8 GB recommended)
- **Disk Space:** 10 GB available
- **CPU:** Dual-core 2.0 GHz or faster
- **Network:** Internet connection for GPS sync

### Supported Databases
- PostgreSQL 12+ (recommended)
- MySQL 8.0+
- SQLite (single-user mode)

### Supported GPS Devices
- Garmin Fleet
- Trimble
- Geotab GO
- Verizon Networkfleet
- Generic NMEA 0183/2000
- ELD-compliant devices

## Installation Process

The installer wizard guides users through:

1. **System Requirements Check** - Validates hardware/software compatibility
2. **Database Configuration** - Sets up connection to fleet database
3. **GPS Device Setup** - Detects and configures tracking hardware
4. **Installation Options** - Choose install location and shortcuts
5. **Installation** - Copies files and configures system

## Post-Installation

After successful installation:

- Launch from Desktop shortcut or Start Menu
- Default admin credentials: `admin` / `admin123` (change immediately)
- Configure organization settings
- Import existing fleet data
- Add vehicles and drivers
- Set up geofencing zones

## Troubleshooting

### Database Connection Issues
- Verify PostgreSQL/MySQL is running
- Check firewall allows port 5432/3306
- Confirm username/password

### GPS Device Not Detected
- Ensure device drivers are installed
- Check USB connection
- Try different USB port
- Restart application

### Performance Issues
- Check available RAM (close other apps)
- Verify disk space >10GB free
- Update graphics drivers
- Disable antivirus temporarily during install

## Support

- Documentation: https://docs.fleetmanager.com
- Email: support@fleetmanager.com
- Phone: 1-800-FLEET-MGR
