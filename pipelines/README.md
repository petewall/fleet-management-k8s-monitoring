# Pipelines

This directory contains Fleet Management-ready pipelines for gathering Kubernetes infrastructure observability data.

You may need to adjust the hostname and username for the prometheus remote_write component if you're going to deploy to
your own stack.

## Pipeline files

- `cadvisor.alloy` - Collects Kubernetes container metrics from cAdvisor.
- `kubelet.alloy` - Collects Kubernetes node and pod metrics from the Kubelet.
- `kube-state-metrics.alloy` - Collects Kubernetes cluster state metrics from kube-state-metrics.
- `node-exporter.alloy` - Collects host-level metrics from Node Exporter.
- `cluster-events.alloy` - Collects Kubernetes cluster events.
- `pod-logs.alloy` - Collects Kubernetes pod logs.

## Supplemental files

- `pipelines.yaml` - Contains the metadata for the pipelines including name, and matchers.
- `fleet-management.yaml` - Contains the host, username, and password for your Fleet Management
  instance. This is git-ignored, but created with `make pipelines/fleet-management.yaml`.
- `sync-pipelines.sh` - A script to sync the pipelines to your Fleet Management instance.
