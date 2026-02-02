#!/bin/bash
 
# --- Configuration ---
# Define the path for the MongoDB repository file.
MONGO_REPO_FILE="/etc/yum.repos.d/mongo.repo"
# Define the content for the MongoDB repository file.
# This specifies the repository for MongoDB 7.0 on Red Hat 9 x86_64.
MONGO_REPO_CONTENT="[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
enabled=1
gpgcheck=0"
# Define the MongoDB configuration file path.
MONGO_CONF_FILE="/etc/mongod.conf"
# Define the log directory path.
LOG_DIR="/var/log/mongodb_install"
# Define the log file path for the scripts operations.
LOG_FILE="$LOG_DIR/mongodb_install.log"
 
# --- Logging Function ---
# Function to log messages with a timestamp.
log_message() {
  local message="$1"
  # Ensure log directory exists
  sudo mkdir -p "$LOG_DIR"
  # Log message to both console and log file
  echo "$(date +%Y-%m-%d %H:%M:%S) - $message" | sudo tee -a "$LOG_FILE"
}
 
# --- Pre-installation Checks ---
# Function to check if the script is run as root.
check_root_privileges() {
  if [[ $EUID -ne 0 ]]; then
    log_message "ERROR: This script must be run as root."
    exit 1
  fi
}
 
# --- Main Installation Logic ---
log_message "Starting MongoDB installation script."
 
# Check for root privileges
check_root_privileges
log_message "Root privileges confirmed."
 
# --- Repository Setup ---
log_message "Setting up MongoDB repository..."
# Check if the repository file already exists.
if [ ! -f "$MONGO_REPO_FILE" ]; then
  # Create the repository file with the specified content.
  echo "$MONGO_REPO_CONTENT" | tee "$MONGO_REPO_FILE" > /dev/null
  if [ $? -eq 0 ]; then
    log_message "Successfully created MongoDB repository file: $MONGO_REPO_FILE"
  else
    log_message "ERROR: Failed to create MongoDB repository file: $MONGO_REPO_FILE"
    exit 1
  fi
else
  log_message "MongoDB repository file already exists at $MONGO_REPO_FILE. Skipping creation."
fi
 
# --- Package Installation ---
log_message "Installing MongoDB packages..."
# Install the MongoDB community edition packages. The -y flag automatically answers yes to prompts.
dnf install mongodb-org -y >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
  log_message "MongoDB installation completed successfully."
else
  log_message "ERROR: MongoDB installation failed. Check $LOG_FILE for details."
  exit 1
fi
 
# --- Service Management ---
log_message "Enabling and starting MongoDB service..."
# Enable the MongoDB service to start automatically on boot.
systemctl enable mongod >> "$LOG_FILE" 2>&1
# Start the MongoDB service.
systemctl start mongod >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
  log_message "MongoDB service enabled and started successfully."
else
  log_message "ERROR: Failed to enable or start MongoDB service. Check $LOG_FILE for details."
  exit 1
fi
 
# --- Network Configuration ---
log_message "Configuring MongoDB to listen on all interfaces..."
# Check if the MongoDB configuration file exists.
if [ -f "$MONGO_CONF_FILE" ]; then
  # Change the bind IP address to 0.0.0.0 to allow remote connections.
  # This replaces 127.0.0.1 with 0.0.0.0 in the configuration file.
  sed -i s/127.0.0.1/0.0.0.0/g "$MONGO_CONF_FILE"
  if [ $? -eq 0 ]; then
    log_message "MongoDB configuration updated to listen on 0.0.0.0."
 
    # Restart the MongoDB service to apply the configuration changes.
    log_message "Restarting MongoDB service to apply changes..."
    systemctl restart mongod >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
      log_message "MongoDB service restarted successfully."
    else
      log_message "ERROR: Failed to restart MongoDB service after configuration update. Check $LOG_FILE for details."
      exit 1
    fi
  else
    log_message "ERROR: Failed to update MongoDB configuration file: $MONGO_CONF_FILE. Check $LOG_FILE for details."
    exit 1
  fi
else
  log_message "WARNING: MongoDB configuration file not found at $MONGO_CONF_FILE. Skipping network configuration."
fi
 
log_message "MongoDB installation and basic configuration finished successfully."
exit 0