#!/bin/bash

# List of applications to upgrade in the order
APPS=("abc" "xyz" "fgh" "integrations")

# Common variables
REPO_URL="" ## Format organisation/repo-name
REPO_DIR="" ## Directory where the deployment repository will be cloned
NAMESPACE=""

GIT_USERNAME=""
GIT_TOKEN=""

COMMIT_FILE_BASE_DIR="./auto-helm-deploy-git/commit_hashes"

OCI_CHART_BASE=""

# Ensure the directory for commit files exists
mkdir -p "$COMMIT_FILE_BASE_DIR"

# Clone the repo if it hasn't been cloned yet
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning the repository for the first time..."
  git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/$REPO_URL" "$REPO_DIR"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to clone the repository."
    exit 1
  fi
fi

# Navigate to the repository directory
cd "$REPO_DIR" || exit 1

# Fetch and pull the latest changes
git fetch origin
git pull origin main

# Function to check if a Helm release upgrade is in progress
check_helm_upgrade_in_progress() {
  local release_name=$1
  helm status "$release_name" --namespace "$NAMESPACE" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Release $release_name not found in namespace $NAMESPACE. Skipping."
    return 1
  fi

  # Check the status of the Helm release
  STATUS=$(helm status "$release_name" --namespace "$NAMESPACE" -o json | jq -r .info.status)
  if [[ "$STATUS" == "pending-upgrade" ]]; then
    echo "Helm upgrade is already in progress for $release_name. Skipping upgrade."
    return 1
  fi
  return 0
}

# Iterate through each application in the list
for APP in "${APPS[@]}"; do
  echo "Processing application: $APP"

  # Set the values for the current app
  VALUES_FILE_NAME="$APP-values-override.yaml"
  VALUES_FILE_PATH="$REPO_DIR/$VALUES_FILE_NAME"
  RELEASE_NAME="$APP"
  OCI_CHART="$OCI_CHART_BASE$APP-ha"
  COMMIT_FILE="$COMMIT_FILE_BASE_DIR/${APP}_last_commit_hash.txt"

  # Check if a Helm upgrade is already in progress for the app
  check_helm_upgrade_in_progress "$RELEASE_NAME"
  if [ $? -ne 0 ]; then
    continue  # Skip this application if an upgrade is in progress
  fi

  # Get the latest commit for the values file
  LATEST_COMMIT=$(git log -n 1 --pretty=format:"%H" -- "$VALUES_FILE_PATH")

  if [ -z "$LATEST_COMMIT" ]; then
    echo "Error: Unable to retrieve the latest commit for $VALUES_FILE_PATH."
    exit 1
  fi

  # Check if a previous commit exists
  if [ ! -f "$COMMIT_FILE" ]; then
    echo "No previous commit found for $APP, saving the current commit hash."
    echo "$LATEST_COMMIT" > "$COMMIT_FILE"
    helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"
    if [ $? -ne 0 ]; then
      echo "Error: Helm upgrade failed for $APP."
      exit 1
    fi
    continue
  fi

  # Read the last commit
  LAST_COMMIT=$(cat "$COMMIT_FILE")

  # Compare the latest commit with the last commit
  if [ "$LATEST_COMMIT" != "$LAST_COMMIT" ]; then
    echo "New commit detected in $VALUES_FILE_PATH for $APP! Updating Helm release..."
    
    helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"
    
    if [ $? -ne 0 ]; then
      echo "Error: Helm upgrade failed for $APP."
      exit 1
    fi

    # Save the latest commit hash
    echo "$LATEST_COMMIT" > "$COMMIT_FILE"
  else
    echo "No new commits detected in $VALUES_FILE_PATH for $APP. Helm upgrade not required."
  fi
done

echo "All applications processed."
