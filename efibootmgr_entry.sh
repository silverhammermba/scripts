#!/bin/bash
# create new Arch Linux UEFI boot entry

LABEL="Arch Linux"
ENTRY="$(efibootmgr | grep "$LABEL" | cut --characters=5-8)"

if [ -n "$ENTRY" ]; then
	echo >&2 "Deleting old entry..."

	efibootmgr \
		--bootnum "$ENTRY" \
		--delete-bootnum \
		> /dev/null
fi

echo >&2 "Creating new entry..."

efibootmgr \
	--create \
	--disk /dev/sda \
	--part 1 \
	--loader /vmlinuz-linux \
	--label "$LABEL" \
	--unicode 'root=UUID=a487a5aa-c376-4a43-bd8c-35692a8fb46b rw initrd=/intel-ucode.img initrd=/initramfs-linux.img acpi_osi="!Windows 2012"' \
	> /dev/null

efibootmgr -v | grep "$LABEL"
