#libraries and functions
export DEBIAN_FRONTEND=noninteractive
sudo su
apt-get update
apt-get install -y tcpdump --assume-yes
#commands
ip addr add 192.168.1.2/24 dev enp0s8
ip link set dev enp0s8 up
ip route del default
ip route add default via 192.168.1.1
