#!/usr/bin/env bash
# Read-only inspection. Pass the actual Kubernetes node name.
set -euo pipefail
if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: bash scripts/inspect.sh NODE_NAME" >&2
  exit 2
fi
gpu_lab_node="$1"
kubectl get node "$gpu_lab_node" -L nvidia.com/mig.strategy,nvidia.com/mig.config,nvidia.com/mig.config.state,nvidia.com/device-plugin.config
kubectl get node "$gpu_lab_node" -o go-template='{{range $key, $value := .status.allocatable}}{{printf "%s: %v\n" $key $value}}{{end}}' | grep '^nvidia.com/' || true
kubectl get pods -n gpu-operator -o wide
kubectl exec -n gpu-operator ds/nvidia-driver-daemonset -c nvidia-driver-ctr -- nvidia-smi
kubectl exec -n gpu-operator ds/nvidia-driver-daemonset -c nvidia-driver-ctr -- nvidia-smi -L
