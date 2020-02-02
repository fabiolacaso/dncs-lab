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

router1.sh
```
ip link add link enp0s8 name enp0s8.10 type vlan id 10
ip link add link enp0s8 name enp0s8.20 type vlan id 20
```

switch.sh
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


## Webserver


## Routing tables


## Testing
