locals {
  cluster_spec = {
    apiVersion = "kops/v1alpha2"
    kind = "Cluster"
    metadata = {
      name = var.cluster-name
    }
    spec = {
      api = {
        loadBalancer = {
          type = var.master-lb-visibility == "Private" ? "Internal" : "Public"
          idleTimeoutSeconds = var.master-lb-idle-timeout
        }
      }
      authorization = {
        (var.rbac ? "rbac" : "alwaysAllow") = {}
      }
      channel = var.channel
      cloudConfig = {
        disableSecurityGroupIngress = var.disable-sg-ingress
      }
      cloudLabels = length(keys(var.cloud-labels)) == 0 ? null : var.cloud-labels
      cloudProvider = "aws"
      clusterDNSDomain = var.kube-dns-domain
      configBase = "s3://${var.kops-state-bucket}/${var.cluster-name}"
      configStore = "s3://${var.kops-state-bucket}/${var.cluster-name}"
      dnsZone = var.cluster-name
      etcdClusters = [
        for etcd_cluster in ["main", "events"]: merge({
          name = etcd_cluster
          enableEtcdTLS = var.etcd-enable-tls
          etcdMembers = [
            for az in var.master-availability-zones: {
              encryptedVolume = true
              instanceGroup = "master-${az}"
              name = az
            }
          ]
          provider= var.etcd-mode
          version = var.etcd-version
        }, var.etcd-backup-enabled ? {
          backups = {
            backupStore = "s3://${var.etcd-backup-s3-bucket == "" ? var.kops-state-bucket : var.etcd-backup-s3-bucket}/${var.cluster-name}/backups/etcd/${etcd_cluster}/"
          }
        } : {})
      ]
      keyStore = "s3://${var.kops-state-bucket}/${var.cluster-name}/pki"
      kubeAPIServer = merge({
        insecureBindAddress = "127.0.0.1"
        enableAdmissionPlugins = var.enable-admission-plugins
        allowPrivileged = true
        anonymousAuth = false
        apiServerCount = length(var.master-availability-zones)
        authorizationMode = var.rbac ? "RBAC" : "AlwaysAllow"
        cloudProvider = "aws"
        etcdServers = ["http://127.0.0.1:4001"]
        etcdServersOverrides = ["/events#http://127.0.0.1:4002"]
        insecurePort = 8080
        kubeletPreferredAddressTypes = ["InternalIP", "Hostname", "ExternalIP"]
        logLevel = var.log-level
        securePort = 443
        serviceClusterIPRange = "100.64.0.0/13"
        storageBackend = "etcd${substr(var.etcd-version, 0, 1)}"
        runtimeConfig = var.apiserver-runtime-flags
        featureGates = var.featuregates-flags
      }, var.oidc-issuer-url == "" ? {} : {
        oidcCAFile = var.oidc-ca-file == "" ? null : var.oidc-ca-file
        oidcClientID = var.oidc-client-id
        oidcGroupsClaim = var.oidc-groups-claim
        oidcIssuerURL = var.oidc-issuer-url
        oidcUsernameClaim = var.oidc-username-claim
      })
      kubeControllerManager = {
        allocateNodeCIDRs = true
        attachDetachReconcileSyncPeriod = "1m0s"
        cloudProvider = "aws"
        clusterCIDR = "100.96.0.0/11"
        clusterName = var.cluster-name
        configureCloudRoutes = false
        leaderElection = {
          leaderElect = true
        }
        logLevel = var.log-level
        useServiceAccountCredentials = true
        horizontalPodAutoscalerSyncPeriod = var.hpa-sync-period
        horizontalPodAutoscalerDownscaleStabilization = var.hpa-scale-downscale-stabilization
        kubeAPIQPS = var.controller-manager-kube-api-qps
        kubeAPIBurst = var.controller-manager-kube-api-burst
        featureGates = var.featuregates-flags
      }
      kubeDNS = {
        domain = var.kube-dns-domain
        replicas = 2
        serverIP = "100.64.0.10"
        provider = var.kube-dns-provider
      }
      kubeProxy = {
        clusterCIDR = "100.96.0.0/11"
        cpuRequest = "100m"
        hostnameOverride = "@aws"
        image = "gcr.io/google_containers/kube-proxy:${var.kubernetes-version}" # From upstream
        logLevel = var.log-level
      }
      kubeScheduler = {
        leaderElection = {
          leaderElect = true
        }
        logLevel = var.log-level
      }
      kubelet = {
        allowedUnsafeSysctls = var.allowed-unsafe-sysctls
        anonymousAuth = true
        cpuCFSQuota = var.kubernetes-cpu-cfs-quota-enabled
        cpuCFSQuotaPeriod = var.kubernetes-cpu-cfs-quota-period
        serializeImagePulls = var.serialize-image-pulls-enabled
        imagePullProgressDeadline = var.image-pull-progress-deadline
        allowPrivileged = true
        cgroupRoot = "/"
        cloudProvider = "aws"
        clusterDNS = "100.64.0.10"
        clusterDomain = var.kube-dns-domain
        enableDebuggingHandlers = true
        evictionHard = var.kubelet-eviction-flag
        hostnameOverride = "@aws"
        kubeconfigPath = "/var/lib/kubelet/kubeconfig"
        logLevel = var.log-level
        networkPluginName = "cni"
        nonMasqueradeCIDR = "100.64.0.0/10"
        podManifestPath = "/etc/kubernetes/manifests"
        kubeReserved = {
          cpu = var.kube-reserved-cpu
          memory = var.kube-reserved-memory
        }
        systemReserved = {
          cpu = var.system-reserved-cpu
          memory = var.system-reserved-memory
        }
        enforceNodeAllocatable = "pods"
        featureGates = var.featuregates-flags
      }
      kubernetesApiAccess = var.trusted-cidrs
      kubernetesVersion = var.kubernetes-version
      masterInternalName = "api.internal.${var.cluster-name}"
      masterKubelet = {
        allowPrivileged = true
        cgroupRoot = "/"
        cloudProvider = "aws"
        clusterDNS = "100.64.0.10"
        clusterDomain = var.kube-dns-domain
        enableDebuggingHandlers = true
        evictionHard = "memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%,imagefs.available<10%,imagefs.inodesFree<5%"
        hostnameOverride = "@aws"
        kubeconfigPath = "/var/lib/kubelet/kubeconfig"
        logLevel = var.log-level
        networkPluginName = "cni"
        nonMasqueradeCIDR = "100.64.0.0/10"
        podManifestPath = "/etc/kubernetes/manifests"
        registerSchedulable = false
      }
      masterPublicName = "api.${var.cluster-name}"
      networkCIDR = var.vpc-networking.vpc-cidr-block
      networkID = var.vpc-networking.vpc-id
      networking = {
        (var.container-networking) = var.container-networking-params
      }
      nonMasqueradeCIDR = "100.64.0.0/10"
      secretStore = "s3://${var.kops-state-bucket}/${var.cluster-name}/secrets"
      serviceClusterIPRange = "100.64.0.0/13"
      sshAccess = var.trusted-cidrs
      subnets = flatten([
        for idx in range(length(var.availability-zones)): [
          {
            cidr = var.vpc-networking.vpc-private-cidrs[idx]
            name = var.availability-zones[idx]
            type = "Private"
            zone = var.availability-zones[idx]
            id   = var.vpc-networking.vpc-private-subnet-ids[idx]
            egress = var.vpc-networking.nat-gateways[idx]
          },
          {
            cidr = var.vpc-networking.vpc-public-cidrs[idx]
            name = "utility-${var.availability-zones[idx]}"
            type = "Utility"
            zone = var.availability-zones[idx]
            id   = var.vpc-networking.vpc-public-subnet-ids[idx]
          },
        ]
      ])
      topology = {
        bastion = {
          bastionPublicName = "bastion.${var.cluster-name}"
        }
        dns = {
          type = var.master-lb-visibility
        }
        masters = "private"
        nodes = "private"
      }
      hooks = length(var.hooks) > 0 ? var.hooks : null
      additionalPolicies = merge(
        length(var.master-additional-policies) == 0 ? {} : {master = var.master-additional-policies},
        length(var.node-additional-policies) == 0 ? {} : {node = var.node-additional-policies}
      )
    }
  }
  master_spec = [
    for az in var.master-availability-zones: {
      apiVersion = "kops/v1alpha2"
      kind = "InstanceGroup"
      metadata = {
        labels = {
          "kops.k8s.io/cluster": var.cluster-name
        }
        name = "master-${az}"
      }
      spec = merge({
        cloudLabels = length(keys(var.master-cloud-labels)) == 0 ? null : var.master-cloud-labels
        nodeLabels = length(var.master-node-labels) > 0 ? var.master-node-labels : null
        associatePublicIp = false
        image = var.master-image
        machineType = var.master-machine-type
        maxSize = 1
        minSize = 1
        role = "Master"
        rootVolumeSize = var.master-volume-size
        rootVolumeType = var.master-volume-type
        rootProvisionedIops = var.master-volume-provisioned-iops == "" ? null : var.master-volume-provisioned-iops
        rootVolumeOptimization = var.master-ebs-optimized
        taints = null
        subnets = [az]
        hooks = length(var.master-hooks) > 0 ? var.master-hooks : null
      }, length(var.master-additional-sgs) > 0 ? {additionalSecurityGroups = var.master-additional-sgs} : {})
    }
  ]
  bastion_spec = var.kops-topology != "private" ? [] : [{
    apiVersion = "kops/v1alpha2"
    kind = "InstanceGroup"
    metadata = {
      labels = {
        "kops.k8s.io/cluster": var.cluster-name
      }
      name = "bastions"
    }
    spec = merge({
      cloudLabels = length(keys(var.bastion-cloud-labels)) == 0 ? null : var.bastion-cloud-labels
      nodeLabels = length(var.bastion-node-labels) > 0 ? var.bastion-node-labels : null
      associatePublicIp = false
      image = var.bastion-image
      machineType = var.bastion-machine-type
      maxSize = var.max-bastions
      minSize = var.min-bastions
      role = "Bastion"
      rootVolumeSize = var.bastion-volume-size
      rootVolumeType = var.bastion-volume-type
      rootProvisionedIops = var.bastion-volume-provisioned-iops == "" ? null : var.bastion-volume-provisioned-iops
      rootVolumeOptimization = var.bastion-ebs-optimized
      taints = null
      subnets = var.availability-zones
      hooks = length(var.bastion-hooks) > 0 ? var.bastion-hooks : null
    }, length(var.bastion-additional-sgs) > 0 ? {additionalSecurityGroups = var.bastion-additional-sgs} : {})
  }]
  minion_spec = {
    apiVersion = "kops/v1alpha2"
    kind = "InstanceGroup"
    metadata = {
      labels = {
        "kops.k8s.io/cluster": var.cluster-name
      }
      name = var.minion-ig-name
    }
    spec = merge({
      cloudLabels = length(keys(var.minion-cloud-labels)) == 0 ? null : var.minion-cloud-labels
      nodeLabels = length(var.minion-node-labels) > 0 ? var.minion-node-labels : null
      associatePublicIp = false
      image = var.minion-image
      machineType = var.minion-machine-type
      maxSize = var.max-minions
      minSize = var.min-minions
      role = "Node"
      rootVolumeSize = var.minion-volume-size
      rootVolumeType = var.minion-volume-type
      rootProvisionedIops = var.minion-volume-provisioned-iops == "" ? null : var.minion-volume-provisioned-iops
      rootVolumeOptimization = var.minion-ebs-optimized
      taints = length(var.minion-taints) > 0 ? var.minion-taints : null
      subnets = var.availability-zones
      hooks = length(var.minion-hooks) > 0 ? var.minion-hooks : null
    }, length(var.minion-additional-sgs) > 0 ? {additionalSecurityGroups = var.minion-additional-sgs} : {})
  }
}

data "template_file" "cluster-spec" {
  template = file("${path.module}/templates/cluster-spec.yaml")

  vars = {
    # Generic cluster configuration
    cluster-name       = var.cluster-name
    channel            = var.channel
    disable-sg-ingress = var.disable-sg-ingress
    cloud-labels       = join("\n", data.template_file.cloud-labels.*.rendered)
    kube-dns-domain    = var.kube-dns-domain
    kube-dns-provider  = var.kube-dns-provider
    kops-state-bucket  = var.kops-state-bucket

    controller-manager-kube-api-qps   = var.controller-manager-kube-api-qps
    controller-manager-kube-api-burst = var.controller-manager-kube-api-burst

    master-lb-visibility     = var.master-lb-visibility == "Private" ? "Internal" : "Public"
    master-lb-dns-visibility = var.master-lb-visibility
    master-count             = length(var.master-availability-zones)
    master-lb-idle-timeout   = var.master-lb-idle-timeout

    kubernetes-version                = var.kubernetes-version
    vpc-cidr                          = var.vpc-networking["vpc-cidr-block"]
    vpc-id                            = var.vpc-networking["vpc-id"]
    trusted-cidrs                     = join("\n", data.template_file.trusted-cidrs.*.rendered)
    subnets                           = join("\n", data.template_file.subnets.*.rendered)
    container-networking              = var.container-networking
    container-networking-params-empty = length(keys(var.container-networking-params)) == 0 ? "{}" : ""
    container-networking-params       = join("\n", data.template_file.container-networking-params.*.rendered)

    hooks = join("\n", data.template_file.hooks.*.rendered)

    # ETCD cluster parameters
    etcd-clusters = <<EOF
  - etcdMembers:
${join("\n", data.template_file.etcd-member.*.rendered)}
    name: main
    enableEtcdTLS: ${var.etcd-enable-tls}
    version: ${var.etcd-version}
    provider: ${var.etcd-mode}
${join("\n", data.template_file.backup-main.*.rendered)}
  - etcdMembers:
${join("\n", data.template_file.etcd-member.*.rendered)}
    name: events
    enableEtcdTLS: ${var.etcd-enable-tls}
    version: ${var.etcd-version}
    provider: ${var.etcd-mode}
${join("\n", data.template_file.backup-events.*.rendered)}
EOF

    # Kubelet configuration
    # CPU and Memory reservation for system/orchestration processes (soft)
    kubelet-eviction-flag = var.kubelet-eviction-flag

    kube-reserved-cpu      = var.kube-reserved-cpu
    kube-reserved-memory   = var.kube-reserved-memory
    system-reserved-cpu    = var.system-reserved-cpu
    system-reserved-memory = var.system-reserved-memory

    # APIServer configuration
    apiserver-storage-backend    = "etcd${substr(var.etcd-version, 0, 1)}"
    kops-authorization-mode      = var.rbac ? "rbac" : "alwaysAllow"
    apiserver-authorization-mode = var.rbac ? "RBAC" : "AlwaysAllow"

    apiserver-runtime-config = join("\n", data.template_file.apiserver-runtime-configs.*.rendered)
    featuregates-config      = join("\n", data.template_file.featuregates-configs.*.rendered)
    oidc-config              = join("\n", data.template_file.oidc-apiserver-conf.*.rendered)
    enable-admission-plugins = trimspace(join("", data.template_file.enable-admission-plugins.*.rendered))

    # kube-controller-manager configuration
    hpa-sync-period                   = var.hpa-sync-period
    hpa-scale-downscale-stabilization = var.hpa-scale-downscale-stabilization

    # Additional IAM policies for masters and nodes
    master-additional-policies = length(var.master-additional-policies) == 0 ? "" : format("master: |\n      %s", indent(6, var.master-additional-policies))
    node-additional-policies   = length(var.node-additional-policies) == 0 ? "" : format("node: |\n      %s", indent(6, var.node-additional-policies))

    # Log level for all master & kubelet components
    log-level = var.log-level

    # Set cpuCFSQuota and cpuCFSQuotaPeriod to improve
    kubernetes-cpu-cfs-quota-enabled = var.kubernetes-cpu-cfs-quota-enabled
    kubernetes-cpu-cfs-quota-period  = var.kubernetes-cpu-cfs-quota-period

    # Set allowed-unsafe-sysctls so we can tweak them in containers
    allowed-unsafe-sysctls = join("\n", data.template_file.allowed-unsafe-sysctls.*.rendered)

    # Improve image pull concurrency
    serialize-image-pulls        = var.serialize-image-pulls-enabled
    image-pull-progress-deadline = var.image-pull-progress-deadline
  }
}

data "template_file" "etcd-member" {
  count = length(var.master-availability-zones)

  template = <<EOF
    - encryptedVolume: true
      instanceGroup: master-$${az}
      name: $${az}
EOF

  vars = {
    az = element(var.master-availability-zones, count.index)
  }
}

data "template_file" "backup-main" {
  count = var.etcd-backup-enabled ? 1 : 0

  template = <<EOF
    backups:
      backupStore: s3://${var.etcd-backup-s3-bucket == "" ? var.kops-state-bucket : var.etcd-backup-s3-bucket}/${var.cluster-name}/backups/etcd/main/
EOF
}

data "template_file" "backup-events" {
  count = var.etcd-backup-enabled ? 1 : 0

  template = <<EOF
    backups:
      backupStore: s3://${var.etcd-backup-s3-bucket == "" ? var.kops-state-bucket : var.etcd-backup-s3-bucket}/${var.cluster-name}/backups/etcd/events/
EOF
}

data "template_file" "trusted-cidrs" {
  count = length(var.trusted-cidrs)

  template = <<EOF
  - $${cidr}
EOF

  vars = {
    cidr = element(var.trusted-cidrs, count.index)
  }
}

data "template_file" "cloud-labels" {
  count = length(keys(var.cloud-labels))

  template = <<EOF
    $${tag}: '$${value}'
EOF

  vars = {
    tag   = element(keys(var.cloud-labels), count.index)
    value = element(values(var.cloud-labels), count.index)
  }
}

data "template_file" "subnets" {
  count = length(var.availability-zones)

  template = <<EOF
  - cidr: $${private-cidr}
    name: $${az}
    type: Private
    zone: $${az}
    id: $${private-subnet-id}
    egress: $${nat-gateway-id}
  - cidr: $${public-cidr}
    name: utility-$${az}
    type: Utility
    zone: $${az}
    id: $${public-subnet-id}
EOF

  vars = {
    az                = element(var.availability-zones, count.index)
    private-cidr      = element(var.vpc-networking["vpc-private-cidrs"], count.index)
    public-cidr       = element(var.vpc-networking["vpc-public-cidrs"], count.index)
    public-subnet-id  = element(var.vpc-networking["vpc-public-subnet-ids"], count.index)
    private-subnet-id = element(var.vpc-networking["vpc-private-subnet-ids"], count.index)
    nat-gateway-id    = element(var.vpc-networking["nat-gateways"], count.index)
  }
}

data "template_file" "oidc-apiserver-conf" {
  count = var.oidc-issuer-url == "" ? 0 : 1

  template = <<EOF
    oidcCAFile: ${var.oidc-ca-file}
    oidcClientID: ${var.oidc-client-id}
    oidcGroupsClaim: ${var.oidc-groups-claim}
    oidcIssuerURL: ${var.oidc-issuer-url}
    oidcUsernameClaim: ${var.oidc-username-claim}
EOF
}

data "template_file" "apiserver-runtime-configs" {
  count = length(var.apiserver-runtime-flags)

  template = "      ${element(keys(var.apiserver-runtime-flags), count.index)}: '${element(values(var.apiserver-runtime-flags), count.index)}'"
}

data "template_file" "featuregates-configs" {
  count = length(var.featuregates-flags)

  template = "      ${element(keys(var.featuregates-flags), count.index)}: '${element(values(var.featuregates-flags), count.index)}'"
}

data "template_file" "hooks" {
  count = length(var.hooks)

  template = <<EOF
${element(var.hooks, count.index)}
EOF
}

data "template_file" "container-networking-params" {
  count = length(keys(var.container-networking-params))

  template = <<EOF
      $${tag}: $${value}
EOF

  vars = {
    tag   = element(keys(var.container-networking-params), count.index)
    value = element(values(var.container-networking-params), count.index)
  }
}

data "template_file" "allowed-unsafe-sysctls" {
  count = length(var.allowed-unsafe-sysctls)

  template = <<EOF
    - $${sysctl}
EOF

  vars = {
    sysctl = element(var.allowed-unsafe-sysctls, count.index)
  }
}

data "template_file" "enable-admission-plugins" {
  count = length(var.enable-admission-plugins)

  template = <<EOF
    - $${plugin}
EOF

  vars = {
    plugin = element(var.enable-admission-plugins, count.index)
  }
}
