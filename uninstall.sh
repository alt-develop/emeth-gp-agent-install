#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
DEFAULT_INSTALL_DIR='/opt/egp_agent'
storage_mount_path="${DEFAULT_INSTALL_DIR}/storage"

# Stop and disable the systemd service
sudo systemctl stop egp-agent
sudo systemctl disable egp-agent

# Remove the systemd service file
sudo rm -f /etc/systemd/system/egp-agent.service

# Remove the egp-agent binary
sudo rm -f /home/"$OS_USER_NAME"/egp-agent

# Remove the libvirt storage pool
sudo virsh pool-destroy egp-agent
sudo virsh pool-undefine egp-agent

# Unmount and remove the storage
sudo umount "$storage_mount_path"
sudo rm -f "${DEFAULT_INSTALL_DIR}/.storage.img"

# Remove the storage mount from /etc/fstab
sudo sed -i "\|${DEFAULT_INSTALL_DIR}/.storage.img|d" /etc/fstab

# Remove the user
sudo userdel -r "$OS_USER_NAME"

# Remove the GPU passthrough settings
sudo rm -f /etc/default/grub.d/egp-gpu-passthrough.cfg
sudo update-grub

echo 'Uninstall completed successfully.'
echo 'Please reboot the system to apply the changes.'
