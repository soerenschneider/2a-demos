# 2A Deploy

2A is deployed using the Helm chart on top of the management kubernetes cluster. It installs required CRDs, hmc kubernetes operator and a couple of common utilities. However, when Helm chart is successfully deployed, 2A is not ready to be used at the moment. HMC operator starts the reconciliation process that installs [CAPI](https://cluster-api.sigs.k8s.io/), different cloud providers, default built-in cluster and service templates, etc. 

To get the information about 2A platform readiness you can run this command:

```shell
PATH=$PATH:./bin kubectl get management hmc -o go-template='{{range $key, $value := .status.components}}{{$key}}: {{if $value.success}}{{$value.success}}{{else}}{{$value.error}}{{end}}{{"\n"}}{{end}}'
```

It checks the `Management` object, which is the HMC custom resource. This object contains requirements on what providers must be installed, the HMC release version, etc. HMC operator reconciles the platform state to satisfy requirements from this object and updates the status.

You can find detailed information about 2A installation in the [official documentation](https://mirantis.github.io/project-2a-docs/quick-start/2a-installation/).