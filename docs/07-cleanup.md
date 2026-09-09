# 8. Cleanup and return to earlier modes

Stop user workloads before changing how their GPUs are exposed. These commands remove
only this repo's named test workloads.

```bash
kubectl delete -f manifests/single-vectoradd.yaml --ignore-not-found
kubectl delete -f manifests/mixed-vectoradd.yaml --ignore-not-found
kubectl delete -f manifests/time-slicing-vectoradd.yaml --ignore-not-found
kubectl delete -f manifests/persistent-gpu-worker.yaml --ignore-not-found
kubectl delete configmap -n default mig-worker-code --ignore-not-found
```

## Return to dedicated mixed profiles

```bash
kubectl label node "$GPU_NODE" nvidia.com/device-plugin.config=dedicated --overwrite
bash scripts/inspect.sh "$GPU_NODE"
```

Wait for nvidia.com/mig-3g.20gb: 1 and for the old .shared resource to disappear or become zero.
The other profile counts should stay 2 and 1. This changes resource sharing, not geometry.

## Return to seven equal partitions with single strategy

First restore seven equal physical partitions while the plugin still uses mixed strategy:

```bash
kubectl label node "$GPU_NODE" nvidia.com/mig.config=all-1g.5gb --overwrite
kubectl get node "$GPU_NODE" -L nvidia.com/mig.config,nvidia.com/mig.config.state --watch
```

Wait for all-1g.5gb / success before continuing. Then remove the external mixed device-plugin
configuration reference and change the operator strategy:

```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --version v26.7.0 \
  --reuse-values \
  --set mig.strategy=single \
  --set-string devicePlugin.config.name= \
  --set-string devicePlugin.config.default= \
  --wait \
  --timeout 10m

kubectl label node "$GPU_NODE" nvidia.com/device-plugin.config-
bash scripts/inspect.sh "$GPU_NODE"
```

Removing the config reference matters: the ConfigMap itself contains migStrategy: mixed.
Expected final count: nvidia.com/gpu: 7.

## Optional: return to a full GPU

With user GPU workloads stopped and sharing disabled:

```bash
kubectl label node "$GPU_NODE" nvidia.com/mig.config=all-disabled --overwrite
kubectl get node "$GPU_NODE" -L nvidia.com/mig.config,nvidia.com/mig.config.state --watch
```

Disabling MIG can require a reset/reboot on this cloud A100. Do not do this merely to clean
up test Pods. Leave the operator installed if you still want it to manage drivers.
