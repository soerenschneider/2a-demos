HMC_NAMESPACE ?= hmc-system
TESTING_NAMESPACE ?= hmc-system
TARGET_NAMESPACE ?= blue
KIND_CLUSTER_NAME ?= hmc-dev


ENVSUBST ?= $(LOCALBIN)/envsubst-$(ENVSUBST_VERSION)
ENVSUBST_VERSION ?= v1.4.2

GOLANGCI_LINT = $(LOCALBIN)/golangci-lint-$(GOLANGCI_LINT_VERSION)
GOLANGCI_LINT_VERSION ?= v1.61.0

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin

HELM ?= $(LOCALBIN)/helm-$(HELM_VERSION)
HELM_VERSION ?= v3.15.1

TEMPLATES_DIR := templates
TEMPLATE_FOLDERS = $(patsubst $(TEMPLATES_DIR)/%,%,$(wildcard $(TEMPLATES_DIR)/*))
CHARTS_PACKAGE_DIR ?= $(LOCALBIN)/charts
$(CHARTS_PACKAGE_DIR): | $(LOCALBIN)
	rm -rf $(CHARTS_PACKAGE_DIR)
	mkdir -p $(CHARTS_PACKAGE_DIR)

REGISTRY_PORT ?= 5001
REGISTRY_REPO ?= oci://127.0.0.1:$(REGISTRY_PORT)/charts
REGISTRY_IS_OCI = $(shell echo $(REGISTRY_REPO) | grep -q oci && echo true || echo false)

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
	@NAMESPACE=$(1) CLUSTERNAME=$(2) $(ENVSUBST) -i $(3)  | KUBECTL_EXTERNAL_DIFF="diff --color -N -u" kubectl diff  -f - || true
	@echo
	NAMESPACE=$(1) CLUSTERNAME=$(2) $(ENVSUBST) -i $(3) | kubectl apply -f -
endef

.PHONY: apply-aws-test1-0.0.1
apply-aws-test1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,aws/1-0.0.1.yaml)

.PHONY: apply-aws-test1-0.1.0
apply-aws-test1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,aws/2-0.1.0.yaml)

.PHONY: apply-aws-test1-ingress-0.1.0
apply-aws-test1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,aws/3-ingress-0.1.0.yaml)


.PHONY: apply-aws-prod1-0.0.1
apply-aws-prod1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,aws/1-0.0.1.yaml)

.PHONY: apply-aws-prod1-0.1.0
apply-aws-prod1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,aws/2-0.1.0.yaml)

.PHONY: apply-aws-prod1-ingress-0.1.0
apply-aws-prod1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,aws/3-ingress-0.1.0.yaml)


.PHONY: apply-aws-dev1-0.0.1
apply-aws-dev1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,aws/1-0.0.1.yaml)

.PHONY: apply-aws-dev1-0.1.0
apply-aws-dev1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,aws/2-0.1.0.yaml)

.PHONY: apply-aws-dev1-ingress-0.1.0
apply-aws-dev1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,aws/3-ingress-0.1.0.yaml)


.PHONY: apply-azure-test1-0.0.1
apply-azure-test1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-test1-0.1.0
apply-azure-test1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/2-0.1.0.yaml)

.PHONY: apply-azure-test1-ingress-0.1.0
apply-azure-test1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TESTING_NAMESPACE),test1,azure/3-ingress-0.1.0.yaml)


.PHONY: apply-azure-prod1-0.0.1
apply-azure-prod1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-prod1-0.1.0
apply-azure-prod1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/2-0.1.0.yaml)

.PHONY: apply-azure-prod1-ingress-0.1.0
apply-azure-prod1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),prod1,azure/3-ingress-0.1.0.yaml)


.PHONY: apply-azure-dev1-0.0.1
apply-azure-dev1-0.0.1: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/1-0.0.1.yaml)

.PHONY: apply-azure-dev1-0.1.0
apply-azure-dev1-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/2-0.1.0.yaml)

.PHONY: apply-azure-dev1-ingress-0.1.0
apply-azure-dev1-ingress-0.1.0: envsubst
	$(call apply-managed-cluster-yaml,$(TARGET_NAMESPACE),dev1,azure/3-ingress-0.1.0.yaml)


apply-global-kyverno:
	KUBECTL_EXTERNAL_DIFF="diff --color -N -u" kubectl -n $(HMC_NAMESPACE) diff -f MultiClusterServices/1-kyverno.yaml || true
	kubectl -n $(HMC_NAMESPACE) apply -f MultiClusterServices/1-kyverno.yaml

.PHONY: approve-templatechain-aws-standalone-cp-0.0.1
approve-templatechain-aws-standalone-cp-0.0.1:
	$(call approve-clustertemplatechain,$(TARGET_NAMESPACE),aws-standalone-cp-0.0.1)

.PHONY: approve-templatechain-aws-standalone-cp-0.0.2
approve-templatechain-aws-standalone-cp-0.0.2:
	$(call approve-clustertemplatechain,$(TARGET_NAMESPACE),aws-standalone-cp-0.0.2)

# copy-servicetemplate will copy a servicetemplate from one namespace into another
# $1 - source namespace
# $2 - target namespace
# $3 - templatename
define copy-servicetemplate
	@kubectl -n $(2) get servicetemplate $(3) > /dev/null 2>&1 && echo "Template $(3) already approved in namespace $(2)" || kubectl -n $(1) get servicetemplate $(3) -o json | jq 'del(.metadata["namespace"])' | kubectl -n $(2) apply -f -
endef


# approve-clustertemplatechain will approve a clustertemplate in a namespace
# $1 - target namespace
# $2 - templatename
define approve-clustertemplatechain
	kubectl -n hmc-system patch TemplateManagement hmc --type='json' -p='[ \
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

.PHONY: approve-template-nginx-ingress-nginx-4.11.0
approve-template-nginx-ingress-nginx-4.11.0:
	$(call copy-servicetemplate,$(HMC_NAMESPACE),$(TARGET_NAMESPACE),ingress-nginx-4-11-0)

# copy-credential will copy a credential from one namespace into another
# $1 - source namespace
# $2 - target namespace
# $3 - credentialname
define copy-credential
	@kubectl -n $(2) get credentials.hmc.mirantis.com $(3) > /dev/null 2>&1 && echo "Credential $(3) already approved in namespace $(2)" || kubectl -n $(1) get credentials.hmc.mirantis.com $(3) -o json | jq 'del(.metadata["namespace"])' | kubectl -n $(2) apply -f -
endef

.PHONY: approve-credential-azure-cluster-identity-cred
approve-credentials-azure:
	$(call copy-credential,$(HMC_NAMESPACE),$(TARGET_NAMESPACE),azure-cluster-identity-cred)

.PHONY: approve-credential-aws-cluster-identity-cred
approve-credentials-aws:
	$(call copy-credential,$(HMC_NAMESPACE),$(TARGET_NAMESPACE),aws-cluster-identity-cred)

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

.PHONY: envsubst
envsubst: $(ENVSUBST)
$(ENVSUBST): | $(LOCALBIN)
	$(call go-install-tool,$(ENVSUBST),github.com/a8m/envsubst/cmd/envsubst,${ENVSUBST_VERSION})

.PHONY: helm
helm: $(HELM) ## Download helm locally if necessary.
HELM_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
$(HELM): | $(LOCALBIN)
	rm -f $(LOCALBIN)/helm-*
	curl -s --fail $(HELM_INSTALL_SCRIPT) | USE_SUDO=false HELM_INSTALL_DIR=$(LOCALBIN) DESIRED_VERSION=$(HELM_VERSION) BINARY_NAME=helm-$(HELM_VERSION) PATH="$(LOCALBIN):$(PATH)" bash


# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary (ideally with version)
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f $(1) ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
if [ ! -f $(1) ]; then mv -f "$$(echo "$(1)" | sed "s/-$(3)$$//")" $(1); fi ;\
}
endef

.PHONY: create-target-namespace-rolebindings
create-target-namespace-rolebindings: envsubst
	kubectl get namespace $(TARGET_NAMESPACE) > /dev/null 2>&1 || kubectl create namespace $(TARGET_NAMESPACE)
	TARGET_NAMESPACE=$(TARGET_NAMESPACE) $(ENVSUBST) -i rolebindings.yaml | kubectl apply -f -

credentials/ca/ca.crt:
	mkdir -p credentials/ca
	docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.crt credentials/ca/ca.crt

credentials/ca/ca.key:
	mkdir -p credentials/ca
	docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.key credentials/ca/ca.key

credentials/platform-engineer/platform-engineer1.key:
	mkdir -p credentials/platform-engineer
	openssl genrsa -out credentials/platform-engineer/platform-engineer1.key 2048

credentials/platform-engineer/platform-engineer1.csr: credentials/platform-engineer/platform-engineer1.key
	openssl req -new -key credentials/platform-engineer/platform-engineer1.key -out credentials/platform-engineer/platform-engineer1.csr -subj '/CN=platform-engineer1/O=blue'

credentials/platform-engineer/platform-engineer1.crt: credentials/platform-engineer/platform-engineer1.csr credentials/ca/ca.crt credentials/ca/ca.key
	openssl x509 -req -in credentials/platform-engineer/platform-engineer1.csr -CA credentials/ca/ca.crt -CAkey credentials/ca/ca.key -CAcreateserial -out credentials/platform-engineer/platform-engineer1.crt -days 360

.PHONY: generate-platform-engineer1-kubeconfig
generate-platform-engineer1-kubeconfig: credentials/platform-engineer/platform-engineer1.crt envsubst
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) USER_NAME=platform-engineer1 USER_CRT=$$(cat credentials/platform-engineer/platform-engineer1.crt | base64) USER_KEY=$$(cat credentials/platform-engineer/platform-engineer1.key | base64)  CA_CRT=$$(cat credentials/ca/ca.crt | base64) CLUSTER_HOST_PORT=$$(docker port $(KIND_CLUSTER_NAME)-control-plane 6443) $(ENVSUBST) -i credentials/kubeconfig-template.yaml > credentials/platform-engineer/kubeconfig.yaml
	@echo "Config exported to credentials/platform-engineer/kubeconfig.yaml"

.PHONY: helm-package
helm-package: $(CHARTS_PACKAGE_DIR) helm
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
	if [ ! $(REGISTRY_IS_OCI) ]; then \
	    repo_flag="--repo"; \
	fi; \
	for chart in $(CHARTS_PACKAGE_DIR)/*.tgz; do \
		base=$$(basename $$chart .tgz); \
		chart_version=$$(echo $$base | grep -o "v\{0,1\}[0-9]\+\.[0-9]\+\.[0-9].*"); \
		chart_name="$${base%-"$$chart_version"}"; \
		echo "Verifying if chart $$chart_name, version $$chart_version already exists in $(REGISTRY_REPO)"; \
		if $(REGISTRY_IS_OCI); then \
		  echo $(HELM) pull $$repo_flag $(REGISTRY_REPO)/$$chart_name --version $$chart_version --destination /tmp \
			$(HELM) pull $$repo_flag $(REGISTRY_REPO)/$$chart_name --version $$chart_version --destination /tmp \
			chart_exists=$$($(HELM) pull $$repo_flag $(REGISTRY_REPO)/$$chart_name --version $$chart_version --destination /tmp 2>&1 | grep "not found" || true); \
		else \
			echo $(HELM) pull $$repo_flag $(REGISTRY_REPO) $$chart_name --version $$chart_version --destination /tmp \
			$(HELM) pull $$repo_flag $(REGISTRY_REPO) $$chart_name --version $$chart_version --destination /tmp \
			chart_exists=$$($(HELM) pull $$repo_flag $(REGISTRY_REPO) $$chart_name --version $$chart_version --destination /tmp 2>&1 | grep "not found" || true); \
		fi; \
		if [ -z "$$chart_exists" ]; then \
			echo "Chart $$chart_name version $$chart_version already exists in the repository."; \
		else \
			if $(REGISTRY_IS_OCI); then \
				echo "Pushing $$chart to $(REGISTRY_REPO)"; \
				$(HELM) push "$$chart" $(REGISTRY_REPO); \
			else \
				if [ ! $$REGISTRY_USERNAME ] && [ ! $$REGISTRY_PASSWORD ]; then \
					echo "REGISTRY_USERNAME and REGISTRY_PASSWORD must be populated to push the chart to an HTTPS repository"; \
					exit 1; \
				else \
					$(HELM) repo add hmc $(REGISTRY_REPO); \
					echo "Pushing $$chart to $(REGISTRY_REPO)"; \
					$(HELM) cm-push "$$chart" $(REGISTRY_REPO) --username $$REGISTRY_USERNAME --password $$REGISTRY_PASSWORD; \
				fi; \
			fi; \
		fi; \
	done