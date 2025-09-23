#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ----- Fix apt -----
dpkg --configure -a || true
apt-get -y --fix-broken install || true
apt-get clean
apt-get update -o Acquire::Retries=3 --fix-missing

# ----- Base packages -----
apt-get install -y apt-transport-https ca-certificates curl wget git htop unzip \
                   python3 python3-pip lsb-release gnupg libglib2.0-bin dbus-x11 \
                   software-properties-common

# ----- Desktop + XRDP + Audio -----
apt-get install -y xfce4 xfce4-terminal xfce4-goodies
apt-get install -y xrdp xorgxrdp tigervnc-standalone-server tigervnc-common
apt-get install -y pulseaudio pulseaudio-utils pulseaudio-module-xrdp ssl-cert libfuse2
echo "startxfce4" > ~/.xsession

# ----- NVIDIA driver 535 (only) -----
# Xóa tất cả driver NVIDIA cũ
apt-get remove --purge -y 'nvidia-*' 'libnvidia-*' || true
apt-get autoremove -y
apt-get clean

# Thêm PPA NVIDIA để lấy đúng driver 535
add-apt-repository ppa:graphics-drivers/ppa -y
apt-get update

# Cài đặt driver NVIDIA 535
apt-get install -y nvidia-driver-535

# Giữ driver NVIDIA 535, không tự động nâng cấp lên 580
apt-mark hold nvidia-driver-535 || true

# ----- Sunshine -----
SUNSHINE_VER=0.24.0
DEB_FILE="sunshine-${SUNSHINE_VER}-x86_64.deb"
wget -q "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/${DEB_FILE}"
apt-get install -y "./${DEB_FILE}"
rm -f "${DEB_FILE}"

# ----- Chromium -----
apt-get install -y chromium-browser || apt-get install -y chromium
CHROMIUM_BIN=$(command -v chromium-browser || command -v chromium)

# ----- PyTorch CUDA -----
pip3 install --upgrade pip
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# ----- Shortcuts -----
DESKTOP_DIR="$HOME/Desktop"
BIN_DIR="$HOME/bin"
mkdir -p "$DESKTOP_DIR" "$BIN_DIR"

cat > "$BIN_DIR/gpu_test.sh" <<'EOS'
#!/usr/bin/env bash
set -e
echo "=== nvidia-smi ==="
nvidia-smi || echo "nvidia-smi not found"
echo
python3 - <<'PY'
import torch
print("PyTorch:", torch.__version__)
print("CUDA Available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("Device:", torch.cuda.get_device_name(0))
PY
read -p "Press Enter to close..."
EOS
chmod +x "$BIN_DIR/gpu_test.sh"

cat > "$DESKTOP_DIR/Sunshine.desktop" <<EOF
[Desktop Entry]
Name=Sunshine
Exec=/usr/bin/sunshine
Type=Application
Terminal=false
Categories=Utility;
EOF

cat > "$DESKTOP_DIR/Chromium.desktop" <<EOF
[Desktop Entry]
Name=Chromium
Exec=$CHROMIUM_BIN
Type=Application
Terminal=false
Categories=Network;WebBrowser;
EOF

cat > "$DESKTOP_DIR/GPU_Test.desktop" <<EOF
[Desktop Entry]
Name=GPU Test
Exec=xfce4-terminal --hold -e $BIN_DIR/gpu_test.sh
Type=Application
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_DIR/"*.desktop

# ----- Start XRDP -----
# Giải quyết vấn đề với invoke-rc.d không cho phép khởi động dịch vụ
echo 'Dpkg::Options { "--force-confdef"; "--force-confold"; }' | sudo tee /etc/apt/apt.conf.d/99fixbadpolicy

# Cài đặt lại và khởi động lại XRDP
systemctl enable xrdp || true
systemctl restart xrdp || true

# Kiểm tra và khởi động lại xrdp và xorgxrdp
systemctl restart xrdp
systemctl restart xorgxrdp

# ----- Kiểm tra audio -----
# Đảm bảo PulseAudio chạy và cài đặt đúng cách
sudo systemctl enable pulseaudio
sudo systemctl start pulseaudio

# ----- Kiểm tra và khởi động lại dịch vụ Sunshine -----
# Đảm bảo Sunshine chạy với quyền cao nhất
sudo systemctl enable sunshine || true
sudo systemctl start sunshine || true

echo "--------------------------------"
echo "Setup complete!"
echo "Check GPU: nvidia-smi"
echo "Desktop icons: Sunshine, Chromium, GPU Test"
echo "--------------------------------"
