# 2. Single MIG: 7 × 1g.5gb

For this A100 40 GB, use all-1g.5gb. The similarly named all-1g.10gb is not interchangeable:
profile geometry depends on the GPU model. This guide's configuration is specifically 40 GB.

Stop user GPU workloads before any geometry change. MIG Manager handles its own GPU components;
it does not make arbitrary application disruption safe.

```bash
kubectl get pods -A
kubectl get node "$GPU_NODE" -L nvidia.com/mig.capable

kubectl label node "$GPU_NODE" nvidia.com/mig.config=all-1g.5gb --overwrite

$ kubectl get node "$GPU_NODE" \
  -L nvidia.com/mig.strategy,nvidia.com/mig.config,nvidia.com/mig.config.state \
  --watch
NAME                       STATUS   ROLES           AGE     VERSION        MIG.CONFIG   MIG.CONFIG.STATE
instance-20260908-112739   Ready    control-plane   9m41s   v1.36.4+k3s1   all-1g.5gb   pending
instance-20260908-112739   Ready    control-plane   9m41s   v1.36.4+k3s1   all-1g.5gb   rebooting
instance-20260908-112739   Ready    control-plane   9m42s   v1.36.4+k3s1   all-1g.5gb   rebooting
```

Wait for success, then stop the watch with Ctrl+C. In the recorded run the state stayed
rebooting because a GPU reset was unsupported and the automatic reboot did not occur.
The host showed current MIG mode Disabled and pending mode Enabled.

Use [the reboot recovery](06-troubleshooting.md) if needed. After reconnecting,
restore KUBECONFIG and GPU_NODE and let driver initialization complete. Do not repeatedly reboot
while components initialize.

## Verify physical partitions and resource registration

```bash
$ kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi

$ kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi -L

GPU 0: NVIDIA A100-SXM4-40GB (UUID: GPU-838f60d9-651f-9166-ea42-f9da674a6947)
  MIG 1g.5gb      Device  0: (UUID: MIG-ffda444c-c706-57c6-98c9-67c441a0b109)
  MIG 1g.5gb      Device  1: (UUID: MIG-fe9bc608-60f5-5479-8cc4-1827021d27a9)
  MIG 1g.5gb      Device  2: (UUID: MIG-90075af8-1349-5b67-83b7-e31b0590b922)
  MIG 1g.5gb      Device  3: (UUID: MIG-f501d9fb-880e-50dc-8f70-f31dff6e44c9)
  MIG 1g.5gb      Device  4: (UUID: MIG-7914baf1-7eeb-5b67-adfa-f8fc35a5a0cc)
  MIG 1g.5gb      Device  5: (UUID: MIG-495535b8-7e4b-54b5-b110-eb69e35255c4)
  MIG 1g.5gb      Device  6: (UUID: MIG-a8e039b8-35d4-590b-80ab-bc9d329d2067)

$ kubectl get node "$GPU_NODE" \
  -o jsonpath='{.status.allocatable.nvidia\.com/gpu}{"\n"}'

7
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
