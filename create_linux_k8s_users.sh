#!/bin/bash

users_file=users.txt

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
done < "$users_file"

read -p "Enter the namespace name: " namespace

# Check if namespace exists, if not create it
if kubectl get namespace $namespace &> /dev/null; then
  echo "Namespace '$namespace' already exists"
else
  kubectl create namespace $namespace
  echo "Namespace '$namespace' created"
fi

# Read usernames from users.txt file
while read -r username; do
  serviceaccount_name="$namespace-$username"
  rolebinding_name="$namespace-$username-rolebinding"

  # Check if service account exists, if not create it
  if kubectl get serviceaccount $serviceaccount_name -n $namespace &> /dev/null; then
    echo "Service account '$serviceaccount_name' already exists in namespace '$namespace'"
  else
    kubectl create serviceaccount $serviceaccount_name -n $namespace
    echo "Service account '$serviceaccount_name' created in namespace '$namespace'"
  fi

  # Check if role exists, if not create it
  if kubectl get role $username -n $namespace &> /dev/null; then
    echo "Role '$username' already exists in namespace '$namespace'"
  else
    kubectl create role $username --verb=get,list,watch,create,update,delete --resource=pods,deployments,services -n $namespace
    echo "Role '$username' created in namespace '$namespace'"
  fi

  # Check if rolebinding exists, if not create it
  if kubectl get rolebinding $rolebinding_name -n $namespace &> /dev/null; then
    echo "Rolebinding '$rolebinding_name' already exists in namespace '$namespace'"
  else
    kubectl create rolebinding $rolebinding_name --role=$username --serviceaccount=$namespace:$serviceaccount_name -n $namespace
    echo "Rolebinding '$rolebinding_name' created and mapped to service account '$serviceaccount_name' in namespace '$namespace'"
  fi

done < "$users_file"
