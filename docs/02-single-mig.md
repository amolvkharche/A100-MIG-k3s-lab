# 2. Single MIG: 7 × 1g.5gb

For this A100 40 GB, use all-1g.5gb. The similarly named all-1g.10gb is not interchangeable:
profile geometry depends on the GPU model. This guide's configuration is specifically 40 GB.

Stop user GPU workloads before any geometry change. MIG Manager handles its own GPU components;
it does not make arbitrary application disruption safe.

```bash
kubectl get pods -A
kubectl get node "$GPU_NODE" -L nvidia.com/mig.capable

kubectl label node "$GPU_NODE" nvidia.com/mig.config=all-1g.5gb --overwrite
kubectl get node "$GPU_NODE" \
  -L nvidia.com/mig.strategy,nvidia.com/mig.config,nvidia.com/mig.config.state \
  --watch
```

Wait for success, then stop the watch with Ctrl+C. In the recorded run the state stayed
rebooting because a GPU reset was unsupported and the automatic reboot did not occur.
The host showed current MIG mode Disabled and pending mode Enabled.

Use [the reboot recovery](06-troubleshooting.md) if needed. After reconnecting,
restore KUBECONFIG and GPU_NODE and let driver initialization complete. Do not repeatedly reboot
while components initialize.

## Verify physical partitions and resource registration

```bash
kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi
kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi -L

kubectl get node "$GPU_NODE" \
  -o jsonpath='{.status.allocatable.nvidia\.com/gpu}{"\n"}'
```

Expected: seven MIG devices and nvidia.com/gpu: 7.
Under single strategy, each nvidia.com/gpu unit here is a MIG instance, not a whole A100.
The nvidia.com/mig.capable label describes hardware capability; it is not a resource limit
and does not, by itself, prove MIG is enabled.

## Execute CUDA

```bash
kubectl apply -f manifests/single-vectoradd.yaml
kubectl wait -n default pod/mig-vectoradd \
  --for=jsonpath='{.status.phase}'=Succeeded \
  --timeout=5m
kubectl logs -n default mig-vectoradd
```

The recorded test printed Test PASSED. It checks actual CUDA execution, not just device discovery.

If a Pod with that name already exists in a terminal state, inspect its logs and remove it
before rerunning. kubectl apply does not rerun a completed Pod.

```bash
kubectl delete -f manifests/single-vectoradd.yaml --ignore-not-found
```

See the [captured single-mode output](../outputs/single-nvidia-smi.txt).
