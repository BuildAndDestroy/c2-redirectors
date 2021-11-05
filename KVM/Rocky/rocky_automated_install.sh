#!/bin/bash
##################################################
# Automate the kvm guest install for Rocky Linux #
##################################################


if [[ $(id -u) != 0 ]]; then
    echo 'Must be ran as root.'
    exit
fi


function _obtain_hostname() {
    # Define the hostname for the new KVM
    echo 'Define the hostname here:'
    read -r -p '>>> ' hostname_variable
}

function _obtain_volume_size() {
    # Value will be an integer, the size of a volume in Gigs.
    echo 'Give me a number, the size of our volume with be in Gigs:'
    read -r -p '>>> ' volume_size
}

function _obtain_memory_size() {
    # Value will be an integer, the size in MB. 1024 = 1Gig
    echo 'Give me a number, the size of virtual memory in MB:'
    read -r -p '>>> ' memory_size
}

function _obtain_cpus() {
    # Provide the amount of CPU cores to a KVM. Typically 4 cpus.
    echo 'Give me a number, how many cores for cpu:'
    read -r -p '>>> ' allocate_cpu
}

function _obtain_network_interface() {
    # Natting or public bridge should be the option here. Most likely "br0".
    echo 'Supply me with the Network interface:'
    read -r -p '>>> ' net_interface
}

function _build_virt_command() {
    # Virsh install command example to spin up an automated kvm:
    virt-install -n $hostname_variable \
    --memory $memory_size \
    --vcpus $allocate_cpu \
    --location /mnt/iso/Rocky/Rocky-8.4-x86_64-minimal.iso \
    --os-variant linux \
    --network bridge=$net_interface \
    --disk /var/lib/libvirt/images/$hostname_variable.qcow2,size=$volume_size \
    --nographics \
    --initrd-inject=/var/lib/libvirt/kickstart/anaconda.cfg \
    --extra-args "ks=file:/anaconda.cfg console=ttyS0"
}




############################
# Functions to be executed #
############################

_obtain_hostname
_obtain_volume_size
_obtain_memory_size
_obtain_cpus
_obtain_network_interface
_build_virt_command
