#!/bin/bash

# Define the group and usernames file
groupname="coredgedev"
usernames_file="/home/ubuntu/usernames.txt"

# Check if the group already exists
if grep -q "^$groupname:" /etc/group; then
  echo "Group '$groupname' already exists"
else
  # Create the group
  sudo groupadd "$groupname"
  echo "Group '$groupname' created"
fi

# Read the usernames from the file and create the users
while read username; do
  # Check if the user already exists
  if id "$username" >/dev/null 2>&1; then
    echo "User '$username' already exists"
  else
    # Generate a random password with 12 characters
    password="core@${username}12345"
    # Create the user with the specified group as secondary group
    sudo useradd -m -p $(openssl passwd -1 "$password") -s /bin/bash -G "$groupname" "$username"
    echo "User '$username' created with password: $password"
  fi
done < "$usernames_file"
