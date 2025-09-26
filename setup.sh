#!/bin/bash

# Cập nhật hệ thống
apt update && apt upgrade -y

# Cài đặt các gói cần thiết
apt install -y chromium-browser steam pulseaudio xfce4 xrdp x11vnc

# Cấu hình username và password
useradd -m -s /bin/bash lt4c
echo "lt4c:lt4c" | chpasswd
usermod -aG sudo lt4c

# Cấu hình RDP (xrdp)
systemctl enable xrdp
systemctl start xrdp

# Cấu hình VNC (x11vnc)
echo -e "password\npassword" | x11vnc -storepasswd
systemctl enable x11vnc
systemctl start x11vnc

# Cấu hình desktop môi trường XFCE4
echo "startxfce4" > /home/lt4c/.xsession
chown lt4c:lt4c /home/lt4c/.xsession

# Cài đặt driver NVIDIA 535 và chặn driver 580
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
echo "options nvidia NVreg_ResmanDebugLevel=4" > /etc/modprobe.d/nvidia.conf
update-initramfs -u

# Cài đặt Chromium và Steam nếu chưa có
if ! command -v chromium-browser &> /dev/null
then
    apt install -y chromium-browser
fi

if ! command -v steam &> /dev/null
then
    apt install -y steam
fi

# Cấu hình PulseAudio
echo "autospawn = yes" >> /etc/pulse/client.conf
systemctl --user enable pulseaudio
systemctl --user start pulseaudio

# Thêm shortcuts cho Chromium và Steam vào desktop
mkdir -p /home/lt4c/Desktop
echo "[Desktop Entry]
Version=1.0
Name=Chromium
Comment=Web Browser
Exec=chromium-browser
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;" > /home/lt4c/Desktop/chromium.desktop

echo "[Desktop Entry]
Version=1.0
Name=Steam
Comment=Steam Client
Exec=steam
Icon=steam
Terminal=false
Type=Application
Categories=Game;" > /home/lt4c/Desktop/steam.desktop

# Chỉnh quyền cho các file desktop
chmod +x /home/lt4c/Desktop/chromium.desktop
chmod +x /home/lt4c/Desktop/steam.desktop
chown -R lt4c:lt4c /home/lt4c/Desktop

# Set màn hình mặc định và giao diện
gsettings set org.gnome.desktop.background picture-uri file:///usr/share/backgrounds/ubuntu-defaults.xml

# Đảm bảo hệ thống luôn sử dụng driver NVIDIA 535
apt install -y nvidia-driver-535
apt-mark hold nvidia-driver-535

# Khởi động lại hệ thống để áp dụng các thay đổi
reboot
