#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Utility Functions ---

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to prompt user to press Enter to continue
pause_for_input() {
  echo ""
  read -r -p "Press [Enter] to continue with the next deployment phase..."
  echo ""
}

# Function to display a timer and allow interruption
timed_wait() {
  local seconds="$1"
  local message="$2"
  echo ""
  echo -n "INFO: Waiting ${seconds}s for ${message} to stabilize (Press [Enter] to skip wait): "

  for ((i = seconds; i >= 0; i--)); do
    echo -n "$i "
    # Use 'read' with a timeout. If 'read' returns a non-zero status (timeout), the loop continues.
    # If the user presses Enter, 'read' returns zero, and we break the loop.
    if read -r -t 1 input; then
      echo "(Skipped wait.)"
      return
    fi
  done
  echo "(Timer finished.)"
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

# Function to deploy a specific profile (MODIFIED TO ACCEPT ACCUMULATED PROFILES)
deploy_profile() {
  local new_profile="$1"
  local current_profiles="$2" # This is the full list of accumulated '--profile' flags

  echo "--- Starting Deployment: $new_profile ---"
  echo "Running: docker compose $current_profiles up -d"

  # Execute with the full list of accumulated profiles for dependency resolution
  docker compose $current_profiles up -d
  echo "--- Deployment Finished: $new_profile ---"
}

# --- Main Deployment Logic ---

echo "=========================================================="
echo "    Microservices Bookstore Application Deployment Tool   "
echo "=========================================================="
echo "Choose deployment mode:"
echo "1) Deploy All at Once (Phased deployment with timed waits)"
echo "2) Deploy Step-by-Step (Phased deployment with manual pauses)"
echo "3) Stop and Remove All Containers"
echo ""

read -r -p "Enter choice (1/2/3): " choice

# Define deployment profiles in the correct order, including the new admin profile
# NOTE: Renamed 'extra-dbadmin' to 'db-admin' for brevity and placed it after infrastructure.
PROFILES=("infrastructure" "extra-dbadmin" "discovery-config" "services")

# Prepare the profiles for explicit passing to 'up' and 'down' commands
PROFILE_ARGS=""
for profile in "${PROFILES[@]}"; do
  PROFILE_ARGS+="--profile $profile "
done

# Initialize a counter and accumulator for phased deployment loops
CURRENT_PHASE=0
ACCUMULATED_PROFILES=""

case "$choice" in
1)
  echo ""
  echo "Starting all services in **Timed Phased Mode** to ensure proper initialization..."
  timed_wait 3 "Exit to cancel now"

  # Loop through profiles and accumulate them
  for profile in "${PROFILES[@]}"; do
    ACCUMULATED_PROFILES+="--profile $profile "
    deploy_profile "$profile" "$ACCUMULATED_PROFILES"
    CURRENT_PHASE=$((CURRENT_PHASE + 1))

    # Custom wait logic based on deployment order
    case $CURRENT_PHASE in
    1) # Infrastructure Services
      timed_wait 30 "Infrastructure Services (Databases)"
      ;;
    2) # DB Admin Tools (Runs immediately after infrastructure without wait)
      timed_wait 3 "Database Admin Tools"
      ;;
    3) # Discovery and Configuration Servers
      timed_wait 20 "Discovery and Config Servers"
      ;;
    4) # Application Services
      timed_wait 60 "Application Microservices and Frontend"
      ;;
    esac
  done
  ;;

2)
  echo ""
  echo "Starting services in phased mode with manual pauses..."

  # Loop through profiles and accumulate them
  for profile in "${PROFILES[@]}"; do
    ACCUMULATED_PROFILES+="--profile $profile "
    deploy_profile "$profile" "$ACCUMULATED_PROFILES"
    CURRENT_PHASE=$((CURRENT_PHASE + 1))

    # Custom pause logic based on deployment order
    case $CURRENT_PHASE in
    1) # Infrastructure Services
      echo "INFO: Infrastructure Services deployed (Databases, Kafka, Zipkin). Please wait for database containers to report successful startup before continuing."
      pause_for_input
      ;;
    2) # DB Admin Tools (Runs immediately after infrastructure without manual pause)
      echo "INFO: Database Admin Tools deployed. Ready to proceed."
      ;;
    3) # Discovery and Configuration Servers
      echo "INFO: Discovery and Config Servers deployed. Waiting for them to fully initialize."
      pause_for_input
      ;;
    4) # Application Services
      echo "INFO: Application Services (API Gateway, Microservices, Frontend, Monitoring) deployed."
      ;;
    esac
  done
  ;;

3)
  echo ""
  echo "Stopping and removing all running containers defined in the compose file..."

  # Explicitly pass all profiles to 'down' to ensure all relevant services are stopped and removed.
  echo "Running: docker compose $PROFILE_ARGS  down -v --remove-orphans"
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
echo "4. Metrics (Grafana) is running at http://localhost:3001 (admin/password)."
echo "5. Tracing (Zipkin) is running at http://localhost:9411."
echo "6. PostgreSQL Admin (pgAdmin): http://localhost:5050 (admin@bookstore.com/password)"
echo "7. MongoDB Admin (Mongo Express): http://localhost:8081"

launch_browser

echo ""
echo "Deployment script finished."
