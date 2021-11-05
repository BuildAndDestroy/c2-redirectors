# c2-redirectors
Automate c2 redirector deployments.


## Rocky Linux

### Automate KVM guest server

* Create a password using sha512. Update the anaconda.cfg file with this password (create two if needed), for root and user, lines 39 and 40.
```
mkpasswd -m sha-512
```

* You will need to download the Rocky Linux .iso file at this time, eventually we will move to http install.
** https://rockylinux.org/download/
* Move your anaconda.cfg file to /var/lib/libvirt/kickstart/
* Move your rocky .iso file to /var/lib/libvirt/images/

Kick off the automation script.
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

* Use the setup script to automate hardening, setup, and install of C2 redirector  of your Rocky Linux host
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
