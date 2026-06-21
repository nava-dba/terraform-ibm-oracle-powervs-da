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
  version = "11.1.5"

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
  tags                        = var.pi_user_tags

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

  # VPC subnet CIDRs - CRITICAL: Required to prevent network conflicts
  vpc_subnet_cidrs = var.vpc_subnet_cidrs

}

########################################################
# Get File Storage NFS info from Landing Zone module
# Dynamically extracts NFS server and device path
########################################################

locals {
  # Extract NFS server IP and device path from module.landing_zone output
  # Format: "10.41.10.5:/7252ceba_8a49_4048_881b_94d0b63ea2d9"
  nfs_host_or_ip_path_parts = split(":", module.landing_zone.nfs_host_or_ip_path)
  nfs_server                = local.nfs_host_or_ip_path_parts[0]
  nfs_device                = local.nfs_host_or_ip_path_parts[1]
}

########################################################
# Initialize Ansible Host with Ready-to-Go Script
########################################################

resource "terraform_data" "reconfigure_ansible_host" {
  depends_on = [module.landing_zone]

  connection {
    type         = "ssh"
    user         = "root"
    bastion_host = module.landing_zone.access_host_or_ip
    host         = module.landing_zone.ansible_host_or_ip
    private_key  = var.ssh_private_key
    agent        = false
    timeout      = "5m"
  }

  # Copy the ready-to-go ansible configuration script
  provisioner "file" {
    source      = "${path.module}/../../../modules/ansible/ansible_node_packages_ready_to_go.sh"
    destination = "/tmp/ansible_node_packages_ready_to_go.sh"
  }

  # Execute the script to install collections properly
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ansible_node_packages_ready_to_go.sh",
      "squid_server_ip=${split(":", module.landing_zone.proxy_host_or_ip_port)[0]} hosts_file_entries='' /tmp/ansible_node_packages_ready_to_go.sh",
      "rm -f /tmp/ansible_node_packages_ready_to_go.sh"
    ]
  }
}

# Copy SSH private key to jump box for passwordless access to AIX instances
resource "terraform_data" "setup_jump_box_ssh" {
  depends_on = [module.landing_zone]

  connection {
    type        = "ssh"
    user        = "root"
    host        = module.landing_zone.access_host_or_ip
    private_key = var.ssh_private_key
    agent       = false
    timeout     = "5m"
  }

  # Copy private key to jump box
  provisioner "file" {
    content     = var.ssh_private_key
    destination = "/root/.ssh/id_rsa"
  }

  # Configure SSH client to disable host key checking
  provisioner "file" {
    content = <<-EOF
      Host *
        StrictHostKeyChecking no
        UserKnownHostsFile=/dev/null
        LogLevel ERROR
    EOF
    destination = "/root/.ssh/config"
  }

  # Set correct permissions
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/id_rsa",
      "chmod 600 /root/.ssh/config",
      "chown root:root /root/.ssh/id_rsa",
      "chown root:root /root/.ssh/config"
    ]
  }
}

########################################################
# PowerVS Workspace Data Source
# Initializes provider context for PowerVS resources
########################################################

data "ibm_pi_workspace" "workspace" {
  provider             = ibm.ibm-pi
  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  depends_on           = [module.landing_zone]
}

########################################################
# Create PowerVS RAC Networks Automatically
# Creates 3 networks required for Oracle RAC:
# 1. Public network for client connections
# 2. Private network 1 for RAC interconnect
# 3. Private network 2 for RAC interconnect
########################################################

# RAC Public Network (for client connections and VIPs)
# Note: IP range 172.16.10.2 - 172.16.10.240 for hosts
#       IP range 172.16.10.241 - 172.16.10.254 reserved for Oracle RAC VIPs (SCAN and Node-VIPs)
# Note: ARP must be enabled at PowerVS workspace level via IBM Support ticket
resource "ibm_pi_network" "rac_public" {
  provider = ibm.ibm-pi
  
  depends_on = [data.ibm_pi_workspace.workspace]

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_network_name      = "${var.prefix}-rac-pub"
  pi_network_type      = "vlan"
  pi_cidr              = "172.16.10.0/24"
  pi_gateway           = "172.16.10.1"
  pi_dns               = [module.landing_zone.dns_host_or_ip]
  pi_network_mtu       = 1450
  
  timeouts {
    create = "10m"
  }
}

# RAC Private Network 1 (interconnect with jumbo frames)
# Note: ARP must be enabled at PowerVS workspace level via IBM Support ticket
resource "ibm_pi_network" "rac_private1" {
  provider = ibm.ibm-pi
  
  depends_on = [data.ibm_pi_workspace.workspace]

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_network_name      = "${var.prefix}-rac-priv1"
  pi_network_type      = "vlan"
  pi_cidr              = "10.60.30.0/28"
  pi_gateway           = "10.60.30.1"
  pi_dns               = [module.landing_zone.dns_host_or_ip]
  pi_network_mtu       = 9000
  
  timeouts {
    create = "10m"
  }
}

# RAC Private Network 2 (interconnect with jumbo frames)
# Note: ARP must be enabled at PowerVS workspace level via IBM Support ticket
resource "ibm_pi_network" "rac_private2" {
  provider = ibm.ibm-pi
  
  depends_on = [data.ibm_pi_workspace.workspace]

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_network_name      = "${var.prefix}-rac-priv2"
  pi_network_type      = "vlan"
  pi_cidr              = "10.50.20.0/28"
  pi_gateway           = "10.50.20.1"
  pi_dns               = [module.landing_zone.dns_host_or_ip]
  pi_network_mtu       = 9000
  
  timeouts {
    create = "10m"
  }
}

########################################################
# PowerVS AIX Instances for Oracle RAC Cluster
# Creates multiple AIX instances with replication policy
########################################################

resource "ibm_pi_instance" "rac_nodes" {
  provider = ibm.ibm-pi
  
  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_instance_name     = "${var.prefix}-rac-aix"
  pi_image_id          = var.pi_aix_image_name
  pi_key_pair_name     = module.landing_zone.powervs_ssh_public_key.name
  pi_memory            = var.pi_aix_instance.memory_gb
  pi_processors        = var.pi_aix_instance.cores
  pi_proc_type         = var.pi_aix_instance.core_type
  pi_sys_type          = var.pi_aix_instance.machine_type

  # Attach all 4 networks: management, public, private1, private2
  dynamic "pi_network" {
    for_each = concat(
      [module.landing_zone.powervs_management_subnet],
      local.powervs_rac_networks_auto
    )
    content {
      network_id = pi_network.value.id
    }
  }

  pi_storage_type          = "tier1"
  pi_pin_policy            = var.pi_aix_instance.pin_policy
  pi_health_status         = var.pi_aix_instance.health_status
  pi_storage_pool_affinity = false
  
  # Create multiple instances with replication
  pi_replicants         = var.rac_nodes
  pi_replication_scheme = "suffix"
  pi_replication_policy = var.pi_replication_policy
  pi_user_tags          = var.pi_user_tags

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
  provider             = ibm.ibm-pi
  
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
    for idx in range(var.rac_nodes) :
    local.rac_instance_map["${var.prefix}-rac-aix-${idx + 1}"]
  ]

  # Extract IPs for each node and network
  rac_node_ips = {
    for idx in range(var.rac_nodes) :
    idx => {
      management = local.rac_instances[idx].networks[0].ip
      public     = local.rac_instances[idx].networks[1].ip
      private1   = local.rac_instances[idx].networks[2].ip
      private2   = local.rac_instances[idx].networks[3].ip
    }
  }
  
  # Management IPs list for Ansible inventory
  aix_management_ips = [
    for idx in range(var.rac_nodes) :
    local.rac_instances[idx].networks[0].ip
  ]
  
  # hosts_and_vars map for Ansible inventory (matching RAC standard solution)
  hosts_and_vars = {
    for idx in range(var.rac_nodes) :
    local.rac_instances[idx].server_name => {
      ip                     = local.rac_instances[idx].networks[0].ip
      EXTEND_ROOT_VOLUME_WWN = ibm_pi_volume.node_storage[idx].wwn
    }
  }
}

########################################################
# Storage Volumes for RAC Nodes
# Node-local volumes: rootvg (for root volume extension)
########################################################

resource "ibm_pi_volume" "node_storage" {
  provider = ibm.ibm-pi
  
  for_each = {
    for idx in range(var.rac_nodes) :
    idx => local.rac_instances[idx]
  }

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_volume_name       = "${each.value.server_name}-rootvg"
  pi_volume_size       = 40
  pi_volume_type       = "tier1"
  pi_volume_shareable  = false

  timeouts {
    create = "30m"
  } 
    lifecycle {
    ignore_changes = [pi_volume_size]
  }
}

# Attach node-local rootvg volumes
resource "ibm_pi_volume_attach" "node_storage_attach" {
  provider = ibm.ibm-pi
  
  for_each = ibm_pi_volume.node_storage

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_volume_id         = each.value.volume_id
  pi_instance_id       = local.rac_instances[each.key].pvm_instance_id

  timeouts {
    create = "30m"
  }
}

########################################################
# Shared ASM Volumes for RAC Cluster
# CRSDG, GIMR, DATA, REDO - shared across all nodes
########################################################

resource "ibm_pi_volume" "shared_asm" {
  provider = ibm.ibm-pi
  
  depends_on = [data.ibm_pi_instances.workspace_instances]
  count      = local.shared_asm_count

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_volume_name       = "${var.prefix}-asm-${local.expanded_shared_volumes[count.index].name}"
  pi_volume_size       = local.expanded_shared_volumes[count.index].size
  pi_volume_type       = local.expanded_shared_volumes[count.index].tier
  pi_volume_shareable  = true

  timeouts {
    create = "30m"
  }
}

# Attach shared ASM volumes to first node
resource "ibm_pi_volume_attach" "shared_asm_attach_node0" {
  provider = ibm.ibm-pi
  
  count      = local.shared_asm_count
  depends_on = [ibm_pi_volume_attach.node_storage_attach]

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  pi_instance_id       = local.rac_instances[0].pvm_instance_id
  pi_volume_id         = ibm_pi_volume.shared_asm[count.index].volume_id

  timeouts {
    create = "30m"
  }
}

# Attach shared ASM volumes to other nodes
resource "ibm_pi_volume_attach" "shared_asm_attach_other_nodes" {
  provider = ibm.ibm-pi
  
  count      = (var.rac_nodes - 1) * local.shared_asm_count
  depends_on = [ibm_pi_volume_attach.shared_asm_attach_node0]

  pi_cloud_instance_id = module.landing_zone.powervs_workspace_guid
  
  # Calculate which node (1, 2, 3, ...)
  pi_instance_id = local.rac_instances[
    1 + floor(count.index / local.shared_asm_count)
  ].pvm_instance_id
  
  # Calculate which volume (0..shared_asm_count-1)
  pi_volume_id = ibm_pi_volume.shared_asm[
    count.index % local.shared_asm_count
  ].volume_id

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
  depends_on = [ibm_pi_volume_attach.node_storage_attach, terraform_data.reconfigure_ansible_host]

  # Required parameters
  deployment_type        = "public"  # Always public for ready-to-go solution
  bastion_host_ip        = module.landing_zone.access_host_or_ip
  squid_server_ip        = split(":", module.landing_zone.proxy_host_or_ip_port)[0]  # Extract IP from IP:PORT
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  # Template configuration
  src_script_template_name = "aix-init/ansible_exec.sh.tftpl"
  dst_script_file_name     = "aix_init_rac.sh"

  src_playbook_template_name = "aix-init/playbook-aix-init.yml.tftpl"
  dst_playbook_file_name     = "aix-init-rac-playbook.yml"
  
  playbook_template_vars = {
    PROXY_IP_PORT          = module.landing_zone.proxy_host_or_ip_port
    NO_PROXY               = "localhost,127.0.0.1"
    ORA_NFS_HOST           = local.nfs_server
    ORA_NFS_DEVICE         = local.nfs_device  # NFS export path for mounting
    EXTEND_ROOT_VOLUME_WWN = "" # Will be set per node via hosts_and_vars
    AIX_INIT_MODE          = "rac"
    ROOT_PASSWORD          = var.root_password
  }

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "aix-init-rac-inventory"
  inventory_template_vars = {
    host_or_ip     = local.aix_management_ips
    hosts_and_vars = local.hosts_and_vars
  }
}

########################################################
# Download Oracle Binaries from IBM Cloud Object Storage
# to Network Services VSI NFS mount point
########################################################

module "ibmcloud_cos_oracle" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.landing_zone, terraform_data.reconfigure_ansible_host]

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

  # Required parameters
  deployment_type        = "public"  # Always public for ready-to-go solution
  bastion_host_ip        = module.landing_zone.access_host_or_ip
  squid_server_ip        = split(":", module.landing_zone.proxy_host_or_ip_port)[0]  # Extract IP from IP:PORT
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  # Template configuration
  src_script_template_name = "oracle-grid-install-rac/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_rac_install.sh"

  src_playbook_template_name = "oracle-grid-install-rac/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-rac.yml"
  playbook_template_vars     = local.playbook_oracle_rac_install_vars

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "oracle-rac-install-inventory"
  inventory_template_vars = {
    host_or_ip     = local.aix_management_ips
    hosts_and_vars = local.hosts_and_vars
  }
}