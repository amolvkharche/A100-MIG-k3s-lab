# 3. Mixed MIG: different partition sizes

There are two independent controls:

| Control | Job |
|---|---|
| mig.strategy=mixed | Expose MIG devices under profile-specific Kubernetes resource names |
| nvidia.com/mig.config=all-balanced | Select a physical partition layout for a node |

On the session's A100 40 GB, all-balanced produced:

| Profile | Count | Resource |
|---|---:|---|
| 1g.5gb | 2 | nvidia.com/mig-1g.5gb |
| 2g.10gb | 1 | nvidia.com/mig-2g.10gb |
| 3g.20gb | 1 | nvidia.com/mig-3g.20gb |

GPU Operator 26.3+ generates per-node MIG configurations from hardware. To inspect yours:

```bash
kubectl get configmap -n gpu-operator "${GPU_NODE}-mig-config" -o yaml
```

For older drivers/configurations, a default static ConfigMap may be used instead.
The balanced layout is model-dependent.

## Change strategy, then layout

Stop user GPU workloads. Remove the earlier test if it remains:

```bash
kubectl delete -f manifests/single-vectoradd.yaml --ignore-not-found

helm upgrade gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --version v26.7.0 \
  --reuse-values \
  -f config/mixed-values.yaml \
  --wait \
  --timeout 10m

kubectl get clusterpolicy cluster-policy \
  -o jsonpath='{.spec.mig.strategy}{"\n"}'
```

Expected strategy: mixed.

```bash
kubectl label node "$GPU_NODE" nvidia.com/mig.config=all-balanced --overwrite

kubectl get node "$GPU_NODE" \
  -L nvidia.com/mig.strategy,nvidia.com/mig.config,nvidia.com/mig.config.state \
  --watch
```

Wait for success. Changing geometry while MIG mode is already enabled normally does not
require repeating the initial mode-enable reboot. Let MIG Manager handle the change.

## Wait for resource registration too

```bash
kubectl exec -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi -L

kubectl get node "$GPU_NODE" \
  -o go-template='{{range $key, $value := .status.allocatable}}{{printf "%s: %v\n" $key $value}}{{end}}' \
  | grep nvidia.com
```

Expected nonzero counts are 2, 1 and 1 for the profiles above. nvidia.com/gpu may remain
with zero capacity because no full GPU is exposed. Geometry success can precede device-plugin
registration: the session initially showed zero counts, then successfully scheduled the
profile-specific test. Inspect pods/logs if the expected counts never appear.

## Test the 10 GB partition

```bash
kubectl apply -f manifests/mixed-vectoradd.yaml
kubectl wait -n default pod/mig-mixed-vectoradd \
  --for=jsonpath='{.status.phase}'=Succeeded \
  --timeout=5m
kubectl logs -n default mig-mixed-vectoradd
```

The limit is nvidia.com/mig-2g.10gb: 1. The session recorded Test PASSED.
Change the resource name in a new test Pod to request another advertised profile.

```bash
kubectl delete -f manifests/mixed-vectoradd.yaml --ignore-not-found
```

See [mixed-mode nvidia-smi -L](../outputs/mixed-nvidia-smi-L.txt).

For a different custom layout, follow NVIDIA's custom MIG ConfigMap guide in
[references](references.md); do not assume any combination whose g values sum to seven
is physically placeable.
