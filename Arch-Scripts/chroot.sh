#!/bin/bash

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
	systemctl enable gdm
	systemctl enable bluetooth
	systemctl enable cups.service
	systemctl enable sshd
	systemctl enable avahi-daemon
	systemctl enable tlp
	systemctl enable reflector.timer
	systemctl enable fstrim.timer
	systemctl enable libvirtd
	systemctl enable firewalld
	systemctl enable acpid
	sleep 10
}

config-users() {
	printf "\e[1;32m********createing user vijay*********/n\e[0m"
	useradd -m vijay
	echo root:vijay | chpasswd
	echo vijay:vijay | chpasswd
	usermod -aG libvirt vijay
	echo "vijay ALL=(ALL) ALL" >> /etc/sudoers.d/vijay
	printf "\e[1;32m********createing user Successfully Done*********/n\e[0m"
	sleep 10
}

install-pkgs() {
	pwd
	sleep 5
	cd /tmp
	curl -LO https://gitlab.com/vijaysrv/arch-repo/-/raw/main/x86_64/yay-10.2.2-4-x86_64.pkg.tar.zst
	curl -LO https://gitlab.com/vijaysrv/arch-repo/-/raw/main/x86_64/google-chrome-91.0.4472.77-1-x86_64.pkg.tar.zst
	curl -LO https://gitlab.com/vijaysrv/arch-repo/-/raw/main/x86_64/brave-bin-1:1.25.68-1-x86_64.pkg.tar.zst
	pacman -U --noconfirm *.pkg.tar.zst
	rm -v *.pkg.tar.zst
	sleep 10
}

install-dots(){
	printf "\e[1;32m ***********installing Dotfiles **********/n\e[0m"
	curl -L vijayakumarravi.github.io/Dotfiles/install.sh -o /home/vijay/install.sh
	bash /home/vijay/install.sh
	rm -v /home/vijay/install.sh
	sleep 20
}

etc-configs
starting-service
config-users
if [[ $1 = "ip" ]]; then
	install-pkgs
fi
grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg
install-dots
sleep 10
printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
