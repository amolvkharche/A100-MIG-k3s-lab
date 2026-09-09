# Official references

Documentation consulted on 8 September 2026. The lab pins GPU Operator v26.7.0;
latest URLs can change. Use the version selector to check the release you deploy.

| Source | Use |
|---|---|
| [GPU Operator installation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html) | Helm values, driver management, CUDA VectorAdd |
| [Platform support](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html) | OS, Kubernetes and runtime compatibility |
| [CDI and NRI](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/cdi.html) | NRI integration and runtime prerequisites |
| [GPU Operator with MIG](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html) | Node labels, reboot behavior, mixed and custom layouts |
| [Default MIG configurations](https://github.com/NVIDIA/gpu-operator/blob/main/assets/state-mig-manager/0400_configmap.yaml) | A100 40 GB all-balanced layout |
| [Time-slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html) | ConfigMap setup, reload behavior and limitations |
| [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin) | Resource naming, flags and replicas |
| [MIG support in Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/kubernetes/latest/index.html) | Meaning of single and mixed strategies |
| [Getting started with MIG](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/latest/getting-started-with-mig.html) | A100 GPU reset and VM reboot considerations |
| [nvidia-smi reference](https://docs.nvidia.com/deploy/nvidia-smi/index.html) | Process tables, MIG limitations, topology and NVLink queries |
| [Fabric Manager](https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html) | NVLink and NVSwitch background |
| [k3s advanced configuration](https://docs.k3s.io/advanced) | k3s runtime configuration |
| [GCP A2/A3 instances](https://docs.cloud.google.com/compute/docs/gpus/create-gpu-vm-accelerator-optimized) | GCP MIG-capable GPU VM context |

Sample configurations are adapted for the recorded one-node lab. Observed terminal evidence
is provided by the user; it is not a claim that every documented extension has been
executed or certified by NVIDIA, GCP, or the repository assembler.
