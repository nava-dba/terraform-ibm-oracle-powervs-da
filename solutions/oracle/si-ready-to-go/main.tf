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

module "standard" {
  source  = "terraform-ibm-modules/powervs-infrastructure/ibm//modules/powervs-vpc-landing-zone"
  version = "11.1.5"

  providers = {
    ibm.ibm-is = ibm.ibm-is
    ibm.ibm-pi = ibm.ibm-pi
    ibm.ibm-sm = ibm.ibm-sm
  }

  powervs_zone                = var.powervs_zone
  powervs_resource_group_name = var.powervs_resource_group_name
  prefix                      = var.prefix
  external_access_ip          = var.external_access_ip
  vpc_intel_images            = var.vpc_intel_images
  ssh_public_key              = var.ssh_public_key
  ssh_private_key             = var.ssh_private_key
  powervs_management_network  = { name = "${var.prefix}-oracle-net", cidr = var.powervs_oracle_network_cidr }
  powervs_backup_network      = null
  configure_dns_forwarder     = true
  configure_ntp_forwarder     = true
  configure_nfs_server        = true
  nfs_server_config           = var.nfs_server_config
  dns_forwarder_config        = { "dns_servers" : "161.26.0.7; 161.26.0.8; 9.9.9.9;" }
  tags                        = var.pi_user_tags
  client_to_site_vpn          = var.client_to_site_vpn
  sm_service_plan             = var.sm_service_plan
  existing_sm_instance_guid   = var.existing_sm_instance_guid
  existing_sm_instance_region = var.existing_sm_instance_region
  vpc_subnet_cidrs            = var.vpc_subnet_cidrs
}

########################################################
# Get File Storage NFS info from Landing Zone module
# Dynamically extracts NFS server and device path
########################################################

locals {
  # Extract NFS server IP and device path from module.standard output
  # Format: "10.41.10.5:/7252ceba_8a49_4048_881b_94d0b63ea2d9"
  nfs_host_or_ip_path_parts = split(":", module.standard.nfs_host_or_ip_path)
  nfs_server                = local.nfs_host_or_ip_path_parts[0]
  nfs_device                = local.nfs_host_or_ip_path_parts[1]
}

########################################################
# Reconfigure Ansible Host with Ready-to-Go Script
# This fixes the collection installation issue
########################################################

resource "terraform_data" "reconfigure_ansible_host" {
  depends_on = [module.standard]

  connection {
    type         = "ssh"
    user         = "root"
    bastion_host = module.standard.access_host_or_ip
    host         = module.standard.ansible_host_or_ip
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
      "squid_server_ip=${split(":", module.standard.proxy_host_or_ip_port)[0]} hosts_file_entries='' /tmp/ansible_node_packages_ready_to_go.sh",
      "rm -f /tmp/ansible_node_packages_ready_to_go.sh"
    ]
  }
}

########################################################
# PowerVS AIX Instance for Oracle Database
########################################################

module "pi_instance_aix" {
  source     = "terraform-ibm-modules/powervs-instance/ibm"
  version    = "2.8.9"
  providers  = { ibm = ibm.ibm-pi }
  depends_on = [module.standard]

  pi_workspace_guid          = module.standard.powervs_workspace_guid
  pi_ssh_public_key_name     = module.standard.powervs_ssh_public_key.name
  pi_image_id                = local.pi_aix_instance.image_id
  pi_networks                = [module.standard.powervs_management_subnet]
  pi_instance_name           = "${var.prefix}-ora-aix"
  pi_pin_policy              = local.pi_aix_instance.pin_policy
  pi_server_type             = local.pi_aix_instance.server_type
  pi_number_of_processors    = local.pi_aix_instance.number_of_processors
  pi_memory_size             = local.pi_aix_instance.memory_size
  pi_cpu_proc_type           = local.pi_aix_instance.cpu_proc_type
  pi_boot_image_storage_tier = local.pi_aix_instance.boot_image_storage_tier
  pi_user_tags               = local.pi_aix_instance.user_tags
  pi_storage_config          = local.powervs_aix_storage_config
}

########################################################
# AIX Instance Initialization
# - Configure proxy settings
# - Mount NFS from network services VSI
# - Extend root volume
########################################################

locals {
  # Ansible playbook variables for AIX initialization
  # Must be defined after pi_instance_aix module to reference its outputs
  # Uses File Storage NFS discovered from Network Services VSI
  playbook_aix_init_vars = {
    PROXY_IP_PORT          = module.standard.proxy_host_or_ip_port
    NO_PROXY               = local.powervs_network_services_config.squid.no_proxy_hosts
    ORA_NFS_HOST           = local.nfs_server
    ORA_NFS_DEVICE         = local.nfs_device  # NFS export path for mounting
    EXTEND_ROOT_VOLUME_WWN = module.pi_instance_aix.pi_storage_configuration[0].wwns
    AIX_INIT_MODE          = ""
    ROOT_PASSWORD          = ""
  }
}

module "pi_instance_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_aix, terraform_data.reconfigure_ansible_host]

  deployment_type        = "public"
  bastion_host_ip        = local.powervs_instance_init_aix.bastion_host_ip
  squid_server_ip        = split(":", module.standard.proxy_host_or_ip_port)[0]
  ansible_host_or_ip     = local.powervs_instance_init_aix.ansible_host_or_ip
  ssh_private_key        = local.powervs_instance_init_aix.ssh_private_key
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
  depends_on = [module.standard, terraform_data.reconfigure_ansible_host]

  access_host_or_ip          = module.standard.access_host_or_ip
  target_server_ip           = module.standard.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_oracle_configuration
}

module "ibmcloud_cos_patch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_oracle]

  access_host_or_ip          = module.standard.access_host_or_ip
  target_server_ip           = module.standard.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_patch_configuration
}

module "ibmcloud_cos_opatch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_patch]

  access_host_or_ip          = module.standard.access_host_or_ip
  target_server_ip           = module.standard.ansible_host_or_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_opatch_configuration
}

module "ibmcloud_cos_grid" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_opatch]
  count      = var.oracle_install_type == "ASM" ? 1 : 0

  access_host_or_ip          = module.standard.access_host_or_ip
  target_server_ip           = module.standard.ansible_host_or_ip
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

  deployment_type        = "public"
  bastion_host_ip        = module.standard.access_host_or_ip
  squid_server_ip        = split(":", module.standard.proxy_host_or_ip_port)[0]
  ansible_host_or_ip     = module.standard.ansible_host_or_ip
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