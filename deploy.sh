#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Utility Functions ---

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Function to prompt user to press Enter to continue
pause_for_input() {
  echo ""
  read -r -p "Press [Enter] to continue with the next deployment phase..."
  echo ""
}

# Function to launch the URL in the default browser
launch_browser() {
  local url="http://localhost:3000"
  echo "Launching front-end application in default web browser: $url"
  if command_exists xdg-open; then
    # Linux (most distributions)
    xdg-open "$url" &
  elif command_exists open; then
    # macOS
    open "$url" &
  elif command_exists start; then
    # Windows (WSL)
    start "$url" &
  else
    echo "⚠️ Could not automatically launch browser. Please navigate to $url manually."
  fi
}

# Function to deploy a specific profile
deploy_profile() {
  local profile_name="$1"
  echo "--- Starting Deployment: $profile_name ---"
  echo "Running: docker compose --profile $profile_name up -d"
  # Use 'docker compose up' and pass the profile as an argument
  docker compose --profile $profile_name up -d
  echo "--- Deployment Finished: $profile_name ---"
}

# --- Main Deployment Logic ---

echo "=========================================================="
echo "    Microservices Bookstore Application Deployment Tool   "
echo "=========================================================="
echo "Choose deployment mode:"
echo "1) Deploy All at Once (Recommended for quick startup)"
echo "2) Deploy Step-by-Step (Phased deployment with pauses)"
echo "3) Stop and Remove All Containers"
echo ""

read -r -p "Enter choice (1/2/3): " choice

# Define deployment profiles in the correct order
PROFILES=("infrastructure" "discovery-config" "services")

# Prepare the profiles for explicit passing to 'up' and 'down' commands
PROFILE_ARGS=""
for profile in "${PROFILES[@]}"; do
    PROFILE_ARGS+="--profile $profile "
done

case "$choice" in
  1)
    echo ""
    echo "Starting ALL services at once by explicitly listing all profiles..."
    
    # FIX: Explicitly pass each profile using the --profile flag repeatedly
    # This is the reliable way to use multiple profiles with modern 'docker compose'
    echo "Running: docker compose $PROFILE_ARGS up -d"
    docker compose $PROFILE_ARGS up -d
    ;;

  2)
    echo ""
    echo "Starting services in phased mode..."
    
    # 1. Infrastructure Services
    deploy_profile "${PROFILES[0]}"
    echo "INFO: Infrastructure Services deployed (Databases, Kafka, Zipkin)."
    pause_for_input

    # 2. Discovery and Configuration Servers
    deploy_profile "${PROFILES[1]}"
    echo "INFO: Discovery and Config Servers deployed. Waiting for them to fully initialize."
    pause_for_input

    # 3. Application Services
    deploy_profile "${PROFILES[2]}"
    echo "INFO: Application Services (API Gateway, Microservices, Frontend, Monitoring) deployed."
    ;;
  
  3)
    echo ""
    echo "Stopping and removing all running containers defined in the compose file..."
    
    # FIX: Explicitly pass all profiles to 'down' to ensure all relevant services are stopped and removed.
    echo "Running: docker compose $PROFILE_ARGS down -v --remove-orphans"
    docker compose $PROFILE_ARGS down -v --remove-orphans
    echo "Cleanup complete."
    exit 0
    ;;

  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# --- Verification and Front-end Launch ---

echo ""
echo "=========================================================="
echo "    DEPLOYMENT COMPLETE"
echo "=========================================================="
echo "Verification Steps:"
echo "1. Wait a moment for all Java services to register with the Discovery Server (port 8761)."
echo "2. Check application functionality via the Front-end (http://localhost:3000)."
echo "3. API Gateway is running at http://localhost:8080."
echo "4. Grafana is running at http://localhost:3001 (admin/password)."
echo "5. Zipkin is running at http://localhost:9411."

launch_browser

echo ""
echo "Deployment script finished."
