# All Makefile variable are available as environment variables during target executions
.EXPORT_ALL_VARIABLES:

HMC_NAMESPACE ?= hmc-system
HMC_REPO ?= oci://ghcr.io/k0rdent/kcm/charts/hmc
HMC_VERSION ?= 0.0.6
TESTING_NAMESPACE ?= hmc-system
TARGET_NAMESPACE ?= blue
KIND_CLUSTER_NAME ?= hmc-management-local

OPENSSL_DOCKER_IMAGE ?= alpine/openssl:3.3.2

TEMPLATES_DIR := templates
TEMPLATE_FOLDERS = $(patsubst $(TEMPLATES_DIR)/%,%,$(wildcard $(TEMPLATES_DIR)/*))
CHARTS_PACKAGE_DIR ?= $(LOCALBIN)/charts
$(CHARTS_PACKAGE_DIR): | $(LOCALBIN)
	rm -rf $(CHARTS_PACKAGE_DIR)
	mkdir -p $(CHARTS_PACKAGE_DIR)

HELM_REGISTRY_INTERNAL_PORT ?= 5000
HELM_REGISTRY_EXTERNAL_PORT ?= 30500
REGISTRY_REPO ?= oci://127.0.0.1:$(HELM_REGISTRY_EXTERNAL_PORT)/helm-charts

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk command is responsible for reading the
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

# Checks if environment variable is set
.check-variable-%:
	@if [ "$($(var_name))" = "" ]; then\
		echo "Please define the $(var_description) with the $(var_name) variable";\
		exit 1;\
	fi

##@ Binaries

OS=$(shell uname | tr A-Z a-z)
ifeq ($(shell uname -m),x86_64)
	ARCH=amd64
else
	ARCH=arm64
endif

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	@mkdir -p $(LOCALBIN)

KIND ?= PATH=$(LOCALBIN):$(PATH) kind
KIND_VERSION ?= 0.25.0

HELM ?= PATH=$(LOCALBIN):$(PATH) helm
HELM_VERSION ?= v3.15.1

KUBECTL ?= PATH=$(LOCALBIN):$(PATH) kubectl

DOCKER_VERSION ?= 27.4.1

# installs binary locally
$(LOCALBIN)/%: $(LOCALBIN)
	@curl -sLo $(LOCALBIN)/$(binary) $(url);\
		chmod +x $(LOCALBIN)/$(binary);

# checks if the binary exists in the PATH and installs it locally otherwise
.check-binary-%:
	@(which "$(binary)" $ > /dev/null || test -f $(LOCALBIN)/$(binary)) \
		|| (echo "Can't find the $(binary) in path, installing it locally" && make $(LOCALBIN)/$(binary))

.check-binary-docker:
	@if ! which docker $ > /dev/null; then \
		if [ "$(OS)" = "linux" ]; then \
			curl -sLO https://download.docker.com/linux/static/stable/$(shell uname -m)/docker-$(DOCKER_VERSION).tgz;\
			tar xzvf docker-$(DOCKER_VERSION).tgz; \
			sudo cp docker/* /usr/bin/ ; \
			echo "Starting docker daemon..." ; \
			sudo dockerd > /dev/null 2>&1 & sudo groupadd docker ; \
			sudo usermod -aG docker $(shell whoami) ; \
			newgrp docker ; \
			echo "Docker engine installed and started"; \
		else \
			echo "Please install docker before proceeding. If your work on machine with MacOS, check this installation guide: https://docs.docker.com/desktop/setup/install/mac-install/" && exit 1; \
		fi; \
	fi;

%kind: binary = kind
%kind: url = "https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-$(OS)-$(ARCH)"
%kubectl: binary = kubectl
%kubectl: url = "https://dl.k8s.io/release/$(shell curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(OS)/$(ARCH)/kubectl"
%helm: binary = helm

.PHONY: kind
kind: $(LOCALBIN)/kind ## Install kind binary locally if necessary

.PHONY: helm
helm: $(LOCALBIN)/helm ## Install helm binary locally if necessary
HELM_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
$(LOCALBIN)/helm: | $(LOCALBIN)
	rm -f $(LOCALBIN)/helm-*
	curl -s --fail $(HELM_INSTALL_SCRIPT) | USE_SUDO=false HELM_INSTALL_DIR=$(LOCALBIN) DESIRED_VERSION=$(HELM_VERSION) BINARY_NAME=helm PATH="$(LOCALBIN):$(PATH)" bash



##@ General Setup

KIND_CLUSTER_CONFIG_PATH ?= $(LOCALBIN)/kind-cluster.yaml
$(KIND_CLUSTER_CONFIG_PATH): $(LOCALBIN)
	@cat setup/kind-cluster.yaml | envsubst > $(LOCALBIN)/kind-cluster.yaml

.PHONY: bootstrap-kind-cluster
bootstrap-kind-cluster: .check-binary-docker .check-binary-kind .check-binary-kubectl $(KIND_CLUSTER_CONFIG_PATH) ## Provision local kind cluster
bootstrap-kind-cluster: ## Provision local kind cluster
	@if $(KIND) get clusters | grep -q $(KIND_CLUSTER_NAME); then\
		echo "$(KIND_CLUSTER_NAME) kind cluster already installed";\
	else\
		$(KIND) create cluster --name=$(KIND_CLUSTER_NAME) --config=$(KIND_CLUSTER_CONFIG_PATH);\
	fi
	@$(KUBECTL) config use-context kind-$(KIND_CLUSTER_NAME)

.PHONY: deploy-2a
deploy-2a: .check-binary-helm ## Deploy 2A to the management cluster
	$(HELM) install hmc $(HMC_REPO) --version $(HMC_VERSION) -n $(HMC_NAMESPACE) --create-namespace

.PHONY: setup-helmrepo
setup-helmrepo: ## Deploy local helm repository and register it in 2A
	@envsubst < setup/helmRepository.yaml | $(KUBECTL) apply -f -

.PHONY: push-helm-charts
push-helm-charts: helm-push ## Push helm charts with custom Cluster and Service templates

##@ Infra Setup

# AWS
.%-aws-access-key: var_name = AWS_ACCESS_KEY_ID
.%-aws-access-key: var_description = AWS access key ID
.%-aws-secret-access-key: var_name = AWS_SECRET_ACCESS_KEY
.%-aws-secret-access-key: var_description = AWS secret access key

.PHONY: setup-aws-creds
setup-aws-creds: .check-variable-aws-access-key .check-variable-aws-secret-access-key ## Setup AWS credentials
	envsubst < setup/aws-credentials.yaml | kubectl apply -f -

# Azure
.%-azure-sp-password: var_name = AZURE_SP_PASSWORD
.%-azure-sp-password: var_description = Azure Service Principal password
.%-azure-sp-app-id: var_name = AZURE_SP_APP_ID
.%-azure-sp-app-id: var_description = Azure Service Principal App ID
.%-azure-sp-tenant-id: var_name = AZURE_SP_TENANT_ID
.%-azure-sp-tenant-id: var_description = Azure Service Principal Tenant ID

.PHONY: setup-azure-creds
setup-azure-creds: .check-variable-azure-sp-password .check-variable-azure-sp-app-id .check-variable-azure-sp-tenant-id ## Setup Azure credentials
	envsubst < setup/azure-credentials.yaml | kubectl apply -f -

##@ TBD

# install-template will install a given template
# $1 - yaml file
define install-template
	kubectl apply -f $(1)
endef

.PHONY: install-clustertemplate-demo-aws-standalone-cp-0.0.1
install-clustertemplate-demo-aws-standalone-cp-0.0.1:
	$(call install-template,templates/cluster/demo-aws-standalone-cp-0.0.1.yaml)

.PHONY: install-clustertemplate-demo-aws-standalone-cp-0.0.2
install-clustertemplate-demo-aws-standalone-cp-0.0.2:
	$(call install-template,templates/cluster/demo-aws-standalone-cp-0.0.2.yaml)

.PHONY: install-servicetemplate-demo-ingress-nginx-4.11.0
install-servicetemplate-demo-ingress-nginx-4.11.0:
	$(call install-template,templates/service/demo-ingress-nginx-4.11.0.yaml)

.PHONY: install-servicetemplate-demo-ingress-nginx-4.11.3
install-servicetemplate-demo-ingress-nginx-4.11.3:
	$(call install-template,templates/service/demo-ingress-nginx-4.11.3.yaml)

.PHONY: install-servicetemplate-demo-kyverno-3.2.6
install-servicetemplate-demo-kyverno-3.2.6:
	$(call install-template,templates/service/demo-kyverno-3.2.6.yaml)

# apply-managed-cluster-yaml will apply a given cluster yaml
# $1 - target namespace
# $2 - clustername
# $3 - yaml file
define apply-managed-cluster-yaml
	@echo "applying: "
	@NAMESPACE=$(1) CLUSTERNAME=$(2) envsubst < $(3)  | KUBECTL_EXTERNAL_DIFF="diff --color -N -u" kubectl diff  -f - || true
	@echo
	NAMESPACE=$(1) CLUSTERNAME=$(2) envsubst < $(3) | kubectl apply -f -
endef

# apply-managed-cluster-yaml-platform-engineer1 will apply a given cluster yaml as platform-engineer1
# $1 - target namespace
# $2 - clustername
# $3 - yaml file
define apply-managed-cluster-yaml-platform-engineer1
	@echo "applying: "
	@NAMESPACE=$(1) CLUSTERNAME=$(2) envsubst < $(3)  | KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" KUBECTL_EXTERNAL_DIFF="diff --color -N -u" kubectl diff  -f - || true
	@echo
	NAMESPACE=$(1) CLUSTERNAME=$(2) envsubst < $(3) | KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" kubectl apply -f -
endef

.PHONY: apply-aws-test1-0.0.1
apply-aws-test1-0.0.1:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,managedClusters/aws/0.0.1.yaml)

.PHONY: watch-aws-test1
watch-aws-test1:
	kubectl get -n $(TESTING_NAMESPACE) ManagedCluster.hmc.mirantis.com hmc-system-aws-test1 --watch

.PHONY: apply-aws-test1-0.0.1-ingress
apply-aws-test1-0.0.1-ingress:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,managedClusters/aws/0.0.1-ingress.yaml)

.PHONY: get-kubeconfig-aws-test1
get-kubeconfig-aws-test1:
	kubectl -n $(TESTING_NAMESPACE) get secret hmc-system-aws-test1-kubeconfig -o jsonpath='{.data.value}' | base64 -d > kubeconfigs/hmc-system-aws-test1.kubeconfig

.PHONY: apply-aws-test1-0.0.2
apply-aws-test1-0.0.2:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,managedClusters/aws/0.0.2.yaml)

.PHONY: apply-aws-test1-0.0.2-ingress
apply-aws-test1-0.0.2-ingress:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,managedClusters/aws/0.0.2-ingress.yaml)


.PHONY: apply-aws-test2-0.0.1
apply-aws-test2-0.0.1:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test2,managedClusters/aws/0.0.1.yaml)

.PHONY: watch-aws-test2
watch-aws-test2:
	kubectl get -n $(TESTING_NAMESPACE) ManagedCluster.hmc.mirantis.com hmc-system-aws-test2 --watch

.PHONY: apply-aws-test2-0.0.1-ingress
apply-aws-test2-0.0.1-ingress:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test2,managedClusters/aws/0.0.1-ingress.yaml)

.PHONY: get-kubeconfig-aws-test2
get-kubeconfig-aws-test2:
	kubectl -n $(TESTING_NAMESPACE) get secret hmc-system-aws-test2-kubeconfig -o jsonpath='{.data.value}' | base64 -d > kubeconfigs/hmc-system-aws-test2.kubeconfig

.PHONY: apply-aws-test2-0.0.2
apply-aws-test2-0.0.2:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test2,managedClusters/aws/0.0.2.yaml)

.PHONY: apply-aws-test2-0.0.2-ingress
apply-aws-test2-0.0.2-ingress:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test2,managedClusters/aws/0.0.2-ingress.yaml)

.PHONY: apply-aws-prod1-0.0.1
apply-aws-prod1-0.0.1:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),prod1,managedClusters/aws/0.0.1.yaml)

.PHONY: apply-aws-prod1-ingress-0.0.1
apply-aws-prod1-ingress-0.0.1:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),prod1,managedClusters/aws/0.0.1-ingress.yaml)

.PHONY: apply-aws-prod1-0.0.2
apply-aws-prod1-0.0.2:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),prod1,managedClusters/aws/0.0.2.yaml)

.PHONY: apply-aws-prod1-ingress-0.0.2
apply-aws-prod1-ingress-0.0.2:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),prod1,managedClusters/aws/0.0.2-ingress.yaml)


.PHONY: apply-aws-dev1-0.0.1
apply-aws-dev1-0.0.1:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),dev1,managedClusters/aws/0.0.1.yaml)

.PHONY: get-kubeconfig-aws-dev1
get-kubeconfig-aws-dev1:
	KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" kubectl -n $(TARGET_NAMESPACE) get secret blue-aws-test1-kubeconfig -o jsonpath='{.data.value}' | base64 -d > kubeconfigs/$(TARGET_NAMESPACE)-aws-dev1.kubeconfig

.PHONY: apply-aws-dev1-ingress-0.0.1
apply-aws-dev1-ingress-0.0.1:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),dev1,managedClusters/aws/0.0.1-ingress.yaml)


.PHONY: apply-aws-dev1-0.0.2
apply-aws-dev1-0.0.2:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),dev1,managedClusters/aws/0.0.2.yaml)

.PHONY: apply-aws-dev1-ingress-0.0.2
apply-aws-dev1-ingress-0.0.2:
	$(call apply-managed-cluster-yaml-platform-engineer1,$(TARGET_NAMESPACE),dev1,managedClusters/aws/0.0.2-ingress.yaml)


.PHONY: apply-azure-test1-0.0.1
apply-azure-test1-0.0.1:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-test1-0.0.2
apply-azure-test1-0.0.2:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/2-0.0.2.yaml)

.PHONY: apply-azure-test1-ingress-0.0.2
apply-azure-test1-ingress-0.0.2:
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/3-ingress-0.0.2.yaml)


.PHONY: apply-azure-prod1-0.0.1
apply-azure-prod1-0.0.1:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-prod1-0.0.2
apply-azure-prod1-0.0.2:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/2-0.0.2.yaml)

.PHONY: apply-azure-prod1-ingress-0.0.2
apply-azure-prod1-ingress-0.0.2:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/3-ingress-0.0.2.yaml)


.PHONY: apply-azure-dev1-0.0.1
apply-azure-dev1-0.0.1:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-dev1-0.0.2
apply-azure-dev1-0.0.2:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/2-0.0.2.yaml)

.PHONY: apply-azure-dev1-ingress-0.0.2
apply-azure-dev1-ingress-0.0.2:
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/3-ingress-0.0.2.yaml)


apply-multiclusterservice-global-kyverno:
	KUBECTL_EXTERNAL_DIFF="diff --color -N -u" kubectl -n $(TESTING_NAMESPACE) diff -f MultiClusterServices/1-global-kyverno.yaml || true
	kubectl -n $(TESTING_NAMESPACE) apply -f MultiClusterServices/1-global-kyverno.yaml

.PHONY: approve-clustertemplatechain-aws-standalone-cp-0.0.1
approve-clustertemplatechain-aws-standalone-cp-0.0.1:
	$(call approve-clustertemplatechain,$(TARGET_NAMESPACE),demo-aws-standalone-cp-0.0.1)

.PHONY: approve-clustertemplatechain-aws-standalone-cp-0.0.2
approve-clustertemplatechain-aws-standalone-cp-0.0.2:
	$(call approve-clustertemplatechain,$(TARGET_NAMESPACE),demo-aws-standalone-cp-0.0.2)


# approve-clustertemplatechain will approve a clustertemplate in a namespace
# $1 - target namespace
# $2 - templatename
define approve-clustertemplatechain
	kubectl -n $(TESTING_NAMESPACE) patch AccessManagement hmc --type='json' -p='[ \
		{ "op": "add", "path": "/spec/accessRules", "value": [] }, \
		{ \
			"op": "add", \
			"path": "/spec/accessRules/-", \
			"value": { \
				"clusterTemplateChains": ["$(2)"], \
				"targetNamespaces": { \
					"list": ["$(1)"] \
				} \
			} \
		} \
	]'
endef

# approve-servicetemplatechain will approve a servicetemplatechain in a namespace
# $1 - target namespace
# $2 - templatename
define approve-servicetemplatechain
	kubectl -n $(TESTING_NAMESPACE) patch AccessManagement hmc --type='json' -p='[ \
		{ "op": "add", "path": "/spec/accessRules", "value": [] }, \
		{ \
			"op": "add", \
			"path": "/spec/accessRules/-", \
			"value": { \
				"serviceTemplateChains": ["$(2)"], \
				"targetNamespaces": { \
					"list": ["$(1)"] \
				} \
			} \
		} \
	]'
endef

.PHONY: approve-templatechain-demo-ingress-nginx-4.11.0
approve-templatechain-demo-ingress-nginx-4.11.0:
	$(call approve-servicetemplatechain,$(TARGET_NAMESPACE),demo-ingress-nginx-4.11.0)

.PHONY: approve-templatechain-demo-ingress-nginx-4.11.3
approve-templatechain-demo-ingress-nginx-4.11.3:
	$(call approve-servicetemplatechain,$(TARGET_NAMESPACE),demo-ingress-nginx-4.11.3)

# approve-credential will approve a credential in a namespace
# $1 - target namespace
# $2 - credentialname
define approve-credential
	kubectl -n $(TESTING_NAMESPACE) patch AccessManagement hmc --type='json' -p='[ \
		{ "op": "add", "path": "/spec/accessRules", "value": [] }, \
		{ \
			"op": "add", \
			"path": "/spec/accessRules/-", \
			"value": { \
				"credentials": ["$(2)"], \
				"targetNamespaces": { \
					"list": ["$(1)"] \
				} \
			} \
		} \
	]'
endef

.PHONY: approve-credential-azure
approve-credential-azure:
	$(call approve-credential,$(TARGET_NAMESPACE),azure-cluster-identity-cred)

.PHONY: approve-credential-aws
approve-credential-aws:
	$(call approve-credential,$(TARGET_NAMESPACE),aws-cluster-identity-cred)

.PHONY: create-target-namespace-rolebindings
create-target-namespace-rolebindings:
	kubectl get namespace $(TARGET_NAMESPACE) > /dev/null 2>&1 || kubectl create namespace $(TARGET_NAMESPACE)
	TARGET_NAMESPACE=$(TARGET_NAMESPACE) envsubst < rolebindings.yaml | kubectl apply -f -

certs/ca/ca.crt:
	mkdir -p certs/ca
	docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.crt certs/ca/ca.crt

certs/ca/ca.key:
	mkdir -p certs/ca
	docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.key certs/ca/ca.key

certs/platform-engineer1/platform-engineer1.key:
	mkdir -p certs/platform-engineer1
	docker run -v ./certs:/certs $(OPENSSL_DOCKER_IMAGE) genrsa -out /certs/platform-engineer1/platform-engineer1.key 2048

certs/platform-engineer1/platform-engineer1.csr: certs/platform-engineer1/platform-engineer1.key
	docker run -v ./certs:/certs $(OPENSSL_DOCKER_IMAGE) req -new -key /certs/platform-engineer1/platform-engineer1.key -out /certs/platform-engineer1/platform-engineer1.csr -subj '/CN=platform-engineer1/O=$(TARGET_NAMESPACE)'

certs/platform-engineer1/platform-engineer1.crt: certs/platform-engineer1/platform-engineer1.csr certs/ca/ca.crt certs/ca/ca.key
	docker run -v ./certs:/certs $(OPENSSL_DOCKER_IMAGE) x509 -req -in /certs/platform-engineer1/platform-engineer1.csr -CA /certs/ca/ca.crt -CAkey /certs/ca/ca.key -CAcreateserial -out /certs/platform-engineer1/platform-engineer1.crt -days 360

##@ Cleanup

.PHONY: cleanup-clusters
cleanup-clusters: clean-certs ## Tear down managed cluster
	# use the explicit --context option to be specific about which cluster should be used to prevent disaster
	kubectl --context=kind-$(KIND_CLUSTER_NAME) delete managedclusters.hmc.mirantis.com -n $(HMC_NAMESPACE) --all

.PHONY: cleanup
cleanup: cleanup-clusters clean-certs ## Tear down management cluster
	@if $(KIND) get clusters | grep -q $(KIND_CLUSTER_NAME); then\
		$(KIND) kind delete cluster --name=$(KIND_CLUSTER_NAME);\
	else\
		echo "Can't find kind cluster with the name $(KIND_CLUSTER_NAME)";\
	fi

.PHONY: clean-certs
clean-certs:
	rm -rf certs/ca
	rm -rf certs/platform-engineer

.PHONY: generate-platform-engineer1-kubeconfig
generate-platform-engineer1-kubeconfig: certs/platform-engineer1/platform-engineer1.crt
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) USER_NAME=platform-engineer1 USER_CRT=$$(cat certs/platform-engineer1/platform-engineer1.crt | base64) USER_KEY=$$(cat certs/platform-engineer1/platform-engineer1.key | base64)  CA_CRT=$$(cat certs/ca/ca.crt | base64) CLUSTER_HOST_PORT=$$(docker port $(KIND_CLUSTER_NAME)-control-plane 6443) envsubst < certs/kubeconfig-template.yaml > certs/platform-engineer1/kubeconfig.yaml
	@echo "Config exported to certs/platform-engineer1/kubeconfig.yaml"

.PHONY: helm-package
helm-package: $(CHARTS_PACKAGE_DIR) .check-binary-helm
	@make $(patsubst %,package-%-tmpl,$(TEMPLATE_FOLDERS))

TEAMPLATES = $(patsubst $(TEMPLATES_DIR)/%,%,$(wildcard $(TEMPLATES_DIR)/*))

lint-chart-%:
	$(HELM) dependency update $(TEMPLATES_SUBDIR)/$*
	$(HELM) lint --strict $(TEMPLATES_SUBDIR)/$*

package-%-tmpl:
	@make TEMPLATES_SUBDIR=$(TEMPLATES_DIR)/$* $(patsubst %,package-chart-%,$(shell find $(TEMPLATES_DIR)/$* -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))


package-chart-%: lint-chart-%
	$(HELM) package --destination $(CHARTS_PACKAGE_DIR) $(TEMPLATES_SUBDIR)/$*

.PHONY: helm-push
helm-push: helm-package
	@for chart in $(CHARTS_PACKAGE_DIR)/*.tgz; do \
		base=$$(basename $$chart .tgz); \
		chart_version=$$(echo $$base | grep -o "v\{0,1\}[0-9]\+\.[0-9]\+\.[0-9].*"); \
		chart_name="$${base%-"$$chart_version"}"; \
		echo "Verifying if chart $$chart_name, version $$chart_version already exists in $(REGISTRY_REPO)"; \
		chart_exists=$$($(HELM) show chart $(REGISTRY_REPO)/$$chart_name --version $$chart_version 2>&1 | grep "failed to download" || true); \
		if [ -z "$$chart_exists" ]; then \
			echo "Chart $$chart_name version $$chart_version already exists in the repository."; \
		else \
			echo "Pushing $$chart to $(REGISTRY_REPO)"; \
			$(HELM) push "$$chart" $(REGISTRY_REPO); \
		fi; \
	done
