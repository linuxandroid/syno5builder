#!/bin/sh

# build modules
echo -e "\033[41;37m Building modules ... \033[0m"
cd kernel
if [ ! -f .config ]; then
	make syno5_sim_defconfig
fi
make modules -j8
cd ..

# cp *.ko
echo -e "\033[41;37m Coping the ko ... \033[0m"
mv rmdisk/lib/modules/synobios.ko synobios.ko
rm -rf rmdisk/lib/modules/*
mv synobios.ko rmdisk/lib/modules/.
find kernel/ -iname "*.ko" -type f -exec cp -p {} rmdisk/lib/modules/ \;

# build bzImage
echo -e "\033[41;37m Building bzImage ... \033[0m"
cd kernel
make bzImage -j8
cd ..

# build img with grub boot
echo -e "\033[41;37m Building the USB Image with grub ... \033[0m"
cp __s54493pre_usb.img ./out/S54493_grub.img
sudo mount -o loop,offset=32256 ./out/S54493_grub.img /mnt/img
sudo cp kernel/arch/x86_64/boot/bzImage /mnt/img/zImage
sudo umount /mnt/img

# build iso with grub boot
echo -e "\033[41;37m Build the ISO with grub ... \033[0m"
cp kernel/arch/x86_64/boot/bzImage __s54493pre_iso_grub/zImage
mkisofs -R -J -input-charset UTF-8 -no-emul-boot -boot-load-size 4 -hide-joliet boot.catalog -boot-info-table -b grldr -hide-joliet grldr -o ./out/S54493_grub.iso __s54493pre_iso_grub/  

#build ios with syslinux boot
echo -e "\033[41;37m Building the ISO with syslinux ... \033[0m"
cp kernel/arch/x86_64/boot/bzImage __s54493pre_iso_syslinux/zImage
mkisofs -R -J -input-charset UTF-8 -no-emul-boot -boot-load-size 4 -hide-joliet boot.catalog -boot-info-table -b bootsec -hide-joliet bootsec -o ./out/S54493_syslinux.iso __s54493pre_iso_syslinux/

# finished
echo -e "\033[41;37m Everything is ok, burn the img file to you USB storage. \033[0m"
