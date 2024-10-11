#!/bin/bash

REPO_URL="" ## Format organisation/repo-name
REPO_DIR="" ## Directory where the deployment repository will be cloned
VALUES_FILE_PATH=""
OCI_CHART="" ## ONLY Suports OCI based helm charts
RELEASE_NAME=""
NAMESPACE=""


GIT_USERNAME=""
GIT_TOKEN=""

COMMIT_FILE="./commits/last_commit_hash.txt"


if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning the repository for the first time..."
  git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/$REPO_URL" "$REPO_DIR"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to clone the repository."
    exit 1
  fi
fi

cd "$REPO_DIR" || exit 1

git fetch origin

git pull origin main

LATEST_COMMIT=$(git log -n 1 --pretty=format:"%H" -- "$VALUES_FILE_PATH")

if [ -z "$LATEST_COMMIT" ]; then
  echo "Error: Unable to retrieve the latest commit for $VALUES_FILE_PATH."
  exit 1
fi

if [ ! -f "$COMMIT_FILE" ]; then
  echo "No previous commit found, saving the current commit hash."
  echo "$LATEST_COMMIT" > "$COMMIT_FILE"
  helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"
  exit 0
fi

LAST_COMMIT=$(cat "$COMMIT_FILE")

if [ "$LATEST_COMMIT" != "$LAST_COMMIT" ]; then
  echo "New commit detected in $VALUES_FILE_PATH! Updating Helm release..."

  git pull origin main

  helm upgrade "$RELEASE_NAME" "$OCI_CHART" --namespace "$NAMESPACE" -f "$VALUES_FILE_PATH"
  
  if [ $? -ne 0 ]; then
    echo "Error: Helm upgrade failed."
    exit 1
  fi

  echo "$LATEST_COMMIT" > "$COMMIT_FILE"
else
  echo "No new commits detected in $VALUES_FILE_PATH. Helm upgrade not required."
fi
