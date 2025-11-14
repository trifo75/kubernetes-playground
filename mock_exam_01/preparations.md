1. Cluster  prerequisites
   TODO

1. Pre-create namespaces

```
kubectl create namespace production
kubectl create namespace development
kubectl create namespace database
kubectl create namespace analytics
kubectl create namespace monitoring
```

1. Deploy some "broken" resources

* A pod with wrong image tag or missing ConfigMap reference
* A node with stopped kubelet service (for task 16)
* A eployment with incorrect configuration

1. Set up Ingress controller

```
# Install nginx-ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
```

1. Create some pre-existing resources

```
# Sample deployment for scaling/update tasks
kubectl create deployment web-frontend --image=nginx:1.21 --replicas=3 -n production

# Sample services
kubectl expose deployment web-frontend --port=80 -n production
kubectl create deployment api-service --image=nginx:alpine --replicas=2 -n production
kubectl expose deployment api-service --port=8080 -n production
```

1. Enable Metrics Server

```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# May need to add --kubelet-insecure-tls flag for local clusters
```

1. Enable SSH access to the nodes

*Ansible* part should have done it yet
```
ssh-copy-id node01
ssh-copy-id node02
ssh-copy-id node03  # if you have this worker
```

1. Set up useful aliases

```
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# Quick context switching
alias kgp="kubectl get pods"
alias kgs="kubectl get svc"
alias kgn="kubectl get nodes"

# Source autocompletion
source <(kubectl completion bash)
complete -F __start_kubectl k
```

1. Have it all in one script

```
#!/bin/bash

# Create namespaces
for ns in production development database analytics monitoring; do
  kubectl create namespace $ns 2>/dev/null || echo "Namespace $ns exists"
done

# Deploy sample apps
kubectl create deployment web-frontend --image=nginx:1.21 --replicas=3 -n production
kubectl create deployment api-service --image=nginx:alpine -n production
kubectl create deployment web-service --image=httpd:alpine -n production

kubectl expose deployment api-service --port=8080 -n production
kubectl expose deployment web-service --port=80 -n production

# Create a broken pod for troubleshooting
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  namespace: development
spec:
  containers:
  - name: nginx
    image: nginx:wrong-tag
    env:
    - name: CONFIG
      valueFrom:
        configMapKeyRef:
          name: missing-config
          key: data
EOF

echo "Lab environment prepared!"
```
