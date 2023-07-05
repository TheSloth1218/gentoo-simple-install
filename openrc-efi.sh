#!/bin/bash

# Set the desired hostname
hostname="tux"

# Set the desired timezone
timezone="America/Chicago"

# Set the desired locale
locale="en_US.UTF-8 UTF-8"


# Download the stage3 tarball
mkdir -p /mnt/gentoo
mount /dev/sda2 /mnt/gentoo
cd /mnt/gentoo
wget https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20230702T170203Z/stage3-amd64-openrc-20230702T170203Z.tar.xz
tar xpvf stage3-amd64-openrc-20230702T170203Z.tar.xz --xattrs-include='*.*' --numeric-owner 

# Configure the Gentoo repository
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Copy DNS info
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Mount necessary filesystems
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
# Ch into the Gentoo environment/mount boot part
chroot /mnt/gentoo /bin/bash <<EOF
source /etc/profile
export PS1="(chroot) ${PS1}"
mount /dev/sda1 /boot

#Sync initial portage tree/world set
emerge-webrsync
emerge -vUDN @world

# Set the timezone
echo "$timezone" > /etc/timezone
emerge --config sys-libs/timezone-data

# Set the locale
echo "$locale" > /etc/locale.gen
locale-gen
eselect locale set 1

# Update the environment
env-update && source /etc/profile

# Set the hostname
echo "hostname=\"$hostname\"" > /etc/conf.d/hostname

# Set the password

# Configure OpenRC
rc-update add dhcpcd default
rc-update add sshd default

# Install necessary packages
emerge -v sys-kernel/gentoo-kernel-bin

# Configure the kernel
eselect kernel set 1


#Genfstab 
emerge -v genfstab 
genfstab -U / >> /etc/fstab

#Systools
emerge -v chrony mlocate genlop gentoolkit dev-vcs/git ufed 
rc-update add chronyd default

#Filetools
emerge -v xfsprogs dosfstools

#BOOTLOADER
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge -v grub
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg
EOF

#re-chroot for passwd end config
chroot /mnt/gentoo /bin/bash




# Reboot
