#!/bin/bash
set -e

# --------------------------------------------
# Cloud GPU T4 Setup Script (Final + Audio Fix)
# --------------------------------------------

echo "[*] Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

echo "[*] Installing NVIDIA driver (535)..."
sudo apt-get install -y nvidia-driver-535

echo "[*] Installing XFCE4 + XRDP for desktop..."
sudo apt-get install -y xfce4 xfce4-goodies xrdp

echo "[*] Installing TigerVNC..."
sudo apt-get install -y tigervnc-standalone-server tigervnc-common

echo "[*] Enabling XRDP audio (PulseAudio modules)..."
sudo apt-get install -y pulseaudio pulseaudio-utils pulseaudio-module-xrdp
# Copy PulseAudio modules if needed
PULSE_DIR="/usr/lib/pulse-$(pulseaudio --version | awk '{print $2}')/modules"
if [ -d "$PULSE_DIR" ]; then
  sudo cp "$PULSE_DIR"/module-xrdp*.so /usr/lib/xrdp/
fi
sudo systemctl restart xrdp

echo "[*] Installing Sunshine..."
SUNSHINE_VER=0.24.0
wget https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/sunshine-${SUNSHINE_VER}-x86_64.deb
sudo apt-get install -y ./sunshine-${SUNSHINE_VER}-x86_64.deb
rm sunshine-${SUNSHINE_VER}-x86_64.deb

echo "[*] Installing Chromium..."
sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium

# (Optional) Steam – uncomment nếu anh muốn test game streaming
# echo "[*] Installing Steam..."
# sudo apt-get install -y steam

echo "[*] Installing basic tools..."
sudo apt-get install -y git curl wget htop unzip python3-pip

echo "[*] Installing PyTorch (CUDA enabled)..."
pip3 install --upgrade pip
pip3 install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118

# --------------------------------
# Tạo shortcut ngoài Desktop
# --------------------------------
DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"

# Sunshine shortcut
cat > "$DESKTOP_DIR/Sunshine.desktop" <<EOF
[Desktop Entry]
Name=Sunshine
Comment=Game/desktop streaming server
Exec=sunshine
Icon=computer
Terminal=false
Type=Application
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/Sunshine.desktop"

# Chromium shortcut
cat > "$DESKTOP_DIR/Chromium.desktop" <<EOF
[Desktop Entry]
Name=Chromium Browser
Comment=Web Browser
Exec=chromium-browser
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF
chmod +x "$DESKTOP_DIR/Chromium.desktop"

# GPU Test shortcut
cat > "$DESKTOP_DIR/GPU_Test.desktop" <<EOF
[Desktop Entry]
Name=GPU Test (nvidia-smi + PyTorch)
Comment=Check NVIDIA T4 + CUDA
Exec=xfce4-terminal -- bash -c "nvidia-smi; python3 -c 'import torch; print(\\"CUDA Available:\\", torch.cuda.is_available())'; exec bash"
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/GPU_Test.desktop"

# --------------------------------
echo "--------------------------------"
echo "Setup hoàn tất!"
echo "- GPU: chạy nvidia-smi"
echo "- PyTorch CUDA: python3 -c \"import torch; print(torch.cuda.is_available())\""
echo "- Remote desktop qua RDP: đã có âm thanh"
echo "- Ngoài Desktop có shortcut: Sunshine, Chromium, GPU Test"
