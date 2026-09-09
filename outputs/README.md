# Recorded evidence and expected outcomes

The terminal results in this directory were supplied by the lab operator during the
8 September 2026 session. They are not synthetic benchmark output.

| File / result | Evidence |
|---|---|
| [single-nvidia-smi.txt](single-nvidia-smi.txt) | 12:11:13; seven 1g.5gb instances, no active process |
| [mixed-nvidia-smi-L.txt](mixed-nvidia-smi-L.txt) | Four MIG devices: 3g.20gb, 2g.10gb, 1g.5gb, 1g.5gb |
| [mixed-nvidia-smi.txt](mixed-nvidia-smi.txt) | 12:42:21; four-instance layout, no active process |
| [time-slicing-nvidia-smi.txt](time-slicing-nvidia-smi.txt) | 12:47:35; four Python PIDs on GPU 0 / GI 2 / CI 0 |
| [vectoradd-passed.txt](vectoradd-passed.txt) | Same successful CUDA output was provided for single and mixed tests |

The three nvidia-smi tables preserve the supplied values. Trailing whitespace is normalized;
the last two supplied excerpts omit the final process-table border. UUIDs in the separate
mixed -L example are deliberately replaced, and its header says so. GI numbering changed
between configurations: compare the layout/profile, not an assumed stable GI number.

## What the session established

- Single layout state success and nvidia.com/gpu allocatable count 7 were captured.
- A pod using nvidia.com/gpu: 1 ran VectorAdd successfully under single strategy.
- Mixed / all-balanced state success and the four physical partitions were captured.
- A pod using nvidia.com/mig-2g.10gb: 1 ran VectorAdd successfully.
- The later active table shows four independent Python CUDA processes sharing GI 2,
  whose capacity is 20096 MiB and whose 42 SMs identify the 3g.20gb instance here.

The final Kubernetes allocatable listing after time-slicing and a pod-to-MIG UUID mapping
were not supplied. A process table alone does not establish pod ownership, replica admission
limits, scheduling fairness or memory isolation. Capture those separately with the commands
in the walkthrough.

## Expected counts (not a captured terminal transcript)

| Stage | Expected nonzero allocatable resources |
|---|---|
| Single | nvidia.com/gpu: 7 |
| Mixed | nvidia.com/mig-1g.5gb: 2; nvidia.com/mig-2g.10gb: 1; nvidia.com/mig-3g.20gb: 1 |
| Mixed + sharing | nvidia.com/mig-1g.5gb: 2; nvidia.com/mig-2g.10gb: 1; nvidia.com/mig-3g.20gb.shared: 4 |

## Reading the shared snapshot

All four process rows have GPU=0, GI=2, CI=0. Their PIDs differ and each reports 408 MiB.
The other MIG instances show small baseline memory usage; they have no processes listed
in this snapshot.

The 3g.20gb name is a profile label. Actual capacity is shown as 20096 MiB; likewise,
the 2g.10gb and 1g.5gb instances show 9984 and 4864 MiB. Four time-sliced clients do not
receive four separately reserved memory budgets.

## Capture your own run

```bash
mkdir -p captures
bash scripts/inspect.sh "$GPU_NODE" | tee captures/current-state.txt
kubectl logs -n default -l app=mig-persistent-worker   --prefix=true --tail=10 | tee captures/worker-logs.txt
```

captures/ is ignored by git so you can review new output before publishing it.
