#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"
COMMAND_UPDATE_SCRIPT="/home/$OS_USER_NAME/update.sh"
ROOT_DIR_UPDATE=/home/"$OS_USER_NAME"

# Path to release_info.json file on GitHub
RELEASE_INFO_URL="https://raw.githubusercontent.com/alt-develop/emeth-gp-agent-install/main/release_info.json"

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

# Download release_info.json file
sudo curl -s -o "$ROOT_DIR_UPDATE"/release_info.json "$RELEASE_INFO_URL" && sudo chmod 775 "$ROOT_DIR_UPDATE"/release_info.json

# Get releaseDate from JSON file
RELEASE_DATE=$(jq -r '.releaseDate' "$ROOT_DIR_UPDATE"/release_info.json)
# RELEASE_DATE="2024-10-16T22:21:00+09:00"
echo "RELEASE_DATE $RELEASE_DATE"

# Convert releaseDate to timestamp (UTC)
RELEASE_TIMESTAMP=$(date -u -d "$RELEASE_DATE" +%s)

# Get last update time of egp-agent file
MODIFIED_DATE=$(stat -c %w "$ROOT_DIR_UPDATE"/egp-agent)
MODIFIED_TIMESTAMP=$(date -d "$MODIFIED_DATE" +%s)

# echo "RELEASE_TIMESTAMP: $RELEASE_TIMESTAMP"
# echo "MODIFIED_TIMESTAMP: $MODIFIED_TIMESTAMP"

# Compare the two versions
if [ $RELEASE_TIMESTAMP -gt $MODIFIED_TIMESTAMP ]; then
    echo "New update available! Release date: $RELEASE_DATE. Perform update..."

    sudo systemctl stop egp-agent.service

    # Update the egp-agent binary
    echo 'Download new version of egp-agent'
    sudo curl -o "$ROOT_DIR_UPDATE"/egp-agent-new https://raw.githubusercontent.com/alt-develop/egp-agent/main/egp-agent && sudo chmod 700 "$ROOT_DIR_UPDATE"/egp-agent-new
    sudo mv "$ROOT_DIR_UPDATE"/egp-agent-new "$ROOT_DIR_UPDATE"/egp-agent
    sudo chmod 700 "$ROOT_DIR_UPDATE"/egp-agent
    echo 'egp-agent binary moved successfully.'

    # Start the new version of egp-agent
    sudo systemctl start egp-agent.service
    
    echo "New version of egp-agent started."
    
else
  echo "No new updates. Release date: $RELEASE_DATE."
fi

# Delete temporary files
sudo rm "$ROOT_DIR_UPDATE"/release_info.json