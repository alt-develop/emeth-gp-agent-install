#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
COMMAND_UPDATE_SCRIPT="/home/$OS_USER_NAME/update.sh"
KEY_JOB_UPDATE="JOB_UPDATE"
KEY_CRON_CREATE_JOB_UPDATE="CREATE_JOB_UPDATE"

RANDOM_HOUR=$(shuf -i 0-23 -n 1)
RANDOM_MINUTE=$(shuf -i 1-59 -n 1)
TOMORROW=$(date -d "tomorrow" +%d)
MONTH=$(date +%m)
YEAR=$(date +%Y)
CRON_SCHEDULE="$RANDOM_MINUTE $RANDOM_HOUR $TOMORROW $MONTH *"
CRON_JOB="$CRON_SCHEDULE $COMMAND_UPDATE_SCRIPT $KEY_JOB_UPDATE"

crontab -l 2>/dev/null | grep -F "$KEY_JOB_UPDATE" > /dev/null
if [ $? -eq 0 ]; then
    echo "Cron #JOB_UPDATE already exists, will be overwritten."
    (crontab -l 2>/dev/null | grep -v "$KEY_JOB_UPDATE") | crontab -
else
    echo "Cron #JOB_UPDATE does not exist yet, will be created."
fi

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job has been updated to run at $RANDOM_HOUR:$RANDOM_MINUTE at $TOMORROW/$MONTH/$YEAR"

crontab -l 2>/dev/null | grep -F "$KEY_CRON_CREATE_JOB_UPDATE" > /dev/null
if [ $? -eq 0 ]; then
    # Xóa cron job
    (crontab -l 2>/dev/null | grep -v "$KEY_CRON_CREATE_JOB_UPDATE") | crontab -
fi
# Check command line parameters
# if [ "$1" != "$KEY_JOB_UPDATE" ]; then
#     echo "Exiting because parameter does not match $KEY_JOB_UPDATE"
#     exit 0
# fi

# get version new of egp-agent
echo 'download new version of egp-agent'
sudo curl -o /home/"$OS_USER_NAME"/egp-agent-new https://raw.githubusercontent.com/alt-develop/egp-agent/main/egp-agent && sudo chmod 700 /home/"$OS_USER_NAME"/egp-agent-new

# Paths to the old and new binary files
BINARY_PATH_OLD="/home/$OS_USER_NAME/egp-agent"
BINARY_PATH_NEW="/home/$OS_USER_NAME/egp-agent-new"

# Check the old binary version
if [ -f "$BINARY_PATH_OLD" ]; then
  OLD_VERSION=$(sudo "$BINARY_PATH_OLD" --version 2>/dev/null)
  if [ -z "$OLD_VERSION" ]; then
    echo "Failed to get version of the old binary."
    exit 1
  else
    echo "Old version: $OLD_VERSION"
  fi
else
  echo "Old binary not found."
  exit 1
fi

# Check the new binary version
if [ -f "$BINARY_PATH_NEW" ]; then
    NEW_VERSION=$(sudo "$BINARY_PATH_NEW" --version 2>/dev/null)
    if [ -z "$NEW_VERSION" ]; then
      echo "Failed to get version of the new binary."
      exit 1
    else
      echo "New version: $NEW_VERSION"
    fi
else
  echo "New binary not found."
  exit 1
fi

# Compare the two versions
if [ "$OLD_VERSION" != "$NEW_VERSION" ]; then
    echo "Versions are different: Old ($OLD_VERSION) vs New ($NEW_VERSION)"

    sudo systemctl stop egp-agent

    # Update the egp-agent binary
    sudo mv /home/"$OS_USER_NAME"/egp-agent-new /home/"$OS_USER_NAME"/egp-agent
    sudo chmod 700 /home/"$OS_USER_NAME"/egp-agent
    echo 'egp-agent binary moved successfully.'

    # Start the new version of egp-agent
    sudo systemctl start egp-agent
    
    echo "New version of egp-agent started."
    
else
  echo "Versions are the same: $OLD_VERSION"
fi
