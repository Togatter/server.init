#!/bin/sh

sudo su -

$DNS1="192.168.2.200"
$DNS2="8.8.8.8"

echo -e "nameserver $DNS1 \nnameserver $DNS2" > /etc/resolv.conf
test -f /etc/bootstrapped && exit

#groupadd ftp_group
useradd toga
echo "toga ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
mkdir /home/toga/.ssh
cp -p /home/vagrant/.ssh/authorized_keys /home/toga/.ssh/authorized_keys
chown -R toga.toga /home/toga/.ssh
chmod 600 /home/toga/.ssh/authorized_keys

date > /etc/bootstrapped
