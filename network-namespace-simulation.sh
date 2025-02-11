#!/bin/bash

# Create network namespaces for two hosts and a router
sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns add router-ns

# Create virtual bridges to connect namespaces
sudo ip link add br0 type bridge
sudo ip link add br1 type bridge

# Bring up the bridges
sudo ip link set br0 up
sudo ip link set br1 up

# Create virtual Ethernet (veth) pairs for host namespaces
sudo ip link add br0-l-veth type veth peer name ns1-veth 
sudo ip link add br1-l-veth type veth peer name ns2-veth

# Assign veth interfaces to their respective namespaces
sudo ip link set ns1-veth netns ns1
sudo ip link set ns2-veth netns ns2

# Connect the other ends of the veth pairs to the bridges
sudo ip link set br0-l-veth master br0
sudo ip link set br1-l-veth master br1

# Activate veth interfaces on the host side
sudo ip link set br0-l-veth up
sudo ip link set br1-l-veth up

# Assign IP addresses to namespace interfaces
sudo ip netns exec ns1 ip addr add 10.11.0.2/24 dev ns1-veth
sudo ip netns exec ns2 ip addr add 10.12.0.2/24 dev ns2-veth

# Set default routes in namespaces to route traffic through the router
sudo ip netns exec ns1 ip route add default via 10.11.0.1 dev ns1-veth
sudo ip netns exec ns2 ip route add default via 10.12.0.1 dev ns2-veth

# Activate loopback interfaces in the namespaces
sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns2 ip link set lo up

# Bring up namespace veth interfaces
sudo ip netns exec ns1 ip link set ns1-veth up
sudo ip netns exec ns2 ip link set ns2-veth up

# Set up default routes in namespaces to reach other networks via the router
sudo ip netns exec ns1 ip route add default via 10.11.0.254
sudo ip netns exec ns2 ip route add default via 10.12.0.254

# Create veth pairs to connect the router to the bridges
sudo ip link add br0-r-veth type veth peer name router-ns-veth1
sudo ip link add br1-r-veth type veth peer name router-ns-veth2

# Assign router veth interfaces to the router namespace
sudo ip link set router-ns-veth1 netns router-ns
sudo ip link set router-ns-veth2 netns router-ns

# Attach the other ends of the veth pairs to the respective bridges
sudo ip link set br0-r-veth master br0
sudo ip link set br1-r-veth master br1

# Bring up the router-side veth interfaces on the host
sudo ip link set br0-r-veth up
sudo ip link set br1-r-veth up

# Assign IP addresses to the router interfaces
sudo ip netns exec router-ns ip addr add 10.11.0.254/24 dev router-ns-veth1 
sudo ip netns exec router-ns ip addr add 10.12.0.254/24 dev router-ns-veth2

# Bring up the router interfaces
sudo ip netns exec router-ns ip link set router-ns-veth1 up
sudo ip netns exec router-ns ip link set router-ns-veth2 up

# Configure routing in the router namespace to forward packets between networks
sudo ip netns exec router-ns ip route add 10.11.0.0/24 dev router-ns-veth1
sudo ip netns exec router-ns ip route add 10.12.0.0/24 dev router-ns-veth2

# Configure iptables to allow forwarding between bridges
sudo iptables --append FORWARD --in-interface br0 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br0 --jump ACCEPT
sudo iptables --append FORWARD --in-interface br1 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br1 --jump ACCEPT

# Test connectivity: Ensure ns1 can reach the router
sudo ip netns exec ns1 ping -c 3 10.11.0.254

# Test connectivity: Ensure ns2 can reach the router
sudo ip netns exec ns2 ping -c 3 10.12.0.254

# Test connectivity: Ensure ns1 and ns2 can communicate through the router
sudo ip netns exec ns1 ping -c 3 10.12.0.2
sudo ip netns exec ns2 ping -c 3 10.11.0.2

# Cleanup: Remove namespaces and interfaces created by the script
sudo ip netns del ns1
sudo ip netns del ns2
sudo ip netns del router-ns
sudo ip link del br0
sudo ip link del br1