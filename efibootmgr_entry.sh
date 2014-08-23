#!/bin/bash
efibootmgr -c -d /dev/sda -p 1 -l /vmlinuz-linux -L "Arch Linux" -u 'root=UUID=a487a5aa-c376-4a43-bd8c-35692a8fb46b rw initrd=/initramfs-linux.img acpi_osi="!Windows 2012"'
