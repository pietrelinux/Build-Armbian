#!/bin/sh

echo "Bienvenido a la instalación de Linux en la memoría interna"
sleep 2

hasdrives=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
if [ "$hasdrives" = "" ]
then
	echo "NO SE PUEDE ENCONTRAR NINGUNA UNIDAD EMMC O SD EN ESTE SISTEMA!!! "
	exit 1
fi
avail=$(lsblk | grep -oE '(mmcblk[0-9]|sda[0-9])' | sort | uniq)
if [ "$avail" = "" ]
then
	echo "NO SE PUEDE ENCONTRAR NINGUNA UNIDAD EN ESTE SISTEMA!!!"
	exit 1
fi
runfrom=$(lsblk | grep /$ | grep -oE '(mmcblk[0-9]|sda[0-9])')
if [ "$runfrom" = "" ]
then
	echo "NO SE PUEDE ENCONTRAR LA RAÍZ DEL SISTEMA EN EJECUCIÓN!!! "
	exit 1
fi
emmc=$(echo $avail | sed "s/$runfrom//" | sed "s/sd[a-z][0-9]//g" | sed "s/ //g")
if [ "$emmc" = "" ]
then
	echo " NO SE PUEDE ENCONTRAR SU UNIDAD EMMC O EL SISTEMA YA FUNCIONA DESDE EMMC!!!"
	exit 1
fi
if [ "$runfrom" = "$avail" ]
then
	echo " USTED ESTÁ EJECTANDO EL SISTEMA DESDE EMMC!!! "
	exit 1
fi
if [ $runfrom = $emmc ]
then
	echo "USTED ESTÁ EJECTANDO EL SISTEMA DESDE EMMC!!! "
	exit 1
fi
if [ "$(echo $emmc | grep mmcblk)" = "" ]
then
	echo " NO APARECE TENER UN DISCO EMMC!!! "
	exit 1
fi

DEV_EMMC="/dev/$emmc"

echo $DEV_EMMC

echo "Iniciar copia de seguridad de u-boot por defecto"

dd if="${DEV_EMMC}" of=/boot/u-boot-default-aml.img bs=1M count=4

echo "Iniciar creación de MBR y particiones"

parted -s "${DEV_EMMC}" mklabel msdos
parted -s "${DEV_EMMC}" mkpart primary fat32 700M 828M
parted -s "${DEV_EMMC}" mkpart primary ext4 829M 100%

echo "Iniciando instalación de u-boot"

dd if=/boot/u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=1 count=442
dd if=/boot/u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=512 skip=1 seek=1

sync

echo "Echo"

echo "Iniciar copia del sistema en memoria eMMC."

mkdir -p /ddbr
chmod 777 /ddbr

PART_BOOT="${DEV_EMMC}p1"
PART_ROOT="${DEV_EMMC}p2"
DIR_INSTALL="/ddbr/install"

if [ -d $DIR_INSTALL ] ; then
    rm -rf $DIR_INSTALL
fi
mkdir -p $DIR_INSTALL

if grep -q $PART_BOOT /proc/mounts ; then
    echo "Desmontando partición BOOT."
    umount -f $PART_BOOT
fi
echo -n "Formateando partición BOOT..."
mkfs.vfat -n "BOOT_EMMC" $PART_BOOT
echo "echo."

mount -o rw $PART_BOOT $DIR_INSTALL

echo -n "Copiando BOOT..."
cp -r /boot/* $DIR_INSTALL && sync
echo "done."

echo -n "Editando configuración de init..."
sed -e "s/ROOTFS/ROOT_EMMC/g" \
 -i "$DIR_INSTALL/uEnv.ini"
echo "done."

rm $DIR_INSTALL/s9*
rm $DIR_INSTALL/aml*
rm $DIR_INSTALL/boot.ini

umount $DIR_INSTALL

if grep -q $PART_ROOT /proc/mounts ; then
    echo "Desmontando partición ROOT."
    umount -f $PART_ROOT
fi

echo "Formateando partición ROOT..."
mke2fs -F -q -t ext4 -L ROOT_EMMC -m 0 $PART_ROOT
e2fsck -n $PART_ROOT
echo "done."

echo "Copiando sistema de archivos raíz."

mount -o rw $PART_ROOT $DIR_INSTALL

cd /
echo "Copiando BIN"
tar -cf - bin | (cd $DIR_INSTALL; tar -xpf -)
#echo "Copy BOOT"
#mkdir -p $DIR_INSTALL/boot
#tar -cf - boot | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando DEV"
mkdir -p $DIR_INSTALL/dev
#tar -cf - dev | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando ETC"
tar -cf - etc | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando HOME"
tar -cf - home | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando LIB"
tar -cf - lib | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando MEDIA"
mkdir -p $DIR_INSTALL/media
#tar -cf - media | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando MNT"
mkdir -p $DIR_INSTALL/mnt
#tar -cf - mnt | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando OPT"
tar -cf - opt | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando PROC"
mkdir -p $DIR_INSTALL/proc
echo "Copiando ROOT"
tar -cf - root | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando RUN"
mkdir -p $DIR_INSTALL/run
echo "Copiando SBIN"
tar -cf - sbin | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando SELINUX"
tar -cf - selinux | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando SRV"
tar -cf - srv | (cd $DIR_INSTALL; tar -xpf -)
echo "Creando SYS"
mkdir -p $DIR_INSTALL/sys
echo "Creando TMP"
mkdir -p $DIR_INSTALL/tmp
echo "Copiando USR"
tar -cf - usr | (cd $DIR_INSTALL; tar -xpf -)
echo "Copiando VAR"
tar -cf - var | (cd $DIR_INSTALL; tar -xpf -)
sync

echo "Copiando fstab"

rm $DIR_INSTALL/etc/fstab
cp -a /root/fstab $DIR_INSTALL/etc/fstab

rm $DIR_INSTALL/root/install.sh
rm $DIR_INSTALL/root/fstab
rm $DIR_INSTALL/usr/bin/ddbr


cd /
sync

umount $DIR_INSTALL

echo "*******************************************************************"
echo 			"Instalación completada en la memoria eMMC "
echo "*******************************************************************"
echo "*************************************************************************************"
echo 			"Por favor, apague el sistema y extraiga el medio de instalación "
echo "*************************************************************************************"
