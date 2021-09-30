# AKS AppArmor Profile Loader Daemonset

One of the issues with utilizing [AppArmor in an AKS cluster](https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-cluster-security#app-armor) is loading your AppArmor profiles onto your nodes. This can be done via a simple [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/), but without some precautions you can end up in a race condition where pods can be scheduled to your node before the AppArmor profiles have been loaded.

The easiest way to work around this in AKS is to taint the nodes on creation with a special taint, then use a DaemonSet that tolerates that taint to copy the profiles, load them, and then remove the taint, which will then allow regular workloads to schedule.

To use this project, you'll need to create a ConfigMap with all of your AppArmor profiles ([an example profile is included](profiles.yaml)). From the directory where your profiles are located, execute the following command to create the `apparmor-profiles` object:

`kubectl -n kube-system create configmap apparmor-profiles --from-file=*.profile`

This project makes use of [`initContainers`](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) to copy and load the profiles, with the regular container that stays running just being an unprivileged copy of the `pause` container that Kubernetes uses in each pod. This means that the resources consumed on the node after load are effectively nil, and security is increased by dropping privileges after the profiles are loaded.

To use this method, the following configuration is required:
- An [AKS cluster](https://docs.microsoft.com/en-us/azure/aks/) with [a system pool and at least one user pool](https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools).
- [The system pool](https://docs.microsoft.com/en-us/azure/aks/use-system-pools) must have the `CriticalAddonsOnly=true:NoSchedule` taint - note that you can't change nodepool taints after the nodepool is created, so you can [add a second system node pool](https://docs.microsoft.com/en-us/azure/aks/use-system-pools#add-a-dedicated-system-node-pool-to-an-existing-aks-cluster) and then remove the original pool to add the taint in an existing cluster.
- [The user pool must have the `WaitingForAppArmorProfiles=true:NoSchedule` taint.](https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools#specify-a-taint-label-or-tag-for-a-node-pool)

A template to deploy an example cluster can be found here: [Bicep](cluster.bicep)/[ARM](cluster.json).

Resources in the manifest:
- `ClusterRole` `apparmor-profile-loader`: contains get and patch permissions on nodes to allow removal of taints.
- `ServiceAccount` `apparmor-profile-loader`: used to authenticate to the Kubernetes API and remove the taint.
- `ClusterRoleBinding` `apparmor-profile-loader`: associates the role to the service account.
- `ConfigMap` `apparmor-scripts`: contains the shell script to untaint the node.
- `DaemonSet` `apparmor-profile-loader`: this DaemonSet consists of 3 initContainers and a pause container image and is what actually loads the profiles.
  - init containers:
    - `apparmor-profiles-copy`: copies the profiles into `/etc/apparmor.d/local/apparmor-profile-loader`.
    - `apparmor-profiles-load`: uses `apparmor_parser` to load the profiles from `/etc/apparmor.d/local/apparmor-profile-loader`.
    - `node-taint-remover`: uses kubectl and the service account to remove the `WaitingForAppArmorProfiles=true:NoSchedule` taint from the node.
  - container:
    - `pause`: this container just sleeps without using any CPU or memory