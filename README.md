# Fleet Management & Kubernetes Monitoring

This repository contains examples on how to set up Kubernetes Monitoring in Grafana Cloud using only Fleet Management
pipelines.

## Prerequisites

### Install required tools

- `helm`
- `jq`
- `kind`
- `kubectl`
- `yq`

### Create credential files

I've built the Makefile to get credentials from 1Password. If you're not me, then create the following files manually:

```shell
export FLEET_MANAGEMENT_HOST=https://fleet-management-prod-001.grafana.net
export FLEET_MANAGEMENT_USER=12345
export FLEET_MANAGEMENT_CLUSTER_TOKEN=glc_...  # This token is for reading Fleet Management pipelines
export FLEET_MANAGEMENT_MANAGER_TOKEN=glc_...  # This token is for setting Fleet Management pipelines
make credential-files
```

## Running

1. Synchronize the Fleet Management pipelines:

```shell
make sync-pipelines
```

This will synchronize the pipelines detailed in `pipelines/pipelines.yaml` to your Fleet Management instance, creating
them if necessary.

2. Create the cluster or use an existing one:

```shell
make create-cluster  # Creates a kind cluster
# or
cp /path/to/your/kubeconfig kubeconfig.yaml  # Use your existing kubeconfig
```

3. Deploy the workloads:

```shell
make deploy
```

This will deploy:

* [Alloy Operator](https://github.com/grafana/alloy-operator)
* kube-state-metrics
* Node Exporter

And three Alloy instances:

* `alloy-metrics` - For collecting metrics
* `alloy-logs` - For collecting logs
* `alloy-singleton` - For collecting Kubernetes cluster events, since it can only be deployed on a single replica

4. Access Grafana Cloud and notice that Kubernetes Monitoring is running!
