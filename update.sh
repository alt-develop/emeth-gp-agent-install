#!/bin/sh

# Set constant variables
OS_USER_NAME="egp-user"

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
    # Check if egp-agent is running
    if pgrep -x "egp-agent" > /dev/null; then
      echo "egp-agent is running. Waiting for it to complete..."

      # Wait for egp-agent to finish its current process
      while pgrep -x "egp-agent" > /dev/null; do
        sleep 10
      done

      echo "egp-agent has completed. Proceeding with the update."

      if ! sudo /home/"$OS_USER_NAME"/egp-agent-new --update; then
        echo 'Failed to update egp-agent binary.'
        exit 1
      else
        echo 'egp-agent binary update successfully.'
        sudo mv /home/"$OS_USER_NAME"/egp-agent-new /home/"$OS_USER_NAME"/egp-agent
        sudo chmod 700 /home/"$OS_USER_NAME"/egp-agent
        echo 'egp-agent binary moved successfully.'
      fi
      
    fi
else
  echo "Versions are the same: $OLD_VERSION"
fi
