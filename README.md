# Arch Linux Easy Installer v2.0

A beginner-friendly, TUI-based installation script for Arch Linux with advanced features.

## What's New in v2.0

🎉 **Major update with powerful new features:**

- 🎮 **Software Bundles** - One-click installation of curated software collections (Gaming, Development, Productivity, etc.)
- 🔒 **Disk Encryption (LUKS)** - Full disk encryption support with password prompts
- 📊 **Progress Indicators** - Visual progress bars for all operations
- ⚡ **Automatic Mirrors** - Uses reflector to find fastest mirrors automatically
- 🔄 **Resume Installation** - Resume interrupted installations from where they left off
- 💾 **Configuration Save/Load** - Save and share installation configurations
- 🧪 **Dry-Run Mode** - Test the installation without making changes
- ✅ **Pre-flight Checks** - Comprehensive system validation before installation
- 🛡️ **Better Validation** - Input validation with helpful error messages
- 📦 **AUR Helper** - Optional yay installation for AUR packages
- 📋 **Better Logging** - Detailed logs for troubleshooting

## Features

### Core Features
- **User-Friendly Interface** - Uses `dialog` for intuitive menu navigation
- **Automatic Partitioning** - Guided automatic disk partitioning with sensible defaults
- **Multiple Desktop Environments** - Install GNOME, KDE Plasma, XFCE, Cinnamon, and more
- **Hardware Detection** - Automatically detects and installs appropriate graphics drivers
- **Safety First** - Confirmation prompts before destructive operations
- **Comprehensive Logging** - All actions logged to `/var/log/arch-easy-install.log`

### Advanced Features
- **Full Disk Encryption** - LUKS2 encryption with secure password handling
- **Resume Capability** - Continue interrupted installations
- **Configuration Management** - Save/load installation profiles
- **Pre-flight Diagnostics** - Check system compatibility before starting
- **Dry-Run Mode** - Test installation without making changes
- **AUR Support** - Install yay and popular AUR packages
- **Progress Tracking** - Visual feedback during long operations

## Quick Start

1. Boot from the Arch Linux ISO
2. Connect to the internet
3. Download and run the installer:

```bash
# Connect to WiFi (if needed)
iwctl station wlan0 connect "Your_SSID"

# Or use Ethernet
dhcpcd

# Download the installer
curl -O https://raw.githubusercontent.com/yourusername/arch-easy-install/main/arch-easy-install.sh
chmod +x arch-easy-install.sh

# Run the installer
sudo bash arch-easy-install.sh
```

## Usage

### Basic Usage
```bash
sudo bash arch-easy-install.sh
```

### Command Line Options
```bash
# Dry run (simulation mode)
sudo bash arch-easy-install.sh --dry-run

# Resume interrupted installation
sudo bash arch-easy-install.sh --resume

# Load custom configuration
sudo bash arch-easy-install.sh --config my-config.json

# Enable verbose logging
sudo bash arch-easy-install.sh --verbose

# Show help
sudo bash arch-easy-install.sh --help
```

## What Gets Installed

### Base System
- Linux kernel (linux) with firmware
- Base system utilities (base, base-devel)
- CPU microcode (intel-ucode or amd-ucode)
- Network Manager
- Basic development tools
- Firewall (UFW)
- PipeWire audio system

### Desktop Environment Options
- **GNOME** - Modern, beginner-friendly
- **KDE Plasma** - Highly customizable
- **XFCE** - Lightweight
- **Cinnamon** - Traditional interface
- **MATE** - Classic GNOME 2 style
- **LXQt** - Very lightweight
- **Budgie** - Elegant design
- **Deepin** - Beautiful, unique
- **i3/Sway** - Tiling window managers

### Common Applications
- Firefox (web browser)
- Thunar (file manager)
- Terminal emulator
- VLC (media player)
- Archive utilities (p7zip, unzip)
- Document and image viewers
- Fonts and emoji support
- Neofetch system info

### Software Bundles 🎮

One-click installation of curated software collections:

| Bundle | Description | Key Packages |
|--------|-------------|--------------|
| **🎮 Gaming** | Steam, emulators, gaming tools | steam, lutris, wine, gamemode, mangohud |
| **💻 Development** | IDEs, editors, compilers | VS Code, vim, git, docker, nodejs, rust |
| **📊 Productivity** | Office suite, note-taking | LibreOffice, Thunderbird, Nextcloud |
| **🎬 Multimedia** | Video editing, audio production | Kdenlive, OBS, Audacity, ffmpeg |
| **🎨 Creative** | Graphics design, 3D modeling | GIMP, Krita, Blender, Inkscape |
| **📡 Streaming** | Streaming and recording tools | OBS, screen recorders |
| **🔒 Security** | VPN, firewall, privacy tools | WireGuard, Tor, KeePassXC |
| **🔬 Science** | Data analysis, math tools | Jupyter, R, Octave, Python scientific stack |

**Usage:** Select bundles during installation or from the main menu. Each bundle includes both official repo and AUR packages where available.

### Optional Features
- **AUR Helper (yay)** - For accessing community packages
- **Reflector** - Automatic mirror updates
- **Disk Encryption** - LUKS2 full disk encryption
- **Swap** - Configurable swap space
- **Software Bundles** - Curated package collections

## Installation Process

### Phase 1: Pre-Installation Checks
- Boot mode detection (UEFI/BIOS)
- Internet connectivity check
- Disk space verification
- System compatibility check
- Optional encryption setup

### Phase 2: Disk Partitioning
- Disk selection with validation
- Automatic or manual partitioning
- EFI/boot partition creation
- Root and optional /home partitions
- Swap configuration
- LUKS encryption (optional)

### Phase 3: Base Installation
- Mirror selection (automatic with reflector)
- Package installation
- fstab generation
- System base setup

### Phase 4: System Configuration
- Timezone selection
- Locale and keyboard layout
- Hostname configuration
- Root password setup
- User account creation
- Sudo configuration

### Phase 5: Bootloader Installation
- systemd-boot (UEFI, default)
- GRUB (UEFI/BIOS)
- Encryption configuration
- Boot entries setup

### Phase 6: Desktop Installation (Optional)
- Desktop environment selection
- Graphics drivers (NVIDIA/AMD/Intel)
- Display manager installation
- Common applications

### Phase 7: Software Bundles (Optional)
- Gaming bundle (Steam, Lutris, Wine)
- Development bundle (IDEs, Docker, Git)
- Productivity bundle (Office, Email)
- Multimedia bundle (Video editing, OBS)
- Creative bundle (GIMP, Blender)
- And more...

### Phase 8: Post-Installation
- Essential services enabled
- Firewall configuration
- Additional utilities installed
- AUR helper (optional)
- Reflector timer setup

## Configuration

### Configuration File Format

The installer uses JSON configuration files:

```json
{
    "version": "1.0.0",
    "disk": {
        "device": "/dev/sda",
        "partitioning": "automatic",
        "filesystem": "ext4",
        "swap_size": "2048",
        "separate_home": true,
        "encrypt": false
    },
    "system": {
        "hostname": "archpc",
        "timezone": "America/New_York",
        "locale": "en_US.UTF-8",
        "keymap": "us",
        "username": "user"
    },
    "desktop": {
        "install": true,
        "environment": "gnome",
        "install_drivers": true
    },
    "packages": {
        "aur_helper": true
    },
    "options": {
        "dry_run": false,
        "verbose": true
    }
}
```

### Saving/Loading Configurations

From the main menu:
1. **Load Configuration** - Load a saved JSON configuration file
2. **Save Configuration** - Save current settings to a JSON file

This allows you to:
- Create standard configurations for multiple machines
- Share configurations with others
- Backup your installation preferences
- Automate installations

## Disk Encryption

### Features
- LUKS2 encryption with Argon2id
- AES-XTS 512-bit encryption
- Separate /home encryption option
- Encrypted swap file
- Bootloader integration

### How It Works
1. Choose encryption during pre-installation
2. Set a strong password (8+ characters)
3. Optional: Secure wipe before encryption
4. System encrypts partitions automatically
5. Enter password at each boot

### Important Notes
⚠️ **DO NOT FORGET YOUR ENCRYPTION PASSWORD!** There is no way to recover data without it.

## Resuming Installation

If the installation is interrupted:

```bash
sudo bash arch-easy-install.sh --resume
```

Or from the main menu, the installer will detect the interrupted installation and offer to resume.

## Directory Structure

```
arch-easy-install/
├── arch-easy-install.sh    # Main entry point
├── setup.sh                # Setup script
├── lib/
│   ├── common.sh          # Utilities and logging
│   ├── config.sh          # Configuration management
│   ├── validation.sh      # Input validation
│   ├── preflight.sh       # Pre-flight checks
│   ├── progress.sh        # Progress indicators
│   ├── encryption.sh      # LUKS encryption
│   ├── disk.sh            # Partitioning functions
│   ├── install.sh         # Base installation
│   ├── desktop.sh         # Desktop environment setup
│   ├── aur.sh             # AUR helper installation
│   └── bundles.sh         # Software bundles
├── config/                # Configuration templates
│   ├── example-minimal.json
│   ├── example-desktop.json
│   └── example-encrypted.json
├── arch-install-plan.md   # Original planning document
└── README.md              # This file
```

## Requirements

### Minimum
- Arch Linux ISO booted
- 512MB RAM
- 20GB disk space
- Internet connection
- x86_64 architecture

### Recommended
- 2GB+ RAM (4GB for desktop)
- 50GB+ disk space
- UEFI boot mode
- SSD for better performance

## Troubleshooting

### No Internet Connection
```bash
# For WiFi
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "Your_SSID"

# For Ethernet
dhcpcd
```

### Check Logs
```bash
# View installation log
cat /var/log/arch-easy-install.log

# View in real-time
tail -f /var/log/arch-easy-install.log
```

### Disk Space Issues
```bash
# Check available space
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Check specific disk
blockdev --getsize64 /dev/sda
```

### Encryption Issues
If you forget your LUKS password, data recovery is **impossible**. Always:
- Choose a memorable but strong password
- Consider writing it down and storing securely
- Test the password immediately after installation

### Resume After Failure
```bash
# Check installation state
cat /tmp/arch-install-state.json

# Resume installation
sudo bash arch-easy-install.sh --resume
```

## Safety Features

- **Disk selection confirmation** - Multiple prompts before erasing
- **Type-to-confirm** - Type "DESTROY" or "INSTALL" for dangerous operations
- **Partition layout review** - Show summary before applying
- **Dry-run mode** - Test without making changes
- **Comprehensive logging** - Track every action
- **Resume capability** - Recover from interruptions

## Customization

Advanced users can modify library files in `lib/` to:
- Add custom packages
- Change default configurations
- Add additional desktop environments
- Modify partition schemes
- Add pre/post-install hooks

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

### Testing Checklist
- [ ] Test on VirtualBox (UEFI and BIOS)
- [ ] Test on real hardware
- [ ] Test with encryption enabled
- [ ] Test resume functionality
- [ ] Test dry-run mode
- [ ] Verify all desktop environments install
- [ ] Check log output for errors

## License

MIT License - Feel free to modify and distribute!

## Disclaimer

This script modifies disk partitions and installs operating system software. **Always backup important data before running.** The authors are not responsible for any data loss or system damage.

## Support

For issues and questions:
- Check the Arch Linux Wiki: https://wiki.archlinux.org
- Arch Linux Forums: https://bbs.archlinux.org
- GitHub Issues (if applicable)

## Credits

- Arch Linux Wiki: https://wiki.archlinux.org
- Arch Linux community
- dialog - TUI library
- reflector - Mirror ranking tool
- LUKS/dm-crypt - Disk encryption

## Version History

### v2.0 (Current)
- Added software bundles (Gaming, Development, Productivity, etc.)
- Added disk encryption (LUKS2)
- Added progress indicators
- Added reflector mirror selection
- Added resume capability
- Added configuration save/load
- Added dry-run mode
- Added pre-flight checks
- Added input validation
- Added AUR helper installation
- Improved error handling
- Better logging

### v1.0
- Initial release
- Basic TUI interface
- Automatic partitioning
- Desktop environment selection
- Basic hardware detection
