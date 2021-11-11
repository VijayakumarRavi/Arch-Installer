#!/bin/bash

create_partition() {
    clear
    echo "Creating ROOT partition"
    sgdisk -Z /dev/sda
    sgdisk -a 2048 -o /dev/sda

    # Creating partition
    sgdisk -n 1:0:+250M -t 1:ef00 -c 1:"UEFISYS" /dev/sda
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT"  /dev/sda

    lsblk
    sleep 10
}

ext4_makefs() {
	clear
	echo "Makeing and Mounting EXT4 partition"
	mkfs.ext4 /dev/sda2
	mkfs.fat -F32 /dev/sda1
	mount /dev/sda2 /mnt
	mkdir -p /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi
	lsblk
	sleep 10
	if [[ -b /dev/sdb1 ]]; then
		echo "Home partition Already exist"
		mkdir -p /mnt/home
		mount /dev/sdb1 /mnt/home
	elif [[ -b /dev/sdb ]]; then
		clear
		echo "Creating home partition"
		sgdisk -Z /dev/sdb
		sgdisk -n 1:0:0 -t 1:8300 -c 1:"HOME" /dev/sdb
		mkdir /mnt/home
		mkfs.ext4 /dev/sdb1
		mount /dev/sdb1 /mnt/home
	else
		echo "Home disk not found"
	fi
	lsblk
	sleep 20
}

btrfs_makefs() {
	clear
	echo "Makeing and Mounting BTRFS partition"
	mkfs.fat -F32 /dev/sda1
	mkfs.btrfs -L ROOT -f /dev/sda2
	mount /dev/sda2 /mnt
	mkdir -p /mnt/boot/
	btrfs sub create /mnt/@
	btrfs sub create /mnt/@home
	btrfs sub create /mnt/@var
	btrfs sub create /mnt/@.snapshots
	umount /mnt
	sleep 5
	
	mount -o noatime,commit=120,compress=zstd,space_cache,subvol=@ /dev/sda2 /mnt
	# You need to manually create folder to mount the other subvolumes at
	mkdir /mnt/{boot,home,var,.snapshots}
	mount -o noatime,commit=120,compress=zstd,space_cache,subvol=@home /dev/sda2 /mnt/home
	mount -o noatime,commit=120,compress=zstd,space_cache,subvol=@.snapshots /dev/sda2 /mnt/.snapshots
	mount -o subvol=@var /dev/sda2 /mnt/var
	# Mounting the boot partition at /boot folder
	mount /dev/sda1 /mnt/boot
	lsblk
	sleep 20
}

chroot_ex() {
	clear
	genfstab -U /mnt > /mnt/etc/fstab ;
	cat /mnt/etc/fstab ;
	printf "\n\n\n\n\n"
	cp -vf /etc/pacman.conf /mnt/etc/pacman.conf
	sleep 20
	cat <<EOF | arch-chroot /mnt bash
clear
#!/bin/bash
printf "\e[1;32m\n*********CHROOT Scripts Started**********\n\e[0m"
etc-configs() {
	echo "editing config files"
	ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
	timedatectl set-ntp true
	hwclock --systohc
	echo "archbtw" >> /etc/hostname
	echo "127.0.0.1 localhost" >> /etc/hosts
	echo "::1       localhost" >> /etc/hosts
	echo "127.0.1.1 archbtw.localdomain archbtw" >> /etc/hosts
	echo "LANG=en_US.UTF-8" >> /etc/locale.conf
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	echo "en_US ISO-8859-1" >> /etc/locale.gen
	locale-gen
	sleep 10
}

starting-service() {
	clear
	echo "Enableing Services "
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
	systemctl enable libvirtd
	systemctl enable gdm
	sleep 10
}

config-users() {
	printf "\e[1;32m\n********createing user vijay*********\n\e[0m"
	useradd -G wheel,audio,video -m vijay
	echo root:vijay | chpasswd
	echo vijay:vijay | chpasswd
	newgrp libvirt
	usermod -aG libvirt vijay
	echo "vijay ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vijay
	printf "\e[1;32m\n********createing user Successfully Done*********\n\e[0m"
	sed -i 's/^#Para/Para/' /etc/pacman.conf
	sleep 10
}


etc-configs
config-users
starting-service
sleep 10
printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
EOF
}

grub_ext4() {
	cat <<EOF | arch-chroot /mnt bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB  && grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

systemd_btrfs() {
    clear

    arch-chroot /mnt /usr/bin/bootctl --path=/boot install
    cat <<EOF > /mnt/boot/loader/loader.conf
default      arch.conf
timeout      5
editor       no
console-mode auto
EOF
    cat /mnt/boot/loader/loader.conf

    cat <<EOF > /mnt/boot/loader/entries/arch.conf
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  root=/dev/sda2 rootfstype=btrfs rootflags=subvol=@ elevator=deadline add_efi_memmap rw quiet splash loglevel=3 vt.global_cursor_default=0 plymouth.ignore_serial_consoles vga=current rd.systemd.show_status=auto r.udev.log_priority=3 nowatchdog fbcon=nodefer i915.fastboot=1 i915.invert_brightness=1
EOF
    cat /mnt/boot/loader/entries/arch.conf

    mkdir /mnt/etc/pacman.d/hooks/
    touch /mnt/etc/pacman.d/hooks/100-systemd-boot.hook

    cat <<EOF > /mnt/etc/pacman.d/hooks/100-systemd-boot.hook
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF
    cat /mnt/etc/pacman.d/hooks/100-systemd-boot.hook

}

de_type() {
	if [[ $DE == GNOME ]] || [[ $DE == 1 ]] || [[ $DE == gnome ]]; then
		printf "\e[1;34m Selected Gnome \n\e[0m"
		pacstrap /mnt base base-devel gnome vijay-gnome vijay-dotfiles vijay-wallpapers
	elif [[ $DE == dwm ]] || [[ $DE == 2 ]] || [[ $DE == dwm ]]; then
		printf "\e[1;34m Selected dwm \n\e[0m"
		pacstrap /mnt base base-devel vijay-full-dwm vijay-dotfiles vijay-wallpapers
	elif [[ $DE == i3 ]] || [[ $DE == 3 ]] || [[ $DE == i3wm ]]; then
		printf "\e[1;34m Selected i3wm \n\e[0m"
		pacstrap /mnt base base-devel i3 vijay-i3 vijay-dotfiles vijay-wallpapers
	elif [[ $DE == basic ]] || [[ $DE == 4 ]]; then
		printf "\e[1;34m Selected Base Install \n\e[0m"
		pacstrap /mnt base vijay-base base-devel vijay-dotfiles
		printf "\e[1;34m Basic installation completed \e[0m"
	else
		printf "\e[1;34m Invalid option \e[0m"
		exit
	fi
}

de_choose() {
  DIALOG_CANCEL=1
  DIALOG_ESC=255
  HEIGHT=0
  WIDTH=0
  exec 3>&1
  DE=$(dialog \
    --backtitle "Arch Installation" \
    --title "Select Desktop type" \
    --cancel-label "Exit" \
    --menu "Please select:" $HEIGHT $WIDTH 4 \
    "1" "Gnome" \
    "2" "Dwm" \
    "3" "i3wm" \
    "4" "basic" \
    2>&1 1>&3)
    exit_status=$?
  exec 3>&-
    case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Program terminated."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac
  case $DE in
	  1 )
		  ;;
	  2 )
		  ;;
	  3 )
		  ;;
  esac

}

filesystem_type() {
    if [[ $FS == EXT4 ]] || [[ $FS == 1 ]] || [[ $FS == ext4 ]]; then
	    printf "\e[1;34m Selected EXT4 \n\e[0m"
	    ext4_makefs
    elif [[ $FS == BTRFS ]] || [[ $FS == 2 ]] || [[ $FS == btrfs ]]; then
	    printf "\e[1;34m Selected BTRFS \n\e[0m"
	    btrfs_makefs
    else
	    printf "\e[1;34m Invalid option \e[0m"
	    exit
    fi
}

filesystem_choose() {
  DIALOG_CANCEL=1
  DIALOG_ESC=255
  HEIGHT=0
  WIDTH=0
  exec 3>&1
  FS=$(dialog \
    --backtitle "Arch Installation" \
    --title "Select Filesystem type" \
    --cancel-label "Exit" \
    --menu "Please select:" $HEIGHT $WIDTH 4 \
    "1" "EXT4" \
    "2" "BTRFS" \
    2>&1 1>&3)
    exit_status=$?
  exec 3>&-
    case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Program terminated."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac
  case $FS in
	  1 )
		  ;;
	  2 )
		  ;;
	  3 )
		  ;;
  esac

}

postinstall() {
cat <<EOF > /mnt/home/vijay/temp.sh
echo "CLONING: YAY"
cd /home/vijay
git clone "https://aur.archlinux.org/yay.git"
cd /home/vijay/yay
makepkg -si --noconfirm
EOF

chmod +x /mnt/home/vijay/temp.sh
arch-chroot /mnt /usr/bin/runuser -u vijay -- /home/vijay/temp.sh
rm -v /mnt/home/vijay/temp.sh
}

main() {
  de_choose
  filesystem_choose
  create_partition
  filesystem_type
  de_type
  chroot_ex
  if [[ $FS == EXT4 ]] || [[ $FS == 1 ]] || [[ $FS == ext4 ]]; then
	  printf "\e[1;34m Selected EXT4 \n\e[0m"
	  grub_ext4
  elif [[ $FS == BTRFS ]] || [[ $FS == 2 ]] || [[ $FS == btrfs ]]; then
	  printf "\e[1;34m Selected BTRFS \n\e[0m"
	  systemd_btrfs
  else
	  printf "\e[1;34m Invalid option \e[0m"
	  exit
  fi
  printf "\e[1;35m\n\next4 Installation completed \n\e[0m"
}

printf "\e[1;32m*********Arch Script Started**********\n\e[0m"

echo "------------------------------------------------------------------------------"

echo "     _     ____    ____  _   _   ___  _   _  ____  _____   _     _      _      "
echo "    / \   |  _ \  / ___|| | | | |_ _|| \ | |/ ___||_   _| / \   | |    | |     "
echo "   / _ \  | |_) || |    | |_| |  | | |  \| |\___ \  | |  / _ \  | |    | |     "
echo "  / ___ \ |  _ < | |___ |  _  |  | | | |\  | ___) | | | / ___ \ | |___ | |___  "
echo " /_/   \_\|_| \_\ \____||_| |_| |___||_| \_||____/  |_|/_/   \_\|_____||_____| "

echo "-------------------------------------------------------------------------------"

preinstall() {
	echo "-------------------------------------------------"
	echo "Setting up mirrors for optimal download          "
	echo "-------------------------------------------------"
	iso=$(curl -4 ifconfig.co/country-iso)
	timedatectl set-ntp true
	timedatectl set-timezone Asia/Kolkata
	cat  <<EOF >> /etc/pacman.conf
[vijay-repo]
SigLevel = DatabaseTrustedOnly
SigLevel = Optional DatabaseOptional
Server = https://gitlab.com/vijaysrv/vijay-repo/-/raw/main/x86_64
EOF
	pacman-key --recv-keys 93FD2B22ADBCAE64
	pacman-key --lsign-key 93FD2B22ADBCAE64
	pacman -Sy --noconfirm dialog pacman-contrib terminus-font reflector rsync
	setfont ter-v22b
	sed -i 's/^#Para/Para/' /etc/pacman.conf
	mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
}

preinstall
main
postinstall
