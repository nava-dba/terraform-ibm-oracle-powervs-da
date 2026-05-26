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

  # PowerVS AIX instance configuration
  powervs_aix_instance = {
    name                       = "ora-aix"
    image_id                   = var.powervs_aix_image_name
    memory_size                = var.powervs_aix_instance.memory_gb
    number_of_processors       = var.powervs_aix_instance.cores
    cpu_proc_type              = var.powervs_aix_instance.core_type
    server_type                = var.powervs_aix_instance.machine_type
    pin_policy                 = var.powervs_aix_instance.pin_policy
    boot_image_storage_tier    = "tier1"
    user_tags                  = var.tags
  }

  # Storage configuration based on Oracle install type
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
  oravg_total_size = tonumber(var.powervs_oravg_volume.size) * tonumber(var.powervs_oravg_volume.count)
  data_total_size  = tonumber(var.powervs_data_volume.size) * tonumber(var.powervs_data_volume.count)
  redo_total_size  = tonumber(var.powervs_redo_volume.size) * tonumber(var.powervs_redo_volume.count)
  arch_total_size  = tonumber(local.pi_arc_volume.size) * tonumber(local.pi_arc_volume.count)

  # Storage configuration for AIX instance
  powervs_aix_storage_config = (
    var.oracle_install_type == "ASM" ?
    [
      local.pi_boot_volume,
      var.powervs_oravg_volume,   # Oracle software VG
      local.pi_crsdg_volume,       # ASM CRSDG
      var.powervs_data_volume,     # ASM DATA diskgroup
      var.powervs_redo_volume,     # ASM REDO diskgroup
      local.pi_arc_volume          # ASM ARCH diskgroup
    ] :
    [
      local.pi_boot_volume,
      var.powervs_oravg_volume,    # Oracle software VG
      var.powervs_data_volume,     # JFS2 DATAVG (for datafiles)
      var.powervs_redo_volume,     # JFS2 REDOVG (for redo + control files)
      local.pi_arc_volume          # JFS2 ARCHVG (for archives)
    ]
  )

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

  # Ansible playbook variables for Oracle installation
  playbook_oracle_install_vars = {
    ORA_NFS_HOST        = module.landing_zone.ansible_host_or_ip
    ORA_NFS_DEVICE      = local.nfs_mount
    DATABASE_SW         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    ORA_SID             = var.oracle_sid
    ORACLE_INSTALL_TYPE = var.oracle_install_type
    ORA_DB_PASSWORD     = var.oracle_db_password
    REDOLOG_SIZE_IN_MB  = var.oracle_redolog_size_in_mb
    ORAVG_SIZE          = tostring(local.oravg_total_size - 1)
    DATA_SIZE           = tostring(local.data_total_size - 1)
    REDO_SIZE           = tostring(local.redo_total_size - 1)
    ARCH_SIZE           = tostring(local.arch_total_size - 1)
  }

  # Ansible playbook variables for AIX initialization
  playbook_aix_init_vars = {
    PROXY_IP_PORT          = module.landing_zone.proxy_host_or_ip_port
    NO_PROXY               = "localhost,127.0.0.1"
    ORA_NFS_HOST           = module.pi_instance_aix.pi_instance_primary_ip
    ORA_NFS_DEVICE         = local.nfs_mount
    EXTEND_ROOT_VOLUME_WWN = module.pi_instance_aix.pi_storage_configuration[0].wwns
    AIX_INIT_MODE          = ""
    ROOT_PASSWORD          = ""
  }
}