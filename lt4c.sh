#!/usr/bin/env bash
set -euo pipefail

# ----- Fix apt -----
dpkg --configure -a || true
apt-get -y --fix-broken install || true
apt-get clean
apt-get update -o Acquire::Retries=3 --fix-missing

# ----- Cài đặt các gói cần thiết -----
apt-get install -y apt-transport-https ca-certificates curl wget git htop unzip \
                   python3 python3-pip lsb-release gnupg libglib2.0-bin dbus-x11 \
                   software-properties-common

# ----- Cài đặt NVIDIA Drivers và các gói liên quan -----
# Bỏ cài đặt driver 580 nếu hệ thống ép cài
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
update-initramfs -u
apt-get install -y nvidia-driver-535

# ----- Cài đặt Pulse Audio -----
apt-get install -y pulseaudio

# ----- Cài đặt Desktop environment và XRDP -----
apt-get install -y ubuntu-desktop gnome-session-flashback xrdp

# ----- Cài đặt các phần mềm cần thiết -----
apt-get install -y chromium-browser
apt-get install -y steam
apt-get install -y sunshine

# ----- Cấu hình màn hình desktop -----
# Đặt hình nền mặc định
gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/ubuntu-defaults-wallpapers/ubuntu-wallpaper.jpg"

# ----- Tạo shortcut cho các ứng dụng cần thiết -----
# Tạo shortcut cho Chromium
echo -e "[Desktop Entry]\nVersion=1.0\nName=Chromium\nComment=Web Browser\nExec=chromium\nIcon=chromium\nTerminal=false\nType=Application\nCategories=Network;WebBrowser;" > /home/lt4c/Desktop/Chromium.desktop
chmod +x /home/lt4c/Desktop/Chromium.desktop

# Tạo shortcut cho Steam
echo -e "[Desktop Entry]\nVersion=1.0\nName=Steam\nComment=Gaming Platform\nExec=steam\nIcon=steam\nTerminal=false\nType=Application\nCategories=Game;" > /home/lt4c/Desktop/Steam.desktop
chmod +x /home/lt4c/Desktop/Steam.desktop

# Tạo shortcut cho Sunshine
echo -e "[Desktop Entry]\nVersion=1.0\nName=Sunshine\nComment=Game Streaming\nExec=sunshine\nIcon=sunshine\nTerminal=false\nType=Application\nCategories=Game;" > /home/lt4c/Desktop/Sunshine.desktop
chmod +x /home/lt4c/Desktop/Sunshine.desktop

# ----- Cấu hình để nhận chuột và phím ảo -----
echo "X11UseLocalhost no" >> /etc/ssh/sshd_config
systemctl restart ssh

# ----- Cấu hình Moonlight, RDP, RVNC -----
# Cài đặt và cấu hình Moonlight
apt-get install -y moonlight

# Cài đặt và cấu hình RDP
echo -e "[Desktop Entry]\nVersion=1.0\nName=RDP\nComment=Remote Desktop\nExec=xfreerdp\nIcon=xfreerdp\nTerminal=false\nType=Application\nCategories=Network;" > /home/lt4c/Desktop/RDP.desktop
chmod +x /home/lt4c/Desktop/RDP.desktop

# Cài đặt và cấu hình RVNC
apt-get install -y tigervnc-viewer

# ----- Cập nhật quyền người dùng -----
usermod -aG sudo lt4c
echo "lt4c:lt4c" | chpasswd

# ----- Khởi động lại để áp dụng toàn bộ thay đổi -----
reboot
