#!/bin/bash

# Set the desired hostname
echo "Please enter desired hostname:"
read -r hostname

# New line to make things look nice
echo ""

# Set the desired timezone
echo "Please enter desired timezone: (ex. America/New_York)"
read -r timezone

echo ""

# Set the desired locale
echo "Please enter desired locale: (ex. en_US-UTF-8 UTF-8)"
read -r locale

echo ""

# Check if archiso
LIVEISO=$(cat /etc/os-release | awk '\NAME=\' |  head -n 1 | sed s/NAME=/''/)
if [ $LIVEISO = 'Arch Linux' ]; then
	pacman -Syu wget
fi

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

# Add MAKEOPTS automatically
THREADS=$(expr $(nproc) / 2)
echo "MAKEOPTS=\"-j"$THREADS"\"

# Chroot into the Gentoo environment/mount boot part
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
echo "Please enter desired root password"
passwd root

# Add user account
echo "Do you want a user account? (y/n)"
read -r user_ask
if [ $user_ask = "y" ]; then
	echo "Please enter desired name:"
	read -r user_name
	echo ""
	echo "Please enter desired groups: (ex. wheel,video,audio)"
	read -r user_groups
	echo ""
	echo "Please enter desired shell: (ex. /bin/bash)"
	read -r user_shell
	echo "Please enter desired password: "
	read -r user_password
	useradd -m -G $user_groups -s $user_shell -p $user_password $user_name
fi

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
