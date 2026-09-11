# A100 MIG on k3s: single, mixed, and MIG + time-slicing

A practical NVIDIA GPU Operator lab based on a A100 session.
Start with one A100 40 GB, create seven equal MIG partitions, switch to a mixed layout,
then configure four shared accesses to the 20 GB partition.

**Verified in the recorded session:** single MIG, mixed MIG, a successful CUDA
VectorAdd pod in each mode, and four Python processes sharing the 3g.20gb MIG instance.
See [validation evidence](outputs/README.md) for the distinction between recorded results
and expected Kubernetes resource counts.

## Lab environment

| Component | Recorded value |
|---|---|
| Platform | GCP Compute Engine VM; one exposed NVIDIA A100-SXM4-40GB |
| OS | Ubuntu 26.04.1 LTS |
| Kubernetes | k3s v1.36.4+k3s1 |
| Helm CLI | v4.2.4 |
| GPU Operator | v26.7.0 used in the installation instructions |
| Driver | 595.91.07, confirmed by nvidia-smi |
| Runtime integration | CDI + NVIDIA NRI plugin in the installation instructions |
| nvidia-smi CUDA version | 13.2 (driver compatibility display, not container toolkit version) |


## Learning sequence

| Stage | Physical layout |  Kubernetes resources |
|---|---|---|
| Single | 7 × 1g.5gb | nvidia.com/gpu: 7 |
| Mixed / balanced | 2 × 1g.5gb + 1 × 2g.10gb + 1 × 3g.20gb | Profile-specific counts 2, 1, 1 |
| Mixed + time-slicing | Same four hardware partitions | 1g.5gb: 2; 2g.10gb: 1; 3g.20gb.shared: 4 |

**Time-slicing does not divide the 20 GB partition into four isolated 5 GB partitions.**
Its clients share memory and execution time. MIG boundaries between separate GPU instances
remain; clients sharing one instance have no per-replica memory/fault isolation or fixed
compute percentage.

## Walkthrough

Run commands from the repository root on the lab VM, using Bash and a cluster-admin context.

1. [Prerequisites and GPU Operator installation](docs/01-install.md)
2. [Single MIG: seven equal partitions](docs/02-single-mig.md)
3. [Mixed MIG: balanced profiles](docs/03-mixed-mig.md)
4. [Time-slice only the 3g.20gb partition](docs/04-time-slicing.md)
5. [Persistent CUDA processes and nvidia-smi](docs/05-persistent-worker.md)
6. [MIG reboot and validation troubleshooting](docs/06-troubleshooting.md)
7. [NVLink and NVSwitch: what this VM exposes](docs/07-nvlink-nvswitch.md)
8. [Cleanup and restoring earlier modes](docs/08-cleanup.md)

Set these in each new shell:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide
```

Use the NAME from kubectl. The recorded node was instance-20260908-112739.
Do not select a node automatically in a multi-node cluster.

## Repository contents

| Directory | Contents |
|---|---|
| config/ | Base Helm values and stage-specific overlays |
| manifests/ | CUDA test pods, time-slicing config, and test deployments |
| scripts/ | Read-only inspection and offline validation |
| docs/ | Commands, explanations, recovery and rollback |
| outputs/ | Recorded output excerpts and separately labelled expected output |

Inspect the current state:

```bash
bash scripts/inspect.sh "$GPU_NODE"
```

The walkthrough is for the single-GPU, single-node lab. Driver-container exec commands use
a DaemonSet selector, which can choose an arbitrary pod on a multi-node cluster; select
the driver pod on your target node in that case. MIG strategy is an operator-wide setting;
MIG layout and device-plugin config labels select per-node behavior.

## References

See [official references and technical notes](docs/references.md).
