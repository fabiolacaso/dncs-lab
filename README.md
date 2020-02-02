# DNCS-LAB

# Requirements
 - Python 3
 - 10GB disk storage
 - 2GB free RAM
 - Virtualbox
 - Vagrant (https://www.vagrantup.com)
 - Internet

# Assignment
This section describes the assignment, its requirements and the tasks the student has to complete.
The assignment consists in a simple piece of design work that students have to carry out to satisfy the requirements described below.
The assignment deliverable consists of a Github repository containing:
- the code necessary for the infrastructure to be replicated and instantiated
- an updated README.md file where design decisions and experimental results are illustrated
- an updated answers.yml file containing the details of 


## Design Requirements
- Hosts 1-a and 1-b are in two subnets (*Hosts-A* and *Hosts-B*) that must be able to scale up to respectively 145 and 212 usable addresses
- Host 2-c is in a subnet (*Hub*) that needs to accommodate up to 512 usable addresses
- Host 2-c must run a docker image (dustnic82/nginx-test) which implements a web-server that must be reachable from Host-1-a and Host-1-b
- No dynamic routing can be used
- Routes must be as generic as possible
- The lab setup must be portable and executed just by launching the `vagrant up` command


# Design

## Table of contents
- [Introduction](#introduction)
- [Vagrantfile changes](#vagrantfile-changes)
- [Subnetting](#subnetting)
- [VLANs](#vlans)
- [Topology](#topology)
- [Implementation](#implementation)
- [Webserver](#webserver)
- [Routing Tables](#routing-tables)
- [Testing](#testing)


## Introduction
A.Y. 2019/20 - course of Design of Networks and Communication Systems. For this network design we will need the following 4 subnets:
- Host-A, between router-1 and host-a;
- Host-B,  between router-1 and host-b;
- Hub,  between router-2 and host-c;
- D, which is the subnet that includes the enp0s9 interface of router-1 and router-2.


## Vagrantfile changes
The first thing I did was modifying the Vagrantfile. I changed the path to the shell script by creating a specific script file for each host machine, instead of leaving the generic “common.sh”. This is the change made for host-a:
```
hosta.vm.provision "shell", path: "hosta.sh"
```
Furthermore I had to expand the RAM used by the host-c from 256MB to 512MB.


## Subnetting
For each network we have to calculate the number of IPs needed in order to meet the design requirements, keeping in mind that every subnet has 2 reserved addresses that can not be used.
- For Host-a we need to cover 145 addresses, so I assigned to the subnet the IP 192.168.1.0/24 in order to have 254 available addresses.
- For Host-b we need to cover 212 addresses, so I assigned to the subnet the IP 192.168.2.0/24 in order to have 254 available addresses.
- For Hub we need to cover 512 addresses, so I assigned to the subnet the IP 192.168.3.0/22 in order to have 1022 available addresses (in this particular case I could not use /23 as a subnet mask because I would not have been able to cover 512 addresses plus the 2 reserved ones).
- For D we need to cover 2 addresses, so I assigned to the subnet the IP 192.168.4.0/30 in order to have 2 available addresses.

|Subnet name|IP|Devices|Number of hosts|
|---|---|---|---|
|Host-A|192.168.1.0/24|router-1 (enp0s8.10)and host-a (enp0s8)|2^(32-24)-2 =254|
|Host-B|192.168.2.0/24|router-1 (enp0s8.20) and host-a (enp0s8)|2^(32-24)-2 =254|
|Hub|192.168.3.0/22|router-2 (enp0s8) and host-c (enp0s8)|2^(32-22)-2 =1022|
|Host-D|192.168.4.0/30|router-1 (enp0s9) and router-2 (enp0s9)|2^(32-30)-2 =2|

Each interface of the devices has its own IP address assigned depending on the relative subnet. I decided to assign X.X.X.1 to routers.

|Subnet|Device|Interface|Ip|
|---|---|---|---|
|Host-A|router-1|enp0s8.10|192.168.1.1/24|
|Host-A|host-a|enp0s8|192.168.1.2/24|
|Host-B|router-2|enp0s8.20|192.168.2.1/24|
|Host-B|host-b|enp0s8|192.168.2.2/24|
|Hub|router-2|enp0s8|192.168.3.1/22|
|Hub|host-c|enp0s8|192.168.3.2/22|
|D|router-1|enp0s9|192.168.4.1/30|
|D|router-2|enp0s9|192.168.4.2/30|


## VLANs

For this given topology we have 2 subnets between router-1 and the switch, so we have to set up two VLANs to split the switch's broadcast domain, otherwise Host-A and Host-B would be in the same collision domain. To do so we add two ports to the switch, one with tag=10 and the other with tag=20. For each tag we add the corresponding interface to router-1, respectively enp0s8.10 and enp0s8.10. The specific commands are the following:

**router1.sh**
```
ip link add link enp0s8 name enp0s8.10 type vlan id 10
ip link add link enp0s8 name enp0s8.20 type vlan id 20
```

**switch.sh**
```
ovs-vsctl add-port switch enp0s9 tag=10
ovs-vsctl add-port switch enp0s9 tag=20
```


|Subnet|VLAN id|Switch interface|
|---|---|---|
|Host-A|10|enp0s9|
|Host-B|20|enp0s10|


## Topology

```

        +-----------------------------------------------------+
        |                                                     |
        |                                                     |enp0s3
        +--+--+                +------------+             +------------+
        |     |                |  192.168.4.1/30       192.168.4.2/30  |
        |     |          enp0s3|          enp0s9       enp0s9          |
        |     +----------------+  router-1  +-------------+  router-2  |
        |     |                |            |             |            |
        |     |                |            |             |            |
        |     |                +------------+             +------------+
        |  M  |                      |enp0s8              enp0s8 | 192.168.3.1/22
        |  A  |                      |                           |
        |  N  |            enp0s8.10 192.168.1.1/24              |
        |  A  |            enp0s8.20 192.168.2.1/24       enp0s8 | 192.168.3.2/22
        |  G  |                      |                     +-----+----+
        |  E  |                      |enp0s8               |          |
        |  M  |            +-------------------+           |          |
        |  E  |      enp0s3|                   |           |  host-c  |
        |  N  +------------+      SWITCH       |           |          |
        |  T  |            |                   |           |          |
        |     |            +-------------------+           +----------+
        |     |              enp0s9     enp0s10                  |enp0s3
        |  V  |               |             |                    |
        |  A  |               |             |                    |
        |  G  |              enp0s8     enp0s8                   |
        |  R  |      192.168.1.2/24     192.168.2.2/24           |
        |  A  |        +----------+     +----------+             |
        |  N  |        |          |     |          |             |
        |  T  |  enp0s3|          |     |          |             |
        |     +--------+  host-a  |     |  host-b  |             |
        |     |        |          |     |          |             |
        |     |        |          |     |          |             |
        ++-+--+        +----------+     +----------+             |
        | |                              |enp0s3                 |
        | |                              |                       |
        | +------------------------------+                       |
        |                                                        |
        |                                                        |
        +--------------------------------------------------------+

```


## Implementation
Provisioning allows to execute a script within each virtual machine. Listed below are the specific commands used:

**hosta.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump --assume-yes
6.  #commands
7.  ip addr add 192.168.1.2/24 dev enp0s8
8.  ip link set dev enp0s8 up
9.  ip route del default
10. ip route add default via 192.168.1.1
```

line 2-5: installation of libraries and functions 

line 7: assign IP address to interface

line 8: set interface up

line 9: delete default route

line 10: define new default route


**hostb.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump --assume-yes
6.  #commands
7.  ip addr add 192.168.2.2/24 dev enp0s8
8.  ip link set dev enp0s8 up
9.  ip route del default
10. ip route add default via 192.168.2.1
```

line 2-5: installation of libraries and functions

line 7: assign IP address to interface

line 8: set interface up

line 9: delete default route

line 10: define new default route


**router1.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump --assume-yes
6.  sysctl -w net.ipv4.ip_forward=1
7.  #commands
8.  ip link add link enp0s8 name enp0s8.10 type vlan id 10
9.  ip link add link enp0s8 name enp0s8.20 type vlan id 20
10. ip link set dev enp0s8 up
11. ip link set dev enp0s8.10 up
12. ip link set dev enp0s8.20 up
13. ip link set dev enp0s9 up
14. ip add add 192.168.1.1/24 dev enp0s8.10
15. ip add add 192.168.2.1/24 dev enp0s8.20
16. ip add add 192.168.4.1/30 dev enp0s9
17. ip route add 192.168.3.0/24 via 192.168.4.2
```

line 2-5: installation of libraries and functions

line 6: enable IP forwarding 

line 8-9: create two different interfaces and set VLAN tags

line 10-13: set interfaces up

line 14-16: assign IP address to interface

line 17: set static route


**router2.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump --assume-yes
6.  sysctl -w net.ipv4.ip_forward=1
7.  #commands
8.  ip link set dev enp0s8 up
9.  ip link set dev enp0s9 up
10. ip add add 192.168.3.1/22 dev enp0s8
11. ip add add 192.168.4.2/22 dev enp0s9
12. ip route add 192.168.1.0/24 via 192.168.4.1
13. ip route add 192.168.2.0/24 via 192.168.4.1
```

line 2-5: installation of libraries and functions

line 6: enable IP forwarding

line 8-9: set interfaces up

line 10-11: assign IP address to interface

line 12-13: set static route


**switch.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump
6.  apt-get install -y openvswitch-common openvswitch-switch apt-transport-https ca-certificates curl software-properties-common
7.  #commands
8.  ovs-vsctl add-br switch
9.  ovs-vsctl add-port switch enp0s8
10. ovs-vsctl add-port switch enp0s9 tag=10
11. ovs-vsctl add-port switch enp0s10 tag=20
12. ip link set dev enp0s8 up
13. ip link set dev enp0s9 up
14. ip link set dev enp0s10 up
```

line 2-6: installation of libraries and functions

line 8: create bridge

line 9: add interface

line 10-11: add interface with VLAN tag

line 12-14: set interfaces up


## Webserver

Host-C must run a docker image. 


**hostc.sh**
```
1.  #libraries and functions
2.  export DEBIAN_FRONTEND=noninteractive
3.  sudo su
4.  apt-get update
5.  apt-get install -y tcpdump --assume-yes
6.  apt install apt-transport-https ca-certificates curl software-properties-common
7.  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
8.  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
9.  apt install -y docker-ce
10. docker pull dustnic82/nginx-test
```

line 2-5: installation of libraries and functions

line 6-9: installation of docker

line 10: pull required image

```
mkdir /www
echo -e
'<!DOCTYPE html>
<html>
<head>

<h1>DNCS LAB 2019/2020</h1>

</head>
<body>

<h3>TESTING PAGE</h3>
<p><i>Student name:</i> Fabiola Caso </br>
<i>Student number: 192707</i></p>

</body>
</html>' > /www/index.html
```

Create directory and HTML file that will be displayed on the web page with the following docker run command.

```
30. docker run --name nginx -v /www:/usr/share/nginx/html -d -p 80:80 dustnic82/nginx-test
31. ip addr add 192.168.3.2/22 dev enp0s8
32. ip link set dev enp0s8 up
33. ip route add 192.168.1.0/24 via 192.168.3.1
34. ip route add 192.168.2.0/24 via 192.168.3.1
```

line 30: run the nginx docker container

line 31: assign IP address to interface 

line 32: set interface up

line 33: set static route 

line 34: set static route 


## Routing tables

To view the routing tables we can use the command ```route -n```.

**host-a**

|Destination|Gateway|Genmask|Interface|
|---|---|---|---|
|0.0.0.0|192.168.1.1|0.0.0.0|enp0s8|
|0.0.0.0|10.0.2.2|0.0.0.0|enp0s3|
|10.0.2.0|0.0.0.0|255.255.255.0|enp0s3|
|10.0.2.2|0.0.0.0|255.255.255.255|enp0s3|
|192.168.1.0|0.0.0.0|255.255.255.0|enp0s8|


**host-b**

|Destination|Gateway|Genmask|Interface|
|---|---|---|---|
|0.0.0.0|192.168.2.1|0.0.0.0|enp0s8|
|0.0.0.0|10.0.2.2|0.0.0.0|enp0s3|
|10.0.2.0|0.0.0.0|255.255.255.0|enp0s3|
|10.0.2.2|0.0.0.0|255.255.255.255|enp0s3|
|192.168.2.0|0.0.0.0|255.255.255.0|enp0s8|


**host-c**

|Destination|Gateway|Genmask|Interface|
|---|---|---|---|
|0.0.0.0|10.0.2.2|0.0.0.0|enp0s3|
|10.0.2.0|0.0.0.0|255.255.255.0|enp0s3|
|10.0.2.2|0.0.0.0|255.255.255.255|enp0s3|
|172.17.0.0|0.0.0.0|255.255.0.0|docker0|
|192.168.0.0|0.0.0.0|255.255.252.0|enp0s8|
|192.168.1.0|192.168.3.1|255.255.255.0|enp0s8|
|192.168.2.0|192.168.3.1|255.255.255.0|enp0s8|


**router-1**

|Destination|Gateway|Genmask|Interface|
|---|---|---|---|
|0.0.0.0|10.0.2.2|0.0.0.0|enp0s3|
|10.0.2.0|0.0.0.0|255.255.255.0|enp0s3|
|10.0.2.2|0.0.0.0|255.255.255.255|enp0s3|
|192.168.1.0|0.0.0.0|255.255.255.0|enp0s8.10|
|192.168.2.0|0.0.0.0|255.255.255.0|enp0s8.20|
|192.168.3.0|192.168.4.2|255.255.255.0|enp0s9|
|192.168.4.0|0.0.0.0|255.255.255.252|enp0s9|


**router-2**

|Destination|Gateway|Genmask|Interface|
|---|---|---|---|
|0.0.0.0|10.0.2.2|0.0.0.0|enp0s3|
|10.0.2.0|0.0.0.0|255.255.255.0|enp0s3|
|10.0.2.2|0.0.0.0|255.255.255.255|enp0s3|
|192.168.0.0|0.0.0.0|255.255.252.0|enp0s8|
|192.168.1.0|192.168.4.1|255.255.255.0|enp0s9|
|192.168.2.0|192.168.4.1|255.255.255.0|enp0s9|
|192.168.4.0|0.0.0.0|255.255.252.0|enp0s9|


## Testing
To check the state of the VMs we can type the command ```vagrant status```. The expected output should be:
```
Current machine states:

router-1                  running (virtualbox)
router-2                  running (virtualbox)
switch                    running (virtualbox)
host-a                    running (virtualbox)
host-b                    running (virtualbox)
host-c                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

### Ping
We can also check the connectivity between each host by using the command ```ping```. For instance we can log into host-a 
```
vagrant ssh host-a
```
and check if we are able to communicate with host-c:
```
vagrant@host-a:~$ ping 192.168.3.2
```
The output is:
```
PING 192.168.3.2 (192.168.3.2) 56(84) bytes of data.
64 bytes from 192.168.3.2: icmp_seq=1 ttl=62 time=2.58 ms
64 bytes from 192.168.3.2: icmp_seq=2 ttl=62 time=2.51 ms
64 bytes from 192.168.3.2: icmp_seq=3 ttl=62 time=2.94 ms
64 bytes from 192.168.3.2: icmp_seq=4 ttl=62 time=3.12 ms
64 bytes from 192.168.3.2: icmp_seq=5 ttl=62 time=3.00 ms
64 bytes from 192.168.3.2: icmp_seq=6 ttl=62 time=1.16 ms
64 bytes from 192.168.3.2: icmp_seq=7 ttl=62 time=2.99 ms
64 bytes from 192.168.3.2: icmp_seq=8 ttl=62 time=2.60 ms
64 bytes from 192.168.3.2: icmp_seq=9 ttl=62 time=3.01 ms
^C
--- 192.168.3.2 ping statistics ---
9 packets transmitted, 9 received, 0% packet loss, time 8021ms
rtt min/avg/max/mdev = 1.163/2.661/3.126/0.570 ms
```

### Webserver test
To show running containers:
```
docker ps -a 
```
The output is:
```
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS                         NAMES
50401e12e847        dustnic82/nginx-test   "nginx -g 'daemon of…"   4 seconds ago       Up 3 seconds        0.0.0.0:80->80/tcp, 443/tcp   nginx
```
To check data transfer to and from the webserver we have to log into one of the hosts and use the following command:
```
vagrant@host-b:~$ curl 192.168.3.2
```
The output is:
```
<!DOCTYPE html><html><head><h1>DNCS LAB 2019/2020</h1></head><body><h3>TESTING PAGE</h3><p><i>Student name:</i> Fabiola Caso </br><i>Student number: 192707</i></p></body></html>
```
