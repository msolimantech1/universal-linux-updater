# Universal Linux Auto Updater

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Systemd](https://img.shields.io/badge/systemd-000000?style=for-the-badge&logo=systemd&logoColor=white)

A cross-distribution automatic update script for Linux systems that supports:
- **Debian/Ubuntu** (apt)
- **RHEL/CentOS** (yum/dnf)
- **Fedora** (dnf)
- **openSUSE** (zypper)
- **Arch Linux** (pacman)
- **Alpine Linux** (apk)

## Features

✅ **Multi-distro support** - Works with 6 major package managers  
✅ **Flexible scheduling** - Daily, weekly, or monthly updates  
✅ **Automatic cleanup** - Removes unnecessary packages after updates  
✅ **Dual scheduling** - Uses systemd timers or cron jobs automatically  
✅ **Comprehensive logging** - Detailed logs in `/var/log/auto-updater.log`  
✅ **Safe operations** - Randomized delay to prevent system overload  
✅ **Alpine optimized** - Special handling for Alpine's unique characteristics  

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/msolimantech1/universal-linux-updater/refs/heads/master/universal-updater.sh

# Make it executable
chmod +x universal-updater.sh

# Run the installer
sudo ./universal-updater.sh
```

Follow the prompts to select your desired update frequency.

## Usage

### Manual Run
```bash
sudo ./universal-updater.sh --run
```

### Check Status
```bash
# For systemd systems:
systemctl list-timers | grep auto-updater
journalctl -u auto-updater -b

# For cron systems:
crontab -l
tail -f /var/log/auto-updater.log
```

### Uninstall
```bash
# Systemd systems:
sudo systemctl disable --now auto-updater.timer
sudo rm /etc/systemd/system/auto-updater.{service,timer}

# Cron systems:
crontab -l | grep -v "universal-updater.sh" | crontab -
```

## Configuration

The script automatically detects your system configuration, but you can customize:

1. **Log location**: Modify `LOG_FILE` variable in the script
2. **Update timing**: Re-run installer to change frequency
3. **Package manager**: Script auto-detects, but you can override if needed

## Compatibility

| Distribution  | Package Manager | Init System  | Tested  |
|--------------|----------------|-------------|---------|
| Ubuntu/Debian | apt           | systemd     | ✅      |
| RHEL/CentOS  | yum/dnf       | systemd     | ✅      |
| Fedora       | dnf           | systemd     | ✅      |
| openSUSE     | zypper        | systemd     | ✅      |
| Arch Linux   | pacman        | systemd     | ✅      |
| Alpine Linux | apk           | OpenRC/cron | ✅      |

## Security Considerations

1. The script requires root privileges for package operations
2. Review the script before running (especially if downloaded remotely)
3. Consider setting up a dedicated user with limited sudo privileges
4. Regularly check update logs for unexpected changes

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)

---

**Maintained by**: [MSolimanTech]  
**Report Issues**: [GitHub Issues](https://github.com/msolimantech1/universal-linux-updater/issues)
```
