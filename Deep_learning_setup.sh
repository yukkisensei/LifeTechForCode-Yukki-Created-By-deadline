#!/usr/bin/env bash
set -euo pipefail

# Setup script for NVIDIA T4 GPU VM with Windows 11 XLite-inspired desktop over XRDP
# Requirements covered:
#  - Creates administrator user "hyper" with password "alo1234"
#  - Installs XRDP, PulseAudio, NVIDIA 535 driver (blocks 580), Steam, Brave, Sunshine
#  - Configures dark theme, brown wallpaper, desktop shortcuts
#  - Enables audio over RDP and optimizes XRDP for pointer capture

TARGET_USER="hyper"
TARGET_PASSWORD="alo1234"
NVIDIA_DRIVER_VERSION="535"
WALL_COLOR_HEX="#8B4513"

log() {
    echo "[SETUP] $1"
}

require_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root." >&2
        exit 1
    fi
}

ensure_dependencies() {
    export DEBIAN_FRONTEND=noninteractive
    log "Updating package index"
    apt-get update

    log "Installing base dependencies"
    apt-get install -y --no-install-recommends \
        software-properties-common apt-transport-https ca-certificates curl gnupg \
        dbus-x11 jq unzip wget policykit-1 \
        xrdp xfce4 xfce4-goodies arc-theme gnome-themes-extra papirus-icon-theme \
        pulseaudio pulseaudio-utils pulseaudio-module-xrdp pavucontrol \
        imagemagick \
        steam \
        python3 python3-venv python3-pip

    log "Enabling multiverse repository for Steam"
    add-apt-repository -y multiverse || true
    apt-get update
}

setup_brave_repo() {
    if ! apt-cache policy brave-browser >/dev/null 2>&1; then
        log "Configuring Brave browser repository"
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            > /etc/apt/sources.list.d/brave-browser-release.list
        apt-get update
    fi
    log "Installing Brave browser"
    apt-get install -y brave-browser
}

create_admin_user() {
    if ! id "${TARGET_USER}" >/dev/null 2>&1; then
        log "Creating user ${TARGET_USER}"
        adduser --disabled-password --gecos "" "${TARGET_USER}"
    else
        log "User ${TARGET_USER} already exists"
    fi

    echo "${TARGET_USER}:${TARGET_PASSWORD}" | chpasswd
    usermod -aG sudo,adm,audio,video,render "${TARGET_USER}"

    log "Ensuring ${TARGET_USER} has Desktop directory"
    local desktop_dir="/home/${TARGET_USER}/Desktop"
    install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" "${desktop_dir}"
}

install_nvidia_driver() {
    log "Installing NVIDIA driver ${NVIDIA_DRIVER_VERSION}"
    apt-get install -y --no-install-recommends "nvidia-driver-${NVIDIA_DRIVER_VERSION}" nvidia-utils-${NVIDIA_DRIVER_VERSION}

    log "Pinning NVIDIA driver ${NVIDIA_DRIVER_VERSION} and blocking 580"
    cat <<EOF >/etc/apt/preferences.d/nvidia-${NVIDIA_DRIVER_VERSION}-pin
Package: nvidia-driver-${NVIDIA_DRIVER_VERSION}
Pin: version ${NVIDIA_DRIVER_VERSION}*
Pin-Priority: 1001

Package: nvidia-driver-${NVIDIA_DRIVER_VERSION}-server
Pin: version ${NVIDIA_DRIVER_VERSION}*
Pin-Priority: 1001

Package: nvidia-driver-580
Pin: release *
Pin-Priority: -1

Package: nvidia-driver-580-server
Pin: release *
Pin-Priority: -1
EOF

    apt-mark hold "nvidia-driver-${NVIDIA_DRIVER_VERSION}" "nvidia-driver-${NVIDIA_DRIVER_VERSION}-server" || true
    log "Driver installation complete"
}

configure_xrdp() {
    log "Configuring XRDP"
    systemctl enable xrdp

    # Optimize XRDP to better capture keyboard and pointer events and prefer Xorg backend
    if grep -q "grab_keyboard" /etc/xrdp/xrdp.ini; then
        sed -i 's/^grab_keyboard=.*/grab_keyboard=true/g' /etc/xrdp/xrdp.ini
    else
        sed -i 's/\[Xorg\]/[Xorg]\ngrab_keyboard=true/g' /etc/xrdp/xrdp.ini
    fi
    sed -i 's/^max_bpp=.*/max_bpp=32/g' /etc/xrdp/xrdp.ini
    sed -i 's/^use_vsock=.*/use_vsock=false/g' /etc/xrdp/xrdp.ini
    sed -i 's/^security_layer=.*/security_layer=negotiate/g' /etc/xrdp/xrdp.ini

    # Ensure PulseAudio module for XRDP is loaded per session
    install -d -m 0755 /etc/xrdp
    cat <<'EOF' >/etc/xrdp/startwm.sh
#!/bin/sh
if [ -r /etc/profile ]; then
  . /etc/profile
fi
pulseaudio --kill >/dev/null 2>&1 || true
pulseaudio --start --log-target=syslog
startxfce4
EOF
    chmod +x /etc/xrdp/startwm.sh

    # Default session for user
    cat <<'EOF' >/home/${TARGET_USER}/.xsession
#!/bin/sh
startxfce4
EOF
    chown ${TARGET_USER}:${TARGET_USER} /home/${TARGET_USER}/.xsession
    chmod 0755 /home/${TARGET_USER}/.xsession

    systemctl restart xrdp
}

create_desktop_configs() {
    local xfce_config_dir="/home/${TARGET_USER}/.config/xfce4/xfconf/xfce-perchannel-xml"
    install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" "${xfce_config_dir}"

    log "Applying dark theme and icon settings"
    cat <<EOF >"${xfce_config_dir}/xsettings.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net/ThemeName" type="string" value="Adwaita-dark"/>
  <property name="Net/IconThemeName" type="string" value="Papirus-Dark"/>
  <property name="Gtk/FontName" type="string" value="Cantarell 11"/>
</channel>
EOF

    log "Configuring window manager theme"
    cat <<EOF >"${xfce_config_dir}/xfwm4.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_alignment" type="string" value="center"/>
  </property>
</channel>
EOF

    log "Setting solid brown wallpaper"
    cat <<EOF >"${xfce_config_dir}/xfce4-desktop.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="color-style" type="int" value="0"/>
        <property name="color1" type="string" value="${WALL_COLOR_HEX}"/>
        <property name="image-show" type="bool" value="false"/>
      </property>
    </property>
  </property>
</channel>
EOF

    chown -R ${TARGET_USER}:${TARGET_USER} "/home/${TARGET_USER}/.config"
}

install_sunshine() {
    log "Installing Sunshine game streaming host"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    pushd "${tmp_dir}" >/dev/null
    local sunshine_url
    sunshine_url=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest \
        | jq -r '.assets[] | select(.name | test("amd64.deb$")) | .browser_download_url' | head -n1)
    if [[ -z "${sunshine_url}" ]]; then
        log "Failed to find Sunshine .deb package"
        exit 1
    fi
    curl -fL -o sunshine.deb "${sunshine_url}"
    apt-get install -y ./sunshine.deb
    popd >/dev/null
    rm -rf "${tmp_dir}"
}

create_shortcuts() {
    log "Creating desktop shortcuts"
    local desktop_dir="/home/${TARGET_USER}/Desktop"
    local applications=("brave-browser.desktop" "steam.desktop" "sunshine.desktop")
    for app in "${applications[@]}"; do
        local source="/usr/share/applications/${app}"
        if [[ -f "${source}" ]]; then
            cp "${source}" "${desktop_dir}/"
        fi
    done
    chown ${TARGET_USER}:${TARGET_USER} "${desktop_dir}"/*.desktop
    chmod +x "${desktop_dir}"/*.desktop
}

optimize_system() {
    log "Applying system optimizations for XRDP and NVIDIA"

    # Improve scheduler for interactive desktop experience
    cat <<'EOF' >/etc/sysctl.d/99-hyper-vm.conf
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
kernel.sched_autogroup_enabled=1
EOF
    sysctl --system

    # Ensure NVIDIA persistence daemon is running for T4 stability
    systemctl enable nvidia-persistenced
    systemctl start nvidia-persistenced || true

    # Enable PulseAudio for XRDP sessions
    install -d -m 0755 /home/${TARGET_USER}/.config/systemd/user
    cat <<'EOF' >/home/${TARGET_USER}/.config/systemd/user/pulseaudio.service
[Unit]
Description=PulseAudio Sound Server
After=sound.target

[Service]
Type=notify
ExecStart=/usr/bin/pulseaudio --daemonize=no --log-target=journal
Restart=on-failure

[Install]
WantedBy=default.target
EOF
    chown -R ${TARGET_USER}:${TARGET_USER} /home/${TARGET_USER}/.config/systemd
}

main() {
    require_root
    ensure_dependencies
    setup_brave_repo
    apt-get install -y brave-browser
    create_admin_user
    install_nvidia_driver
    configure_xrdp
    create_desktop_configs
    install_sunshine
    create_shortcuts
    optimize_system

    log "Setup complete. Reboot recommended."
}

main "$@"
