########################################################
# Local Variables and Configuration for Oracle RAC
########################################################

locals {
  # Region mapping for PowerVS zones to VPC regions
  powervs_zone_region_map = {
    "dal10"    = "us-south"
    "dal12"    = "us-south"
    "dal13"    = "us-south"
    "us-south" = "us-south"
    "us-east"  = "us-east"
    "wdc06"    = "us-east"
    "wdc07"    = "us-east"
    "sao01"    = "br-sao"
    "sao04"    = "br-sao"
    "tor01"    = "ca-tor"
    "mon01"    = "ca-tor"
    "eu-de-1"  = "eu-de"
    "eu-de-2"  = "eu-de"
    "lon04"    = "eu-gb"
    "lon06"    = "eu-gb"
    "mad02"    = "eu-es"
    "mad04"    = "eu-es"
    "syd04"    = "au-syd"
    "syd05"    = "au-syd"
    "tok04"    = "jp-tok"
    "osa21"    = "jp-osa"
  }

  # PowerVS zone cloud connection mapping
  powervs_zone_cloud_connection_map = {
    "dal10"    = "us-south"
    "dal12"    = "us-south"
    "dal13"    = "us-south"
    "us-south" = "us-south"
    "us-east"  = "us-east"
    "wdc06"    = "us-east"
    "wdc07"    = "us-east"
    "sao01"    = "br-sao"
    "sao04"    = "br-sao"
    "tor01"    = "ca-tor"
    "mon01"    = "ca-tor"
    "eu-de-1"  = "eu-de"
    "eu-de-2"  = "eu-de"
    "lon04"    = "eu-gb"
    "lon06"    = "eu-gb"
    "mad02"    = "eu-es"
    "mad04"    = "eu-es"
    "syd04"    = "au-syd"
    "syd05"    = "au-syd"
    "tok04"    = "jp-tok"
    "osa21"    = "jp-osa"
  }

  # Derived regions
  powervs_region = lookup(local.powervs_zone_cloud_connection_map, var.powervs_zone, null)
  vpc_region     = lookup(local.powervs_zone_region_map, var.powervs_zone, null)
  vpc_zone       = "${local.vpc_region}-1"

  # NFS mount point for Oracle binaries
  nfs_mount = "/nfs"

  # RAC-specific configuration
  scan_name = "${var.prefix}-scan"
  ora_version = "19c"
  
  # AIX network interfaces for RAC
  aix_network_interfaces = {
    public   = "en1"
    private1 = "en2"
    private2 = "en3"
  }

  # Network services configuration for PowerVS instances
  powervs_network_services_config = {
    squid = {
      enable               = true
      squid_server_ip_port = module.landing_zone.proxy_host_or_ip_port
      no_proxy_hosts       = "161.0.0.0/8,10.0.0.0/8,localhost,127.0.0.1"
    }
    nfs = {
      enable          = true
      nfs_server_path = module.landing_zone.nfs_host_or_ip_path
      nfs_client_path = var.nfs_server_config.mount_path
      opts            = module.landing_zone.network_services_config.nfs.opts
      fstype          = module.landing_zone.network_services_config.nfs.fstype
    }
    dns = {
      enable        = true
      dns_server_ip = module.landing_zone.dns_host_or_ip
    }
    ntp = {
      enable        = module.landing_zone.ntp_host_or_ip != "" ? true : false
      ntp_server_ip = module.landing_zone.ntp_host_or_ip
    }
  }

  # Storage configuration
  pi_boot_volume = {
    name  = "rootvg"
    size  = "40"
    count = "1"
    tier  = "tier1"
  }

  pi_crsdg_volume = {
    name  = "CRSDG"
    size  = "1"
    count = "4"
    tier  = "tier1"
  }

  # Dynamic GIMR sizing based on RAC nodes
  # Formula: 20GB base + (5GB per additional node beyond 2)
  # 2 nodes = 40GB total, 4 nodes = 50GB total, 8 nodes = 70GB total
  gimr_size_per_disk = var.rac_node_count <= 2 ? "20" : tostring(20 + ((var.rac_node_count - 2) * 5))
  
  pi_gimr_volume = {
    name  = "GIMR"
    size  = local.gimr_size_per_disk
    count = "2"
    tier  = "tier1"
  }

  pi_arc_volume = {
    name  = "arch"
    size  = "10"
    count = "2"
    tier  = "tier3"
  }

  # Calculate total sizes for Ansible (subtract 1GB for VG overhead)
  oravg_total_size = tonumber(var.powervs_oravg_volume.size) * tonumber(var.powervs_oravg_volume.count)
  data_total_size  = tonumber(var.powervs_data_volume.size) * tonumber(var.powervs_data_volume.count)
  redo_total_size  = tonumber(var.powervs_redo_volume.size) * tonumber(var.powervs_redo_volume.count)
  gimr_total_size  = tonumber(local.pi_gimr_volume.size) * tonumber(local.pi_gimr_volume.count)
  arch_total_size  = tonumber(local.pi_arc_volume.size) * tonumber(local.pi_arc_volume.count)

  # Storage configuration for each RAC node (ASM is mandatory for RAC)
  powervs_rac_storage_config = [
    local.pi_boot_volume,
    var.powervs_oravg_volume,   # Oracle software VG
    local.pi_crsdg_volume,       # ASM CRSDG
    var.powervs_data_volume,     # ASM DATA diskgroup
    var.powervs_redo_volume,     # ASM REDO diskgroup
    local.pi_gimr_volume,        # ASM GIMR diskgroup
    local.pi_arc_volume          # ASM ARCH diskgroup
  ]

  # COS service credentials
  cos_service_credentials  = jsondecode(var.ibmcloud_cos_service_credentials)
  cos_apikey               = local.cos_service_credentials.apikey
  cos_resource_instance_id = local.cos_service_credentials.resource_instance_id

  # COS configurations for Oracle binaries
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

  ibmcloud_cos_cluvfy_configuration = var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path != null ? {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path
    download_dir_path        = local.nfs_mount
  } : null

  # Network details for RAC configuration
  # Assuming network order: [0]=management, [1]=public, [2]=priv1, [3]=priv2
  mgmt_network   = module.landing_zone.powervs_management_subnet
  public_network = length(var.powervs_rac_networks) > 0 ? var.powervs_rac_networks[0] : null
  priv1_network  = length(var.powervs_rac_networks) > 1 ? var.powervs_rac_networks[1] : null
  priv2_network  = length(var.powervs_rac_networks) > 2 ? var.powervs_rac_networks[2] : null

  # Auto-generate SCAN IPs from public network CIDR
  scan_ips_list = local.public_network != null ? [
    cidrhost(local.public_network.cidr, 241),
    cidrhost(local.public_network.cidr, 242),
    cidrhost(local.public_network.cidr, 243)
  ] : []

  # Ansible playbook variables for Oracle RAC installation
  playbook_oracle_rac_install_vars = {
    ORA_NFS_HOST        = module.landing_zone.ansible_host_or_ip
    ORA_NFS_DEVICE      = local.nfs_mount
    DATABASE_SW         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    CLUVFY_FILE         = local.ibmcloud_cos_cluvfy_configuration != null ? "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path}" : ""
    ORA_SID             = var.oracle_sid
    ORA_DB_PASSWORD     = var.oracle_db_password
    REDOLOG_SIZE_IN_MB  = var.oracle_redolog_size_in_mb
    SCAN_NAME           = local.scan_name
    SCAN_IPS            = join(",", local.scan_ips_list)
    RAC_NODE_COUNT      = var.rac_node_count
    # Pass calculated sizes to Ansible (subtract 1GB for VG overhead)
    ORAVG_SIZE = tostring(local.oravg_total_size - 1)
    DATA_SIZE  = tostring(local.data_total_size - 1)
    REDO_SIZE  = tostring(local.redo_total_size - 1)
    GIMR_SIZE  = tostring(local.gimr_total_size - 1)
    ARCH_SIZE  = tostring(local.arch_total_size - 1)
    # Network interface names
    PUBLIC_INTERFACE   = local.aix_network_interfaces.public
    PRIVATE1_INTERFACE = local.aix_network_interfaces.private1
    PRIVATE2_INTERFACE = local.aix_network_interfaces.private2
  }
}