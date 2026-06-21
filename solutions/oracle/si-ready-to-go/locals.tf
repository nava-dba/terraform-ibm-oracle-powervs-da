########################################################
# Local Variables and Configuration
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

  # Network services configuration for PowerVS instances
  powervs_network_services_config = {
    squid = {
      enable               = true
      squid_server_ip_port = module.standard.proxy_host_or_ip_port
      no_proxy_hosts       = "161.0.0.0/8,${var.vpc_subnet_cidrs.vpn},${var.vpc_subnet_cidrs.mgmt},${var.vpc_subnet_cidrs.vpe},${var.vpc_subnet_cidrs.edge},${var.powervs_oracle_network_cidr != null ? "${var.powervs_oracle_network_cidr}," : ""}${var.client_to_site_vpn.client_ip_pool}"
    }
    nfs = {
      enable          = true
      nfs_server_path = module.standard.nfs_host_or_ip_path
      nfs_client_path = var.nfs_server_config.mount_path
      opts            = module.standard.network_services_config.nfs.opts
      fstype          = module.standard.network_services_config.nfs.fstype
    }
    dns = {
      enable        = true
      dns_server_ip = module.standard.dns_host_or_ip
    }
    ntp = {
      enable        = module.standard.ntp_host_or_ip != "" ? true : false
      ntp_server_ip = module.standard.ntp_host_or_ip
    }
  }

  # PowerVS AIX instance configuration
  # CPU cores with fallback to 0.25 for public deployment if not specified
  pi_aix_cpu_cores = coalesce(
    try(var.pi_aix_instance.cores, null),
    0.25
  )

  powervs_aix_instance = {
    name                    = "ora-aix"
    image_id                = var.pi_aix_image_name
    memory_size             = var.pi_aix_instance.memory_gb
    number_of_processors    = local.pi_aix_cpu_cores
    cpu_proc_type           = var.pi_aix_instance.core_type
    server_type             = var.pi_aix_instance.machine_type
    pin_policy              = var.pi_aix_instance.pin_policy
    boot_image_storage_tier = "tier1"
    user_tags               = var.pi_user_tags
  }

  # Storage volumes configuration
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

  pi_arc_volume = {
    name  = "ARCH"
    size  = "10"
    count = "4"
    tier  = "tier3"
  }

  # Calculate total sizes for Ansible (subtract 1GB for VG overhead)
  oravg_total_size = tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)
  data_total_size  = tonumber(var.pi_data_volume.size) * tonumber(var.pi_data_volume.count)
  redo_total_size  = tonumber(var.pi_redo_volume.size) * tonumber(var.pi_redo_volume.count)
  arch_total_size  = tonumber(local.pi_arc_volume.size) * tonumber(local.pi_arc_volume.count)

  # Storage configuration for AIX instance based on Oracle install type
  powervs_aix_storage_config = (
    var.oracle_install_type == "ASM" ?
    [
      local.pi_boot_volume,
      var.pi_oravg_volume, # Oracle software VG
      local.pi_crsdg_volume,    # ASM CRSDG
      var.pi_data_volume,  # ASM DATA diskgroup
      var.pi_redo_volume,  # ASM REDO diskgroup
      local.pi_arc_volume       # ASM ARCH diskgroup
    ] :
    [
      local.pi_boot_volume,
      var.pi_oravg_volume, # Oracle software VG
      var.pi_data_volume,  # JFS2 DATAVG (for datafiles)
      var.pi_redo_volume,  # JFS2 REDOVG (for redo + control files)
      local.pi_arc_volume       # JFS2 ARCHVG (for archives)
    ]
  )

  # COS service credentials
  cos_service_credentials  = jsondecode(var.ibmcloud_cos_service_credentials)
  cos_apikey               = local.cos_service_credentials.apikey
  cos_resource_instance_id = local.cos_service_credentials.resource_instance_id

  # COS configurations for Oracle binaries download
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

  # AIX instance initialization configuration
  powervs_instance_init_aix = {
    enable             = true
    bastion_host_ip    = module.standard.access_host_or_ip
    ansible_host_or_ip = module.standard.ansible_host_or_ip
    ssh_private_key    = var.ssh_private_key
  }

  # Ansible playbook variables for Oracle installation
  # Uses File Storage NFS discovered from Network Services VSI
  playbook_oracle_install_vars = {
    ORA_NFS_HOST        = local.nfs_server
    ORA_NFS_DEVICE      = local.nfs_device  # NFS export path for mounting
    DATABASE_SW         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    ORA_SID             = var.ora_sid
    ORACLE_INSTALL_TYPE = var.oracle_install_type
    ORA_DB_PASSWORD     = var.ora_db_password
    REDOLOG_SIZE_IN_MB  = var.redolog_size_in_mb
    ORAVG_SIZE          = tostring(local.oravg_total_size - 1)
    DATA_SIZE           = tostring(local.data_total_size - 1)
    REDO_SIZE           = tostring(local.redo_total_size - 1)
    ARCH_SIZE           = tostring(local.arch_total_size - 1)
  }
}