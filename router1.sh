#libraries and functions
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y tcpdump --assume-yes
sudo su
sysctl -w net.ipv4.ip_forward=1
#commands
ip link add link enp0s8 name enp0s8.10 type vlan id 10
ip link add link enp0s8 name enp0s8.20 type vlan id 20
ip link set dev enp0s8 up
ip link set dev enp0s8.10 up
ip link set dev enp0s8.20 up
ip link set dev enp0s9 up
ip add add 192.168.1.1/24 dev enp0s8.10
ip add add 192.168.2.1/24 dev enp0s8.20
ip add add 192.168.4.1/30 dev enp0s9
ip route add 192.168.3.0/24 via 192.168.4.2
