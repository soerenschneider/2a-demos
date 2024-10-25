apiVersion: hmc.mirantis.com/v1alpha1
kind: ManagedCluster
metadata:
  name: aws-hosted
spec:
  template: aws-hosted-cp
  config:
    vpcID: "{{.spec.network.vpc.id}}"
    region: "{{.spec.region}}"
    subnets:
      - id: "{{(index .spec.network.subnets 0).resourceID}}"
        availabilityZone: "{{(index .spec.network.subnets 0).availabilityZone}}"
    amiID: ami-0bf2d31c356e4cb25
    instanceType: t3.medium
    securityGroupIDs:
      - "{{.status.networkStatus.securityGroups.node.id}}"
