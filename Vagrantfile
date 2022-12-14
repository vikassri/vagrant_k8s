Vagrant.configure("2") do |config|
  config.vm.provision :shell, privileged: true, inline: $install_common_tools

  config.vm.define :master do |master|
    master.vm.provider :virtualbox do |vb|
      vb.name = "master"
      vb.memory = 2048
      vb.cpus = 2
    end
    master.vm.box = "ubuntu/bionic64"
    master.disksize.size = "25GB"
    master.vm.hostname = "master"
    master.vm.network :private_network, ip: "192.168.59.21"
    master.vm.provision :shell, privileged: false, inline: $provision_master_node
  end

  %w{node01 node02 node03}.each_with_index do |name, i|
    config.vm.define name do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = "node0#{i + 1}"
        vb.memory = 2048
        vb.cpus = 2
      end
      node.vm.box = "ubuntu/bionic64"
      node.disksize.size = "25GB"
      node.vm.hostname = name
      node.vm.network :private_network, ip: "192.168.59.#{i + 22}"
      node.vm.provision :shell, privileged: false, inline: <<-SHELL
        sudo /vagrant/configs/join.sh
        echo 'Environment="KUBELET_EXTRA_ARGS=--node-ip=192.168.59.#{i + 22}"' | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
        cat /vagrant/configs/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
        SHELL
    end
  end

  config.vm.provision "shell", inline: $install_multicast
end


$install_common_tools = <<-SCRIPT
# bridged traffic to iptables is enabled for kube-router.
cat >> /etc/ufw/sysctl.conf <<EOF
net/bridge/bridge-nf-call-ip6tables = 1
net/bridge/bridge-nf-call-iptables = 1
net/bridge/bridge-nf-call-arptables = 1
EOF
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts
# remove ubuntu-bionic entry
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts
# Patch OS
apt-get update && apt-get upgrade -y
# Create local host entries
echo "192.168.59.21 master" >> /etc/hosts
echo "192.168.59.22 node01" >> /etc/hosts
echo "192.168.59.23 node02" >> /etc/hosts
echo "192.168.59.24 node03" >> /etc/hosts
# disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab
# Install kubeadm, kubectl and kubelet
export DEBIAN_FRONTEND=noninteractive
apt-get -qq install ebtables ethtool
apt-get -qq update
apt-get -qq install -y docker.io apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get -qq update
apt-get -qq install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubectl kubeadm
# Set external DNS
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart
SCRIPT

$provision_master_node = <<-SHELL
OUTPUT_FILE=/vagrant/configs/join.sh
KEY_FILE=/vagrant/configs/id_rsa.pub
rm -rf $OUTPUT_FILE
rm -rf $KEY_FILE

# Create folder for config
config_path="/vagrant/configs"
if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

# Create key
ssh-keygen -q -t rsa -b 4096 -N '' -f /home/vagrant/.ssh/id_rsa
cat /home/vagrant/.ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
cat /home/vagrant/.ssh/id_rsa.pub > ${KEY_FILE}

# Start cluster
sudo kubeadm init --apiserver-advertise-address=192.168.59.21 --pod-network-cidr=10.244.0.0/16 | grep -Ei "kubeadm join|discovery-token-ca-cert-hash" > ${OUTPUT_FILE}
chmod +x $OUTPUT_FILE

# Configure kubectl for vagrant and root users
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo chown -R root:root /root/.kube

# Fix kubelet IP
echo 'Environment="KUBELET_EXTRA_ARGS=--node-ip=192.168.59.21"' | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Use our flannel config file so that routing will work properly
# kubectl create -f /vagrant/kube-flannel.yml

# Set alias on master for vagrant and root users
echo "alias k=/usr/bin/kubectl" >> $HOME/.bash_profile
echo "alias k=/usr/bin/kubectl" | sudo tee -a /root/.bash_profile

# Install the etcd client
sudo apt install etcd-client
sudo systemctl daemon-reload
sudo systemctl restart kubelet

sudo cp -i /etc/kubernetes/admin.conf /vagrant/configs/config

echo """export KUBECONFIG=configs/config
kubectl get nodes -o wide
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f https://raw.githubusercontent.com/scriptcamp/kubeadm-scripts/main/manifests/metrics-server.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.5/config/manifests/metallb-native.yaml
sleep 90
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.59.25-192.168.59.50
status: {}
EOF

sleep 20

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
status: {}
EOF

sleep 20

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

sleep 20

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

sleep 20

kubectl create token admin-user -n kubernetes-dashboard >> ./configs/admin-token

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF

""" > /vagrant/start.sh
SHELL

$install_multicast = <<-SHELL
apt-get -qq install -y avahi-daemon libnss-mdns
SHELL
