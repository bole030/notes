#!/usr/bin/env bash

#cfdisk

lsblk

echo "enter diskname"
read DISKNAME

echo "enter efi partition index"
read EFIINDEX
EFI="/dev/${DISKNAME}p${EFIINDEX}"
echo $EFI

echo "enter swap partition index"
read SWAPINDEX
SWAP="/dev/${DISKNAME}p${SWAPINDEX}"
echo $SWAP

echo "enter root partition index"
read ROOTINDEX
ROOT="/dev/${DISKNAME}p${ROOTINDEX}"
echo $ROOT

echo "Please enter your hostname"
read HOSTNAME

echo "Please enter your root password"
read ROOTPASSWORD

echo "Please enter your username"
read USERNAME

echo "Please enter your password"
read PASSWORD

echo -e "\n create and mount partitions \n"

mkfs.fat -F32 "${EFI}"
mkfs.ext4 "${ROOT}"
mkswap "${SWAP}"

# mount target
mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount "${EFI}" /mnt/boot/
swapon "${SWAP}"

echo "installing arch base"
pacstrap /mnt base base-devel --noconfirm --needed

echo "installing linux"
pacstrap /mnt linux linux-firmware --noconfirm --needed

echo "installing basic tools"
pacstrap /mnt zsh networkmanager vim sof-firmware --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
echo "Please enter your root password"
echo root:$ROOTPASSWORD | chpasswd
useradd -m $USERNAME
usermod -aG wheel,storage,power,audio $USERNAME
echo bole:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^#%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo "set language and set locale"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

echo "set time"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

echo "${HOSTNAME}" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	${HOSTNAME}.localdomain	${HOSTNAME}
EOF

echo "-- installing bootloader  --"
pacman -S grub efibootmgr dosfstools mtools

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

echo "auth       optional     pam_gnome_keyring.so" >> /etc/pam.d/login
echo "session    optional     pam_gnome_keyring.so auto_start" >> /etc/pam.d/login

su $USERNAME

echo "installing compressing stuff"
sudo pacman -S zip unzip --noconfirm --needed

echo "installing time sync"
sudo pacman -S ntp --noconfirm --needed

echo "installing bluetooth stuff"
sudo pacman -S bluez bluez-utils blueman --noconfirm --needed
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service
sudo sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sudo sed -i 's/^# AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sudo sed -i 's/^#AutoEnable = true/AutoEnable=true/' /etc/bluetooth/main.conf
sudo sed -i 's/^# AutoEnable = true/AutoEnable=true/' /etc/bluetooth/main.conf
sudo sed -i 's/^#FastConnectable = false/FastConnectable = false/' /etc/bluetooth/main.conf
sudo sed -i 's/^# FastConnectable = false/FastConnectable = false/' /etc/bluetooth/main.conf

echo "installing remote stuff (ssh, ufw, rsync, git)"
sudo pacman -S openssl openssh ufw rsync git --noconfirm --needed
sudo systemctl enable sshd
sudo systemctl start sshd
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22
sudo ufw enable

echo "installing display stuff"
sudo pacman -S xorg feh figlet --noconfirm --needed

echo "installing audio stuff"
sudo pacman -S pulseaudio --noconfirm --needed

echo "installing browsers"
sudo pacman -S firefox chromium

echo "installing discord"
sudo pacman -S discord

echo "installing xdotool and xclip"
sudo pacman -S xdotool xclip

echo "installing manuals"
sudo pacman -S man-db

echo "installing vnc"
sudo pacman -S tigervnc

echo "installing gnome-kering-daemon"
sudo pacman -S gnome-keyring

echo "installing nvm for node"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

echo "installing python"
sudo pacman -S python

sudo pacman -S nvidia picom fuse3 os-prober
sudo sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=20/' /etc/default/grub
sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo sed -i 's/^# GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

REALEND

arch-chroot /mnt sh next.sh

umount -lR /mnt
