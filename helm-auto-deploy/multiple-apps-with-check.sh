#!/bin/bash

LOCK_FILE="/tmp/<name-of-the-script-file>.lock"

# Function to check if the script is already running
check_already_running() {
  if [ -f "$LOCK_FILE" ]; then
    # If lock file exists, check if the process is still running
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" > /dev/null 2>&1; then
      echo "The script is already running with PID: $PID. Exiting."
      exit 1
    else
      # If the process is not running, remove the stale lock file
      echo "Stale lock file found. Removing it."
      rm -f "$LOCK_FILE"
    fi
  fi

  # Create a lock file with the current PID
  echo $$ > "$LOCK_FILE"
}

# Function to clean up the lock file when the script finishes
cleanup() {
  echo "Cleaning up..."
  rm -f "$LOCK_FILE"
}

# Trap signals to clean up the lock file if the script is interrupted
trap cleanup EXIT

# Check if another instance of the script is already running
check_already_running

###############################################################

# List of release names (These are the Helm release names)
APP_RELEASE_NAME=("keycloak" "ccp-integrations")

# Corresponding chart names (These are the Helm chart names in the OCI repository)
CHART_NAMES=("keycloak-ha" "ccp-integrations")

# The source path in the repository for override values files for one client and environment (client-name/env)
APP_OVERRIDE_SOURCE_PATH="dummy/qa"  # Only one client environment at a time

# Common variables
SOURCE_REPO_URL="rishi97/deployments" ## Format organisation/repo-name
HOST_REPO_DIR="/home/core/rishi97/auto-helm-deploy" ## Directory where the deployment repository will be cloned
NAMESPACE="testing" ## The namespace where the Helm releases will be upgraded

GIT_USERNAME=""
GIT_TOKEN=""

COMMIT_FILE_BASE_DIR="/home/core/rishi97/auto-helm-deploy-git/commit_hashes"

OCI_CHART_BASE="oci://registry-1.docker.io/coredgehelm/"

# Ensure the directory for commit files exists
mkdir -p "$COMMIT_FILE_BASE_DIR"

# Clone the repo if it hasn't been cloned yet
if [ ! -d "$HOST_REPO_DIR/.git" ]; then
  echo "Cloning the repository for the first time..."
  git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/$SOURCE_REPO_URL" "$HOST_REPO_DIR"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to clone the repository."
    exit 1
  fi
fi

# Navigate to the source repository directory
# This where the git repo is cloned
cd "$HOST_REPO_DIR" || exit 1

# Fetch and pull the latest changes
git fetch origin
git pull origin main

# Check if the length of both arrays is the same
if [ ${#APP_RELEASE_NAME[@]} -ne ${#CHART_NAMES[@]} ]; then
  echo "Error: The number of app release names and chart names do not match."
  exit 1
fi

# Function to check if a Helm release exists and if an upgrade is already in progress
check_helm_release_and_upgrade_in_progress() {
  local release_name=$1
  local namespace=$2

  # Check if the Helm release exists
  helm status "$release_name" --namespace "$namespace" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Release $release_name not found in namespace $namespace. Skipping."
    return 1
  fi

  # Check if an upgrade is already in progress
  STATUS=$(helm status "$release_name" --namespace "$namespace" -o json | jq -r .info.status)
  if [[ "$STATUS" == "pending-upgrade" ]]; then
    echo "Helm upgrade is already in progress for $release_name. Skipping upgrade."
    return 1
  fi

  return 0
}

# Iterate through each app release name and its corresponding chart
for i in "${!APP_RELEASE_NAME[@]}"; do
  APP="${APP_RELEASE_NAME[$i]}"
  CHART="${CHART_NAMES[$i]}"

  echo "Processing application: $APP with chart: $CHART"

  # Set the values for the current app
  VALUES_FILE_NAME="${APP}-override-values.yaml"
  VALUES_FILE_PATH="$HOST_REPO_DIR/$APP_OVERRIDE_SOURCE_PATH/$VALUES_FILE_NAME"
  RELEASE_NAME="$APP"
  OCI_CHART="$OCI_CHART_BASE$CHART"
  COMMIT_FILE="$COMMIT_FILE_BASE_DIR/${RELEASE_NAME}_last_commit_hash.txt"

  # Check if the values file exists
  if [ ! -f "$VALUES_FILE_PATH" ]; then
    echo "Error: Values file not found for $APP in $APP_OVERRIDE_SOURCE_PATH at $VALUES_FILE_PATH."
    exit 1
  fi

  # Check if the Helm release exists and if an upgrade is in progress
  check_helm_release_and_upgrade_in_progress "$RELEASE_NAME" "$NAMESPACE"
  if [ $? -ne 0 ]; then
    continue  # Skip this application if the release doesn't exist or an upgrade is in progress
  fi

  # Get the latest commit for the values file
  LATEST_COMMIT=$(git log -n 1 --pretty=format:"%H" -- "$VALUES_FILE_PATH")

  if [ -z "$LATEST_COMMIT" ]; then
    echo "Error: Unable to retrieve the latest commit for $VALUES_FILE_PATH."
    exit 1
  fi

  # Check if a previous commit exists
  if [ ! -f "$COMMIT_FILE" ]; then
    echo "No previous commit found for $APP in $APP_OVERRIDE_SOURCE_PATH, saving the current commit hash."
    echo "$LATEST_COMMIT" > "$COMMIT_FILE"
    helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"
    if [ $? -ne 0 ]; then
      echo "Error: Helm upgrade failed for $APP in $APP_OVERRIDE_SOURCE_PATH."
      exit 1
    fi
    continue
  fi

  # Read the last commit
  LAST_COMMIT=$(cat "$COMMIT_FILE")

  # Compare the latest commit with the last commit
  if [ "$LATEST_COMMIT" != "$LAST_COMMIT" ]; then
    echo "New commit detected in $VALUES_FILE_PATH for $APP in $APP_OVERRIDE_SOURCE_PATH! Updating Helm release..."

    helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"

    if [ $? -ne 0 ]; then
      echo "Error: Helm upgrade failed for $APP in $APP_OVERRIDE_SOURCE_PATH."
      exit 1
    fi

    # Save the latest commit hash
    echo "$LATEST_COMMIT" > "$COMMIT_FILE"
  else
    echo "No new commits detected in $VALUES_FILE_PATH for $APP in $APP_OVERRIDE_SOURCE_PATH. Helm upgrade not required."
  fi
done

echo "All applications processed for environment: $APP_OVERRIDE_SOURCE_PATH."
