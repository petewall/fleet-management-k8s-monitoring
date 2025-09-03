##@ Cluster Management
kubeconfig.yaml:
	kind create cluster --name fm-test-cluster

.PHONY: create-cluster delete-cluster
create-cluster: kubeconfig.yaml ## Create the Kubernetes cluster
delete-cluster: ## Delete the Kubernetes cluster
	kind delete cluster --name fm-test-cluster
	rm -f kubeconfig.yaml


##@ Kubernetes Deployments
deploy-alloy-operator: kubeconfig.yaml ## Deploy the Alloy Operator via Helm
	helm upgrade --install alloy-operator grafana/alloy-operator --namespace monitoring --create-namespace

deploy-kube-state-metrics: kubeconfig.yaml ## Deploy kube-state-metrics via Helm
	helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics --namespace monitoring --create-namespace

deploy-node-exporter: kubeconfig.yaml ## Deploy node-exporter via Helm
	helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter --namespace monitoring --create-namespace

deployments/remote-config-credentials.yaml: ## Create Kubernetes secret for remote config credentials
	echo "---" > $@
	kubectl create secret generic remote-config-credentials \
		--namespace monitoring \
		--from-literal=url="$(shell op read "op://Lab/Fleet Management Cluster Token/website")" \
		--from-literal=username="$(shell op read "op://Lab/Fleet Management Cluster Token/username")" \
		--from-literal=password="$(shell op read "op://Lab/Fleet Management Cluster Token/password")" \
		-o yaml --dry-run=client >> $@

deploy: kubeconfig.yaml deploy-alloy-operator deploy-kube-state-metrics deploy-node-exporter deployments/remote-config-credentials.yaml ## Deploy all components to the Kubernetes cluster
	kubectl apply -f deployments


##@ Fleet Management Pipelines
pipelines/fleet-management.yaml: ## Create Fleet Management pipeline configuration
	echo "---" > $@
	echo "host: $(shell op read "op://Lab/Fleet Management Manager Token/website")" >> $@
	echo "username: $(shell op read "op://Lab/Fleet Management Manager Token/username")" >> $@
	echo "password: $(shell op read "op://Lab/Fleet Management Manager Token/password")" >> $@

sync-pipelines: pipelines/fleet-management.yaml ## Sync Fleet Management pipelines
	./pipelines/sync-pipelines.sh


##@ General
# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
