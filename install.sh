#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
CONFIG="/home/${OS_USER_NAME}/egp-agent-config.yaml"
MINIMUM_REQUIRED_STORAGE_GB=500
METADATA_STORAGE_GB=200
DEFAULT_INSTALL_DIR='/opt/egp_agent'


# Check if the required packages are installed
if ! kvm --version >/dev/null 2>&1; then
    echo 'This program requires kvm to be installed.'
    missing_pkg=true
fi
if ! qemu-img --version >/dev/null 2>&1; then
    echo 'This program requires qemu-img to be installed.'
    missing_pkg=true
fi
if ! virsh --version >/dev/null 2>&1; then
    echo 'This program requires virsh to be installed.'
    missing_pkg=true
fi
if ! fio --version  >/dev/null 2>&1; then
    echo 'This program requires fio to be installed.'
    missing_pkg=true
fi
if ! guestfish --version  >/dev/null 2>&1; then
    echo 'This program requires libguestfs-tools to be installed.'
    missing_pkg=true
fi
if ! bc --version  >/dev/null 2>&1; then
    echo 'This program requires bc to be installed.'
    missing_pkg=true
fi


if [ "$missing_pkg" = true ]; then
    echo 'Missing packages detected.'
    echo 'You can install the required packages by running the following commands:'
    echo '--------------------------------------------'
    echo 'sudo apt-get update \'
    echo '&& sudo apt-get upgrade -y \'
    echo '&& sudo apt-get install -y qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients libvirt-dev libguestfs-tools bridge-utils virt-manager ovmf fio curl bc'
    exit 1
fi

if ! vagrant --version >/dev/null 2>&1; then
    echo 'This program requires vagrant to be installed.'
    missing_pkg=true
fi

if [ "$missing_pkg" = true ]; then
    echo 'Missing packages detected.'
    echo 'To continue, please install Vagrant by following the instructions at:'
    echo '--------------------------------------------'
    echo 'https://developer.hashicorp.com/vagrant/install'
    echo 'After installation, please re-run this script.'
    exit 1
fi

# Request the API key
echo -e '\e[32m

H   H  EEEEE L     L      OOO      U   U  SSSS EEEEE RRRR  
H   H  E     L     L     O   O     U   U S     E     R   R 
HHHHH  EEEE  L     L     O   O     U   U  SSS  EEEE  RRRR  
H   H  E     L     L     O   O     U   U     S E     R  R  
H   H  EEEEE LLLLL LLLLL  OOO       UUU  SSSS  EEEEE R   R 

\e[0m'
echo 'Please enter the your API key for the EMETH GPU POOL.'
echo '--------------------------------------------'
read -p 'API Key: ' api_key
if [ -z "$api_key" ]; then
    echo 'API key is required.'
    exit 1
fi
echo ''
echo ''

# Get the resource allocation amounts desired by the user
## Get the machine specs
sudo update-pciids
gpu_devices=$(lspci -nn | grep 'NVIDIA' | grep '3D controller\|VGA compatible controller')
cpu_model_name=$(grep 'model name' /proc/cpuinfo | head -1 | awk -F': ' '{print $2}')
vcpu_total=$(grep -c ^processor /proc/cpuinfo)
memory_total=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')

echo 'Please enter the storage path to be used by egp-agent.'
echo 'Will be used to store the VM disk images.'
echo 'Make sure to input a path on a device with at least 200GB of free space.'
echo '--------------------------------------------'
read -p "Install directory [$DEFAULT_INSTALL_DIR]: " install_dir
install_dir=${install_dir:-"$DEFAULT_INSTALL_DIR"}
echo "$install_dir"
if [ ! -d "$install_dir" ]; then
    sudo mkdir -p "$install_dir"
fi
storage_avail_byte=$(df --output=avail "$install_dir" | tail -n +2)
storage_avail_gb=$(($storage_avail_byte/1024/1024))
if [ "$storage_avail_gb" -lt "$MINIMUM_REQUIRED_STORAGE_GB" ]; then
    echo "The storage path does not have enough space. Please input a path with at least ${MINIMUM_REQUIRED_STORAGE_GB}GB of free space."
    exit 1
fi

echo ''
echo ''
echo '[Your Machine Specs]'
echo '--------------------------------------------'
echo "vCPU: $vcpu_total"
echo "Memory(GB): $memory_total"
echo "Storage(GB): $storage_avail_gb [${install_dir}]"
echo "GPU Devices:"
echo "$gpu_devices"
echo ''
echo ''

## Get the user input for the resource allocation
### GPU
if [ ! -z "$gpu_devices" ]; then
    echo 'Please enter the agreement to enable GPU passthrough.'
    echo -e "\e[33mWARNING:
Please be aware that if you proceed, this program will modify the grub settings to enable GPU Passthrough. 
As a result of these changes, you will not be able to directly access the GPU from the Host OS.\e[0m"
    echo '--------------------------------------------'
    read -p 'Do you want to proceed with the GPU passthrough? (y/n) [y]: ' gpu_passthrough_agreement
    echo "$gpu_passthrough_agreement"
    gpu_passthrough_agreement=${gpu_passthrough_agreement:-'y'}
    if [ "$gpu_passthrough_agreement" = "y" ]; then
        gpu_model_name=$(echo "$gpu_devices" | awk -F'[' '{print $3}' | awk -F']' '{print $1}' | head -1)
        gpu_pci_ids=$(echo "$gpu_devices" | awk -F']:' '{print $2}' | awk -F'[' '{print $3}' | awk -F']' '{print $1}' | uniq | sed 's/ /,/g')
        gpu_pci_addresses=$(echo "$gpu_devices" | awk -F' ' '{print $1}')
    else
        echo 'GPU passthrough canceled.'
    fi
    echo ''
    echo ''
fi

### CPU
vcpu_limit_max=$((vcpu_total-2))
read -p "Enter the number of vCPU to allocate (1-${vcpu_limit_max}) [${vcpu_limit_max}]: " vcpu_limit
vcpu_limit=${vcpu_limit:-"$vcpu_limit_max"}
if [ "$vcpu_limit" -lt 1 ] || [ "$vcpu_limit" -gt "$vcpu_limit_max" ]; then
    echo "Invalid vCPU limit. Please enter a value between 1 and $vcpu_limit_max."
    exit 1
fi

### Memory
memory_limit_max=$((memory_total-(memory_total/10)))
read -p "Enter the amount of memory to allocate in GB (1-${memory_limit_max}) [${memory_limit_max}]: " memory_limit
memory_limit=${memory_limit:-"$memory_limit_max"}
if [ "$memory_limit" -lt 1 ] || [ "$memory_limit" -gt "$memory_limit_max" ]; then
    echo "Invalid memory limit. Please enter a value up to $memory_limit_max GB."
    exit 1
fi

### Storage
storage_allocate_max_gb="$storage_avail_gb"
read -p "Enter the amount of storage to allocate in GB ${MINIMUM_REQUIRED_STORAGE_GB}-${storage_allocate_max_gb}) [$((storage_allocate_max_gb))]: " storage_allocate_gb
storage_allocate_gb=${storage_allocate_gb:-"$((storage_allocate_max_gb))"}
if [ "$storage_allocate_gb" -lt "$MINIMUM_REQUIRED_STORAGE_GB" ] || [ "$storage_allocate_gb" -gt "$storage_allocate_max_gb" ]; then
    echo "Invalid storage limit. Please enter a value between $MINIMUM_REQUIRED_STORAGE_GB and $storage_allocate_max_gb GB."
    exit 1
fi
storage_limit_gb=$(echo "$storage_allocate_gb * 0.99 - $METADATA_STORAGE_GB" | bc)

### Network
global_ip=$(curl -s ifconfig.me)

## Display the resource allocation
echo ''
echo ''
echo '[Resource Allocation]'
echo "CPU Name: $cpu_model_name"
echo "vCPU: $vcpu_limit"
echo "Memory(GB): $memory_limit"
echo "Storage(GB): $storage_allocate_gb"
if [ "$gpu_passthrough_agreement" = 'y' ]; then
    echo "GPU Devices:"
    echo "$gpu_devices"
fi
echo '--------------------------------------------'
echo ''
read -p "Do you want to proceed with the resource allocation? (y/n) [y]: " proceed
echo ''

proceed=${proceed:-"y"}
if [ "$proceed" != "y" ]; then
    echo "Resource allocation canceled."
    exit 1
fi


# Allocate the resources
## User setup
echo "Creating user ${OS_USER_NAME} ..."
sudo useradd -m "$OS_USER_NAME"
sudo usermod -aG libvirt "$OS_USER_NAME"
echo "${OS_USER_NAME} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$OS_USER_NAME"

## Setup the configuration file
config_overwrite='y'
echo 'Setting up the configuration file...'
if [ -f "$CONFIG" ]; then
    echo 'Configuration file already exists.'
    read -p 'Do you want to overwrite the configuration file? (y/n) [y]: ' config_overwrite
fi
if [ ! "$config_overwrite" = 'n' ]; then
    echo '# egp-agent configurations' | sudo tee "$CONFIG"
    echo '' | sudo tee -a "$CONFIG"
    echo "api_key: ${api_key}" | sudo tee -a "$CONFIG"
    echo "hostname: $(hostname)" | sudo tee -a "$CONFIG"
    echo "global_ip: ${global_ip}" | sudo tee -a "$CONFIG"
    echo "cpu_model_name: ${cpu_model_name}" | sudo tee -a "$CONFIG"
    echo "vcpu_limit: ${vcpu_limit}" | sudo tee -a "$CONFIG"
    echo "memory_limit: ${memory_limit}" | sudo tee -a "$CONFIG"
    echo "storage_path: ${install_dir}/storage" | sudo tee -a "$CONFIG"
    echo "storage_limit_gb: ${storage_limit_gb}" | sudo tee -a "$CONFIG"
    echo "gpu_model_name: ${gpu_model_name}" | sudo tee -a "$CONFIG"
    echo "gpu_pci_adresses:" | sudo tee -a "$CONFIG"
    if [ "$gpu_passthrough_agreement" = 'y' ]; then
        for gpu_pci_address in ${gpu_pci_addresses}
        do
            echo "  - '${gpu_pci_address}'" | sudo tee -a "$CONFIG"
        done
    fi
fi

## Storage
### setup file system
storage_img_path="${install_dir}/.storage.img"
storage_mount_path="${install_dir}/storage"
echo 'Allocating storage...'
if [ -f "$storage_img_path" ]; then
    echo 'Storage image already exists. Skipping storage allocation.'
else
    sudo qemu-img create -f raw "${storage_img_path}" "${storage_allocate_gb}G"
    sudo mkfs.xfs "$storage_img_path"
    sudo mkdir -p "$storage_mount_path"
    sudo mount -o loop "$storage_img_path" "$storage_mount_path"
fi

fstab_entry="${storage_img_path} ${storage_mount_path} xfs loop 0 0"
if ! grep -Fq "$fstab_entry" /etc/fstab; then
    echo "$fstab_entry" | sudo tee -a /etc/fstab
else
    echo 'Storage mount already exists in /etc/fstab.'
fi


### setup libvirt storage pool
if sudo virsh pool-list --all | grep -q 'egp-agent'; then
    echo 'Storage pool already exists. Skipping storage pool setup.'
else
    sudo virsh pool-define-as --name egp-agent --type dir --target "$storage_mount_path"
    sudo virsh pool-autostart egp-agent
    sudo virsh pool-start egp-agent
fi

### setup vagrant storage
echo "export VAGRANT_HOME=${storage_mount_path}/.vagrant.d" | sudo tee /home/"$OS_USER_NAME"/.profile

## GPU Passthrough
if [ "$gpu_passthrough_agreement" = 'y' ]; then
    echo 'Setting up GPU passthrough...'
    echo "GRUB_CMDLINE_LINUX=\"noresume nomodeset intel_iommu=on iommu=pt vfio-pci.ids=${gpu_pci_ids} module_blacklist=nvidia\"" | sudo tee /etc/default/grub.d/egp-gpu-passthrough.cfg
    sudo update-grub
fi


# install binary
echo 'Installing egp-agent binary...'
sudo curl -o /home/"$OS_USER_NAME"/egp-agent https://raw.githubusercontent.com/alt-develop/egp-agent/main/egp-agent && sudo chmod 700 /home/"$OS_USER_NAME"/egp-agent
if ! sudo /home/"$OS_USER_NAME"/egp-agent --version; then
    echo 'Failed to install egp-agent binary.'
    exit 1
else
    echo 'egp-agent binary installed successfully.'
fi

# setup cronjob update for egp-agent
echo 'download update.sh file...'
sudo curl -o /home/"$OS_USER_NAME"/update.sh https://raw.githubusercontent.com/alt-develop/egp-agent/main/update.sh
RANDOM=$(od -An -N2 -i /dev/urandom | tr -d ' ')
UPDATE_SCRIPT="/home/$OS_USER_NAME/update.sh"
# Ensure the update script is executable
sudo chmod +x $UPDATE_SCRIPT
# Set a random time for the cron job
if ! $(crontab -l | grep "$UPDATE_SCRIPT" > /dev/null); then
    RANDOM_MINUTE=$(($RANDOM % 60))
    RANDOM_HOUR=$(($RANDOM % 24))

    # Add the cron job
    (crontab -l ; echo "$RANDOM_MINUTE $RANDOM_HOUR * * * $UPDATE_SCRIPT") | crontab -
    echo 'Cron job setup successfully.'
    crontab -l
else
    echo 'Cron job already exists. Skipping cron job setup.'
fi

# Permission setup
sudo mkdir -p /home/"$OS_USER_NAME"/.ssh
sudo chmod 700 /home/"$OS_USER_NAME"/.ssh
sudo chown -R "$OS_USER_NAME":"$OS_USER_NAME" /home/"$OS_USER_NAME"
sudo chown -R "$OS_USER_NAME":"$OS_USER_NAME" "$install_dir"


# vagrant plugin setup
echo 'Setting up vagrant plugin...'
if sudo -iu "$OS_USER_NAME" vagrant plugin list | grep vagrant-libvirt; then
    echo 'vagrant-libvirt plugin already installed. skipping plugin installation.'
else
    sudo -iu "$OS_USER_NAME" vagrant plugin install vagrant-libvirt
    if ! sudo -iu "$OS_USER_NAME" vagrant plugin list | grep vagrant-libvirt; then
        echo 'Failed to install vagrant-libvirt plugin.'
        exit 1
    else
        echo 'vagrant-libvirt plugin installed successfully.'
    fi
fi


# systemd service setup
echo "[Unit]
Description=egp-agent
After=network.target



[Service]
Environment='VAGRANT_HOME=${storage_mount_path}/.vagrant.d'
Environment='VAGRANT_LOG=warn'
Type=simple
User=${OS_USER_NAME}
Group=${OS_USER_NAME}
ExecStart=/home/${OS_USER_NAME}/egp-agent --config ${CONFIG}
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/egp-agent.service

sudo systemctl enable egp-agent


# Reboot
echo 'Install completed successfully.'
echo 'Please reboot the system to apply the changes.'
read -p 'Do you want to reboot now? (y/n) [y]: ' reboot
if [ "$reboot" != "n" ]; then
    sudo reboot
fi
