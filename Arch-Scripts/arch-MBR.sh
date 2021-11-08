#!/bin/bash

create-part-d1() {
	cat <<EOF | fdisk /dev/sda
o
n
p


+200M
n
p


+2G
n
p



n
p


w
EOF
	partprobe
	sleep 10
}
create-part-d2() {
	cat <<EOF | fdisk /dev/sdb
o
n
p



w
EOF
	partprobe
	sleep 10
}

makefs() {
	mkfs.ext4 /dev/sdb1
	mkfs.ext4 /dev/sda3
	mkfs.ext4 /dev/sda1
	mkswap /dev/sda2
	sleep 10
}

mountfs() {
	swapon /dev/sda2
	mount /dev/sda3 /mnt
	mkdir -p /mnt/boot
	mount /dev/sda1 /mnt/boot
	mkdir -p /mnt/home
	mount /dev/sdb1 /mnt/home
	mkdir ~/temp
	mkdir -p /mnt/temp
	lsblk
	sleep 20
}

install-pkgs() {
	pacman -Sy --noconfirm archlinux-keyring
	pacstrap /mnt base base-devel linux linux-headers linux-firmware xf86-video-nouveau git neovim intel-ucode curl htop neofetch python-pip gawk grub networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools avahi gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils alsa-utils pulseaudio bash-completion openssh rsync acpi acpi_call tlp dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld sof-firmware nss-mdns acpid os-prober ntfs-3g terminus-font cups reflector polkit udisks2 pulseaudio-bluetooth npm
	genfstab -U /mnt >> /mnt/etc/fstab ;
	cat /mnt/etc/fstab ;
	sleep 20
}

chroot-ex() {
	cat <<EOF | arch-chroot /mnt bash
#!/bin/bash
printf "\e[1;32m*********CHROOT Scripts Started**********\e[0m"
etc-configs() {
	ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
	timedatectl set-ntp true
	hwclock --systohc
	echo "archlinux" >> /etc/hostname
	echo "127.0.0.1 localhost" >> /etc/hosts
	echo "::1       localhost" >> /etc/hosts
	echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts
	echo "LANG=en_US.UTF-8" >> /etc/locale.conf
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	echo "en_US ISO-8859-1" >> /etc/locale.gen
	locale-gen
	sleep 10
}

starting-service() {
	systemctl enable NetworkManager
	systemctl enable bluetooth
	systemctl enable cups.service
	systemctl enable sshd
	systemctl enable avahi-daemon
	systemctl enable tlp
	systemctl enable reflector.timer
	systemctl enable fstrim.timer
	systemctl enable firewalld
	systemctl enable acpid
	sleep 10
}

config-users() {
	printf "\e[1;32m********createing user vijay*********/n\e[0m"
	useradd -m vijay
	echo root:vijay | chpasswd
	echo vijay:vijay | chpasswd
	echo "vijay ALL=(ALL) ALL" >> /etc/sudoers.d/vijay
	printf "\e[1;32m********createing user Successfully Done*********/n\e[0m"
	sleep 10
}

etc-configs
starting-service
config-users
grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg
sleep 10
#printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
EOF
}
printf "\e[1;32m*********Arch Scripts Started**********\e[0m"
timedatectl set-ntp true
create-part-d1
# create-part-d2
makefs
mountfs
install-pkgs
chroot-ex

