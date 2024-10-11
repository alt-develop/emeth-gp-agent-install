#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
COMMAND_UPDATE_SCRIPT="/home/$OS_USER_NAME/update.sh"

# Generate random time for the job
RANDOM_HOUR=$(shuf -i 0-23 -n 1)
RANDOM_MINUTE=$(shuf -i 1-59 -n 1)

# Set schedule for tomorrow
TOMORROW=$(date -d "tomorrow" +%d)
MONTH=$(date +%m)
CRON_SCHEDULE="$RANDOM_MINUTE $RANDOM_HOUR $TOMORROW $MONTH *"
CRON_JOB="$CRON_SCHEDULE $COMMAND_UPDATE_SCRIPT"

# Check if a cron job exists for today
EXISTING_CRON_JOB=$(crontab -l 2>/dev/null | grep -F "$COMMAND_UPDATE_SCRIPT")

if [ -n "$EXISTING_CRON_JOB" ]; then
  # Remove the existing cron job for today
  (crontab -l 2>/dev/null | grep -v -F "$COMMAND_UPDATE_SCRIPT") | crontab -
  echo "Existing cron job for today removed: $EXISTING_CRON_JOB"
  echo "Adding new cron job for tomorrow: $CRON_JOB"
else
  echo "No existing cron job for today. Adding new cron job for tomorrow: $CRON_JOB"
fi

# Add the new cron job for tomorrow
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

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
