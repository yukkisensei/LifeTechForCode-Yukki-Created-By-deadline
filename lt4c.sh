#!/usr/bin/env bash
# lt4c_full_tigervnc_sunshine_autoapps_deb.sh
# Tối ưu: Sunshine chạy với quyền ROOT để có full permission, bao gồm tạo input ảo.
# XFCE + XRDP (tuned) + TigerVNC (:0) + Sunshine (.deb + auto-add apps) + Steam (Flatpak) + Chromium (Flatpak)

set -Eeuo pipefail

# ======================= CONFIG =======================
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
LOG="/var/log/a_sh_install.log"

USER_NAME="${USER_NAME:-lt4c}"
USER_PASS="${USER_PASS:-lt4c}"
VNC_PASS="${VNC_PASS:-lt4c}"
GEOM="${GEOM:-1280x720}"
VNC_PORT="${VNC_PORT:-5900}"
SUN_HTTP_TLS_PORT="${SUN_HTTP_TLS_PORT:-47990}"

SUN_DEB_URL="${SUN_DEB_URL:-https://github.com/LizardByte/Sunshine/releases/download/v2025.628.4510/sunshine-ubuntu-22.04-amd64.deb}"

step(){ echo "[BƯỚC] $*"; }

# =================== PREPARE ===================
: >"$LOG"
apt update -qq >>"$LOG" 2>&1 || true
apt -y install tmux iproute2 >>"$LOG" 2>&1 || true

step "0/10 Chuẩn bị môi trường & công cụ cơ bản"
mkdir -p /etc/needrestart/conf.d
echo '$nrconf{restart} = "a";' >/etc/needrestart/conf.d/zzz-auto.conf || true
apt -y purge needrestart >>"$LOG" 2>&1 || true
systemctl stop unattended-upgrades >>"$LOG" 2>&1 || true
systemctl disable unattended-upgrades >>"$LOG" 2>&1 || true
apt -y -o Dpkg::Use-Pty=0 install \
  curl wget ca-certificates gnupg gnupg2 lsb-release apt-transport-https software-properties-common \
  sudo dbus-x11 xdg-utils desktop-file-utils xfconf >>"$LOG" 2>&1

# =================== USER ===================
step "1/10 Tạo user ${USER_NAME}"
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "LT4C" "$USER_NAME" >>"$LOG" 2>&1
  echo "${USER_NAME}:${USER_PASS}" | chpasswd
  usermod -aG sudo "$USER_NAME"
fi
USER_UID="$(id -u "$USER_NAME")"

# =================== DESKTOP + XRDP + TigerVNC ===================
step "2/10 Cài XFCE + XRDP + TigerVNC"
apt -y install \
  xfce4 xfce4-goodies xorg \
  xrdp xorgxrdp pulseaudio \
  tigervnc-standalone-server \
  remmina remmina-plugin-rdp remmina-plugin-vnc neofetch kitty flatpak \
  mesa-vulkan-drivers libgl1-mesa-dri libasound2 libpulse0 libxkbcommon0 >>"$LOG" 2>&1

systemctl enable --now xrdp >>"$LOG" 2>&1 || true

# =================== Steam/Chromium (Flatpak) + Heroic ===================
step "3/10 Cài Chromium + Steam (Flatpak --system) & Heroic (user)"
flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1 || true
flatpak -y --system install flathub org.chromium.Chromium com.valvesoftware.Steam >>"$LOG" 2>&1 || true

printf '%s\n' '#!/bin/sh' 'exec flatpak run org.chromium.Chromium "$@"' >/usr/local/bin/chromium && chmod +x /usr/local/bin/chromium
printf '%s\n' '#!/bin/sh' 'exec flatpak run com.valvesoftware.Steam "$@"' >/usr/local/bin/steam && chmod +x /usr/local/bin/steam

su - "$USER_NAME" -c 'flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo' >>"$LOG" 2>&1 || true
su - "$USER_NAME" -c 'flatpak -y install flathub com.heroicgameslauncher.hgl' >>"$LOG" 2>&1 || true

cat >/etc/profile.d/flatpak-xdg.sh <<'EOF'
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
EOF
chmod +x /etc/profile.d/flatpak-xdg.sh

step "4/10 Disable XFCE compositor (giảm lag)"
su - "$USER_NAME" -c 'mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/'
su - "$USER_NAME" -c 'echo "<channel name=\"xfwm4\" version=\"1.0\"><property name=\"general\" type=\"empty\"><property name=\"use_compositing\" type=\"bool\" value=\"false\"/></property></channel>" > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml' || true

# =================== TigerVNC :0 ===================
step "5/10 Cấu hình TigerVNC :0 (${GEOM})"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.vnc"
su - "$USER_NAME" -c "printf '%s\n' '$VNC_PASS' | vncpasswd -f > ~/.vnc/passwd"
chmod 600 "/home/$USER_NAME/.vnc/passwd"

cat >"/home/$USER_NAME/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=xfce
[ -x /usr/bin/dbus-launch ] && eval $(/usr/bin/dbus-launch --exit-with-session)
exec startxfce4
EOF
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.vnc/xstartup"
chmod +x "/home/$USER_NAME/.vnc/xstartup"

cat >/etc/systemd/system/vncserver@.service <<EOF
[Unit]
Description=TigerVNC server on display :%i (user ${USER_NAME})
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=${USER_NAME}
Group=${USER_NAME}
WorkingDirectory=/home/${USER_NAME}
Environment=HOME=/home/${USER_NAME}
ExecStart=/usr/bin/vncserver -fg -localhost no -geometry ${GEOM} :%i
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure
RestartSec=2
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vncserver@0.service >>"$LOG" 2>&1 || true

# =================== Sunshine (run as ROOT) & Input Permissions ===================
step "6/10 Cài Sunshine và cấp quyền input cao nhất"
TMP_DEB="/tmp/sunshine.deb"
wget -O "$TMP_DEB" "$SUN_DEB_URL"
dpkg -i "$TMP_DEB" || apt -f install -y >>"$LOG" 2>&1 || true

# Cấu hình để Sunshine chạy với quyền ROOT và kết nối vào màn hình VNC
install -d /etc/systemd/system/sunshine.service.d
cat >/etc/systemd/system/sunshine.service.d/override.conf <<EOF
[Service]
# Chạy với quyền ROOT (mặc định khi không ghi rõ User/Group)
# User=root
# Group=root
# Đảm bảo Sunshine tìm thấy màn hình VNC đang chạy của user ${USER_NAME}
Environment=DISPLAY=:0
EOF

# Thiết lập quyền tạo thiết bị ảo (chuột/phím)
apt -y install evtest joystick >>"$LOG" 2>&1 || true
echo 'uinput' >/etc/modules-load.d/uinput.conf
modprobe uinput || true
groupadd -f input
usermod -aG input "${USER_NAME}" # Thêm user vào nhóm input là một good practice

cat >/etc/udev/rules.d/60-sunshine-input.rules <<'EOF'
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
SUBSYSTEM=="input", KERNEL=="event*", MODE="0660", GROUP="input"
EOF
udevadm control --reload-rules || true
udevadm trigger || true

systemctl daemon-reload
systemctl enable --now sunshine >>"$LOG" 2>&1 || true
systemctl restart sunshine >>"$LOG" 2>&1 || true # Khởi động lại để áp dụng cấu hình

step "7/10 Cài Virtual Gamepad (ViGEm/vgamepad) - tùy chọn"
apt -y install dkms build-essential linux-headers-generic git >>"$LOG" 2>&1 || true
if ! lsmod | grep -q '^vgamepad'; then
  TMP_VGP="/tmp/vgamepad_$(date +%s)"
  git clone --depth=1 https://github.com/ViGEm/vgamepad.git "$TMP_VGP" >>"$LOG" 2>&1 || true
  if [ -f "$TMP_VGP/dkms.conf" ] || [ -f "$TMP_VGP/Makefile" ]; then
    VGP_VER="$(grep -Po 'PACKAGE_VERSION.?=\K.*' "$TMP_VGP/dkms.conf" | tr -d ' \"' || echo 0.1)"
    DEST="/usr/src/vgamepad-${VGP_VER}"
    rm -rf "$DEST"
    mkdir -p "$DEST" && cp -a "$TMP_VGP/"* "$DEST/"
    dkms add "vgamepad/${VGP_VER}" >>"$LOG" 2>&1 && \
    dkms build "vgamepad/${VGP_VER}" >>"$LOG" 2>&1 && \
    dkms install "vgamepad/${VGP_VER}" >>"$LOG" 2>&1 || true
  fi
  modprobe vgamepad || true
fi
cat >/etc/udev/rules.d/61-vgamepad.rules <<'EOF'
KERNEL=="vgamepad*", MODE="0660", GROUP="input"
EOF
udevadm control --reload-rules && udevadm trigger || true


# =================== Shortcuts & App Config ===================
step "8/10 Tạo shortcut ra Desktop và cấu hình app cho Sunshine"
DESKTOP_DIR="/home/$USER_NAME/Desktop"
install -d -m 0755 -o "$USER_NAME" -g "$USER_NAME" "$DESKTOP_DIR"

cat >"$DESKTOP_DIR/steam.desktop" <<EOF
[Desktop Entry]
Name=Steam
Exec=flatpak run com.valvesoftware.Steam
Icon=com.valvesoftware.Steam
Terminal=false
Type=Application
Categories=Game;
EOF

cat >"$DESKTOP_DIR/moonlight.desktop" <<EOF
[Desktop Entry]
Name=Moonlight (Sunshine Web UI)
Comment=Mở giao diện Sunshine để kết nối
Exec=chromium https://localhost:${SUN_HTTP_TLS_PORT}
Icon=sunshine
Terminal=false
Type=Application
Categories=Network;Game;Settings;
EOF

cat >"$DESKTOP_DIR/chromium.desktop" <<EOF
[Desktop Entry]
Name=Chromium
Exec=flatpak run org.chromium.Chromium
Icon=org.chromium.Chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

chown -R "$USER_NAME:$USER_NAME" "$DESKTOP_DIR"
chmod +x "$DESKTOP_DIR"/*.desktop

# Cấu hình apps.json cho Sunshine
# Khi chạy với quyền root, Sunshine có thể tìm config ở /etc/sunshine hoặc /root/.config
# Ta sẽ tạo ở cả hai nơi để đảm bảo nó được nhận
read -r -d '' APPS_JSON_CONTENT <<JSON
{
  "apps": [
    { "name": "Steam", "cmd": ["/usr/bin/flatpak", "run", "com.valvesoftware.Steam"], "working_dir": "/home/${USER_NAME}" },
    { "name": "Chromium", "cmd": ["/usr/bin/flatpak", "run", "org.chromium.Chromium"], "working_dir": "/home/${USER_NAME}" }
  ]
}
JSON
install -d -m 0755 /etc/sunshine
printf '%s\n' "$APPS_JSON_CONTENT" > /etc/sunshine/apps.json
chmod 644 /etc/sunshine/apps.json

# =================== Tối ưu mạng & Firewall ===================
step "9/10 Bật TCP low latency + mở cổng (nếu có ufw)"
echo 'net.ipv4.tcp_low_latency = 1' >/etc/sysctl.d/90-remote-desktop.conf
sysctl --system >/dev/null 2>&1 || true

if command -v ufw >/dev/null 2>&1; then
  ufw allow 3389/tcp || true        # RDP
  ufw allow "${VNC_PORT}/tcp" || true
  ufw allow "${SUN_HTTP_TLS_PORT}/tcp" || true
  ufw allow 47984:47990/tcp || true # Sunshine
  ufw allow 47998:48010/udp || true # Sunshine
fi

# Tối ưu xrdp
sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^max_bpp=.*/max_bpp=24/' /etc/xrdp/xrdp.ini 2>/dev/null || true
systemctl restart xrdp || true

# =================== DONE + PRINT IP ===================
step "10/10 Hoàn tất (log: $LOG)"
get_ip() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
}
IP="$(get_ip || ip -o -4 addr show up scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
IP="${IP:-<no-ip-detected>}"

echo "==================== THÔNG TIN KẾT NỐI ===================="
echo "🖥️  TigerVNC : ${IP}:${VNC_PORT}  (pass: ${VNC_PASS})"
echo "💻  XRDP     : ${IP}:3389        (user: ${USER_NAME} / pass: ${USER_PASS})"
echo "☀️  Sunshine : https://${IP}:${SUN_HTTP_TLS_PORT}  (Truy cập để lấy mã PIN)"
echo "------------------------------------------------------------"
echo "✅ Cài đặt hoàn tất!"
