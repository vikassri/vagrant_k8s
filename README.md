# vagrant_k8s
Three node vagrant kubernetes cluster

# START SCRIPT

```bash
# update the script with master ip and public ip ranger
MASTER_IP=192.168.59.21
PUBLIC_IP_START=192.168.59.25
PUBLIC_IP_END=192.168.59.50

# Execute the script it will replace the variable and execute the scripst
sh setup.sh
```

# Kubectl on Host machine
```bash
# export the kubeconfig from the same directory to access the cluster using config
export KUBECONFIG=configs/config
kubectl get nodes -o wide


# There is one sample deployed, which you can access by below url
echo "http://$(kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"/
```

