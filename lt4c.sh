#!/bin/bash
set -e

# --------------------------------------------
# Cloud GPU T4 Setup Script (fixed & cleaned)
# --------------------------------------------

echo "[*] Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

echo "[*] Installing NVIDIA driver (535)..."
sudo apt-get install -y nvidia-driver-535

echo "[*] Installing XFCE + XRDP for desktop..."
sudo apt-get install -y xfce4 xfce4-goodies xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

echo "[*] Installing TigerVNC..."
sudo apt-get install -y tigervnc-standalone-server tigervnc-common

echo "[*] Installing Sunshine..."
SUNSHINE_VER=0.24.0
wget https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/sunshine-${SUNSHINE_VER}-x86_64.deb
sudo apt-get install -y ./sunshine-${SUNSHINE_VER}-x86_64.deb
rm sunshine-${SUNSHINE_VER}-x86_64.deb

echo "[*] Installing Chromium..."
sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium

# (Optional) Steam - uncomment if anh muốn test game streaming
# echo "[*] Installing Steam..."
# sudo apt-get install -y steam

echo "[*] Installing basic tools..."
sudo apt-get install -y git curl wget htop unzip

# Quick GPU test tool
echo "[*] Installing PyTorch (CPU+CUDA)..."
pip install --upgrade pip
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118

echo "--------------------------------"
echo "Setup hoàn tất!"
echo "- Kiểm tra GPU: nvidia-smi"
echo "- Kiểm tra CUDA trong PyTorch: python3 -c \"import torch; print(torch.cuda.is_available())\""
echo "- Remote desktop: kết nối RDP client vào IP máy"
echo "- Sunshine config: ~/.config/sunshine/"
