# c2-redirectors
Automate c2 redirector deployments.


## Rocky Linux

## Install Options

* Follow the Automated KVM install if you are running Rocky as a virtual machine on KVM. The certificate is set to self signed.
* If you are running Rocky as an exposed service on the internet, feel free to update the rocky_setup.sh file to use certbot instead of the self signed certificate.

### Automate KVM guest server

* Skip this KVM install if you already have Rocky running.
* Create a password using sha512. Update the anaconda.cfg file with this password (create two if needed), for root and user, lines 39 and 40.
```
mkpasswd -m sha-512
```

* You will need to download the Rocky Linux .iso file at this time, eventually we will move to http install.
** https://rockylinux.org/download/
* Move your anaconda.cfg file to /var/lib/libvirt/kickstart/
* Move your rocky .iso file to /var/lib/libvirt/images/

Kick off the automation script on your KVM host.
```
sudo ./rocky_automated_install.sh

Define the hostname here:
>>> c2-redirector
Give me a number, the size of our volume with be in Gigs:
>>> 15
Give me a number, the size of virtual memory in MB:
>>> 2048
Give me a number, how many cores for cpu:
>>> 2
Supply me with the Network interface:
>>> br0
```

## Setup

* Use the setup script to automate hardening, setup, and install of C2 redirector of your Rocky Linux host
```
[rockyuser@c2-redirector3]$ ./rocky_setup.sh 

Please provide domain name for calling redirector:
>>> servicer.domain.com 
Your malicious domain name is servicer.domain.com
Make sure you own the domain, or this will fail!
Do you own root domain and have an A record servicer.domain.com?
>>> y

```

You may now use this host as part of your c2 infrastructure. 

# C2 Servers

### Tested on Kali - system daemon on startup

* These daemon files will allow your C2 to open a reverse tunnel to the C2 Redirectors
* Open ssh-port-forward and c2_redirectors and update the IP addresses to your Rocky ip addresses
* Place the files accordingly onto your Kali/C2 servers:

```
mv c2-redirectors/c2_server/kali/etc/init.d/ssh-port-forward /etc/init.d/
mv c2-redirectors/c2_server/kali/usr/sbin/c2_redirectors /usr/sbin/
systemctl enable ssh-port-forward
```

