#!/bin/bash

# Define variables
registry_url="<your-container-registry>"
output_dir="trivy_scan_json"
mkdir -p $output_dir

# Get a list of all repositories in the registry
images=$(curl -s https://$registry_url/v2/_catalog | jq -r '.repositories[]')

# Loop through each image to get the tags and scan them with Trivy
for image in $images; do
    # Get all tags for the image
    tags=$(curl -s https://$registry_url/v2/$image/tags/list | jq -r '.tags[]')
    
    for tag in $tags; do
        image_full="$registry_url/$image:$tag"
        # Replace slashes in image name with dashes to avoid directory creation issues
        image_file_name=$(echo "$image" | tr '/' '-')
        echo "Scanning $image_full"
        
        # Perform the Trivy scan and output as HTML
        trivy image --format json -o "$output_dir/${image_file_name}-${tag}-report.json" $image_full
        
        echo "Report saved for $image_full at $output_dir/${image_file_name}-${tag}-report.json"
    done
done

echo "Trivy scans completed. Reports are stored in $output_dir."
