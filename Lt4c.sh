#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERR] line $LINENO: $BASH_COMMAND" >&2' ERR
export DEBIAN_FRONTEND=noninteractive

retry(){ n=0; until "$@"; do n=$((n+1)); [ $n -ge 3 ] && return 1; sleep 3; done; }
is_cmd(){ command -v "$1" >/dev/null 2>&1; }
has_systemd(){ [ -d /run/systemd/system ] && [ "$(ps -p 1 -o comm=)" = "systemd" ]; }
in_container(){ [ -f /.dockerenv ] || grep -qiE '(docker|lxc|containerd)' /proc/1/cgroup 2>/dev/null; }

# ---- Detect user + paths
if [ -n "${SUDO_USER-}" ] && [ "$SUDO_USER" != "root" ]; then
  TARGET_USER="$SUDO_USER"
else
  if [ -d /home ] && ls /home | head -n1 >/dev/null 2>&1; then
    TARGET_USER="$(ls /home | head -n1)"
  else
    TARGET_USER="${USER:-root}"
  fi
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "/home/$TARGET_USER")"
DESKTOP_DIR="$TARGET_HOME/Desktop"
BIN_DIR="$TARGET_HOME/bin"
AUTOSTART_DIR="$TARGET_HOME/.config/autostart"

# ---- OS info
. /etc/os-release || true
CODENAME=${VERSION_CODENAME:-$(lsb_release -sc 2>/dev/null || echo jammy)}

# ---- APT fix + repos
dpkg --configure -a || true
apt-get -y --fix-broken install || true
retry apt-get update -o Acquire::Retries=3 --fix-missing

apt-get install -y apt-transport-https ca-certificates curl wget git htop unzip python3 python3-pip lsb-release gnupg libglib2.0-bin dbus-x11

if [ "${ID:-}" = "ubuntu" ]; then
  apt-get install -y software-properties-common || true
  if ! grep -Rqs " ${CODENAME} .*universe" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    add-apt-repository -y universe || {
      echo "deb http://archive.ubuntu.com/ubuntu ${CODENAME} universe" >> /etc/apt/sources.list
      echo "deb http://archive.ubuntu.com/ubuntu ${CODENAME}-updates universe" >> /etc/apt/sources.list
      echo "deb http://security.ubuntu.com/ubuntu ${CODENAME}-security universe" >> /etc/apt/sources.list
    }
  fi
  if ! grep -Rqs " ${CODENAME} .*multiverse" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    add-apt-repository -y multiverse || {
      echo "deb http://archive.ubuntu.com/ubuntu ${CODENAME} multiverse" >> /etc/apt/sources.list
      echo "deb http://archive.ubuntu.com/ubuntu ${CODENAME}-updates multiverse" >> /etc/apt/sources.list
    }
  fi
  if ! grep -Rqs " ${CODENAME} .*restricted" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    add-apt-repository -y restricted || true
  fi
  retry apt-get update
fi

# ---- NVIDIA driver (host VM; bỏ qua trong container)
if ! in_container; then
  apt-get install -y ubuntu-drivers-common || true
  (ubuntu-drivers autoinstall || apt-get install -y nvidia-driver-550 || apt-get install -y nvidia-driver-535 || true) || true
fi

# ---- Desktop + RDP + VNC
apt-get install -y xfce4 xfce4-terminal xfce4-goodies || apt-get install -y xfce4 xfce4-terminal || true
apt-get install -y xrdp xorgxrdp || true
printf 'startxfce4\n' > "$TARGET_HOME/.xsession" || true
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xsession" || true

apt-get install -y tigervnc-standalone-server tigervnc-common || true

# ---- Audio
apt-get install -y pulseaudio pulseaudio-utils || true
apt-get install -y pulseaudio-module-xrdp || apt-get install -y xrdp-pulseaudio-installer || true

# ---- Sunshine (.deb)
SUNSHINE_VER="0.24.0"
DEB_FILE="sunshine-${SUNSHINE_VER}-x86_64.deb"
retry wget -q "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/${DEB_FILE}" && apt-get install -y "./${DEB_FILE}" && rm -f "${DEB_FILE}" || true
usermod -aG video,audio,render,input "$TARGET_USER" || true

# ---- Browser
apt-get install -y chromium-browser || apt-get install -y chromium || true
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || echo chromium)"

# ---- PyTorch (CUDA wheel)
sudo -u "$TARGET_USER" python3 -m pip install --user --upgrade pip || true
sudo -u "$TARGET_USER" python3 -m pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 || true

# ---- Shortcuts
su - "$TARGET_USER" -c "mkdir -p \"$DESKTOP_DIR\" \"$BIN_DIR\" \"$AUTOSTART_DIR\"" || true

cat > "$BIN_DIR/gpu_test.sh" <<'EOS'
#!/usr/bin/env bash
set -e
echo "=== nvidia-smi ==="
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi; else echo "nvidia-smi not found"; fi
echo
python3 - <<'PY'
try:
    import torch
    print("PyTorch:", torch.__version__)
    print("CUDA Available:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("Device:", torch.cuda.get_device_name(0))
except Exception as e:
    print("PyTorch check error:", e)
PY
echo
read -p "Press Enter to close..."
EOS
chown "$TARGET_USER:$TARGET_USER" "$BIN_DIR/gpu_test.sh" || true
chmod +x "$BIN_DIR/gpu_test.sh" || true

cat > "$DESKTOP_DIR/Sunshine.desktop" <<EOF
[Desktop Entry]
Name=Sunshine
Comment=Game/desktop streaming server
Exec=/usr/bin/sunshine
Icon=computer
Terminal=false
Type=Application
Categories=Utility;
EOF

cat > "$DESKTOP_DIR/Chromium.desktop" <<EOF
[Desktop Entry]
Name=Chromium Browser
Comment=Web Browser
Exec=$CHROMIUM_BIN
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

TERMINAL_BIN="$(command -v xfce4-terminal || command -v xterm || command -v x-terminal-emulator || echo xterm)"
cat > "$DESKTOP_DIR/GPU_Test.desktop" <<EOF
[Desktop Entry]
Name=GPU Test (nvidia-smi + PyTorch)
Comment=Check NVIDIA + CUDA
Exec=$TERMINAL_BIN --hold -e $BIN_DIR/gpu_test.sh
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
EOF

chown "$TARGET_USER:$TARGET_USER" "$DESKTOP_DIR/"*.desktop || true
chmod +x "$DESKTOP_DIR/"*.desktop || true
su - "$TARGET_USER" -c "gio set \"$DESKTOP_DIR/Sunshine.desktop\" metadata::trusted yes" 2>/dev/null || true
su - "$TARGET_USER" -c "gio set \"$DESKTOP_DIR/Chromium.desktop\" metadata::trusted yes" 2>/dev/null || true
su - "$TARGET_USER" -c "gio set \"$DESKTOP_DIR/GPU_Test.desktop\" metadata::trusted yes" 2>/dev/null || true

# ---- XRDP start (systemd or manual)
if has_systemd; then
  systemctl enable xrdp || true
  systemctl restart xrdp || true
else
  pkill xrdp || true; pkill xrdp-sesman || true
  if is_cmd /usr/sbin/xrdp-sesman && is_cmd /usr/sbin/xrdp; then
    /usr/sbin/xrdp-sesman >/var/log/xrdp-sesman.log 2>&1 &
    /usr/sbin/xrdp >/var/log/xrdp.log 2>&1 &
  fi
fi

echo "--------------------------------------------"
echo "Done. User: $TARGET_USER"
echo "Desktop icons ready: Sunshine, Chromium, GPU Test"
echo "If you are inside a container, XRDP is started without systemd."
echo "--------------------------------------------"
