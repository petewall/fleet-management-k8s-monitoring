CLUSTER_NAME := fm-test-cluster

##@ Cluster Management
kubeconfig.yaml:
	kind create cluster --name fm-test-cluster --kubeconfig $@

.PHONY: create-cluster delete-cluster
create-cluster: kubeconfig.yaml ## Create the Kubernetes cluster
delete-cluster: ## Delete the Kubernetes cluster
	kind delete cluster --name $(CLUSTER_NAME)
	rm -f kubeconfig.yaml


##@ Kubernetes Deployments
.PHONY: deploy-alloy-operator deploy-kepler deploy-kube-state-metrics deploy-node-exporter deploy-opencost deploy
deploy-alloy-operator: kubeconfig.yaml ## Deploy the Alloy Operator via Helm
	helm upgrade --install --kubeconfig kubeconfig.yaml \
		alloy-operator alloy-operator \
		--repo https://grafana.github.io/helm-charts \
		--namespace monitoring --create-namespace

deploy-kepler: kubeconfig.yaml ## Deploy Kepler via Helm
	helm upgrade --install --kubeconfig kubeconfig.yaml \
		kepler kepler \
		--repo https://sustainable-computing-io.github.io/kepler-helm-chart \
		--namespace monitoring --create-namespace

deploy-kube-state-metrics: kubeconfig.yaml ## Deploy kube-state-metrics via Helm
	helm upgrade --install --kubeconfig kubeconfig.yaml \
		kube-state-metrics kube-state-metrics \
		--repo https://prometheus-community.github.io/helm-charts \
		--namespace monitoring --create-namespace

deploy-node-exporter: kubeconfig.yaml ## Deploy node-exporter via Helm
	helm upgrade --install --kubeconfig kubeconfig.yaml \
		node-exporter prometheus-node-exporter \
		--repo https://prometheus-community.github.io/helm-charts \
		--namespace monitoring --create-namespace

deploy-opencost: kubeconfig.yaml deployments/prometheus-credentials.yaml ## Deploy OpenCost via Helm
	KUBECONFIG=kubeconfig.yaml kubectl apply -f deployments/prometheus-credentials.yaml
	helm upgrade --install --kubeconfig kubeconfig.yaml \
		opencost opencost \
		--repo https://opencost.github.io/opencost-helm-chart \
		--values opencost-values.yaml \
		--set "opencost.exporter.defaultClusterId=$(CLUSTER_NAME)" \
		--set "opencost.prometheus.external.url=${METRICS_HOST}/api/prom" \
		--namespace monitoring --create-namespace

deployments/remote-config-credentials.yaml: ## Create Kubernetes secret for remote config credentials
	echo "---" > $@
	kubectl create secret generic remote-config-credentials \
		--namespace monitoring \
		--from-literal=url="$(FLEET_MANAGEMENT_HOST)" \
		--from-literal=username="$(FLEET_MANAGEMENT_USER)" \
		--from-literal=password="$(FLEET_MANAGEMENT_CLUSTER_TOKEN)" \
		-o yaml --dry-run=client >> $@

deployments/prometheus-credentials.yaml: ## Create Kubernetes secret for remote config credentials
	echo "---" > $@
	kubectl create secret generic metrics-credentials \
		--namespace monitoring \
		--from-literal=username="$(METRICS_USER)" \
		--from-literal=password="$(METRICS_TOKEN)" \
		-o yaml --dry-run=client >> $@

deployments/cluster-config.yaml: ## Create Kubernetes configmap for cluster configuration
	echo "---" >
	kubectl create configmap cluster-config \
		--namespace monitoring \
		--from-literal clusterName=$(CLUSTER_NAME) \
		-o yaml --dry-run=client >> $@

deploy: kubeconfig.yaml deploy-alloy-operator deploy-kepler deploy-kube-state-metrics deploy-node-exporter deploy-opencost deployments/cluster-config.yaml deployments/remote-config-credentials.yaml ## Deploy all components to the Kubernetes cluster
	KUBECONFIG=kubeconfig.yaml kubectl apply -f deployments


##@ Fleet Management Pipelines
PIPELINE_TEMPLATES := $(wildcard pipelines/templates/*.alloy)
PIPELINE_FILES := $(patsubst pipelines/templates/%.alloy,pipelines/%.alloy,$(PIPELINE_TEMPLATES))

pipelines/%.alloy: pipelines/templates/%.alloy
	sed -e "s|{{ .metrics.host }}|$(METRICS_HOST)|g; \
			s|{{ .metrics.username }}|$(METRICS_USER)|g; \
			s|{{ .logs.host }}|$(LOGS_HOST)|g; \
			s|{{ .logs.username }}|$(LOGS_USER)|g" $< > $@

pipelines/fleet-management.yaml: ## Create Fleet Management pipeline configuration
	echo "---" > $@
	echo "host: $(FLEET_MANAGEMENT_HOST)" >> $@
	echo "username: $(FLEET_MANAGEMENT_USER)" >> $@
	echo "password: $(FLEET_MANAGEMENT_MANAGER_TOKEN)" >> $@

.PHONY: sync-pipelines pipelines
pipelines: $(PIPELINE_FILES)

sync-pipelines: pipelines/fleet-management.yaml $(PIPELINE_FILES) ## Sync Fleet Management pipelines
	./pipelines/sync-pipelines.sh


##@ General
.PHONY: credential-files help
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

credential-files: deployments/remote-config-credentials.yaml pipelines/fleet-management.yaml ## Create credential files

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
