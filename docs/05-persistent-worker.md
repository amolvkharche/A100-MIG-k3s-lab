# 5. Keep CUDA processes visible in nvidia-smi

VectorAdd exits after a small calculation. In the time-slicing test each shell waits ten
seconds before launching it again, so a point-in-time process table often shows nothing.
Allocating a Kubernetes GPU resource alone does not keep a CUDA process active.

This optional worker maintains a Python process, CUDA context and three 4096 × 4096
float32 tensors (192 MiB total), and repeatedly runs matrix multiplication. NVIDIA runtime
context/library overhead adds to the memory reported by nvidia-smi. It is a lab workload,
not an inference server, training job or utilization benchmark.

The supplied session output shows four Python processes at 408 MiB each. The worker here
reproduces the same long-lived allocation pattern; it is not asserted to be the exact
program that produced that snapshot. Memory values vary by software and runtime.
The earlier HTTP networking demonstration is not required for this GPU-interconnect lab.

## Replace the short-lived sharing test

The four shared slots cannot also hold a second four-pod Deployment. Stop the earlier test:

```bash
kubectl delete -n default deployment mig-timeslice-test --ignore-not-found

kubectl create configmap mig-worker-code -n default \
  --from-file=worker.py=workloads/worker.py \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f manifests/persistent-gpu-worker.yaml
kubectl rollout status -n default deployment/mig-persistent-worker --timeout=10m
kubectl get pods -n default -l app=mig-persistent-worker -o wide
kubectl logs -n default -l app=mig-persistent-worker --prefix=true --tail=5
```

The first PyTorch image download can take several minutes. The manifests assume all four
shared slots are available. Worker output should show increasing iteration counts.

## Inspect the GPU

```bash
kubectl exec -it -n gpu-operator ds/nvidia-driver-daemonset \
  -c nvidia-driver-ctr -- nvidia-smi -l 2
```

Stop monitoring with Ctrl+C. The GPU workers continue running.

In the [recorded active snapshot](../outputs/time-slicing-nvidia-smi.txt):

| Field | Observed meaning |
|---|---|
| GPU 0 | One physical A100 |
| GI 2 | The 3g.20gb GPU instance |
| CI 0 | Its compute instance |
| PIDs 54097, 54161, 54163, 54206 | Four Python compute processes |
| 408 MiB each | Per-process GPU memory reported in this snapshot |
| 1759 / 20096 MiB | Memory usage/capacity reported for the shared GPU instance |

Four processes × 408 MiB = 1632 MiB; instance usage is not necessarily exactly the
sum of the visible rounded per-process values because driver/context/accounting overhead
can contribute. The result is evidence of shared access, not four equal memory reservations.

GPU-Util may show N/A with MIG. Do not interpret it as zero utilization.
If names/PIDs are unavailable in one container's view, inspect from a worker too:

```bash
kubectl exec -n default deployment/mig-persistent-worker -- nvidia-smi
```

PID namespace visibility matters; a PID printed by Python inside the container can
differ from the host PID reported by the driver. To inspect assigned visible MIG UUIDs:

```bash
for pod in $(kubectl get pods -n default -l app=mig-persistent-worker -o name); do
  echo "$pod"
  kubectl exec -n default "$pod" -- nvidia-smi -L
done
```

Inspect the MIG device entries, not just the enclosing physical GPU UUID. On this lab,
all four shared requests should map to the same MIG instance. Device IDs and GI IDs can
change after recreation; use current output rather than hardcoded IDs.

## Stop the workload

```bash
kubectl delete -f manifests/persistent-gpu-worker.yaml
kubectl delete configmap -n default mig-worker-code --ignore-not-found
```

This frees workload allocations without changing the MIG geometry or sharing configuration.
