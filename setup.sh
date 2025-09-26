#!/bin/bash

# Cập nhật và nâng cấp hệ thống
echo "Updating and upgrading system..."
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói cơ bản
echo "Installing necessary packages..."
sudo apt install -y chromium-browser steam sunshine xorg openbox pulseaudio pavucontrol xrdp tigervnc-standalone-server

# Cài đặt driver NVIDIA phiên bản 535
echo "Installing NVIDIA driver 535..."
sudo apt install -y nvidia-driver-535

# Cấu hình để tránh cài đặt driver 580
echo "Blocking installation of NVIDIA driver 580..."
echo "NVIDIA-580" | sudo tee -a /etc/apt/preferences.d/nvidia

# Cấu hình user và quyền root
echo "Creating user lt4c with root privileges..."
sudo useradd -m -s /bin/bash lt4c
echo "lt4c:lt4c" | sudo chpasswd
sudo usermod -aG sudo lt4c

# Cấu hình quyền cho Sunshine
echo "Elevating Sunshine privileges..."
sudo chmod +s /usr/bin/sunshine

# Cấu hình môi trường desktop
echo "Setting up default desktop environment..."
sudo apt install -y xfce4 xfce4-goodies
echo "startxfce4" > ~/.xsession

# Tạo biểu tượng trên màn hình cho các ứng dụng
echo "Creating shortcuts for Chromium, Sunshine, and Steam on desktop..."
echo "[Desktop Entry]
Version=1.0
Name=Chromium
Comment=Open Chromium Browser
Exec=chromium-browser
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;" > ~/Desktop/Chromium.desktop

echo "[Desktop Entry]
Version=1.0
Name=Sunshine
Comment=Sunshine Streaming
Exec=sunshine
Icon=sunshine
Terminal=false
Type=Application
Categories=Network;Streaming;" > ~/Desktop/Sunshine.desktop

echo "[Desktop Entry]
Version=1.0
Name=Steam
Comment=Steam Game Client
Exec=steam
Icon=steam
Terminal=false
Type=Application
Categories=Game;" > ~/Desktop/Steam.desktop

# Đảm bảo quyền cho các shortcuts
chmod +x ~/Desktop/Chromium.desktop
chmod +x ~/Desktop/Sunshine.desktop
chmod +x ~/Desktop/Steam.desktop

# Cấu hình Moonlight và RDP
echo "Setting up Moonlight and RDP..."
sudo apt install -y moonlight-embedded
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Cấu hình đầu ra âm thanh
echo "Configuring PulseAudio..."
sudo systemctl enable pulseaudio
sudo systemctl start pulseaudio

# Chạy Sunshine và RDP
echo "Starting Sunshine service..."
sudo systemctl enable sunshine
sudo systemctl start sunshine

# Đảm bảo xrdp chạy trên port 3389
echo "Configuring xrdp..."
sudo sed -i 's/3389/3389/' /etc/xrdp/xrdp.ini

# Cấu hình màn hình hiển thị
echo "Setting up default desktop session..."
echo "xfce4-session" > ~/.xsession

# Lỗi không nhận đầu ra
echo "Fixing output issue by configuring PulseAudio..."
sudo apt install -y pulseaudio-utils
pulseaudio --start

# Khởi động lại để áp dụng toàn bộ thay đổi
echo "Rebooting system to apply all changes..."
sudo reboot
