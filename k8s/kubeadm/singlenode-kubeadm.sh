#!/bin/bash

#Function to Install general dependencies
installGeneralDependencies()
{
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
}

#Function to Install Containerd
installContainerd()
{
    # Install config.toml
    curl -fsSLo containerd-config.toml https://gist.githubusercontent.com/oradwell/31ef858de3ca43addef68ff971f459c2/raw/5099df007eb717a11825c3890a0517892fa12dbf/containerd-config.toml
    sudo mkdir /etc/containerd
    sudo mv containerd-config.toml /etc/containerd/config.toml
    curl -fsSLo containerd-1.6.14-linux-amd64.tar.gz https://github.com/containerd/containerd/releases/download/v1.6.25/containerd-1.6.25-linux-amd64.tar.gz
    # Extract the binaries
    sudo tar Cxzvf /usr/local containerd-1.6.25-linux-amd64.tar.gz

    # Install containerd as a service
    sudo curl -fsSLo /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

    sudo systemctl daemon-reload
    sudo systemctl enable --now containerd
}

#Function to Install runc
installRunc()
{
    curl -fsSLo runc.amd64 https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.amd64
    sudo install -m 755 runc.amd64 /usr/local/sbin/runc
}

#Function to Install CNI network plugins
installCniNetworkPlugins()
{
    curl -fsSLo cni-plugins-linux-amd64-v1.3.0.tgz https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
    sudo mkdir -p /opt/cni/bin
    sudo tar -C /opt/cni/bin -xzvf cni-plugins-linux-amd64-v1.3.0.tgz
}

#Function to forward IPv4 and let iptables see bridged network traffic
forwardIpv4()
{
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF
    sudo modprobe -a overlay br_netfilter

    # sysctl params required by setup, params persist across reboots
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF


    # Apply sysctl params without reboot
    sudo sysctl --system
}

#Function to Install kubeadm, kubelet & kubectl
installKube()
{
    # Add Kubernetes GPG key
    #sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
    deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

    # Add Kubernetes apt repository
    #echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    # Fetch package list
    sudo apt-get update

    sudo apt-get install -y kubelet=1.27.6-00 kubeadm=1.27.6-00 kubectl=1.27.6-00

    # Prevent them from being updated automatically
    sudo apt-mark hold kubelet=1.27.6-00 kubeadm=1.27.6-00 kubectl=11.27.6-00
}

#Function to ensure swap is disabled
swapDisable()
{
    # See if swap is enabled
    swapon --show

    # Turn off swap
    sudo swapoff -a

    # Disable swap completely
    sudo sed -i -e '/swap/d' /etc/fstab
}

#Function to create the cluster using kubeadm
createCluster()
{
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs
}

#Function to configure kubectl
configureKubectl()
{
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

#Function to untaint node
nodeUntain()
{
    kubectl taint nodes --all node-role.kubernetes.io/master-
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
}

#Function to Install a CNI plugin
installCniplugin()
{
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
}

#Function to Install helm
installHelm()
{
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
}

#Function to Install a CSI driver
installCsiDriver()
{
    # Add openebs repo to helm
    helm repo add openebs https://openebs.github.io/charts
    helm repo update

    helm install openebs openebs/openebs --set localprovisioner.hostpathClass.isDefaultClass=true --namespace=openebs --create-namespace
}

#Install MetalLB as BGP ControlPlan/LB
installMetalLB()
{
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
}

#Configure MetalLB for IP Pools and L2 Adv
configureMetalLB()
{
    nodeIP=`kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'`
    
    kubectl apply -f - <<EOF
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
        name: ingress-pool
        namespace: metallb-system
    spec:
        addresses:
        - $nodeIP-$nodeIP
    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
        name: ingress-pool-l2
        namespace: metallb-system
    spec:
        ipAddressPools:
        - ingress-pool
EOF
}

#Install ingress-nginx controller
installIngressNginx()
{
    # Add ingress-nginx repo to helm
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    #helm install openebs openebs/openebs --set localprovisioner.hostpathClass.isDefaultClass=true --namespace=openebs --create-namespace
    helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
}

echo "Installing general dependencies"
installGeneralDependencies

echo "Installing Containerd"
installContainerd

echo "Installing runc"
installRunc

echo "Installing CNI network plugins"
installCniNetworkPlugins

echo "Forwarding IPv4 and let iptables see bridged network traffic"
forwardIpv4

echo "Installing kubeadm, kubelet & kubectl"
installKube

echo "Ensuring swap is disabled"
swapDisable

echo "Creating the cluster using kubeadm"
createCluster

echo "Configuring Kubectl"
configureKubectl

echo "Untaint master nodes"
nodeUntain

echo "Installing CNI plugins"
installCniplugin

echo "Installing Helm"
installHelm

echo "Install OpenEBS Storage Class? (Y/N)"
if [ "$user_input" == "Y" ] || [ "$user_input" == "y" ]; then
    echo "Installing OpenEBS SC with Default Configuration..."
    installCsiDriver
else
    exit 0
fi

echo "Install MetalLB and Ingress Nginx Controller? (Y/N)"
read user_input
if [ "$user_input" == "Y" ] || [ "$user_input" == "y" ]; then
    echo "Installing MetalLB.."
    installMetalLB
    echo "Configuring MetalLB.."
    configureMetalLB
    echo "Installing Ingress Nginx Controller.."
    installIngressNginx
elif [ "$user_input" == "N" ] || [ "$user_input" == "n" ]; then
    echo "Not installing anything!"
    exit 0
else
    exit 0
fi
