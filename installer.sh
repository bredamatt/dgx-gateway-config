#!/bin/bash

# This will install a K3S control plane locally as a systemd service, and configure it to use Cilium as the CNI. After that, a Gateway is deployed that can be proxied to via a Tailscale net

# K3S Installation
curl -sfL https://get.k3s.io | sh -s - --config=$(pwd)/config.yaml
sudo cp -i /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Add Gateway API CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml

# Add TLSRoute 
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

# Cilium Installation
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=$(dpkg --print-architecture)
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

API_SERVER_IP=127.0.0.1
API_SERVER_PORT=6443
cilium install \
  --set k8sServiceHost=${API_SERVER_IP} \
  --set k8sServicePort=${API_SERVER_PORT} \
  --set kubeProxyReplacement=true \
  --set l7Proxy=true \
  --set gatewayAPI.enabled=true \
  --set envoy.securityContext.capabilities.keepCapNetBindService=true \
  --set gatewayAPI.hostNetwork.enabled=false \
  --helm-set=operator.replicas=1

cilium status --wait

# Install the Cilium LB IP Pool
kubectl apply -f ip-pool.yaml

# Install the GatewayClass for Cilium
kubectl apply -f gatewayclass.yaml

# Create the namespace for Gateways
kubectl create ns gateway

# Install the Gateway
kubectl apply -f gateway.yaml

# Serve the gateway through the tailscale net
sudo tailscale serve --bg --https=443 http://192.168.100.240:80
