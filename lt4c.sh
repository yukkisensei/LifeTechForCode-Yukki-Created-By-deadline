#!/bin/bash
set -e

# Update hệ thống
sudo apt-get update
sudo apt-get upgrade -y

# Cài driver NVIDIA cho T4 (Ubuntu 22.04/20.04 dùng bản 535 ổn định)
sudo apt-get install -y nvidia-driver-535

# Cài XFCE4 + XRDP cho remote desktop cơ bản
sudo apt-get install -y xfce4 xfce4-goodies xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Cài TigerVNC (nếu dùng VNC)
sudo apt-get install -y tigervnc-standalone-server tigervnc-common

# Cài Sunshine (dùng .deb release chính thức, tránh PPA lỗi)
SUNSHINE_VER=0.24.0
wget https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VER}/sunshine-${SUNSHINE_VER}-x86_64.deb
sudo apt-get install -y ./sunshine-${SUNSHINE_VER}-x86_64.deb
rm sunshine-${SUNSHINE_VER}-x86_64.deb

# Cài Chromium (web browser nhẹ)
sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium

# (Tuỳ chọn) Steam – comment nếu không cần
# sudo apt-get install -y steam

# Tiện ích cơ bản
sudo apt-get install -y git curl wget htop unzip

echo "--------------------------------"
echo "Setup hoàn tất.Kiểm tra GPU bằng:"
echo "  nvidia-smi"
echo "Nếu thấy card T4 hiện ra thì driver OK."
echo "Remote desktop: dùng RDP client kết nối với IP máy."
echo "Sunshine: cấu hình qua ~/.config/sunshine/"
