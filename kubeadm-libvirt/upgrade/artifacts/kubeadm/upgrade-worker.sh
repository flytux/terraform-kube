#!/bin/sh
cd "${0%/*}"
NEW_VERSION=v1.27.6
MASTER_IP=192.168.122.101
HOST_IP=$(hostname -I | awk '{print $1}')
OLD_VERSION=$(/usr/local/bin/kubeadm version | grep -oE 'v([1-9]|\.)+')

echo "=== check kubeadm plan ==="
mv /usr/local/bin/kubeadm kubeadm-$OLD_VERSION
cp ./$NEW_VERSION/kubeadm /usr/local/bin/kubeadm && chmod +x /usr/local/bin/kubeadm
kubeadm upgrade plan

echo "=== upgrade node ==="
kubeadm upgrade node 


echo "=== drain node ==="
kubectl drain $(hostname) --ignore-daemonsets
echo "=== stop kubelet.service ==="
systemctl stop kubelet.service

echo "=== copy new version kubelet and restart"
cp ./$NEW_VERSION/kubelet /usr/local/bin/kubelet && chmod +x /usr/local/bin/kubelet

echo "=== restart kubelet.service ==="
systemctl daemon-reload
systemctl restart kubelet.service

echo "=== uncordon node ==="
kubectl uncordon $(hostname)
