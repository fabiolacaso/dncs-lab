#libraries and functions
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y tcpdump --assume-yes
sudo su
apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
apt install -y docker-ce
docker pull dustnic82/nginx-test

mkdir /www
echo -e '<!DOCTYPE html><html><head><h1>DNCS LAB 2019/2020</h1></head><body><h3>TESTING PAGE</h3><p><i>Student name:</i> Fabiola Caso </br><i>Student number: 192707</i></p></body></html>' > /www/index.html

docker run --name nginx -v /www:/usr/share/nginx/html -d -p 80:80 dustnic82/nginx-test
ip addr add 192.168.3.2/22 dev enp0s8
ip link set dev enp0s8 up
ip route add 192.168.1.0/24 via 192.168.3.1 
ip route add 192.168.2.0/24 via 192.168.3.1 
