#!/bin/bash

# Universal System Update Script with Enhanced Alpine Support
VERSION="2.1"
LOG_FILE="/var/log/auto-updater.log"

# Initialize logging
setup_logging() {
    sudo touch "$LOG_FILE"
    sudo chown "$(whoami)" "$LOG_FILE"
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
        ["apt"]="/usr/bin/apt-get"
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
        apt)
            UPDATE_CMD="sudo apt-get update -y && sudo apt-get upgrade -y"
            CLEAN_CMD="sudo apt-get autoremove -y && sudo apt-get clean"
            ;;
        dnf|yum)
            UPDATE_CMD="sudo $PKG_MANAGER upgrade -y"
            CLEAN_CMD="sudo $PKG_MANAGER autoremove -y"
            ;;
        pacman)
            UPDATE_CMD="sudo pacman -Syu --noconfirm"
            CLEAN_CMD="sudo pacman -Qtdq | sudo pacman -Rns --noconfirm -"
            ;;
        zypper)
            UPDATE_CMD="sudo zypper refresh && sudo zypper update -y"
            CLEAN_CMD="sudo zypper packages --unneeded | awk -F'|' '/^i/ {print \$3}' | xargs -r sudo zypper remove -y"
            ;;
        apk)
            UPDATE_CMD="sudo apk update && sudo apk upgrade"
            CLEAN_CMD="sudo apk cache clean"
            # Alpine needs explicit cache directory creation
            sudo mkdir -p /var/cache/apk
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
    
    sudo bash -c "cat > $service_file" <<EOF
[Unit]
Description=Automatic System Updater
After=network.target

[Service]
Type=oneshot
ExecStart=$PWD/$0 --run
User=root
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

    sudo bash -c "cat > $timer_file" <<EOF
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

    sudo systemctl daemon-reload
    sudo systemctl enable --now auto-updater.timer
}

# Install as cron job (for Alpine/Non-systemd systems)
install_cron_job() {
    local cron_time=""
    
    case "$period" in
        daily) cron_time="0 0 * * *";;
        weekly) cron_time="0 0 * * 0";;
        monthly) cron_time="0 0 1 * *";;
    esac

    local cron_job="$cron_time $PWD/$0 --run >> $LOG_FILE 2>&1"
    
    if ! (crontab -l 2>/dev/null | grep -qF "$0"); then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    fi
    
    # Ensure cron service is running (especially for Alpine)
    if [ -f "/etc/init.d/crond" ]; then
        sudo /etc/init.d/crond start
    elif [ -f "/etc/init.d/cron" ]; then
        sudo /etc/init.d/cron start
    fi
}

# Main script execution
main() {
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
        crontab -l | grep "$0"
    fi

    echo "Logging to: $LOG_FILE"
    echo "Installation complete!"
}

main "$@"
