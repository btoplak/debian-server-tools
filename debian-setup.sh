#!/bin/bash
#
# Debian jessie server setup.
#
# AUTORUN       :wget -O ds.sh http://git.io/vtcLq && . ds.sh
# GIST-AUTORUN  :wget -O ds.dh http://git.io/vIlCB && . ds.dh

# How to choose VPS provider?
#
# - Disk access time
# - CPU speed (~2000 PassMark CPU Mark, ~20 ms sysbench)
# - Worldwide and regional bandwidth, port speed
# - Spammer neighbours https://www.projecthoneypot.org/ip_1.2.3.4
# - Nightime technical support network or hardware failure response time
# - Daytime technical and billing support
# - (D)DoS mitigation

# Packages sources
DS_MIRROR="http://http.debian.net/debian"
#DS_MIRROR="http://ftp.COUNTRY-CODE.debian.org/debian"
DS_REPOS="dotdeb nodejs-iojs percona szepeviktor"
#DS_REPOS="deb-multimedia dotdeb mariadb mod-pagespeed mt-aws-glacier \
#    newrelic nginx nodejs-iojs oracle percona postgre szepeviktor varnish"

# OVH configuration
#
#     /etc/ovhrc
#     cdns.ovh.net.
#     ntp.ovh.net.
#
# Aruba configuration
#
#     DC1-IT 62.149.128.4 62.149.132.4
#     DC3-CZ 81.2.192.131 81.2.193.227

set -e -x

Error() { echo "ERROR: $(tput bold;tput setaf 7;tput setab 1)$*$(tput sgr0)" >&2; }

# Download architecture-independent packages
Getpkg() { local P="$1"; local R="${2-sid}"; local WEB="https://packages.debian.org/${R}/all/${P}/download";
    local URL="$(wget -qO- "$WEB"|grep -o '[^"]\+ftp.fr.debian.org/debian[^"]\+\.deb')";
    [ -z "$URL" ] && return 1; wget -qO "${P}.deb" "$URL" && dpkg -i "${P}.deb"; echo "Ret=$?"; }

[ "$(id -u)" == 0 ] || exit 1

# Identify distribution
lsb_release -a && sleep 5

# Download this repo
mkdir ~/src
cd ~/src
wget -O- https://github.com/szepeviktor/debian-server-tools/archive/master.tar.gz|tar xz
cd debian-server-tools-master/
D="$(pwd)"

# Clean packages
apt-get clean
rm -vrf /var/lib/apt/lists/*
apt-get clean
apt-get autoremove --purge -y

# Packages sources
mv -vf /etc/apt/sources.list "/etc/apt/sources.list~"
cp -v ${D}/package/apt-sources/sources.list /etc/apt/
sed -i "s/%MIRROR%/${DS_MIRROR//\//\\/}/g" /etc/apt/sources.list
# Install HTTPS transport
apt-get update
apt-get install -y apt-transport-https
for R in ${DS_REPOS};do cp -v ${D}/package/apt-sources/${R}.list /etc/apt/sources.list.d/;done
eval "$(grep -h -A5 "^deb " /etc/apt/sources.list.d/*.list|grep "^#K: "|cut -d' ' -f2-)"
#editor /etc/apt/sources.list

# APT settings
echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00languages
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' > /etc/apt/apt.conf.d/20download-upgrade

# Upgrade
apt-get update
apt-get dist-upgrade -y --force-yes
apt-get install -y lsb-release xz-utils ssh sudo ca-certificates most less lftp \
    time bash-completion htop bind9-host mc lynx ncurses-term
ln -sv /usr/bin/host /usr/local/bin/mx

# Input
. /etc/profile.d/bash_completion.sh || Error "bash_completion.sh"
echo "alias e='editor'" > /etc/profile.d/e-editor.sh
sed -i 's/^# \(".*: history-search-.*ward\)$/\1/' /etc/inputrc
update-alternatives --set pager /usr/bin/most
update-alternatives --set editor /usr/bin/mcedit

# Bash
#sed -e 's/\(#.*enable bash completion\)/#\1/' -e '/#.*enable bash completion/,+8 { s/^#// }' -i /etc/bash.bashrc
echo "dash dash/sh boolean false"|debconf-set-selections -v
dpkg-reconfigure -f noninteractive dash

# --- Automated --------------- >8 ------------- >8 ------------
#grep -B1000 "# -\+ Automated -\+" debian-setup.sh
set +e +x
kill -SIGINT $$

# Remove systemd
dpkg -s systemd &> /dev/null && apt-get install -y sysvinit-core sysvinit sysvinit-utils
read -s -p 'Ctrl + D to reboot ' || reboot

apt-get remove -y --purge --auto-remove systemd
echo -e 'Package: *systemd*\nPin: origin ""\nPin-Priority: -1' > /etc/apt/preferences.d/systemd

# Wget defaults
echo -e "\ncontent_disposition = on" >> /etc/wgetrc

# User settings
editor /root/.bashrc

# ---------------------------------------------------------------------

#export LANG=en_US.UTF-8
#export LC_ALL=en_US.UTF-8

export IP="$(ip addr show dev eth0|sed -n 's/^\s*inet \([0-9\.]\+\)\b.*$/\1/p')"

PS1exitstatus() { local RET="$?";if [ "$RET" -ne 0 ];then echo -n "$(tput setaf 7;tput setab 1)"'!'"$RET";fi; }
export PS1="\[$(tput sgr0)\][\[$(tput setaf 3)\]\u\[$(tput bold;tput setaf 1)\]@\h\[$(tput sgr0)\]:\
\[$(tput setaf 8;tput setab 4)\]\w\[$(tput sgr0)\]:\t:\
\[$(tput bold)\]\!\[\$(PS1exitstatus;tput sgr0)\]]\n"

# putty Connection / Data / Terminal-type string: putty-256color
# ls -1 /usr/share/mc/skins/|sed "s/\.ini$//g"
if [ "${TERM/256/}" == "$TERM" ]; then
    if [ "$(id -u)" == 0 ]; then
        export MC_SKIN="modarcon16root-defbg-thin"
    else
        export MC_SKIN="modarcon16"
    fi
else
    if [ "$(id -u)" == 0 ]; then
        export MC_SKIN="modarin256root-defbg-thin"
    else
        export MC_SKIN="xoria256"
    fi
fi

export GREP_OPTIONS="--color"
alias grep='grep $GREP_OPTIONS'
alias iotop='iotop -d 0.1 -qqq -o'
alias iftop='NCURSES_NO_UTF8_ACS=1 iftop -nP'
alias transit='xz -9|base64 -w $((COLUMNS-1))'
alias transit-receive='base64 -d|xz -d'
#alias readmail='MAIL=/var/mail/MAILDIR/ mailx'

# Colorized man pages with less
#     man termcap # String Capabilities
man() {
    #
    #     so   Start standout mode (search)
    #     se   End standout mode
    #     us   Start underlining (italic)
    #     ue   End underlining
    #     md   Start bold mode (highlight)
    #     me   End all mode like so, us, mb, md and mr
    env \
        LESS_TERMCAP_so=$(tput setab 230) \
        LESS_TERMCAP_se=$(tput sgr0) \
        LESS_TERMCAP_us=$(tput setaf 2) \
        LESS_TERMCAP_ue=$(tput sgr0) \
        LESS_TERMCAP_md=$(tput bold) \
        LESS_TERMCAP_me=$(tput sgr0) \
        man "$@"
}

# ---------------------------------------------------------------------

# Markdown for mc
#cp -v /etc/mc/mc.ext ~/.config/mc/mc.ext && apt-get install -y pandoc
#editor ~/.config/mc/mc.ext
#    regex/\.md(own)?$
#    	View=pandoc -s -f markdown -t man %p | man -l -

# Add INI extensions for mc
cp -v /usr/share/mc/syntax/Syntax ~/.config/mc/mcedit/Syntax
sed -i 's;^\(file .*\[nN\]\[iI\]\)\(.*\)$;\1|cf|conf|cnf|local|htaccess\2;' ~/.config/mc/mcedit/Syntax
sed -i 's;^file sources.list\$ sources\\slist$;file (sources)?\\.list$ sources\\slist;' ~/.config/mc/mcedit/Syntax
#editor ~/.config/mc/mcedit/Syntax

# Username
U="viktor"
# GECOS: Full name,Room number,Work phone,Home phone
adduser --gecos "" ${U}
# <<< Enter password twice
K="PUBLIC-KEY"
S="/home/${U}/.ssh";mkdir --mode 700 "$S";echo "$K" >> "${S}/authorized_keys2";chown -R ${U}:${U} "$S"
adduser ${U} sudo

# Change root and other passwords to "*"
editor /etc/shadow
# sshd on another port
sed 's/^Port 22$/#Port 22\nPort 3022/' -i /etc/ssh/sshd_config
# Disable root login
sed 's/^PermitRootLogin yes$/PermitRootLogin no/' -i /etc/ssh/sshd_config
# Disable password login for sudoers
echo -e 'Match Group sudo\n    PasswordAuthentication no' >> /etc/ssh/sshd_config
# Add IP blocking
# See: $D/security/README.md
editor /etc/hosts.deny
service ssh restart
netstat -antup|grep sshd

# Log out as root
logout

# Log in
sudo su - || exit
D="$(pwd)"

# Hardware
lspci
[ -f /proc/modules ] && lsmod || echo "WARNING: monolithic kernel"

# Disk configuration
clear; cat /proc/mdstat; cat /proc/partitions
pvdisplay && vgdisplay && lvdisplay
# ls -1 /etc/default/*
TOTAL_MEM="$(grep MemTotal /proc/meminfo|sed 's;.*[[:space:]]\([0-9]\+\)[[:space:]]kB.*;\1;')"
[ "$TOTAL_MEM" -gt $((2047 * 1024)) ] && sed -i 's/^#RAMTMP=no$/RAMTMP=yes/' /etc/default/tmpfs
# <file system> <mount point>             <type>          <options>                               <dump> <pass>
editor /etc/fstab
cat /proc/mounts
swapoff -a; swapon -a; cat /proc/swaps
# Create swap file
#     dd if=/dev/zero of=/swap0 bs=1M count=768
#     chmod 0600 /swap0
#     echo "/swap0    none    swap    sw    0   0" >> /etc/fstab

grep "\S\+\s\+/\s.*relatime" /proc/mounts || echo "ERROR: no relAtime for rootfs"

# Kernel
uname -a
# List kernels
apt-cache policy "linux-image-3.*"
#apt-get install linux-image-amd64=KERNEL-VERSION
ls -l /lib/modules/
# Verbose boot
sed -i 's/^##VERBOSE=no$/#VERBOSE=yes/' /etc/default/rcS
dpkg -l | grep "grub"
ls -latr /boot/
# OVH Kernel "made-in-ovh"
#     https://gist.github.com/szepeviktor/cf6b60ac1b2515cb41c1
# Linode Kernels: auto renew on reboot
#     https://www.linode.com/kernels/
editor /etc/modules
editor /etc/sysctl.conf

# Miscellaneous configuration
editor /etc/rc.local
editor /etc/profile
ls -l /etc/profile.d/
editor /etc/motd

# Networking
editor /etc/network/interfaces
#     iface eth0 inet static
#         address IP
#         netmask 255.255.255.0
#         gateway GATEWAY
ifconfig -a
route -n -4
route -n -6
netstat -antup

editor /etc/resolv.conf
#     nameserver 8.8.8.8
#     nameserver LOCAL-NS
#     nameserver 8.8.4.4
#     options timeout:2
#     #options rotate

ping6 -c 4 ipv6.google.com
host -v -t A example.com
# Should be: A 93.184.216.34
# View network Graph v4/v6: http://bgp.he.net/ip/IP

# Set up MYATTACKERS chain
iptables -N MYATTACKERS
iptables -I INPUT -j MYATTACKERS
iptables -A MYATTACKERS -j RETURN
# For management scripts see: $D/tools/deny-ip.sh

# Hostname
# Set A record and PTR record
# Consider: http://www.iata.org/publications/Pages/code-search.aspx
#           http://www.world-airport-codes.com/
H="HOST-NAME"
# Search for the old hostname
grep -ir "$(hostname)" /etc/
hostname "$H"
echo "$H" > /etc/hostname
echo "$H" > /etc/mailname
#     127.0.0.1 localhost
#     127.0.1.1 localhost
#     ::1     ip6-localhost ip6-loopback
#     fe00::0 ip6-localnet
#     ff00::0 ip6-mcastprefix
#     ff02::1 ip6-allnodes
#     ff02::2 ip6-allrouters
#
#     # ORIGINAL-PTR $(host "$IP")
#     IP.IP.IP.IP HOST.DOMAIN HOST
editor /etc/hosts

# Locale and timezone
locale; locale -a
dpkg-reconfigure locales
cat /etc/timezone
dpkg-reconfigure tzdata

# Comment out getty[2-6], NOT /etc/init.d/rc !
# Consider /sbin/agetty
editor /etc/inittab
# Sanitize users
editor /etc/passwd
editor /etc/shadow

# Sanitize packages (-hardware-related +monitoring -daemons)
# 1. Delete not-installed packages
dpkg -l|grep -v "^ii"
# 2. Usually unnecessary packages
apt-get purge  \
    at ftp dc dbus rpcbind exim4-base exim4-config python2.6-minimal python2.6 \
    manpages man-db rpcbind nfs-common w3m tex-common isc-dhcp-client isc-dhcp-common
deluser Debian-exim
deluser messagebus
# 3. VPS monitoring
ps aux|grep -v "grep"|grep -E "snmp|vmtools|xe-daemon"
dpkg -l|grep -E "xe-guest-utilities|dkms"
# See: ${D}/package/vmware-tools-wheezy.sh
vmware-toolbox-cmd stat sessionid
# 4. Hardware related
dpkg -l|grep -E -w "dmidecode|eject|laptop-detect|usbutils|kbd|console-setup-linux\
|fancontrol|hddtemp|lm-sensors|sensord|smartmontools|mdadm|lvm2"
# 5. Non-stable packages
dpkg -l|grep "~[a-z]\+"
dpkg -l|grep -E "~squeeze|~wheezy|python2\.6"
# 6. Non-Debian packages
aptitude search '?narrow(?installed, !?origin(Debian))'
# 7. Obsolete packages
aptitude search '?obsolete'
# 8. Manually installed, not "required" and not "important" packages minus known ones
aptitude search '?and(?installed, ?not(?automatic), ?not(?priority(required)), ?not(?priority(important)))' -F"%p" \
    | grep -v -x -f ${D}/package/debian-jessie-not-req-imp.pkg | xargs echo
# 9. Development packages
dpkg -l|grep -- "-dev"
# List by section
aptitude search '?and(?installed, ?not(?automatic), ?not(?priority(required)), ?not(?priority(important)))' -F"%s %p"|sort

dpkg -l | most
apt-get autoremove --purge

# Essential packages
apt-get install -y localepurge unattended-upgrades \
    apt-listchanges cruft debsums heirloom-mailx iptables-persistent bootlogd \
    ntpdate pwgen dos2unix strace ccze mtr-tiny gcc make colordiff
# Backports
# @wheezy apt-get install -t wheezy-backports -y rsyslog whois git goaccess init-system-helpers
apt-get install -y goaccess git

# debsums cron
editor /etc/default/debsums
#     CRON_CHECK=weekly

# Automatic package updates
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true"|debconf-set-selections -v
dpkg-reconfigure -f noninteractive unattended-upgrades

# Sanitize files
HOSTING_COMPANY="HOSTING-COMPANY"
find / -iname "*${HOSTING_COMPANY}*"
grep -ir "${HOSTING_COMPANY}" /etc/
dpkg -l | grep -i "${HOSTING_COMPANY}"
cruft --ignore /dev | tee cruft.log
# Find broken symlinks
find / -type l -xtype l -not -path "/proc/*"
debsums --all --changed | tee debsums-changed.log

# Custom APT repositories
#editor /etc/apt/sources.list.d/others.list && apt-get update

# Detect whether your container is running under a hypervisor
wget -O slabbed-or-not.zip https://github.com/kaniini/slabbed-or-not/archive/master.zip
unzip slabbed-or-not.zip && rm -f slabbed-or-not.zip
cd slabbed-or-not-master/ && make && ./slabbed-or-not|tee ../slabbed-or-not.log && cd ..

# rsyslogd immark plugin: http://www.rsyslog.com/doc/rsconf1_markmessageperiod.html
editor /etc/rsyslog.conf
#     $ModLoad immark
#     $MarkMessagePeriod 1800

# Debian tools
cd /usr/local/src/ && git clone --recursive https://github.com/szepeviktor/debian-server-tools.git
D="$(pwd)/debian-server-tools"
rm -rf /root/src/debian-server-tools-master/

# Make cron log all failed jobs (exit status != 0)
sed -i "s/^#\s*\(EXTRA_OPTS='-L 5'\)/\1/" /etc/default/cron || echo "ERROR: cron-default"
service cron restart

# IRQ balance
declare -i CPU_COUNT="$(grep -c "^processor" /proc/cpuinfo)"
[ "$CPU_COUNT" -gt 1 ] && apt-get install -y irqbalance && cat /proc/interrupts

# Time synchronization
cd ${D}; ./install.sh monitoring/ntpdated
# Set nearest time server: http://www.pool.ntp.org/en/
#     NTPSERVERS="0.uk.pool.ntp.org 1.uk.pool.ntp.org 2.uk.pool.ntp.org 3.uk.pool.ntp.org"
#     NTPSERVERS="0.de.pool.ntp.org 1.de.pool.ntp.org 2.de.pool.ntp.org 3.de.pool.ntp.org"
#     NTPSERVERS="0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org"
#     NTPSERVERS="0.cz.pool.ntp.org 1.cz.pool.ntp.org 2.cz.pool.ntp.org 3.cz.pool.ntp.org"
#     NTPSERVERS="0.hu.pool.ntp.org 1.hu.pool.ntp.org 2.hu.pool.ntp.org 3.hu.pool.ntp.org"
# OVH
#     NTPSERVERS="ntp.ovh.net"
editor /etc/default/ntpdate

# µnscd
apt-get install -y unscd
editor /etc/nscd.conf
#     enable-cache            hosts   yes
#     positive-time-to-live   hosts   60
#     negative-time-to-live   hosts   20
service unscd stop && service unscd start

# VPS check
cd ${D}; ./install.sh monitoring/vpscheck.sh
editor /usr/local/sbin/vpscheck.sh
vpscheck.sh -gen
editor /root/.config/vpscheck/configuration
# Test run
vpscheck.sh

# Courier MTA - deliver all mail to a smarthost
apt-get install -y courier-mta courier-mta-ssl
dpkg -l | grep -E "postfix|exim"
# Host name
editor /etc/courier/me
mx $(cat /etc/courier/me) || Error "no MX for me"
editor /etc/courier/defaultdomain
editor /etc/courier/dsnfrom
editor /etc/courier/aliases/system
editor /etc/courier/esmtproutes
#     : %SMART-HOST%,587 /SECURITY=REQUIRED
# From jessie on - requires ESMTP_TLS_VERIFY_DOMAIN=1 and TLS_VERIFYPEER=PEER
#     : %SMART-HOST%,465 /SECURITY=SMTPS
editor /etc/courier/esmtpd
# ADDRESS=127.0.0.1
# ESMTPAUTH=""
# ESMTPAUTH_TLS=""
editor /etc/courier/esmtpd-ssl
# SSLADDRESS=127.0.0.1
makealiases
makesmtpaccess
service courier-mta restart
service courier-mta-ssl restart
# Allow unauthenticated SMTP traffic from this server on the smarthost
#     editor /etc/courier/smtpaccess/default
#     %%IP%%<TAB>allow,RELAYCLIENT,AUTH_REQUIRED=0
echo "This is a test mail."|mailx -s "[first] Subject of the first email" ADDRESS

# Fail2ban
#     https://packages.qa.debian.org/f/fail2ban.html
Getpkg geoip-database-contrib
apt-get install -y geoip-bin recode python3-pyinotify
#     apt-get install -y fail2ban
Getpkg fail2ban
mc ${D}/security/fail2ban-conf/ /etc/fail2ban/
# Config:    fail2ban.local
# Jails:     jail.local
# /filter.d: apache-combined.local, apache-asap.local
# /action.d: sendmail-geoip-lines.local
service fail2ban restart

# Apache 2.4
# @wheezy apt-get install -y -t wheezy-experimental apache2-mpm-itk apache2-utils libapache2-mod-fastcgi
apt-get install -y apache2-mpm-itk apache2-utils libapache2-mod-fastcgi
a2enmod actions rewrite headers deflate expires
cp -v ${D}/webserver/apache-conf-available/* /etc/apache2/conf-available/
cp -vf ${D}/webserver/apache-sites-available/* /etc/apache2/sites-available/
# Use php-fpm.conf settings per site
a2enconf h5bp
editor /etc/apache2/conf-enabled/security.conf
#     ServerTokens Prod
editor /etc/apache2/apache2.conf
#     LogLevel info
# @TODO fcgi://port,path?? ProxyPassMatch ^/.*\.php$ unix:/var/run/php5-fpm.sock|fcgi://127.0.0.1:9000/var/www/website/html

# For poorly written themes and plugins
apt-get install -y mod-pagespeed-stable
# Remove duplicate
ls -l /etc/apt/sources.list.d/*pagespeed*
#rm -v /etc/apt/sources.list.d/mod-pagespeed.list

# Add the development website
# See: ${D}/webserver/add-dev-site.sh

# Add a website
# See: ${D}/webserver/add-site.sh

# Nginx 1.8
apt-get install -y nginx-lite
# Nginx packages: lite, full, extra
#    https://docs.google.com/a/moolfreet.com/spreadsheet/ccc?key=0AjuNPnOoex7SdG5fUkhfc3BCSjJQbVVrQTg4UGU2YVE#gid=0
#    apt-get install -y nginx-full
# Put ngx-conf in PATH
ln -sv /usr/sbin/ngx-conf/ngx-conf /usr/local/sbin/ngx-conf
# HTTP/AUTH
mkdir /etc/nginx/http-auth
# Configuration
#    https://codex.wordpress.org/Nginx
#    http://wiki.nginx.org/WordPress
git clone https://github.com/szepeviktor/server-configs-nginx.git
NGXC="/etc/nginx"
cp -va h5bp/ ${NGXC}
cp -vf mime.types ${NGXC}
cp -vf nginx.conf ${NGXC}
ngx-conf --disable default
cp -vf sites-available/no-default ${NGXC}/sites-available
ngx-conf --enable no-default

# PHP 5.6
apt-get install -y php5-apcu php5-cli php5-curl php5-fpm php5-gd \
    php5-mcrypt php5-mysqlnd php5-readline php5-sqlite php-pear php5-dev
PHP_TZ="$(head -n 1 /etc/timezone)"
sed -i 's/^expose_php = .*$/expose_php = Off/' /etc/php5/fpm/php.ini
sed -i 's/^max_execution_time = .*$/max_execution_time = 65/' /etc/php5/fpm/php.ini
sed -i 's/^memory_limit = .*$/memory_limit = 384M/' /etc/php5/fpm/php.ini
sed -i 's/^upload_max_filesize = .*$/upload_max_filesize = 20M/' /etc/php5/fpm/php.ini
sed -i 's/^post_max_size = .*$/post_max_size = 20M/' /etc/php5/fpm/php.ini
sed -i 's/^allow_url_fopen = .*$/allow_url_fopen = Off/' /etc/php5/fpm/php.ini
sed -i "s|^;date.timezone =.*\$|date.timezone = ${PHP_TZ}|" /etc/php5/fpm/php.ini

# @TODO realpath_cache* -> measure

grep -Ev "^\s*#|^\s*;|^\s*$" /etc/php5/fpm/php.ini | most
# Disable "www" pool
sed -i 's/^/;/' /etc/php5/fpm/pool.d/www.conf
cp -v ${D}/webserver/php5fpm-pools/* /etc/php5/fpm/
# PHP 5.6+ session cleaning
mkdir -p /usr/local/lib/php5
cp -v ${D}/webserver/sessionclean5.5 /usr/local/lib/php5/

# @FIXME Timeouts
# - PHP max_execution_time
# - PHP max_input_time
# - FastCGI -idle-timeout
# - PHP-FPM pool request_terminate_timeout

# Suhosin
#     https://github.com/stefanesser/suhosin/releases
#     SUHOSIN_URL="RELEASE-TAR"
# Build version 0.9.38
#SUHOSIN_URL="https://github.com/stefanesser/suhosin/archive/0.9.38.tar.gz"
#wget -O- "$SUHOSIN_URL" | tar xz && cd suhosin-*
#phpize && ./configure && make && make test || echo "ERROR: suhosin build failed."
#make install && cp -v suhosin.ini /etc/php5/fpm/conf.d/00-suhosin.ini && cd ..
# Enable suhosin
#sed -i 's/^;\(extension=suhosin.so\)$/\1/' /etc/php5/fpm/conf.d/00-suhosin.ini || echo "ERROR: enabling suhosin"
apt-get install -y php5-suhosin-extension
#sed -i '1i; priority=99' /etc/php5/mods-available/suhosin.ini
php5enmod -s fpm suhosin

# @TODO .ini-handler, Search for it! ?ucf

# PHP security directives
#     assert.active
#     mail.add_x_header
#     suhosin.executor.disable_emodifier = On
#     suhosin.disable.display_errors = 1
#     suhosin.session.cryptkey = $(apg -m 32)

# PHP directives for Drupal
#     suhosin.get.max_array_index_length = 128
#     suhosin.post.max_array_index_length = 128
#     suhosin.request.max_array_index_length = 128

# MariaDB
apt-get install -y mariadb-server-10.0 mariadb-client-10.0
echo -e "[mysql]\nuser=root\npass=?\ndefault-character-set=utf8" >> /root/.my.cnf
chmod 600 /root/.my.cnf
editor /root/.my.cnf

# Control panel for opcache and APC
# Add "web" user, see: ${D}/webserver/add-site.sh
#TOOLS_DOCUMENT_ROOT="TOOLS-DOCUMENT-ROOT"
TOOLS_DOCUMENT_ROOT=/home/web/website/html
# Favicon and robots.txt
wget -P ${TOOLS_DOCUMENT_ROOT} "https://www.debian.org/favicon.ico"
echo -e "User-agent: *\nDisallow: /" > ${TOOLS_DOCUMENT_ROOT}/robots.txt
# kabel / ocp.php
cp -v ${D}/webserver/ocp.php ${TOOLS_DOCUMENT_ROOT}
# apc.php from APC trunk for PHP 5.4-
#     php -r 'if(1!==version_compare("5.5",phpversion())) exit(1);' \
#         && wget -O ${TOOLS_DOCUMENT_ROOT}/apc.php "http://git.php.net/?p=pecl/caching/apc.git;a=blob_plain;f=apc.php;hb=HEAD"
# apc.php from APCu master for PHP 5.5+
php -r 'if(1===version_compare("5.5",phpversion())) exit(1);' \
    && wget -O ${TOOLS_DOCUMENT_ROOT}/apc.php "https://github.com/krakjoe/apcu/raw/simplify/apc.php"
# HTTP/AUTH
htpasswd -c $(dirname ${TOOLS_DOCUMENT_ROOT})/htpasswords USERNAME
chmod 600 $(dirname ${TOOLS_DOCUMENT_ROOT})/htpasswords

# @TODO extract Dev site setup to a script

# PHPMyAdmin
# See: ${D}/package/phpmyadmin-get-sf.sh
cd phpMyAdmin-*-english
cp -v config.sample.inc.php config.inc.php
pwgen -y 30 1
#     http://docs.phpmyadmin.net/en/latest/config.html#basic-settings
editor config.inc.php
#     $cfg['blowfish_secret'] = '$(pwgen -y 30 1)';
#     $cfg['DefaultLang'] = 'en';
#     $cfg['PmaNoRelation_DisableWarning'] = true;
#     $cfg['SuhosinDisableWarning'] = true;
#     $cfg['CaptchaLoginPublicKey'] = '<Site key from https://www.google.com/recaptcha/admin >';
#     $cfg['CaptchaLoginPrivateKey'] = '<Secret key>';

# PHP security check
git clone https://github.com/sektioneins/pcc.git
# Pool config: env[PCC_ALLOW_IP] = 1.2.3.*

# wp-cli
WPCLI_URL="https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
wget -O /usr/local/bin/wp "$WPCLI_URL" && chmod -c +x /usr/local/bin/wp
WPCLI_COMPLETION_URL="https://github.com/wp-cli/wp-cli/raw/master/utils/wp-completion.bash"
wget -O- "$WPCLI_COMPLETION_URL"|sed 's/wp cli completions/wp --allow-root cli completions/' > /etc/bash_completion.d/wp-cli
# If you have suhosin in global php5 config
#     grep "[^;#]*suhosin\.executor\.include\.whitelist.*phar" /etc/php5/cli/conf.d/*suhosin*.ini || Error "Whitelist phar"

# Drush
#     https://github.com/drush-ops/drush/releases
wget -qO getcomposer.php https://getcomposer.org/installer
php getcomposer.php --install-dir=/usr/local/bin --filename=composer
mkdir -p /opt/drush && cd /opt/drush
composer require drush/drush:6.*
ln -sv /opt/drush/vendor/bin/drush /usr/local/bin/drush
# Set up Drupal site
#     sudo -u SITE-USER -i
#     cd website/
#     drush dl drupal --drupal-project-rename=html
#     cd html/
#     drush site-install standard \
#         --db-url='mysql://DB-USER:DB-PASS@localhost/DB-NAME' \
#         --site-name=SITE-NAME --account-name=USER-NAME --account-pass=USER-PASS
#     drush --root=DOCUMENT-ROOT vset --yes file_private_path "PRIVATE-PATH"
#     drush --root=DOCUMENT-ROOT vset --yes file_temporary_path "UPLOAD-DIRECTORY"
#     drush --root=DOCUMENT-ROOT vset --yes cron_safe_threshold 0
#
# See: ${D}/webserver/preload-cache.sh

# Spamassassin
Getpkg spamassassin

# SSL certificate for web, mail etc.
# See: ${D}/security/new-ssl-cert.sh

# Test TLS connections
# See: ${D}/security/README.md

# ProFTPD
# When the default locale for your system is not en_US.UTF-8
# be sure to add this to /etc/default/proftpd for fail2ban to understand dates.
#     export LC_TIME="en_US.UTF-8"

# Simple syslog monitoring
apt-get install -y libdate-manip-perl
# Version 0.50
wget -O /usr/local/bin/dategrep https://github.com/mdom/dategrep/releases/download/0.50/dategrep-standalone-small
chmod +x /usr/local/bin/dategrep
cd ${D}; ./install.sh monitoring/syslog-errors.sh

# Monit - monitoring
#     https://packages.debian.org/sid/amd64/monit/download
apt-get install -y monit
# See: ${D}/monitoring/monit/
#     https://mmonit.com/monit/documentation/monit.html
service monit restart
# Wait for start
tail -f /var/log/monit.log
monit summary
lynx 127.0.0.1:2812

# Munin - network-wide graphing
# See: ${D}/monitoring/munin/munin-debian-setup.sh

# Clean up
apt-get autoremove --purge

# Throttle package downloads (1000 kB/s)
echo 'Acquire::Queue-mode "access"; Acquire::http::Dl-Limit "1000";' > /etc/apt/apt.conf.d/76download

# Backup /etc
tar cJf "/root/${H//./-}_etc-backup_$(date --rfc-3339=date).tar.xz" /etc/

# Clients and services
editor /root/clients.list
editor /root/services.list
