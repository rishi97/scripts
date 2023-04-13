creating_namespace(){
    if [ "$checknamespace" -eq 0 ]; then
        echo "Creating namespace $namespace_name"
        kubectl create ns $namespace_name
        creating_role
        creating_serviceaccount
    elif [ "$checknamespace" -eq 1 ]; then
        echo "$namespace_name Already exists!"
        creating_role
        creating_serviceaccount
    else
        echo "All the resources required exists"
    fi
}

creating_serviceaccount(){
    while read username; do
        svcac=`kubectl get serviceaccount -n=${namespace_name} | grep -i ${username}| wc -l`
        sa="${username}-${namespace_name}-sa"
        if [ "$svcac" -eq 0 ]; then
            echo "Creating service account for user: $username"
            kubectl create sa $sa -n $namespace_name
            echo "---- Success -------"
            creating_rolebinding
        elif [ "$svcac" -eq 1 ]; then
            echo "A serviceaccount already exists!"
            echo "Creating rolebinding for $username"
            creating_rolebinding
        else
            echo "A serviceaccount already exists!"
        fi
    done < "$usernames_file"
}

creating_rolebinding(){
    rbname="${username}-${namespace_name}-rolebinding"
    kubectl create rolebinding $rbname --user=$username --serviceaccount=$namespace_name:$sa --namespace=$namespace_name --role=$rolename
}

creating_role(){
    if [ "$checkrole" -eq 0 ]; then
        echo "Creating role"
        kubectl create role $rolename --verb=* --resource=* -n $namespace_name
    else
        echo "Role $rolename exists"
    fi
}


groupname="coredgedev"
usernames_file="/home/ubuntu/users.txt"

echo "Enter namespace name to create!"
read ns_name
namespace_name=$ns_name
rolename="$namespace_name-dev-role"
checknamespace=`kubectl get ns | grep -i $namespace_name | wc -l`
checkrole=`kubectl get role -n=${namespace_name} | grep -i $rolename | wc -l`
# checkrolebing=`kubectl get rolebinding | grep -i ${username} | wc -l`
# checksa=`kubectl get serviceaccount -A | grep -i ${username}| wc -l`

creating_namespace
