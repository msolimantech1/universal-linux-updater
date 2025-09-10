#!/bin/bash

# Universal System Update Script v2.2
VERSION="2.2"
LOG_FILE="/var/log/auto-updater.log"

# Check root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
}

# Initialize logging
setup_logging() {
    touch "$LOG_FILE" 2>/dev/null || {
        echo "Cannot create log file at $LOG_FILE" >&2
        LOG_FILE="$HOME/auto-updater.log"
        echo "Using fallback log location: $LOG_FILE"
    }
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# Detect distribution and package manager
detect_system() {
    if [ -f /etc/os-release ]; then
        DISTRO_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
        DISTRO_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
    elif [ -f /etc/alpine-release ]; then
        DISTRO_ID="alpine"
        DISTRO_VERSION=$(cat /etc/alpine-release)
    fi

    declare -A PKG_MANAGERS=(
        ["old-apt"]="/usr/bin/apt-get"
        ["new-apt"]="/usr/bin/apt"
        ["dnf"]="/usr/bin/dnf"
        ["yum"]="/usr/bin/yum"
        ["pacman"]="/usr/bin/pacman"
        ["zypper"]="/usr/bin/zypper"
        ["apk"]="/sbin/apk"
    )

    for manager in "${!PKG_MANAGERS[@]}"; do
        if [ -x "${PKG_MANAGERS[$manager]}" ]; then
            PKG_MANAGER="$manager"
            break
        fi
    done

    if [ -z "$PKG_MANAGER" ]; then
        echo "ERROR: No supported package manager found" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Define update commands for each package manager
set_update_commands() {
    case "$PKG_MANAGER" in
        old-apt)
            UPDATE_CMD="apt-get update -y && apt-get upgrade -y"
            CLEAN_CMD="apt-get autoremove -y && apt-get clean"
            ;;
        new-apt)
            UPDATE_CMD="apt update -y && apt upgrade -y"
            CLEAN_CMD="apt autoremove -y && apt clean"
            ;;
        dnf|yum)
            UPDATE_CMD="$PKG_MANAGER upgrade -y"
            CLEAN_CMD="$PKG_MANAGER autoremove -y"
            ;;
        pacman)
            UPDATE_CMD="pacman -Syu --noconfirm"
            CLEAN_CMD="pacman -Qtdq | pacman -Rns --noconfirm -"
            ;;
        zypper)
            UPDATE_CMD="zypper refresh && zypper update -y"
            CLEAN_CMD="zypper packages --unneeded | awk -F'|' '/^i/ {print \$3}' | xargs -r zypper remove -y"
            ;;
        apk)
            UPDATE_CMD="apk update && apk upgrade"
            CLEAN_CMD="apk cache clean"
            mkdir -p /var/cache/apk
            ;;
    esac
}

# Perform the actual system update
perform_update() {
    echo "=== $(date) - Starting system update ($DISTRO_ID $DISTRO_VERSION) ==="
    echo "Using package manager: $PKG_MANAGER"
    
    if ! eval "$UPDATE_CMD"; then
        echo "ERROR: Update failed" | tee -a "$LOG_FILE"
        return 1
    fi
    
    eval "$CLEAN_CMD"
    echo "=== $(date) - System update completed successfully ==="
    return 0
}

# Install as systemd service
install_systemd_service() {
    local service_file="/etc/systemd/system/auto-updater.service"
    
    cat > "$service_file" <<EOF
[Unit]
Description=Automatic System Updater
After=network.target

[Service]
Type=oneshot
ExecStart=$PWD/$(basename "$0") --run
WorkingDirectory=$PWD
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    local timer_file="/etc/systemd/system/auto-updater.timer"
    local calendar=""

    case "$period" in
        daily) calendar="*-*-* 00:00:00";;
        weekly) calendar="Mon *-*-* 00:00:00";;
        monthly) calendar="*-*-01 00:00:00";;
    esac

    cat > "$timer_file" <<EOF
[Unit]
Description=Run auto-updater $period

[Timer]
OnCalendar=$calendar
AccuracySec=1h
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now auto-updater.timer
}

# Install as cron job
install_cron_job() {
    local cron_time=""
    
    case "$period" in
        daily) cron_time="0 0 * * *";;
        weekly) cron_time="0 0 * * 0";;
        monthly) cron_time="0 0 1 * *";;
    esac

    local cron_job="$cron_time $PWD/$(basename "$0") --run >> $LOG_FILE 2>&1"
    
    if ! (crontab -l 2>/dev/null | grep -qF "$(basename "$0")"); then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    fi
    
    # Ensure cron service is running
    if [ -f "/etc/init.d/crond" ]; then
        /etc/init.d/crond start
    elif [ -f "/etc/init.d/cron" ]; then
        /etc/init.d/cron start
    fi
}

# Main script execution
main() {
    check_root
    setup_logging
    detect_system
    set_update_commands

    if [ "$1" = "--run" ]; then
        perform_update
        exit $?
    fi

    echo "=== Auto Updater v$VERSION ==="
    echo "Detected system: $DISTRO_ID $DISTRO_VERSION"
    echo "Using package manager: $PKG_MANAGER"

    # Get update frequency
    read -p "Choose update frequency (daily/weekly/monthly): " period
    period=$(echo "$period" | tr '[:upper:]' '[:lower:]')

    [[ $period =~ ^(daily|weekly|monthly)$ ]] || {
        echo "Invalid frequency. Must be daily, weekly, or monthly."
        exit 1
    }

    # Initial update
    perform_update

    # Install scheduling
    if [ -d "/run/systemd/system" ]; then
        install_systemd_service
        echo "Installed systemd timer:"
        systemctl list-timers | grep auto-updater
    else
        install_cron_job
        echo "Installed cron job:"
        crontab -l | grep "$(basename "$0")"
    fi

    echo "Logging to: $LOG_FILE"
    echo "Installation complete!"
}

main "$@"
