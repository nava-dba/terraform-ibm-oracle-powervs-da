########################################################
# Oracle Database Single Instance (SI) - Ready to Go
# 
# This solution creates:
# 1. VPC Landing Zone with 2 VSIs (Management + Network Services)
# 2. PowerVS Workspace with networks
# 3. AIX instance for Oracle Database
# 4. Automated Oracle Grid Infrastructure and Database installation
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

  # PowerVS network configuration
  powervs_management_network = {
    name = "${var.prefix}-oracle-mgmt"
    cidr = var.powervs_management_network_cidr
  }
  powervs_backup_network = null # Not needed for Oracle SI

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
  enable_monitoring               = var.enable_monitoring
  existing_monitoring_instance_crn = var.existing_monitoring_instance_crn
  enable_scc_wp                   = var.enable_scc_wp
  ansible_vault_password          = var.ansible_vault_password
}

########################################################
# PowerVS AIX Instance for Oracle Database
########################################################

module "pi_instance_aix" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.8.9"

  depends_on = [module.landing_zone]

  pi_workspace_guid          = module.landing_zone.powervs_workspace_guid
  pi_ssh_public_key_name     = module.landing_zone.powervs_ssh_public_key.name
  pi_image_id                = var.powervs_aix_image_name
  pi_networks                = [module.landing_zone.powervs_management_subnet]
  pi_instance_name           = "${var.prefix}-ora-aix"
  pi_pin_policy              = local.powervs_aix_instance.pin_policy
  pi_server_type             = local.powervs_aix_instance.server_type
  pi_number_of_processors    = local.powervs_aix_instance.number_of_processors
  pi_memory_size             = local.powervs_aix_instance.memory_size
  pi_cpu_proc_type           = local.powervs_aix_instance.cpu_proc_type
  pi_boot_image_storage_tier = local.powervs_aix_instance.boot_image_storage_tier
  pi_user_tags               = local.powervs_aix_instance.user_tags
  pi_storage_config          = local.powervs_aix_storage_config
}

########################################################
# AIX Instance Initialization
# - Configure proxy settings
# - Mount NFS from network services VSI
# - Extend root volume
########################################################

module "pi_instance_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_aix]

  bastion_host_ip        = module.landing_zone.access_host_or_ip
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  src_script_template_name = "aix-init/ansible_exec.sh.tftpl"
  dst_script_file_name     = "aix_init.sh"

  src_playbook_template_name = "aix-init/playbook-aix-init.yml.tftpl"
  dst_playbook_file_name     = "aix-init-playbook.yml"
  playbook_template_vars     = local.playbook_aix_init_vars

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "aix-init-inventory"
  inventory_template_vars     = { host_or_ip = module.pi_instance_aix.pi_instance_primary_ip }
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

module "ibmcloud_cos_patch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_oracle]

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

module "ibmcloud_cos_grid" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_opatch]
  count      = var.oracle_install_type == "ASM" ? 1 : 0

  access_host_or_ip          = module.landing_zone.access_host_or_ip
  target_server_ip           = module.landing_zone.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_grid_configuration
}

########################################################
# Oracle Grid Infrastructure and Database Installation
# Installs Oracle Grid (if ASM) and Oracle Database
########################################################

module "oracle_install" {
  source     = "../../../modules/ansible"
  depends_on = [module.ibmcloud_cos_grid, module.pi_instance_aix_init]

  bastion_host_ip        = module.landing_zone.access_host_or_ip
  ansible_host_or_ip     = module.landing_zone.ansible_host_or_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false

  src_script_template_name = "oracle-grid-install/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_install.sh"

  src_playbook_template_name = "oracle-grid-install/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-grid.yml"
  playbook_template_vars     = local.playbook_oracle_install_vars

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "oracle-grid-install-inventory"
  inventory_template_vars     = { host_or_ip = module.pi_instance_aix.pi_instance_primary_ip }
}