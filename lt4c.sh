dpkg --configure -a || true
apt-get -y --fix-broken install || true
apt-get update -o Acquire::Retries=3 --fix-missing

. /etc/os-release
if [ "${ID:-}" = "ubuntu" ]; then
  apt-get install -y software-properties-common
  add-apt-repository -y universe
  add-apt-repository -y multiverse
  add-apt-repository -y restricted
  apt-get update
  apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp pulseaudio pulseaudio-utils pulseaudio-module-xrdp ssl-cert libfuse2
elif [ "${ID:-}" = "debian" ]; then
  sed -i -E "s/ main( |$)/ main contrib non-free non-free-firmware /" /etc/apt/sources.list
  apt-get update
  apt-get install -y task-xfce-desktop xrdp pulseaudio pulseaudio-utils ssl-cert libfuse2
else
  echo "Unsupported distro: ${ID:-unknown}"; exit 1
fi

systemctl restart xrdp || true
