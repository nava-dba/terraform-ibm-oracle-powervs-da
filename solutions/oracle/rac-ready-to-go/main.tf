########################################################
# Oracle Database Real Application Clusters (RAC) - Ready to Go
# 
# This solution creates:
# 1. VPC Landing Zone with 2 VSIs (Management + Network Services)
# 2. PowerVS Workspace with 4 networks (mgmt, public, priv1, priv2)
# 3. Multiple AIX instances for Oracle RAC cluster (2-8 nodes)
# 4. Automated Oracle Grid Infrastructure and RAC Database installation
########################################################

########################################################
# VPC Landing Zone Module
# Creates complete infrastructure:
# - VPC with Management and Network Services VSIs
# - Transit Gateway connecting VPC to PowerVS
# - PowerVS Workspace with management network
# - Network services: SQUID proxy, DNS, NTP, NFS, Ansible
########################################################

module "landing_zone" {
  source  = "terraform-ibm-modules/powervs-infrastructure/ibm//modules/powervs-vpc-landing-zone"
  version = "11.0.1"

  providers = {
    ibm.ibm-is = ibm.ibm-is
    ibm.ibm-pi = ibm.ibm-pi
    ibm.ibm-sm = ibm.ibm-sm
  }

  # Basic configuration
  powervs_zone                = var.powervs_zone
  powervs_resource_group_name = var.powervs_resource_group_name
  prefix                      = var.prefix
  external_access_ip          = var.external_access_ip
  ssh_public_key              = var.ssh_public_key
  ssh_private_key             = var.ssh_private_key
  tags                        = var.tags

  # VPC Intel images for Management and Network Services VSIs
  vpc_intel_images = var.vpc_intel_images

  # PowerVS network configuration - only management network created by landing zone
  # RAC-specific networks (public, priv1, priv2) must be pre-created
  powervs_management_network = {
    name = "${var.prefix}-oracle-mgmt"
    cidr = var.powervs_management_network_cidr
  }
  powervs_backup_network = null # Not needed for Oracle RAC

  # Network services configuration
  configure_dns_forwarder = true
  configure_ntp_forwarder = true
  configure_nfs_server    = true
  nfs_server_config       = var.nfs_server_config
  dns_forwarder_config    = { dns_servers = "161.26.0.7; 161.26.0.8; 9.9.9.9;" }

  # Optional: Client-to-site VPN
  client_to_site_vpn          = var.client_to_site_vpn
  sm_service_plan             = var.sm_service_plan
  existing_sm_instance_guid   = var.existing_sm_instance_guid
  existing_sm_instance_region = var.existing_sm_instance_region

  # Optional: Monitoring and Security
  enable_monitoring                = var.enable_monitoring
  existing_monitoring_instance_crn = var.existing_monitoring_instance_crn
  enable_scc_wp                    = var.enable_scc_wp
  ansible_vault_password           = var.ansible_vault_password
}

########################################################
# PowerVS AIX Instances for Oracle RAC Cluster
# Creates multiple AIX instances with replication policy
########################################################

resource "ibm_pi_instance" "rac_nodes" {
  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_instance_name     = "${var.prefix}-rac-aix"
  pi_image_id          = var.powervs_aix_image_name
  pi_key_pair_name     = module.landing_zone.powervs_ssh_public_key.name
  pi_memory            = var.powervs_aix_instance.memory_gb
  pi_processors        = var.powervs_aix_instance.cores
  pi_proc_type         = var.powervs_aix_instance.core_type
  pi_sys_type          = var.powervs_aix_instance.machine_type

  # Attach all 4 networks: management, public, private1, private2
  dynamic "pi_network" {
    for_each = concat(
      [module.landing_zone.powervs_management_subnet],
      var.powervs_rac_networks
    )
    content {
      network_id = pi_network.value.id
    }
  }

  pi_storage_type          = "tier1"
  pi_pin_policy            = var.powervs_aix_instance.pin_policy
  pi_health_status         = "OK"
  pi_storage_pool_affinity = false
  
  # Create multiple instances with replication
  pi_replicants         = var.rac_node_count
  pi_replication_scheme = "suffix"
  pi_replication_policy = var.pi_replication_policy
  pi_user_tags          = var.tags

  timeouts {
    create = "60m"
  }

  lifecycle {
    ignore_changes = [
      pi_cloud_instance_id,
      pi_image_id,
      pi_instance_name,
      pi_user_tags,
      pi_network
    ]
  }
}

# Wait for instances to be fully created
resource "time_sleep" "wait_after_rac_vm_creation" {
  depends_on      = [ibm_pi_instance.rac_nodes]
  create_duration = "180s"
}

# Fetch all instances in the workspace to get IPs
data "ibm_pi_instances" "workspace_instances" {
  depends_on           = [time_sleep.wait_after_rac_vm_creation]
  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
}

locals {
  # Filter RAC instances by name pattern
  rac_instance_map = {
    for instance in data.ibm_pi_instances.workspace_instances.pvm_instances :
    instance.server_name => instance
    if can(regex("^${var.prefix}-rac-aix-[0-9]+$", instance.server_name))
  }

  # Create ordered list of RAC instances
  rac_instances = [
    for idx in range(var.rac_node_count) :
    local.rac_instance_map["${var.prefix}-rac-aix-${idx + 1}"]
  ]

  # Extract IPs for each node and network
  rac_node_ips = {
    for idx in range(var.rac_node_count) :
    idx => {
      management = local.rac_instances[idx].networks[0].ip
      public     = local.rac_instances[idx].networks[1].ip
      private1   = local.rac_instances[idx].networks[2].ip
      private2   = local.rac_instances[idx].networks[3].ip
    }
  }
}

########################################################
# Storage Volumes for RAC Nodes
# Create shared storage volumes for each node
########################################################

resource "ibm_pi_volume" "node_storage" {
  for_each = {
    for idx in range(var.rac_node_count) :
    idx => local.rac_instances[idx]
  }

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_volume_name       = "${each.value.server_name}-storage"
  pi_volume_size       = 100
  pi_volume_type       = "tier1"
  pi_volume_shareable  = false

  timeouts {
    create = "30m"
  }
}

# Attach storage volumes to instances
resource "ibm_pi_volume_attach" "node_storage_attach" {
  for_each = ibm_pi_volume.node_storage

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_volume_id         = each.value.volume_id
  pi_instance_id       = local.rac_instances[each.key].pvm_instance_id

  timeouts {
    create = "30m"
  }
}

########################################################
# AIX Instances Initialization
# - Configure proxy settings
# - Mount NFS from network services VSI
# - Extend root volumes
# - Configure RAC interconnect networks
########################################################

module "pi_instances_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [ibm_pi_volume_attach.node_storage_attach]

  bastion_host_ip        = module.landing_zone.access_host_or_ip
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  src_script_template_name = "aix-init/ansible_exec.sh.tftpl"
  dst_script_file_name     = "aix_init_rac.sh"

  src_playbook_template_name = "aix-init/playbook-aix-init.yml.tftpl"
  dst_playbook_file_name     = "aix-init-rac-playbook.yml"
  
  playbook_template_vars = {
    PROXY_IP_PORT          = module.landing_zone.proxy_host_or_ip_port
    NO_PROXY               = "localhost,127.0.0.1"
    ORA_NFS_HOST           = module.landing_zone.ansible_host_or_ip
    ORA_NFS_DEVICE         = local.nfs_mount
    EXTEND_ROOT_VOLUME_WWN = "" # Will be set per node
    AIX_INIT_MODE          = "rac"
    ROOT_PASSWORD          = ""
  }

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "aix-init-rac-inventory"
  inventory_template_vars = {
    rac_nodes = [
      for idx in range(var.rac_node_count) :
      {
        hostname = local.rac_instances[idx].server_name
        ip       = local.rac_node_ips[idx].management
      }
    ]
  }
}

########################################################
# Download Oracle Binaries from IBM Cloud Object Storage
# to Network Services VSI NFS mount point
########################################################

module "ibmcloud_cos_oracle" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.landing_zone]

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_oracle_configuration
}

module "ibmcloud_cos_grid" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_oracle]

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_grid_configuration
}

module "ibmcloud_cos_patch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_grid]

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_patch_configuration
}

module "ibmcloud_cos_opatch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_patch]

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_opatch_configuration
}

module "ibmcloud_cos_cluvfy" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_opatch]
  count      = local.ibmcloud_cos_cluvfy_configuration != null ? 1 : 0

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_cluvfy_configuration
}

########################################################
# Oracle Grid Infrastructure and RAC Database Installation
# Installs Oracle Grid for RAC and Oracle RAC Database
########################################################

module "oracle_rac_install" {
  source     = "../../../modules/ansible"
  depends_on = [module.ibmcloud_cos_cluvfy, module.pi_instances_aix_init]

  bastion_host_ip        = module.landing_zone.access_host_or_ip
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  src_script_template_name = "oracle-grid-install-rac/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_rac_install.sh"

  src_playbook_template_name = "oracle-grid-install-rac/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-rac.yml"
  playbook_template_vars     = local.playbook_oracle_rac_install_vars

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "oracle-rac-install-inventory"
  inventory_template_vars = {
    rac_nodes = [
      for idx in range(var.rac_node_count) :
      {
        hostname = local.rac_instances[idx].server_name
        ip       = local.rac_node_ips[idx].management
      }
    ]
  }
}