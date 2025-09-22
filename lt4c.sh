#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERROR] at line $LINENO: $BASH_COMMAND" >&2' ERR
export DEBIAN_FRONTEND=noninteractive

echo "=== LT4C | Cloud T4 one-shot setup ==="

# ---- Detect target user (the actual desktop/RDP user) ----
if [ -n "${SUDO_USER-}" ] && [ "$SUDO_USER" != "root" ]; then
  TARGET_USER="$SUDO_USER"
else
  # pick first normal user (uid >= 1000), fallback to current
  TARGET_USER="$(awk -F: '$3>=1000 && $1!="nobody"{print $1; exit}' /etc/passwd || true)"
  TARGET_USER="${TARGET_USER:-$USER}"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DESKTOP_DIR="$TARGET_HOME/Desktop"
BIN_DIR="$TARGET_HOME/bin"
AUTOSTART_DIR="$TARGET_HOME/.config/autostart"

echo "[*] Using target user: $TARGET_USER ($TARGET_HOME)"

# ---- Helpers ----
apt_install() {
  sudo -E apt-get install -y --no-install-recommends "$@"
}
retry() {
  # retry a command up to 3 times
  local n=0
  until [ $n -ge 3 ]; do
    "$@" && break
    n=$((n+1))
    echo "[warn] Retry $n for: $*"
    sleep 3
  done
  [ $n -lt 3 ]
}

# ---- Base system ----
echo "[*] Updating apt..."
retry sudo apt-get update
retry sudo apt-get -y upgrade

echo "[*] Base tools..."
apt_install ca-certificates curl wget git htop unzip python3-pip libglib2.0-bin

# ---- GPU driver (auto-pick the right one) ----
echo "[*] NVIDIA driver (ubuntu-drivers autoinstall)..."
apt_install ubuntu-drivers-common
retry sudo ubuntu-drivers autoinstall || {
  echo "[warn] ubuntu-drivers failed, falling back to known driver versions..."
  retry apt_install nvidia-driver-550 || retry apt_install nvidia-driver-535 || retry apt_install nvidia-driver-525
}

# ---- Desktop + RDP + VNC ----
echo "[*] XFCE4 + XRDP + Xorg backend..."
apt_install xfce4 xfce4-goodies xrdp xorgxrdp
# Make RDP start XFCE
echo "startxfce4" | sudo tee "$TARGET_HOME/.xsession" >/dev/null
sudo chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xsession"

echo "[*] TigerVNC..."
apt_install tigervnc-standalone-server tigervnc-common

# ---- Audio for XRDP ----
echo "[*] XRDP audio via PulseAudio..."
apt_install pulseaudio pulseaudio-utils pulseaudio-module-xrdp
sudo systemctl restart xrdp || true

# ---- Sunshine (.deb release) ----
echo "[*] Sunshine..."
SUNSHINE_VER="0.24.0"
ARCH="$(dpkg --print-architecture)"
# Sunshine publishes x86_64 build; map if necessary
DEB_ARCH="x86_64"
DEB_FILE="sunshine-${SUNSHINE_VER}-${DEB_ARCH}.deb"
retry wget -q "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/${DEB_FILE}"
sudo apt-get install -y ./"${DEB_FILE}"
rm -f "${DEB_FILE}"

# Ensure user can access devices
sudo usermod -aG video,audio,render,input "$TARGET_USER" || true

# ---- Browser ----
echo "[*] Chromium..."
apt_install chromium-browser || apt_install chromium || true
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || echo chromium)"

# ---- PyTorch (CUDA wheel) for quick GPU test ----
echo "[*] PyTorch CUDA wheel (user install)..."
sudo -u "$TARGET_USER" python3 -m pip install --user --upgrade pip
# CUDA 11.8 wheel is broadly compatible with recent drivers
retry sudo -u "$TARGET_USER" python3 -m pip install --user \
  torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 || \
  echo "[warn] PyTorch install failed (network or wheel mismatch). GPU test will still run nvidia-smi."

# ---- Desktop shortcuts (create under the real user, not root) ----
echo "[*] Creating desktop shortcuts..."
sudo -u "$TARGET_USER" mkdir -p "$DESKTOP_DIR" "$BIN_DIR" "$AUTOSTART_DIR"

# GPU test script
sudo -u "$TARGET_USER" tee "$BIN_DIR/gpu_test.sh" >/dev/null <<'EOS'
#!/usr/bin/env bash
set -e
echo "=== nvidia-smi ==="
command -v nvidia-smi >/dev/null && nvidia-smi || echo "nvidia-smi not found."
echo
echo "=== PyTorch CUDA quick check ==="
python3 - <<'PY'
try:
    import torch
    print("PyTorch:", torch.__version__)
    print("CUDA Available:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("Device:", torch.cuda.get_device_name(0))
        print("Capability:", torch.cuda.get_device_capability(0))
except Exception as e:
    print("PyTorch check error:", e)
PY
echo
echo "(Close this window when done)"
exec bash
EOS
sudo chmod +x "$BIN_DIR/gpu_test.sh"

# Sunshine shortcut
sudo -u "$TARGET_USER" tee "$DESKTOP_DIR/Sunshine.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Sunshine
Comment=Game/desktop streaming server
Exec=/usr/bin/sunshine
Icon=computer
Terminal=false
Type=Application
Categories=Utility;
EOF

# Chromium shortcut (use the resolved binary)
sudo -u "$TARGET_USER" tee "$DESKTOP_DIR/Chromium.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Chromium Browser
Comment=Web Browser
Exec=$CHROMIUM_BIN
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

# GPU Test shortcut
sudo -u "$TARGET_USER" tee "$DESKTOP_DIR/GPU_Test.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Name=GPU Test (nvidia-smi + PyTorch)
Comment=Check NVIDIA T4 + CUDA
Exec=xfce4-terminal --hold --command="$HOME/bin/gpu_test.sh"
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
EOF

# Make them trusted/executable for XFCE/Thunar
sudo chmod +x "$DESKTOP_DIR/"*.desktop
sudo chown -R "$TARGET_USER:$TARGET_USER" "$DESKTOP_DIR" "$BIN_DIR" "$AUTOSTART_DIR"
sudo -u "$TARGET_USER" gio set "$DESKTOP_DIR/Sunshine.desktop" "metadata::trusted" yes || true
sudo -u "$TARGET_USER" gio set "$DESKTOP_DIR/Chromium.desktop" "metadata::trusted" yes || true
sudo -u "$TARGET_USER" gio set "$DESKTOP_DIR/GPU_Test.desktop" "metadata::trusted" yes || true

# ---- Final notes ----
echo "--------------------------------------------"
echo "Done. Gợi ý:"
echo " • Re-login XRDP (hoặc reboot) để driver NVIDIA tải đầy đủ."
echo " • Desktop đã có: Sunshine, Chromium, GPU Test."
echo " • Kiểm tra nhanh GPU: mở icon 'GPU Test' hoặc chạy 'nvidia-smi'."
echo "--------------------------------------------"
