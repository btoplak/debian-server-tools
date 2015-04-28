#!/bin/bash
#
# Debian server setup - wheezy amd64
# Not a script but a manual.
#
# OVH /etc/ovhrc
#     cdns.ovh.net.
#     ntp.ovh.net
# aruba
#     dns.aruba.it. dns2.aruba.it.

# How to choose VPS provider?
#
# - Disk access time
# - CPU speed
# - Worldwide and local bandwidth
# - Nightime technical support: network or hardware failure response time
# - Daytime technical and billing support
# - DoS mitigation


exit 0

# Whitelist outgoing SMTP server sending notifications.
# /etc/courier/smtpaccess/default
1.2.3.4	allow,RELAYCLIENT


# download this repo
mkdir ~/src && cd ~/src
wget https://github.com/szepeviktor/debian-server-tools/archive/master.zip
unzip master.zip && cd debian-server-tools-master/
D="$(pwd)"

# identify distribution
lsb_release -a

# clean packages
apt-get clean
apt-get autoremove --purge -y

# packages sources
nano /etc/apt/sources.list
# Linode: http://mirrors.linode.com/debian
# OVH: http://debian.mirrors.ovh.net/debian
# server4you: http://debian.intergenia.de/debian
# closest mirror http://http.debian.net/debian
# national mirror: http://ftp.<COUNTRY-CODE>.debian.org/debian
deb <MIRROR> wheezy main contrib non-free
# security
deb http://security.debian.org/ wheezy/updates main contrib non-free
# updates (previously known as 'volatile')
deb <MIRROR> wheezy-updates main
# backports
# http://backports.debian.org/changes/wheezy-backports.html
deb <MIRROR> wheezy-backports main

# disable apt languages
echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00languages

# throttle package downloads (1000 kB/s)
echo 'Acquire::Queue-mode "access"; Acquire::http::Dl-Limit "1000";' > /etc/apt/apt.conf.d/76download

# upgrade
apt-get update && apt-get dist-upgrade -y
apt-get install -y ssh sudo ca-certificates most lftp bash-completion htop bind9-host mc lynx ncurses-term
ln -sv /usr/bin/host /usr/local/bin/mx

# remove systemd
apt-get install sysvinit-core sysvinit sysvinit-utils
apt-get remove --purge --auto-remove systemd
echo -e 'Package: *systemd*\nPin: origin ""\nPin-Priority: -1' > /etc/apt/preferences.d/systemd

# input
echo "alias e='mcedit'" > /etc/profile.d/editor.sh || echo "ERROR: alias 'e'"
sed -i 's/^# \(".*: history-search-.*ward\)$/\1/' /etc/inputrc || echo "ERROR: history-search-backward"
sed -e 's/\(#.*enable bash completion\)/#\1/' -e '/#.*enable bash completion/,+8 { s/^#// }' -i /etc/bash.bashrc || echo "ERROR: bash completion"
update-alternatives --set pager /usr/bin/most
update-alternatives --set editor /usr/bin/mcedit
# Markdown for mc
# cp /etc/mc/mc.ext ~/.config/mc/mc.ext && apt-get install -y pandoc
# editor ~/.config/mc/mc.ext
# regex/\.md(own)?$
# 	View=pandoc -s -f markdown -t man %p | man -l -
cp /usr/share/mc/syntax/Syntax ~/.config/mc/mcedit/Syntax
sed -i 's;^\(file .*\[nN\]\[iI\]\)\(.*\)$;\1|cf|conf|cnf|local|htaccess\2;' ~/.config/mc/mcedit/Syntax
nano ~/.config/mc/mcedit/Syntax

# bash
echo "dash dash/sh boolean false"|debconf-set-selections -v
dpkg-reconfigure -f noninteractive dash
nano /root/.bashrc
export PS1="[\[$(tput setaf 3)\]\u\[\033[1;31m\]@\h\[$(tput sgr0)\]:\[$(tput setaf 8)\]\[$(tput setab 4)\]\
\w\[$(tput sgr0)\]:\t:\[$(tput setaf 0)\]\!\[$(tput sgr0)\]]\n"
export GREP_OPTIONS="--color"
alias grep='grep $GREP_OPTIONS'
alias iotop='iotop -d 0.1 -qqq -o'
alias iftop='NCURSES_NO_UTF8_ACS=1 iftop -nP'
# putty / Connection / Data / Terminal-type string: putty-256color
# ls -1 /usr/share/mc/skins/
export MC_SKIN="modarin256root-defbg"
alias transit='xz -9|base64 -w $((COLUMNS-1))'
alias transit-receive='base64 -d|xz -d'

# wget defaults.
echo -e "\ncontent_disposition = on" >> /etc/wgetrc

# Username.
U="viktor"
adduser $U
# Enter password twice.
K="<PUBLIC-KEY>"
S="/home/$U/.ssh"; mkdir --mode 700 "$S"; echo "$K" >> "${S}/authorized_keys2"; chown -R $U:$U "$S"
adduser $U sudo

# Remove root etc. passwords.
nano /etc/shadow
# sshd on another port.
sed 's/^Port 22$/#Port 22\nPort 3022/' -i /etc/ssh/sshd_config
# Disable root login.
sed 's/^PermitRootLogin yes$/#PermitRootLogin yes/' -i /etc/ssh/sshd_config
# Disable password login for sudoers.
echo -e 'Match Group sudo\n    PasswordAuthentication no' >> /etc/ssh/sshd_config
# Add IP blocking.
# see: $D/security/README.md
nano /etc/hosts.deny
service ssh restart
netstat -antup|grep sshd

# log out as root
logout

# log in
sudo su - || exit

# hardware
lspci
[ -f /proc/modules ] && lsmod || echo "WARNING: monolithic kernel"

# disk configuration
cat /proc/mdstat
cat /proc/partitions
pvdisplay && vgdisplay && lvdisplay
cat /proc/mounts
cat /proc/swaps
# dd if=/dev/zero of=/swap0 bs=1M count=768
# chmod 0600 /swap0
# echo "/swap0    none    swap    sw    0   0" >> /etc/fstab

grep "relatime" /proc/mounts || echo "ERROR: no relAtime"

# kernel
uname -a
# list kernels
apt-cache policy linux-image-amd64
apt-get install linux-image-amd64=<KERNEL-VERSION>
dpkg -l|grep "grub"
ls -latr /boot/
# OVH Kernel
# https://gist.github.com/szepeviktor/cf6b60ac1b2515cb41c1
# Linode Kernels
# auto renew on reboot - https://www.linode.com/kernels/
editor /etc/modules
editor /etc/sysctl.conf

# misc. files
editor /etc/rc.local
editor /etc/profile
editor /etc/motd

# network
editor /etc/network/interfaces
# iface eth0 inet static
#     address <IP>
#     gateway <GATEWAY>
ifconfig -a
route -n -4
route -n -6
netstat -antup
editor /etc/resolv.conf
# nameserver 8.8.8.8
# nameserver 8.8.4.4
# nameserver <LOCAL_NS>
# options timeout:2
# #options rotate
ping6 -c 4 ipv6.google.com
# should be A 93.184.216.119
host -v -t A example.com
# view network graph: http://bgp.he.net/ip/<IP>

# MYATTACKERS chain
iptables -N MYATTACKERS
iptables -I INPUT -j MYATTACKERS
iptables -A MYATTACKERS -j RETURN
# for management scripts see: $D/tools/deny-ip.sh

# hostname
# set A record and PTR record
# consider: http://www.iata.org/publications/Pages/code-search.aspx
#           http://www.world-airport-codes.com/
H="<HOST-NAME>"
# search for the old hostname
grep -ir "$(hostname)" /etc/
hostname "$H"
echo "$H" > /etc/hostname
echo "$H" > /etc/mailname
# # <ORIG-REVERSE-DNS>
# 127.0.1.1 host host.domain.tld
editor /etc/hosts

# locale, timezone
locale
locale -a
dpkg-reconfigure locales
cat /etc/timezone
dpkg-reconfigure tzdata

# comment out getty[2-6], not /etc/init.d/rc !
# consider agetty
editor /etc/inittab
# sanitize users
editor /etc/passwd
editor /etc/shadow

# sanitize packages (-hardware-related +monitoring -daemons)
# delete not installed packages
dpkg -l|grep -v "^ii"
# apt-get purge isc-dhcp-client isc-dhcp-common python2.6-minimal python2.6 rpcbind nfs-common
# non-stable packages
dpkg -l|grep "~[a-z]\+"|sort|uniq -c|sort -n
dpkg -l|egrep "~squeeze|python2\.6"
# non-Debian packages
aptitude search '?narrow(?installed, !?origin(Debian))'
# obsolete pacakages
aptitude search '?obsolete'
# vps monitoring
ps aux|grep -v "grep"|egrep "snmp|vmtools|xe-daemon"
# see: package/vmware-tools-wheezy.sh
dpkg -l|egrep "fancontrol|acpid|laptop-detect|eject|lm-sensors|sensord|smartmontools|mdadm|lvm|usbutils|dmidecode"
dpkg -l|most
apt-get autoremove --purge

# essential packages
apt-get install -y heirloom-mailx unattended-upgrades apt-listchanges cruft debsums \
    iptables-persistent bootlogd ntpdate gcc make time colordiff pwgen dos2unix \
    strace ccze mtr-tiny apt-transport-https
apt-get install -t wheezy-backports -y rsyslog whois git goaccess
# rsyslogd immark plugin: http://www.rsyslog.com/doc/rsconf1_markmessageperiod.html
# editor /etc/rsyslog.conf
# $ModLoad immark
# $MarkMessagePeriod 1800
cd /root/src/ && git clone --recursive https://github.com/szepeviktor/debian-server-tools.git

# IRQ balance
declare -i CPU_COUNT="$(grep -c "^processor" /proc/cpuinfo)"
[ "$CPU_COUNT" -gt 1 ] && apt-get install -y irqbalance && cat /proc/interrupts

# time
cp -v $D/monitoring/ntpdated /usr/local/sbin/
$D/install-cron.sh $D/monitoring/ntpdated
# set nearest time server: http://www.pool.ntp.org/en/
# NTPSERVERS="0.uk.pool.ntp.org 1.uk.pool.ntp.org 2.uk.pool.ntp.org 3.uk.pool.ntp.org"
# NTPSERVERS="0.de.pool.ntp.org 1.de.pool.ntp.org 2.de.pool.ntp.org 3.de.pool.ntp.org"
# NTPSERVERS="0.fr.pool.ntp.org 1.fr.pool.ntp.org 2.fr.pool.ntp.org 3.fr.pool.ntp.org"
# NTPSERVERS="0.hu.pool.ntp.org 1.hu.pool.ntp.org 2.hu.pool.ntp.org 3.hu.pool.ntp.org"
# OVH
# NTPSERVERS="ntp.ovh.net"
editor /etc/default/ntpdate

#TODO  measure CPU speed bz2 25MB, disk access time and throughput hdd-, network speed multiple connections
# https://github.com/mgutz/vpsbench/blob/master/vpsbench

# backported unscd
wget -O unscd_amd64.deb http://szepeviktor.github.io/debian/pool/main/u/unscd/unscd_0.51-1~bpo70+1_amd64.deb
dpkg -i unscd_amd64.deb
editor /etc/nscd.conf
# enable-cache            hosts   yes
# positive-time-to-live   hosts   60
# negative-time-to-live   hosts   20
service unscd stop && service unscd start

# sanitize files
HOSTING_COMPANY="<HOSTING-COMPANY>"
find / -iname "*${HOSTING_COMPANY}*"
grep -ir "${HOSTING_COMPANY}" /etc/
dpkg -l|grep -i "${HOSTING_COMPANY}"
cruft --ignore /dev/|tee cruft.log
# find broken symlinks
find / -type l -xtype l -not -path "/proc/*"
debsums -c

# updates
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true"|debconf-set-selections -v
dpkg-reconfigure -f noninteractive unattended-upgrades

# detect whether your container is running under a hypervisor
wget -O slabbed-or-not.zip https://github.com/kaniini/slabbed-or-not/archive/master.zip
unzip slabbed-or-not.zip && rm slabbed-or-not.zip
cd slabbed-or-not-master/ && make && ./slabbed-or-not|tee ../slabbed-or-not.log && cd ..

# VPS check
#FIXME install.sh ...
cp -v $D/monitoring/vpscheck.sh /usr/local/sbin/
editor /usr/local/sbin/vpscheck.sh
vpscheck.sh -gen
editor /root/.config/vpscheck/configuration
vpscheck.sh
$D/install-cron.sh /usr/local/sbin/vpscheck.sh

# fail2ban latest version's .dsc: https://tracker.debian.org/pkg/fail2ban
apt-get install -y geoip-bin recode python3-pyinotify
apt-get install -t wheezy-backports -y init-system-helpers
# latest geoip-database-contrib version
GEOIP=$(wget -qO- https://packages.debian.org/sid/all/geoip-database-contrib/download|grep -o '[^"]\+ftp.fr.debian.org/debian[^"]\+\.deb')
wget -O geoip-database-contrib_all.deb "$GEOIP"
dpkg -i geoip-database-contrib_all.deb
# .dsc from sid:  https://packages.debian.org/sid/fail2ban
#dget -ux <DSC-URL>
#dpkg-checkbuilddeps && dpkg-buildpackage -b -us -uc
# packaged 0.9.1
wget -O fail2ban_all.deb http://szepeviktor.github.io/debian/pool/main/f/fail2ban/fail2ban_0.9.1-1_all.deb
dpkg -i fail2ban_all.deb
# filter: apache-combined, apache-asap
# action: sendmail-geoip-lines.local
editor /etc/fail2ban/jail.local
editor /etc/fail2ban/fail2ban.local

# apt repositories for these softwares, see package/README.md
editor /etc/apt/sources.list.d/others.list
eval "$(grep "^#K:" /etc/apt/sources.list.d/others.list | cut -d' ' -f2-)"
apt-get update

# Apache 2.4.x (jessie backport)
apt-get install -y -t wheezy-experimental apache2-mpm-itk apache2-utils libapache2-mod-fastcgi
a2enmod actions
a2enmod rewrite
a2enmod headers
a2enmod deflate
a2enmod expires
cp -v $D/webserver/apache-conf-available/* /etc/apache2/conf-available/
cp -vf $D/webserver/apache-sites-available/* /etc/apache2/sites-available/
a2enconf php-fpm
a2enconf h5bp
editor /etc/apache2/conf-enabled/security.conf
# ServerTokens Prod
editor /etc/apache2/apache2.conf
# LogLevel info
#TODO: fcgi://port,path?? ProxyPassMatch ^/.*\.php$ unix:/var/run/php5-fpm.sock|fcgi://127.0.0.1:9000/var/www/website/server

# for poorly written themes/plugins
apt-get install -y mod-pagespeed-stable
# comment out mod-pagespeed/deb
editor /etc/apt/sources.list.d/others.list

# adding a website see: webserver/Add-site.md

# PHP 5.5 from DotDeb
apt-get install -y php-pear php5-apcu php5-cli php5-curl php5-dev php5-fpm php5-gd \
    php5-mcrypt php5-mysqlnd php5-readline php5-sqlite
# FIXME ??? pkg-php-tools
PHP_TZ="$(head -n 1 /etc/timezone)"
sed -i 's/^expose_php = .*$/expose_php = Off/' /etc/php5/fpm/php.ini
sed -i 's/^max_execution_time = .*$/max_execution_time = 65/' /etc/php5/fpm/php.ini
sed -i 's/^memory_limit = .*$/memory_limit = 384M/' /etc/php5/fpm/php.ini
sed -i 's/^upload_max_filesize = .*$/upload_max_filesize = 20M/' /etc/php5/fpm/php.ini
sed -i 's/^post_max_size = .*$/post_max_size = 20M/' /etc/php5/fpm/php.ini
sed -i 's/^allow_url_fopen = .*$/allow_url_fopen = Off/' /etc/php5/fpm/php.ini
sed -i "s|^;date.timezone =.*\$|date.timezone = ${PHP_TZ}|" /etc/php5/fpm/php.ini
grep -v "^#\|^;\|^$" /etc/php5/fpm/php.ini|most
# disable "www" pool
sed -i 's/^/;/' /etc/php5/fpm/pool.d/www.conf
cp -v $D/webserver/php5fpm-pools/* /etc/php5/fpm/
# PHP 5.6+ session cleaning
mkdir -p /usr/local/lib/php5
cp $D/webserver/sessionclean5.5 /usr/local/lib/php5/

# FIXME timeouts
# - PHP max_execution_time
# - PHP max_input_time
# - FastCGI -idle-timeout
# - PHP-FPM pool request_terminate_timeout

# suhosin: https://github.com/stefanesser/suhosin/releases
#SUHOSIN_URL="<RELEASE-TAR-GZ>"
# version 0.9.37.1
SUHOSIN_URL="https://github.com/stefanesser/suhosin/archive/0.9.37.1.tar.gz"
wget -qO- "$SUHOSIN_URL"|tar xz && cd suhosin-*
phpize && ./configure && make && make test || echo "ERROR: suhosin build failed."
make install && cp -v suhosin.ini /etc/php5/fpm/conf.d/00-suhosin.ini && cd ..
# enable
sed -i 's/^;\(extension=suhosin.so\)$/\1/' /etc/php5/fpm/conf.d/00-suhosin.ini || echo "ERROR: enabling suhosin"

#TODO: ini-handler, Search for it!

# PHP secure directives
assert.active
mail.add_x_header
suhosin.executor.disable_emodifier = On
suhosin.disable.display_errors = 1
suhosin.session.cryptkey = `apg -m 32`

# PHP directives for Drupal
suhosin.get.max_array_index_length = 128
suhosin.post.max_array_index_length = 128
suhosin.request.max_array_index_length = 128

# PHP security check
git clone https://github.com/sektioneins/pcc.git
# pool config: env[PCC_ALLOW_IP] = 1.2.3.*

# MariaDB
apt-get install -y mariadb-server-10.0 mariadb-client-10.0
echo -e "[mysql]\nuser=root\npass=*\ndefault-character-set=utf8" >> /root/.my.cnf && chmod 600 /root/.my.cnf
editor /root/.my.cnf

# control panel for opcache and APC
# add "web" user, see: webserver/add-site.sh
#TOOLS_DOCUMENT_ROOT="<TOOLS-DOCUMENT-ROOT>"
TOOLS_DOCUMENT_ROOT=/home/web/public_html/server/
# favicon, robots.txt
wget -P "$TOOLS_DOCUMENT_ROOT" https://www.debian.org/favicon.ico
echo -e "User-agent: *\nDisallow: /" > "${TOOLS_DOCUMENT_ROOT}/robots.txt"
# kabel / ocp.php
cp -v $D/webserver/ocp.php "$TOOLS_DOCUMENT_ROOT"
# old apc/PECL
#APC_URL="http://pecl.php.net/get/APC-3.1.13.tgz"
#wget -qO- "$APC_URL" | tar xz --no-anchored apc.php && mv APC*/apc.php "$TOOLS_DOCUMENT_ROOT" && rmdir APC*
# apc trunk for PHP 5.4-
php -r 'if(1!==version_compare("5.5",phpversion())) exit(1);' \
    && wget -O "${TOOLS_DOCUMENT_ROOT}/apc.php" "http://git.php.net/?p=pecl/caching/apc.git;a=blob_plain;f=apc.php;hb=HEAD"
# APCu master for PHP 5.5+
php -r 'if(1===version_compare("5.5",phpversion())) exit(1);' \
    && wget -O "${TOOLS_DOCUMENT_ROOT}/apc.php" "https://github.com/krakjoe/apcu/raw/simplify/apc.php"
# HTTP/AUTH
htpasswd -c ../htpasswords <USERNAME>
chmod 600 ../htpasswords

# PHPMyAdmin
# see: $D/package/phpmyadmin-get-sf.sh
cd phpMyAdmin-*-english
cp config.sample.inc.php config.inc.php
pwgen -y 30 1
# http://docs.phpmyadmin.net/en/latest/config.html#basic-settings
editor config.inc.php
# $cfg['blowfish_secret'] = '$(pwgen -y 30 1)';
# $cfg['DefaultLang'] = 'en';
# $cfg['PmaNoRelation_DisableWarning'] = true;
# $cfg['SuhosinDisableWarning'] = true;
# $cfg['CaptchaLoginPublicKey'] = '<Site key from https://www.google.com/recaptcha/admin >';
# $cfg['CaptchaLoginPrivateKey'] = '<Secret key>';

# wp-cli
WPCLI_URL="https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
wget -O /usr/local/bin/wp "$WPCLI_URL" && chmod +x /usr/local/bin/wp
WPCLI_COMPLETION_URL="https://github.com/wp-cli/wp-cli/raw/master/utils/wp-completion.bash"
wget -O- "$WPCLI_COMPLETION_URL"|sed 's/wp cli completions/wp --allow-root cli completions/' > /etc/bash_completion.d/wp-cli
# if you have suhosin in global php5 config
#grep "[^;#]*suhosin\.executor\.include\.whitelist.*phar" /etc/php5/cli/conf.d/*suhosin*.ini || echo "Please enable phar in suhosin!"

# drush - https://github.com/drush-ops/drush/releases
wget -qO getcomposer.php https://getcomposer.org/installer
php getcomposer.php --install-dir=/usr/local/bin --filename=composer
mkdir -p /opt/drush && cd /opt/drush
composer require drush/drush:6.*
ln -sv /opt/drush/vendor/bin/drush /usr/local/bin/drush
# set up Drupal site
# sudo -u <SITE-USER> -i
# cd public_html/
# drush dl drupal --drupal-project-rename=server
# cd server/
# drush site-install standard \
#    --db-url='mysql://<DB-USER>:<DB-PASS>@localhost/<DB_NAME>' \
#    --site-name=<SITE-NAME> --account-name=<USERNAME> --account-pass=<USERPASS>
# drush --root=<DOCUMENT-ROOT> vset --yes file_private_path "<PRIVATE-PATH>"
# drush --root=<DOCUMENT-ROOT> vset --yes file_temporary_path "<UPLOAD-DIRECTORY>"
# drush --root=<DOCUMENT-ROOT> vset --yes cron_safe_threshold 0
# see: $D/webserver/preload-cache.sh

# Courier MTA - deliver all mail to a smarthost
apt-get install -y courier-mta courier-mta-ssl
# SMTPS: apt-get install -y courier-mta courier-mta-ssl
dpkg -l|egrep "postfix|exim"
apt-get purge exim4 exim4-base exim4-config exim4-daemon-light
# hostname
editor /etc/courier/me
mx $(cat /etc/courier/me)
editor /etc/courier/defaultdomain
editor /etc/courier/dsnfrom
editor /etc/courier/aliases/system
editor /etc/courier/esmtproutes
# from jessie on: ": <SMART-HOST>,465 /SECURITY=SMTPS" - requires ESMTP_TLS_VERIFY_DOMAIN=1 and TLS_VERIFYPEER=PEER
# : <SMART-HOST>,587 /SECURITY=REQUIRED
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
echo "This is a test mail." | mailx -s "[first] subject of the first email" <ADDRESS>
# on the smarthost add:
# <IP><TAB>allow,RELAYCLIENT,AUTH_REQUIRED=0

# latest Spamassassin version
#SA_URL=$(wget -qO- https://packages.debian.org/sid/all/spamassassin/download|grep -o '[^"]\+ftp.fr.debian.org/debian[^"]\+\.deb')
#wget -O spamassassin_all.deb "$SA_URL"
#dpkg -i spamassassin_all.deb

# SSL for web, mail etc.
# see: security/new-ssl-cert.sh
# test TLS connections: security/README.md

# ProFTPD
# When the default locale for your system is not en_US.UTF-8
# be sure to add this to /etc/default/proftpd for fail2ban to understand dates.
# export LC_TIME="en_US.UTF-8"

# monit - monitoring
# https://mmonit.com/monit/documentation/monit.html
#apt-get install -t wheezy-backports -y monit
# backported from sid: https://packages.debian.org/sid/amd64/monit/download
wget -O monit_amd64.deb http://szepeviktor.github.io/debian/pool/main/m/monit/monit_5.10-1_amd64.deb
dpkg -i monit_amd64.deb
# for configuration see: monitoring/monit
service monit restart
# wait for start
tail -f /var/log/monit.log
monit summary
lynx 127.0.0.1:2812

# munin - network-wide graphing
apt-get install -y time liblwp-useragent-determined-perl libcache-cache-perl
apt-get install -t wheezy-backports -y munin-node
# for configuration see: monitoring/munin
# enable plugins by hand
munin-node-configure --shell
# review plugins
ps aux
ls -l /etc/munin/plugins
# check plugins
ls /etc/munin/plugins/|while read P;do if ! munin-run "$P" config;then echo "ERROR ${P} config status=$?";sleep 4;
    elif ! munin-run "$P";then echo "ERROR ${P} fetch status=$?";sleep 4;fi;done
# allow munin server IP in node config
# regexp IP address: ^1\.2\.3\.4$
editor /etc/munin/munin-node.conf
service munin-node restart

# clean up
apt-get autoremove --purge

# backup /etc
tar cJf "/root/etc-backup_$(date --rfc-3339=date).tar.xz" /etc/

# colorized man with less
man() {
    env \
        LESS_TERMCAP_mb=$(printf "\e[1;31m") \
        LESS_TERMCAP_md=$(printf "\e[1;31m") \
        LESS_TERMCAP_me=$(printf "\e[0m") \
        LESS_TERMCAP_se=$(printf "\e[0m") \
        LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
        LESS_TERMCAP_ue=$(printf "\e[0m") \
        LESS_TERMCAP_us=$(printf "\e[1;32m") \
            man "$@"
}
