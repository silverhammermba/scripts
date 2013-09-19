#!/bin/bash
efibootmgr -c -d /dev/sda -p 1 -l /EFI/arch/vmlinuz-arch.efi -L "Arch Linux" -u 'root=UUID=a487a5aa-c376-4a43-bd8c-35692a8fb46b rw add_efi_memmap initrd=\EFI\arch\initramfs-arch.img elevator=noop acpi_osi="!Windows 2012"'
