# 4. Time-slice the 3g.20gb MIG instance

The session later recorded four Python processes on GPU 0 / GI 2 / CI 0, the 3g.20gb
MIG instance. See [the captured process table](../outputs/time-slicing-nvidia-smi.txt).
That confirms multiple active CUDA processes on one instance. The resource counts below
are expected configuration outcomes; a final allocatable listing and per-pod UUID mapping
were not supplied. The assembled manifests still need to be executed on your own cluster.

Keep mixed strategy and all-balanced geometry. Expose the one 3g.20gb instance as four
schedulable shared accesses. The 1g.5gb and 2g.10gb resources remain dedicated.

| Resource after configuration | Expected count |
|---|---:|
| nvidia.com/mig-1g.5gb | 2 |
| nvidia.com/mig-2g.10gb | 1 |
| nvidia.com/mig-3g.20gb.shared | 4 |

This does not create more MIG instances. nvidia-smi -L should still show four.
Each client shares the 20 GB instance's memory and compute; there is no reserved
5 GB per client and no guaranteed 25% compute share. Isolation between different MIG
instances remains, but not between replicas sharing the same instance.
Requesting extra replicas does not buy proportionally more compute.

## Apply the config to this node

Stop user workloads using the resource being changed. The following config has two keys:
dedicated (no sharing) and share-3g (four replicas). The default stays dedicated until
the node label selects share-3g.

```bash
kubectl apply -f manifests/time-slicing-config.yaml

helm upgrade gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --version v26.7.0 \
  --reuse-values \
  -f config/mixed-values.yaml \
  -f config/time-slicing-values.yaml \
  --wait \
  --timeout 10m

kubectl label node "$GPU_NODE" nvidia.com/device-plugin.config=share-3g --overwrite
```

The shared resource list contains only nvidia.com/mig-3g.20gb. renameByDefault=true adds
.shared to its advertised name. failRequestsGreaterThanOne=true rejects requests for more
than one shared replica per container. If there were multiple physical 3g.20gb instances
on this node, the factor would apply to every instance of that resource type, not one chosen UUID.

## Verify

```bash
kubectl get pods -n gpu-operator
kubectl get node "$GPU_NODE" -L nvidia.com/device-plugin.config
kubectl get node "$GPU_NODE" \
  -o go-template='{{range $key, $value := .status.allocatable}}{{printf "%s: %v\n" $key $value}}{{end}}' \
  | grep nvidia.com
```

Wait for the counts above before deploying. Old resource names can linger with zero capacity.

## Four CUDA clients

```bash
kubectl apply -f manifests/time-slicing-vectoradd.yaml
kubectl rollout status -n default deployment/mig-timeslice-test --timeout=5m
kubectl get pods -n default -l app=mig-timeslice-test -o wide
kubectl logs -n default -l app=mig-timeslice-test \
  --all-containers=true --prefix=true --tail=8
```

Expected: four running pods, each with Test PASSED in its logs. The manifest requests
nvidia.com/mig-3g.20gb.shared: 1 per pod. This checks shared CUDA access; it is not a
performance, fairness, memory-isolation, or simultaneous-kernel benchmark.

For a scheduling-capacity experiment, scale to five replicas:

```bash
kubectl scale -n default deployment/mig-timeslice-test --replicas=5
kubectl get pods -n default -l app=mig-timeslice-test
```

On this one-node lab, if no other shared clients run, expect four running pods and one pending.
Inspect the pending pod's Events for insufficient shared resources, then return to four:

```bash
kubectl scale -n default deployment/mig-timeslice-test --replicas=4
```

## Editing replicas later

After editing the existing ConfigMap, restart the device plugin and GPU feature discovery
so the change is reread:

```bash
kubectl apply -f manifests/time-slicing-config.yaml
kubectl rollout restart -n gpu-operator daemonset/nvidia-device-plugin-daemonset
kubectl rollout restart -n gpu-operator daemonset/gpu-feature-discovery
```

The Operator does not automatically watch the ConfigMap contents for this change.
Make edits with user GPU workloads stopped and verify counts again.

## Observability limitation

NVIDIA documents that DCGM Exporter cannot associate GPU metrics to individual containers
when device-plugin time-slicing is enabled. Do not interpret a shared instance's aggregate
utilization as accurate per-pod attribution.

For long-lived GPU processes, continue to [the persistent worker](05-persistent-worker.md).
For rollback, see [cleanup](08-cleanup.md).
