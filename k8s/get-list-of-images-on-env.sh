#!/bin/bash

# Output file for the images
IMAGE_LIST="images.txt"

# Step 1: Get images from Kubernetes API resources
kubectl get deployments,daemonsets,statefulsets,jobs,cronjobs -A -o json | jq -r '.items[] | .spec.template.spec.containers[].image, .spec.template.spec.initContainers[]?.image' | sort -u > standard-images.txt

# Step 2: Get images from static pod manifests
sudo grep -r 'image:' /etc/kubernetes/manifests/*.yaml | sed -E 's/.*image:\s*"?([^"]+)"?/\1/' | sort -u > static-pod-images.txt

# Step 3: Combine the lists
cat standard-images.txt static-pod-images.txt | sort -u > $IMAGE_LIST
