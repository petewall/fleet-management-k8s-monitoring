
kubeconfig.yaml:
	kind create cluster --name fm-test-cluster

.PHONY: create-cluster delete-cluster
create-cluster: kubeconfig.yaml
delete-cluster:
	kind delete cluster --name fm-test-cluster
	rm -f kubeconfig.yaml

deploy-alloy-operator: kubeconfig.yaml
	helm upgrade --install alloy-operator grafana/alloy-operator --namespace monitoring --create-namespace

deploy-kube-state-metrics: kubeconfig.yaml
	helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics --namespace monitoring --create-namespace

deploy-node-exporter: kubeconfig.yaml
	helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter --namespace monitoring --create-namespace

pipelines/fleet-management.yaml:
	echo "---" > $@
	echo "host: $(shell op read "op://Lab/Fleet Management Manager Token/website")" >> $@
	echo "username: $(shell op read "op://Lab/Fleet Management Manager Token/username")" >> $@
	echo "password: $(shell op read "op://Lab/Fleet Management Manager Token/password")" >> $@

deployments/remote-config-credentials.yaml:
	echo "---" > $@
	kubectl create secret generic remote-config-credentials \
		--namespace monitoring \
		--from-literal=url="$(shell op read "op://Lab/Fleet Management Cluster Token/website")" \
		--from-literal=username="$(shell op read "op://Lab/Fleet Management Cluster Token/username")" \
		--from-literal=password="$(shell op read "op://Lab/Fleet Management Cluster Token/password")" \
		-o yaml --dry-run=client >> $@

deploy: kubeconfig.yaml deploy-alloy-operator deploy-kube-state-metrics deploy-node-exporter deployments/remote-config-credentials.yaml
	kubectl apply -f deployments
