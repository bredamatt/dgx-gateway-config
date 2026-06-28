# Single-Node K3s on DGX Spark

This is a single-node Kubernetes setup running on an NVIDIA DGX Spark (GB10, `aarch64`). The K3s **control plane runs as a systemd service** (`k3s.service`) and its embedded agent doubles as the worker, so one node hosts both the API server and the workloads. **Cilium** is the CNI, installed with `kubeProxyReplacement=true` and the L7 (Envoy) proxy enabled. GPU workloads run as normal pods: K3s's embedded containerd uses the **NVIDIA container runtime**, and the GB10 is shared across pods via the device plugin's **time-slicing** (the GB10 does not support MIG, so there is no hardware partitioning).

Ingress is handled by the **Cilium Gateway API**. The `Gateway` is fronted by a `type: LoadBalancer` service that gets a stable IP (`192.168.100.240`) from a `CiliumLoadBalancerIPPool` — no L2/BGP announcement is needed because nothing on the LAN reaches that IP directly. Instead, **`tailscale serve`** on the host terminates HTTPS and proxies to the Gateway locally (`http://192.168.100.240:80`, reachable on the host via Cilium's socket LB). Remote clients on the tailnet — e.g. the laptop — reach everything through the host's MagicDNS name (`https://<device>.<tailnet>.ts.net`), with routing done by path in `HTTPRoute`s.

## Networking

```
   ┌────────────────────────┐
   │  Laptop (macbook)       │
   │  on tailnet             │
   └───────────┬────────────┘
               │  https://<device>.<tailnet>.ts.net
               │  (Tailscale / WireGuard, encrypted)
               ▼
╔══════════════════════════════════════════════════════════════╗
║  DGX Spark  (GB10, aarch64)                                    ║
║                                                                ║
║    tailscaled ── serve :443  (TLS termination)                 ║
║         │                                                      ║
║         │  http://192.168.100.240:80  (local, via socket LB)   ║
║         ▼                                                      ║
║    Cilium Gateway   [LoadBalancer svc + LB-IPAM]               ║
║         │   192.168.100.240:80   (no hostname → path routing)  ║
║         ▼                                                      ║
║    HTTPRoute (path-based)                                      ║
║         │                                                      ║
║         ▼                                                      ║
║    Backend Pods ───────────────▶  GB10 GPU                     ║
║    (containerd + nvidia runtime, device-plugin time-slicing)   ║
║                                                                ║
║    ── k3s server (systemd) + embedded agent ──                 ║
║    ── Cilium CNI (kube-proxy replacement, Envoy L7) ──         ║
╚══════════════════════════════════════════════════════════════╝
```

## Install

Simply execute the installer as `sudo`:

```bash
sudo ./installer.sh
```
