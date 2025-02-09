#!/bin/bash

# Create all the namespaces
sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns add router-ns

# Add bridges for namespaces
sudo ip link add br0 type bridge
sudo ip link add br1 type bridge

# Bring up the bridges
sudo ip link set br0 up
sudo ip link set br1 up

# Add veth pairs for namespaces
sudo ip link add br0-l-veth type veth peer name ns1-veth 
sudo ip link add br1-l-veth type veth peer name ns2-veth

# Attach veth interfaces to namespaces
sudo ip link set ns1-veth netns ns1
sudo ip link set ns2-veth netns ns2

# Attach the other ends to bridges
sudo ip link set br0-l-veth master br0
sudo ip link set br1-l-veth master br1

# Bring up the veth interfaces on the host side
sudo ip link set br0-l-veth up
sudo ip link set br1-l-veth up

# Assign IP addresses to namespace interfaces
sudo ip netns exec ns1 ip addr add 10.11.0.2/24 dev ns1-veth
sudo ip netns exec ns2 ip addr add 10.12.0.2/24 dev ns2-veth

# Bring up loopback interfaces in namespaces
sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns2 ip link set lo up

# Bring up namespace veth interfaces
sudo ip netns exec ns1 ip link set ns1-veth up
sudo ip netns exec ns2 ip link set ns2-veth up

# Add default routes in namespaces pointing to router
sudo ip netns exec ns1 ip route add default via 10.11.0.254
sudo ip netns exec ns2 ip route add default via 10.12.0.254

# Add veth pairs for connecting router to bridges
sudo ip link add br0-r-veth type veth peer name router-ns-veth1
sudo ip link add br1-r-veth type veth peer name router-ns-veth2

# Attach router veth interfaces to router namespace
sudo ip link set router-ns-veth1 netns router-ns
sudo ip link set router-ns-veth2 netns router-ns

# Attach the other ends to bridges
sudo ip link set br0-r-veth master br0
sudo ip link set br1-r-veth master br1

# Bring up router-side veth interfaces on the host
sudo ip link set br0-r-veth up
sudo ip link set br1-r-veth up

# Assign IP addresses to router interfaces
sudo ip netns exec router-ns ip addr add 10.11.0.254/24 dev router-ns-veth1 
sudo ip netns exec router-ns ip addr add 10.12.0.254/24 dev router-ns-veth2

# Bring up router interfaces
sudo ip netns exec router-ns ip link set router-ns-veth1 up
sudo ip netns exec router-ns ip link set router-ns-veth2 up

# Enable IP forwarding in the router namespace
sudo sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1

# Add routes in router namespace to enable forwarding between networks
sudo ip netns exec router-ns ip route add 10.11.0.0/24 dev router-ns-veth1
sudo ip netns exec router-ns ip route add 10.12.0.0/24 dev router-ns-veth2

# Test connectivity: Check if ns1 can reach the router
sudo ip netns exec ns1 ping -c 3 10.11.0.254

# Test connectivity: Check if ns2 can reach the router
sudo ip netns exec ns2 ping -c 3 10.12.0.254

# Test connectivity between ns1 and ns2 through the router
sudo ip netns exec ns1 ping -c 3 10.12.0.2
sudo ip netns exec ns2 ping -c 3 10.11.0.2
