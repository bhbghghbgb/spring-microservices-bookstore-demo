#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Initial Setup ---

# Create required cache and build output directories
mkdir -p data/cache/.m2
mkdir -p data/builds

# --- Maven Build Execution (Build-in-Container) ---

echo "Reading modules from pom.xml..."
# Use grep and sed to extract all module names from the pom.xml file
# MODULES=$(grep -A 1000 '<modules>' pom.xml | grep -B 1000 '</modules>' | grep '<module>' | sed 's/.*<module>//;s/<\/module>.*//' | tr '\n' ' ')
# Use awk to extract all module names from the pom.xml file
MODULES=$(awk '/<modules>/,/<\/modules>/ { if ($0 ~ /<module>/) { gsub(/.*<module>|<\/module>.*/, "", $0); print $0 } }' pom.xml)

# Check if MODULES list is empty
if [ -z "$MODULES" ]; then
  echo "Error: Could not read any modules from pom.xml. Exiting."
  exit 1
fi
echo "Found modules: $MODULES"

echo "Building Java microservices into tarballs using JIB..."

# Run Maven in a Docker container to clean, package, and execute jib:buildTar on all modules
docker run --rm -it \
  -v "$(pwd)/data/cache/.m2":/root/.m2 \
  -v "$(pwd)":/app \
  -w /app \
  maven:3.9.11-eclipse-temurin-17-alpine \
  mvn clean package -DskipTests

# --- Load Microservice Images into Local Docker Registry ---

echo "Loading microservice tarballs into local Docker registry..."

# Iterate through the dynamically read list of modules
for module in $MODULES; do
  TAR_PATH="./data/builds/${module}-image.tar"
  IMAGE_NAME="microservices-bookstore/$module"

  if [ -f "$TAR_PATH" ]; then
    echo "Loading $IMAGE_NAME from $TAR_PATH..."
    docker load -i "$TAR_PATH"
  else
    echo "Tarball not found for $module at $TAR_PATH — skipping. Check Jib configuration/paths."
  fi
done

# --- Build Frontend and Pull Other Images ---

echo "Building Docker image for Next.js frontend..."

# Build the separate Next.js frontend image
docker build -t microservices-bookstore/nextjs-frontend:latest ./frontend

# Pull all required base images defined in all profiles
echo "Pulling required base images (mongo, postgres, kafka, zipkin, pgadmin, mongo-express, etc.) from Docker Hub..."
# Using 'docker compose pull' and passing all profiles to ensure all images are fetched
docker compose \
  --profile infrastructure \
  --profile extra-dbadmin \
  --profile discovery-config \
  --profile services \
  up --no-start

echo "All images built, pulled, and loaded successfully."
