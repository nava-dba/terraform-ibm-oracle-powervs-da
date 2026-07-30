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

  # AIX network interfaces for RAC
  aix_network_interfaces = {
    public   = "en1"
    private1 = "en2"
    private2 = "en3"
  }

  # Automatically created RAC networks (public, private1, private2)
  # Management network is added separately via concat in instance resource
  powervs_rac_networks_auto = [
    # Index 0: RAC Public network
    {
      name = ibm_pi_network.rac_public.pi_network_name
      id   = ibm_pi_network.rac_public.network_id
      cidr = ibm_pi_network.rac_public.pi_cidr
    },
    # Index 1: RAC Private1 network
    {
      name = ibm_pi_network.rac_private1.pi_network_name
      id   = ibm_pi_network.rac_private1.network_id
      cidr = ibm_pi_network.rac_private1.pi_cidr
    },
    # Index 2: RAC Private2 network
    {
      name = ibm_pi_network.rac_private2.pi_network_name
      id   = ibm_pi_network.rac_private2.network_id
      cidr = ibm_pi_network.rac_private2.pi_cidr
    }
  ]

  ########################################################
  # Storage configuration
  ########################################################

  # CRSDG volume configuration
  pi_crsdg_volume = {
    name  = "CRSDG"
    size  = "1"
    count = "4"
    tier  = "tier1"
  }

  # Dynamic GIMR sizing based on RAC nodes
  # Formula: 20GB base + (5GB per additional node beyond 2)
  # 2 nodes = 40GB total, 4 nodes = 50GB total, 8 nodes = 70GB total
  gimr_size_per_disk = var.rac_nodes <= 2 ? "20" : tostring(20 + ((var.rac_nodes - 2) * 5))

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

  # Expand shared volumes into individual disks
  expanded_shared_volumes = flatten([
    for vol in [local.pi_crsdg_volume, var.pi_data_volume, var.pi_redo_volume, local.pi_gimr_volume] : [
      for i in range(tonumber(vol.count)) : {
        name = "${vol.name}-${i + 1}"
        size = vol.size
        tier = vol.tier
      }
    ]
  ])

  shared_asm_count = length(local.expanded_shared_volumes)

  # Calculate total sizes for Ansible (subtract 1GB for VG overhead)
  oravg_total_size = tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)
  data_total_size  = tonumber(var.pi_data_volume.size) * tonumber(var.pi_data_volume.count)
  redo_total_size  = tonumber(var.pi_redo_volume.size) * tonumber(var.pi_redo_volume.count)
  gimr_total_size  = tonumber(local.pi_gimr_volume.size) * tonumber(local.pi_gimr_volume.count)
  arch_total_size  = tonumber(local.pi_arc_volume.size) * tonumber(local.pi_arc_volume.count)

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
  # RAC networks: [0]=public, [1]=priv1, [2]=priv2
  public_network = local.powervs_rac_networks_auto[0]
  priv1_network  = local.powervs_rac_networks_auto[1]
  priv2_network  = local.powervs_rac_networks_auto[2]

  # Auto-generate SCAN IPs from public network CIDR
  scan_ips_list = local.public_network != null ? [
    cidrhost(local.public_network.cidr, 241),
    cidrhost(local.public_network.cidr, 242),
    cidrhost(local.public_network.cidr, 243)
  ] : []

  # Ansible playbook variables for Oracle RAC installation
  # Uses File Storage NFS discovered from Network Services VSI
  playbook_oracle_rac_install_vars = {
    ORA_NFS_HOST       = local.nfs_server
    ORA_NFS_DEVICE     = local.nfs_device # NFS export path for mounting
    DATABASE_SW        = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW            = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE            = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE        = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    CLUVFY_FILE        = local.ibmcloud_cos_cluvfy_configuration != null ? "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_cluvfy_file_path}" : ""
    ORA_SID            = var.ora_sid
    ORA_DB_PASSWORD    = var.ora_db_password
    REDOLOG_SIZE_IN_MB = var.redolog_size_in_mb
    SCAN_NAME          = local.scan_name
    SCAN_IPS           = join(",", local.scan_ips_list)
    RAC_NODE_COUNT     = var.rac_nodes
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
