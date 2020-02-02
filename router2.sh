#libraries and functions
export DEBIAN_FRONTEND=noninteractive
sudo su
apt-get update
apt-get install -y tcpdump --assume-yes
sysctl -w net.ipv4.ip_forward=1
#commands
ip link set dev enp0s8 up
ip link set dev enp0s9 up
ip add add 192.168.3.1/22 dev enp0s8
ip add add 192.168.4.2/22 dev enp0s9
ip route add 192.168.1.0/24 via 192.168.4.1
ip route add 192.168.2.0/24 via 192.168.4.1
