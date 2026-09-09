# 6. MIG reboot and validation troubleshooting

## A100 mode is pending and reset is unsupported

The session observed:

```text
NVIDIA A100-SXM4-40GB, Disabled, Enabled
Resetting GPU 00000000:00:04.0 is not supported.
```

On an A100 passthrough VM, enabling MIG can require rebooting the guest when the
hypervisor cannot provide a GPU reset. MIG Manager's rebooting label records the requested
state; it does not prove a reboot occurred. Even a log saying "Successfully updated"
at this point does not prove partitions are ready.

Read the latest state:

```bash
uptime -s
kubectl logs -n gpu-operator ds/nvidia-mig-manager \
  -c nvidia-mig-manager --timestamps --tail=120

kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- \
  nvidia-smi --query-gpu=name,mig.mode.current,mig.mode.pending --format=csv
```

In the session the boot time was 11:39:24 and the request was 11:51:52; the VM had not
rebooted when the logs were collected. With current Disabled / pending Enabled and a
reboot still outstanding, the successful recovery was:

```bash
systemctl reboot
```

This interrupts the single-node control plane and SSH. Reconnect, restore your environment
variables and wait for initialization:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export GPU_NODE="YOUR_KUBERNETES_NODE_NAME"

kubectl get pods -n gpu-operator
kubectl wait -n gpu-operator --for=condition=Ready pod \
  -l app=nvidia-driver-daemonset --timeout=300s

kubectl get node "$GPU_NODE" -L nvidia.com/mig.config,nvidia.com/mig.config.state
```

Expected: current Enabled / pending Enabled, then geometry state success. In the recorded
recovery some pods temporarily showed Unknown or 0/1 while drivers initialized.
If initialization fails, collect current logs before attempting another reboot.

## Driver or validator not ready

```bash
kubectl logs -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr --timestamps --tail=100
kubectl get pods -n gpu-operator
kubectl get events -n gpu-operator --sort-by=.metadata.creationTimestamp | tail -25
kubectl describe pod -n gpu-operator YOUR_VALIDATOR_POD
```

Inspect the failing init container's logs by its name from describe.
Running does not necessarily mean all containers are ready.
After the underlying failure is corrected, a terminated validation test may need to be
removed, and a stuck operator-validator pod can be recreated by its DaemonSet.
Use exact pod names from current output; do not delete all GPU components indiscriminately.

## Configuration success but resources are zero

Physical reconfiguration and device-plugin registration finish at different times.
The mixed-mode session briefly reported nvidia.com/gpu: 0 and nvidia.com/mig-1g.5gb: 0,
then successfully ran a pod requesting nvidia.com/mig-2g.10gb: 1.

```bash
kubectl get pods -n gpu-operator
kubectl logs -n gpu-operator ds/nvidia-device-plugin-daemonset \
  -c nvidia-device-plugin --tail=100
kubectl get node "$GPU_NODE" \
  -o go-template='{{range $key, $value := .status.allocatable}}{{printf "%s: %v\n" $key $value}}{{end}}' \
  | grep nvidia.com
```

A persistent zero count needs investigation; do not treat it as proof the resources are ready.

## Pod Pending

Read its actual scheduling reason before changing resource names or tolerations:

```bash
kubectl describe pod -n default YOUR_POD_NAME
kubectl get node "$GPU_NODE" \
  -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}'
kubectl get nodes
```

Use nvidia.com/gpu for the single stage, named MIG resources for mixed, and the .shared
name for the time-sliced 3g instance. Requests exceeding available slots remain Pending.
No blanket toleration is included in these lab manifests.

## Completed / failed test pods

Applying an unchanged completed Pod does not rerun it. Inspect logs, delete that test,
then reapply its manifest. A failed CUDA test needs its logs and Events inspected first.
