#############################
# Create RHEL VM
# Create AIX VM
# Initialize RHEL VM
# Initialize AIX VM
# Download Oracle binaries from cos
# Install GRID and RDBMS and Create Oracle Database
#############################

locals {
  nfs_mount   = "/repos"
  ora_version = "19c"

  pi_boot_volume = {
    "name" : "rootvg",
    "size" : "40",
    "count" : "1",
    "tier" : "tier1"
  }

  pi_crsdg_volume = {
    "name" : "CRSDG",
    "size" : "4",
    "count" : "4",
    "tier" : "tier1"
  }

  # Dynamic GIMR sizing based on RAC nodes
  # Formula: 20GB base + (10GB per additional node beyond 2)
  # 2 nodes = 40GB total, 4 nodes = 60GB total, 8 nodes = 100GB total

  gimr_size_per_disk = var.rac_nodes <= 2 ? "20" : tostring(20 + ((var.rac_nodes - 2) * 5))
  pi_gimr_volume = {
    "name" : "GIMR",
    "size" : local.gimr_size_per_disk,
    "count" : "2",
    "tier" : "tier1"
  }

  pi_arc_volume = {
    "name" : "ARCH",
    "size" : "10",
    "count" : "4",
    "tier" : "tier3"
  }

  pi_cpu_map = {
    public  = 0.25
    private = 0.05
  }

  pi_rhel_cpu_cores = lookup(local.pi_cpu_map, var.deployment_type, 0.25)

  pi_aix_cpu_cores = coalesce(
    try(var.pi_aix_instance.number_processors, null),
    lookup(local.pi_cpu_map, var.deployment_type, 0.25)
  )
}

###########################################################
# Fetch Network Details for CIDR/Gateway/Netmask
###########################################################
data "ibm_pi_network" "networks" {
  count                = length(var.pi_networks)
  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_network_name      = var.pi_networks[count.index].name
}

locals {
  # Map network details by network name for easy lookup
  network_details = {
    for idx, net in var.pi_networks :
    net.name => {
      cidr    = data.ibm_pi_network.networks[idx].cidr
      gateway = data.ibm_pi_network.networks[idx].gateway
      # Calculate netmask from CIDR
      netmask = cidrnetmask(data.ibm_pi_network.networks[idx].cidr)
    }
  }

  # Assuming network order: [0]=management, [1]=public, [2]=priv1, [3]=priv2
  # Users must provide networks in this order
  mgmt_network_name  = length(var.pi_networks) > 0 ? var.pi_networks[0].name : null
  pub_network_name   = length(var.pi_networks) > 1 ? var.pi_networks[1].name : null
  priv1_network_name = length(var.pi_networks) > 2 ? var.pi_networks[2].name : null
  priv2_network_name = length(var.pi_networks) > 3 ? var.pi_networks[3].name : null

  # Get netmasks for each network type
  netmask_mgmt  = local.mgmt_network_name != null ? local.network_details[local.mgmt_network_name].netmask : null
  netmask_pub   = local.pub_network_name != null ? local.network_details[local.pub_network_name].netmask : null
  netmask_priv1 = local.priv1_network_name != null ? local.network_details[local.priv1_network_name].netmask : null
  netmask_priv2 = local.priv2_network_name != null ? local.network_details[local.priv2_network_name].netmask : null

  # Build a stable, ordered list of networks based on user input order
  ordered_pi_networks = {
    for idx, net in var.pi_networks :
    idx => {
      name = net.name
      id   = net.id
    }
  }
  # Auto-generate SCAN IPs and VIP base
  pub_network_cidr = local.pub_network_name != null ? local.network_details[local.pub_network_name].cidr : null
  
  scan_ips_list = local.pub_network_cidr != null ? [
    cidrhost(local.pub_network_cidr, 241),
    cidrhost(local.pub_network_cidr, 242),
    cidrhost(local.pub_network_cidr, 243)
  ] : []
}

###########################################################
# Create RHEL Management VM
###########################################################
module "pi_instance_rhel" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.7.0"

  pi_workspace_guid       = var.pi_existing_workspace_guid
  pi_ssh_public_key_name  = var.pi_ssh_public_key_name
  pi_image_id             = var.pi_rhel_image_name
  pi_networks             = [var.pi_networks[0]]
  pi_instance_name        = "${var.prefix}-mgmt-rhel"
  pi_memory_size          = var.pi_memory_size
  pi_number_of_processors = local.pi_rhel_cpu_cores
  pi_server_type          = var.pi_rhel_management_server_type
  pi_cpu_proc_type        = "shared"
  pi_storage_config = [{
    name  = "nfs"
    size  = "50"
    count = "1"
    tier  = "tier3"
    mount = local.nfs_mount
  }]
}

###########################################################
# Create DNS VM
###########################################################
module "pi_instance_dns" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.7.0"

  pi_workspace_guid       = var.pi_existing_workspace_guid
  pi_ssh_public_key_name  = var.pi_ssh_public_key_name
  pi_image_id             = var.pi_rhel_image_name
  pi_networks             = [var.pi_networks[0]]
  pi_instance_name        = "${var.prefix}-dns"
  pi_memory_size          = var.pi_memory_size
  pi_number_of_processors = local.pi_rhel_cpu_cores
  pi_server_type          = var.pi_rhel_management_server_type
  pi_cpu_proc_type        = "shared"
}

###########################################################
# Create AIX VM for Oracle RAC database
###########################################################

resource "ibm_pi_instance" "rac_nodes" {  
  pi_cloud_instance_id   = var.pi_existing_workspace_guid
  pi_instance_name       = "${var.prefix}-aix"
  pi_image_id            = var.pi_aix_image_name
  pi_key_pair_name       = var.pi_ssh_public_key_name
  pi_memory              = var.pi_aix_instance.memory_size
  pi_processors          = local.pi_aix_cpu_cores
  pi_proc_type           = var.pi_aix_instance.cpu_proc_type
  pi_sys_type            = var.pi_aix_instance.server_type

  dynamic "pi_network" {
    for_each = local.ordered_pi_networks
    content {
      network_id = pi_network.value.id
    }
  }

  pi_storage_type          = "tier1"
  pi_pin_policy            = var.pi_aix_instance.pin_policy
  pi_health_status         = "OK"
  pi_storage_pool_affinity = false
  pi_replicants            = var.rac_nodes
  pi_replication_scheme    = "suffix"
  pi_replication_policy    = "affinity"
  pi_user_tags             = var.pi_user_tags

  timeouts {
    create = "50m"
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

# delay after creation of VMS
resource "time_sleep" "wait_after_rac_vm_creation" {
  depends_on      = [ibm_pi_instance.rac_nodes]
  create_duration = "180s"
}


# Refresh the data to get all IPs
data "ibm_pi_instance" "attached_instances" {
  depends_on           = [time_sleep.wait_after_rac_vm_creation]
  count                = var.rac_nodes
  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_instance_name     = "${var.prefix}-aix-${count.index + 1}"
}

locals {
  get_ip_by_network = {
    for idx in range(var.rac_nodes) :
    idx => {
      for net_name in [local.mgmt_network_name, local.pub_network_name, local.priv1_network_name, local.priv2_network_name] :
      net_name => try([
        for n in data.ibm_pi_instance.attached_instances[idx].networks :
        n.ip if n.network_name == net_name
      ][0], null) if net_name != null
    }
  }
  
  # Get dns server ip
  dns_server_ip = module.pi_instance_dns.pi_instance_primary_ip
  dns_hostname  = module.pi_instance_dns.pi_instance_name 

  hosts_and_vars = {
    for idx in range(var.rac_nodes) :
    data.ibm_pi_instance.attached_instances[idx].pi_instance_name => {
      ip                     = local.get_ip_by_network[idx][local.mgmt_network_name]
      EXTEND_ROOT_VOLUME_WWN = ibm_pi_volume.node_rootvg[idx].wwn
    }
  }

  # Update the primary IP list for Ansible modules
  aix_primary_ips = [
    for idx in range(var.rac_nodes) :
    local.get_ip_by_network[idx][local.mgmt_network_name]
  ]

  # Create /etc/hosts entries from AIX instances
  hosts_file_entries = join("\n", [
    for idx in range(var.rac_nodes) :
    "${local.hosts_and_vars[data.ibm_pi_instance.attached_instances[idx].pi_instance_name].ip} ${data.ibm_pi_instance.attached_instances[idx].pi_instance_name}"
  ])
}

#####################################################
# Create Local and Shared Volumes
#####################################################
locals {
  aix_instance_ids = [
    for i in range(var.rac_nodes) : data.ibm_pi_instance.attached_instances[i].id
  ]

  # Expand oravg volumes per node
  expanded_oravg_volumes = flatten([
    for node_idx in range(var.rac_nodes) : [
      for vol_idx in range(tonumber(var.pi_oravg_volume.count)) : {
        node_index = node_idx
        vol_index  = vol_idx
        name       = "${lower(var.pi_oravg_volume.name)}-${vol_idx + 1}"
        size       = var.pi_oravg_volume.size
        tier       = var.pi_oravg_volume.tier
      }
    ]
  ])

  oravg_volumes_per_node = tonumber(var.pi_oravg_volume.count)
  total_oravg_volumes    = var.rac_nodes * local.oravg_volumes_per_node

  expanded_shared_volumes = flatten([
    for vol in [local.pi_crsdg_volume, var.pi_data_volume, var.pi_redo_volume, local.pi_gimr_volume, local.pi_arc_volume] : [
      for i in range(tonumber(vol.count)) : {
        name = "${lower(vol.name)}-${i + 1}"
        size = vol.size
        tier = vol.tier
      }
    ]
  ])

  shared_count = length(local.expanded_shared_volumes)
}

# --- Node-local volumes: rootvg ---
resource "ibm_pi_volume" "node_rootvg" {
  depends_on = [data.ibm_pi_instance.attached_instances]
  count      = var.rac_nodes

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_volume_name       = "${var.prefix}-aix-${count.index + 1}-${local.pi_boot_volume.name}"
  pi_volume_size       = local.pi_boot_volume.size
  pi_volume_type       = local.pi_boot_volume.tier
  pi_volume_shareable  = false
  pi_user_tags         = var.pi_user_tags
  
  lifecycle {
    ignore_changes = [pi_user_tags]
  }
}

# --- Node-local volumes: oravg (multiple per node) ---
resource "ibm_pi_volume" "node_oravg" {
  depends_on = [ibm_pi_volume.node_rootvg]
  count      = local.total_oravg_volumes

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_volume_name       = "${var.prefix}-aix-${local.expanded_oravg_volumes[count.index].node_index + 1}-${local.expanded_oravg_volumes[count.index].name}"
  pi_volume_size       = local.expanded_oravg_volumes[count.index].size
  pi_volume_type       = local.expanded_oravg_volumes[count.index].tier
  pi_volume_shareable  = false
  pi_user_tags         = var.pi_user_tags
  
  lifecycle {
    ignore_changes = [pi_user_tags]
  }
}

# --- Shared volumes ---
resource "ibm_pi_volume" "shared" {
  depends_on = [ibm_pi_volume.node_oravg]
  count      = local.shared_count

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_volume_name       = "${var.prefix}-asm-${local.expanded_shared_volumes[count.index].name}"
  pi_volume_size       = local.expanded_shared_volumes[count.index].size
  pi_volume_type       = local.expanded_shared_volumes[count.index].tier
  pi_volume_shareable  = true
  pi_user_tags         = var.pi_user_tags
  
  lifecycle {
    ignore_changes = [pi_user_tags]
  }
}

# --- Attach node-local volumes: rootvg ---
resource "ibm_pi_volume_attach" "node_rootvg_attach" {
  count = var.rac_nodes

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_instance_id       = local.aix_instance_ids[count.index]
  pi_volume_id         = ibm_pi_volume.node_rootvg[count.index].volume_id

  depends_on = [
    ibm_pi_volume.node_rootvg
  ]

  lifecycle {
    ignore_changes = [pi_instance_id]
  }
}

# --- Attach node-local volumes: oravg (multiple per node) ---
resource "ibm_pi_volume_attach" "node_oravg_attach" {
  count = local.total_oravg_volumes

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_instance_id       = local.aix_instance_ids[local.expanded_oravg_volumes[count.index].node_index]
  pi_volume_id         = ibm_pi_volume.node_oravg[count.index].volume_id

  depends_on = [
    ibm_pi_volume.node_oravg,
    ibm_pi_volume_attach.node_rootvg_attach
  ]

  lifecycle {
    ignore_changes = [pi_instance_id]
  }
}


# To avoid with multiattach enabled","error":"Conflict"
# --- Attach shared volumes to first node  ---
resource "ibm_pi_volume_attach" "shared_attach_node0" {
  count = local.shared_count

  pi_cloud_instance_id = var.pi_existing_workspace_guid
  pi_instance_id       = local.aix_instance_ids[0]
  pi_volume_id         = ibm_pi_volume.shared[count.index].volume_id

  depends_on = [
    ibm_pi_volume.shared,
    ibm_pi_volume_attach.node_oravg_attach
  ]

  lifecycle {
    ignore_changes = [pi_instance_id]
  }
}


# --- Attach shared volumes to rest nodes  ---
resource "ibm_pi_volume_attach" "shared_attach_other_nodes" {
  count = (var.rac_nodes - 1) * local.shared_count

  pi_cloud_instance_id = var.pi_existing_workspace_guid

  # node index: 1..N-1
  pi_instance_id = local.aix_instance_ids[
    1 + floor(count.index / local.shared_count)
  ]

  # volume index: 0..shared_count-1
  pi_volume_id = ibm_pi_volume.shared[
    count.index % local.shared_count
  ].volume_id

  depends_on = [
    ibm_pi_volume_attach.shared_attach_node0
  ]

  lifecycle {
    ignore_changes = [pi_instance_id]
  }
}

###########################################################
# Ansible Host setup and configure as Proxy, NTP and DNS
###########################################################

locals {
  network_services_config = {
    squid = {
      enable     = true
      squid_port = "3128"
    }
  }
}

module "pi_instance_rhel_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = true
  squid_server_ip        = var.squid_server_ip
  hosts_file_entries     = local.hosts_file_entries

  src_script_template_name = "configure-rhel-management/ansible_exec.sh.tftpl"
  dst_script_file_name     = "configure-rhel-management.sh"

  src_playbook_template_name = "configure-rhel-management/playbook-configure-network-services.yml.tftpl"
  dst_playbook_file_name     = "configure-rhel-management-playbook.yml"

  playbook_template_vars = {
    server_config     = jsonencode(local.network_services_config)
    pi_storage_config = jsonencode(module.pi_instance_rhel.pi_storage_configuration)
    nfs_config = jsonencode({
      nfs = {
        enable      = true
        directories = [local.nfs_mount]
      }
    })
  }

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "configure-rhel-management-inventory"
  inventory_template_vars = {
    host_or_ip = [module.pi_instance_rhel.pi_instance_primary_ip]
  }
}

###########################################################
# AIX Initialization
###########################################################

locals {
  squid_server_ip = var.squid_server_ip

  aix_rootvg_wwns = [
    for idx in range(var.rac_nodes) :
    ibm_pi_volume.node_rootvg[idx].wwn
  ]

  playbook_aix_init_vars = {
    PROXY_IP_PORT          = "${local.squid_server_ip}:3128"
    NO_PROXY               = var.no_proxy_list
    ORA_NFS_HOST           = join(",", local.aix_primary_ips)
    ORA_NFS_DEVICE         = local.nfs_mount
    AIX_INIT_MODE          = "rac"
    ROOT_PASSWORD          = var.root_password
    EXTEND_ROOT_VOLUME_WWN = "" # Empty for RAC - will use hostvars instead
  }
}

module "pi_instance_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel_init]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip        = local.squid_server_ip

  src_script_template_name = "aix-init/ansible_exec.sh.tftpl"
  dst_script_file_name     = "aix_init.sh"

  src_playbook_template_name = "aix-init/playbook-aix-init.yml.tftpl"
  dst_playbook_file_name     = "aix-init-playbook.yml"
  playbook_template_vars     = local.playbook_aix_init_vars

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "aix-init-inventory"
  inventory_template_vars = {
    host_or_ip     = local.aix_primary_ips
    hosts_and_vars = local.hosts_and_vars
  }
}

###########################################################
# DNS Configuration for N Nodes
###########################################################
locals {
  rac_nodes_list = [
    for idx in range(var.rac_nodes) : {
      hostname = data.ibm_pi_instance.attached_instances[idx].pi_instance_name
      pub_ip   = local.get_ip_by_network[idx][local.pub_network_name]
      vip      = cidrhost(local.pub_network_cidr, 245 + idx)
    }
  ]
  
  dns_playbook_vars = {
    dns_server_ip   = tostring(local.dns_server_ip)
    dns_domain_name = tostring(var.cluster_domain)
    dns_hostname    = tostring(local.dns_hostname)
    scan_name       = tostring(var.scan_name)
    scan_ips        = jsonencode(local.scan_ips_list)
    rac_nodes_count = tostring(var.rac_nodes)
    rac_nodes       = jsonencode(local.rac_nodes_list)
  }
}


module "dns_configuration" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_aix_init]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip        = var.squid_server_ip

  src_script_template_name = "dns/ansible_exec.sh.tftpl"
  dst_script_file_name     = "dns_configuration.sh"

  src_playbook_template_name = "dns/playbook-dns-config.yml.tftpl"
  dst_playbook_file_name     = "playbook-dns-config.yml"
  playbook_template_vars     = local.dns_playbook_vars

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "dns-inventory"
  inventory_template_vars = {
    host_or_ip = [local.dns_server_ip]
  }
}

######################################################
# COS Service credentials
# Download Oracle binaries from COS
######################################################
locals {
  cos_service_credentials  = jsondecode(var.ibmcloud_cos_service_credentials)
  cos_apikey               = local.cos_service_credentials.apikey
  cos_resource_instance_id = local.cos_service_credentials.resource_instance_id

  ibmcloud_cos_oracle_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_database_sw_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_grid_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_patch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_ru_file_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_opatch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_cluvfy_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path
    download_dir_path        = local.nfs_mount
  }
}

module "ibmcloud_cos_oracle" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.pi_instance_rhel_init]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_oracle_configuration
}

module "ibmcloud_cos_patch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_oracle]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_patch_configuration
}

module "ibmcloud_cos_opatch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_patch]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_opatch_configuration
}

module "ibmcloud_cos_grid" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_opatch]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_grid_configuration
}

module "ibmcloud_cos_cluvfy" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_grid]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_cluvfy_configuration
}

###########################################################
# Oracle GRID Installation on AIX
###########################################################
locals {
  # Build cluster_nodes string
  cluster_nodes = join(",", [
    for idx in range(var.rac_nodes) :
    "${data.ibm_pi_instance.attached_instances[idx].pi_instance_name}:${data.ibm_pi_instance.attached_instances[idx].pi_instance_name}-vip"
  ])

  # Build nodes list for Oracle installation (different from DNS rac_nodes_list)
  oracle_rac_nodes = [
    for idx in range(var.rac_nodes) : {
      name     = data.ibm_pi_instance.attached_instances[idx].pi_instance_name
      fqdn     = "${data.ibm_pi_instance.attached_instances[idx].pi_instance_name}.${var.cluster_domain}"
      pub_ip   = local.get_ip_by_network[idx][local.pub_network_name]
      priv1_ip = local.get_ip_by_network[idx][local.priv1_network_name]
      priv2_ip = local.get_ip_by_network[idx][local.priv2_network_name]
      pub_if   = var.aix_network_interfaces.public
      priv1_if = var.aix_network_interfaces.private1
      priv2_if = var.aix_network_interfaces.private2
    }
  ]
  
  # Calculate total size: (size per disk * count) - 1GB for VG overhead
  oravg_total_size = (tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)) - 1

  # Base playbook vars - encode nodes as JSON string to ensure all values are strings
  playbook_oracle_install_base_vars = {
    ORA_NFS_HOST        = module.pi_instance_rhel.pi_instance_primary_ip
    ORA_NFS_DEVICE      = local.nfs_mount
    DNS_SERVER_IP       = local.dns_server_ip
    DATABASE_SW         = var.ibmcloud_cos_configuration.cos_oracle_database_sw_path
    GRID_SW             = var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path
    RU_FILE             = var.ibmcloud_cos_configuration.cos_oracle_ru_file_path
    OPATCH_FILE         = var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path
    CLUVFY_FILE         = var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path
    RU_VERSION          = var.ru_version
    ORA_SID             = var.ora_sid
    ROOT_PASSWORD       = var.root_password
    ORA_DB_PASSWORD     = var.ora_db_password
    TIME_ZONE           = var.time_zone
    CLUSTER_DOMAIN      = var.cluster_domain
    CLUSTER_NAME        = var.cluster_name
    CLUSTER_NODES       = local.cluster_nodes
    ORA_VERSION         = local.ora_version
    REDOLOG_SIZE_IN_MB  = var.redolog_size_in_mb
    ORAVG_SIZE          = tostring(local.oravg_total_size)
    ORAVG_DISK_COUNT    = tostring(var.pi_oravg_volume.count)
    netmask_pub         = local.netmask_pub
    netmask_pvt         = local.netmask_priv1
    nodes               = jsonencode(local.oracle_rac_nodes)
  }

  # Use base vars directly
  playbook_oracle_install_vars = local.playbook_oracle_install_base_vars
}

module "oracle_install" {
  source     = "../../../modules/ansible"
  depends_on = [module.ibmcloud_cos_grid, module.pi_instance_aix_init, module.dns_configuration.configuration_complete]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip        = local.squid_server_ip

  src_script_template_name = "oracle-grid-install-rac/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_install.sh"

  src_playbook_template_name = "oracle-grid-install-rac/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-grid.yml"
  playbook_template_vars     = local.playbook_oracle_install_vars

  src_vars_template_name = "oracle-grid-install-rac/rac_vars.yml.tftpl"
  dst_vars_file_name     = "rac_vars.yml"
  vars_template_vars     = local.playbook_oracle_install_vars

  src_inventory_template_name = "inventory-rac.tftpl"
  dst_inventory_file_name     = "oracle-grid-install-inventory"
  inventory_template_vars = {
    host_or_ip     = local.aix_primary_ips
    hosts_and_vars = local.hosts_and_vars
  }
}