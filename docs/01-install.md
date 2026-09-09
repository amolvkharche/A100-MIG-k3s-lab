# 1. Install NVIDIA GPU Operator

This begins from an existing k3s cluster on A100 node.
The lab did not capture the k3s provisioning command, so provisioning is outside this repo.

## Preflight

As root, from the repository root:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export GPU_NODE="YOUR_KUBERNETES_NODE_NAME"

cat /etc/os-release
uname -r
kubectl get nodes -o wide
helm version --short
command -v nvidia-smi || true
kubectl get pods -A | grep -Ei 'nvidia|gpu-operator' || true

apt-get update
apt-get install -y pciutils linux-headers-$(uname -r)

$ lspci -nn | grep -i nvidia
00:04.0 3D controller [0302]: NVIDIA Corporation GA100 [A100 SXM4 40GB] [10de:20b0] (rev a1)

ls -l /var/run/nri/nri.sock
```

Use a boot disk with headroom for image pulls, unpacked images, drivers and logs.
Model weights and larger images need additional capacity.

The supplied values use CDI + NRI. NVIDIA's documentation lists containerd 1.7.30,
2.1.x, 2.2.x and 2.3.x for its NRI integration, and separately lists supported OS/runtime
combinations. For this Ubuntu 26.04 route, verify a supported 2.1–2.3 runtime,
CDI and NRI enabled, and the NRI socket present. A socket alone does not prove all prerequisites.
If these checks differ, consult the references and adapt runtime integration before installing.
Do not install a second standalone containerd alongside k3s.

No host driver was installed in this session. On a system with an existing working driver,
set driver.enabled=false and consult the preinstalled-driver guidance instead of installing
a competing host driver. The published support matrix lists Helm v3; Helm v4.2.4 was the
CLI reported in this session, which does not establish general Helm v4 vendor validation.

## Install

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --version v26.7.0 \
  -f config/gpu-operator-values.yaml \
  --wait \
  --timeout 20m

kubectl get pods -n gpu-operator
kubectl get clusterpolicy

$ kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi

Tue Sep  8 11:50:21 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.91.07              Driver Version: 595.91.07      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA A100-SXM4-40GB          On  |   00000000:00:04.0 Off |                    0 |
| N/A   34C    P0             46W /  400W |       0MiB /  40960MiB |      0%      Default |
|                                         |                        |             Disabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+

```

The driver is managed in a container, so host-shell nvidia-smi may still be unavailable.
Use the driver-container exec commands throughout this guide.

The base values enable MIG Manager and use the single strategy; they do not create
partitions yet. WITH_REBOOT=true lets MIG Manager request a node reboot when needed.
On a one-node control plane a reboot interrupts SSH and the Kubernetes API.

## Continue

Proceed to [single MIG](02-single-mig.md) only after driver and toolkit initialization
succeed. Ready daemon pods should have all regular containers ready; finished CUDA
validation pods may be Completed.
