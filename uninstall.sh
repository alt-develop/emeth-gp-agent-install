#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
CONFIG="/home/${OS_USER_NAME}/egp-agent-config.yaml"
DEFAULT_INSTALL_DIR='/opt/egp_agent'
SERVICE_NAME="egp-agent"
STORAGE_IMG_PATH="${DEFAULT_INSTALL_DIR}/.storage.img"
STORAGE_MOUNT_PATH="${DEFAULT_INSTALL_DIR}/storage"
FSTAB_ENTRY="${STORAGE_IMG_PATH} ${STORAGE_MOUNT_PATH} xfs loop 0 0"
GRUB_CONFIG_FILE="/etc/default/grub.d/egp-gpu-passthrough.cfg"
SUDOERS_FILE="/etc/sudoers.d/${OS_USER_NAME}"

echo "Starting uninstallation of egp-agent..."

# Stop and disable the systemd service
echo "Stopping and disabling the systemd service..."
sudo systemctl stop ${SERVICE_NAME}
sudo systemctl disable ${SERVICE_NAME}
sudo rm -f /etc/systemd/system/${SERVICE_NAME}.service

# Remove the user and group
echo "Removing user and group..."
if id "${OS_USER_NAME}" >/dev/null 2>&1; then
    sudo userdel -r "${OS_USER_NAME}"
else
    echo "User ${OS_USER_NAME} does not exist. Skipping user deletion."
fi

# Unmount and remove the storage
echo "Unmounting and removing storage..."
if mountpoint -q "${STORAGE_MOUNT_PATH}"; then
    sudo umount "${STORAGE_MOUNT_PATH}"
fi

# Remove fstab entry
echo "Removing fstab entry..."
sudo sed -i "\#${FSTAB_ENTRY}#d" /etc/fstab

# Remove storage image and directory
echo "Deleting storage image and directory..."
sudo rm -rf "${STORAGE_IMG_PATH}"
sudo rm -rf "${STORAGE_MOUNT_PATH}"

# Remove installation directory
echo "Removing installation directory..."
sudo rm -rf "${DEFAULT_INSTALL_DIR}"

# Remove GRUB configuration and update GRUB
if [ -f "${GRUB_CONFIG_FILE}" ]; then
    echo "Removing GRUB configuration..."
    sudo rm -f "${GRUB_CONFIG_FILE}"
    sudo update-grub
fi

# Remove cron job
echo "Removing cron job..."
CRON_JOB="/home/${OS_USER_NAME}/update.sh"
if crontab -l 2>/dev/null | grep -F "${CRON_JOB}" >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "${CRON_JOB}" | crontab -
    echo "Cron job removed."
else
    echo "Cron job does not exist. Skipping."
fi

# Remove Vagrant plugins and configurations
echo "Removing Vagrant plugins and configurations..."
VAGRANT_HOME="${STORAGE_MOUNT_PATH}/.vagrant.d"
sudo rm -rf "${VAGRANT_HOME}"

# Remove libvirt storage pool
echo "Removing libvirt storage pool..."
if sudo virsh pool-list --all | grep -q 'egp-agent'; then
    sudo virsh pool-destroy egp-agent
    sudo virsh pool-undefine egp-agent
else
    echo "Libvirt storage pool 'egp-agent' does not exist. Skipping."
fi

# Remove configuration file
echo "Removing configuration file..."
sudo rm -f "${CONFIG}"

echo "Uninstallation completed successfully."

# Remove sudoers file
echo "Removing sudoers file..."
if [ -f "${SUDOERS_FILE}" ]; then
    sudo rm -f "${SUDOERS_FILE}"
fi

# Prompt for reboot
echo "Some changes may require a reboot to take effect."
printf 'Do you want to reboot now? (y/n) [n]: '
read reboot
reboot=${reboot:-'n'}
if [ "$reboot" = "y" ]; then
    sudo reboot
fi
