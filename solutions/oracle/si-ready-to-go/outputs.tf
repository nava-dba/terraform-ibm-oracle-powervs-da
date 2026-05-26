########################################################
# VPC Landing Zone Outputs
########################################################

output "prefix" {
  description = "The prefix used for all resources."
  value       = var.prefix
}

output "powervs_zone" {
  description = "PowerVS zone where infrastructure is deployed."
  value       = var.powervs_zone
}

output "powervs_resource_group_name" {
  description = "IBM Cloud resource group name."
  value       = var.powervs_resource_group_name
}

########################################################
# Access and Network Services
########################################################

output "access_host_or_ip" {
  description = "Management (bastion) host IP address for SSH access."
  value       = module.landing_zone.access_host_or_ip
}

output "ansible_host_or_ip" {
  description = "Network services VSI IP address (Ansible execution node)."
  value       = module.landing_zone.ansible_host_or_ip
}

output "proxy_host_or_ip_port" {
  description = "SQUID proxy server address and port."
  value       = module.landing_zone.proxy_host_or_ip_port
}

output "dns_host_or_ip" {
  description = "DNS forwarder IP address."
  value       = module.landing_zone.dns_host_or_ip
}

output "ntp_host_or_ip" {
  description = "NTP server IP address."
  value       = module.landing_zone.ntp_host_or_ip
}

output "nfs_host_or_ip_path" {
  description = "NFS server path for shared storage."
  value       = module.landing_zone.nfs_host_or_ip_path
}

output "network_services_config" {
  description = "Complete network services configuration."
  value       = module.landing_zone.network_services_config
}

########################################################
# PowerVS Workspace
########################################################

output "powervs_workspace_name" {
  description = "Name of the PowerVS workspace."
  value       = module.landing_zone.powervs_workspace_name
}

output "powervs_workspace_id" {
  description = "ID of the PowerVS workspace."
  value       = module.landing_zone.powervs_workspace_id
}

output "powervs_workspace_guid" {
  description = "GUID of the PowerVS workspace."
  value       = module.landing_zone.powervs_workspace_guid
}

output "powervs_ssh_public_key" {
  description = "SSH public key details in PowerVS workspace."
  value       = module.landing_zone.powervs_ssh_public_key
}

output "powervs_management_subnet" {
  description = "PowerVS management subnet details."
  value       = module.landing_zone.powervs_management_subnet
}

########################################################
# Transit Gateway
########################################################

output "transit_gateway_name" {
  description = "Name of the transit gateway."
  value       = module.landing_zone.transit_gateway_name
}

output "transit_gateway_id" {
  description = "ID of the transit gateway."
  value       = module.landing_zone.transit_gateway_id
}

########################################################
# VPC Infrastructure
########################################################

output "vpc_names" {
  description = "List of VPC names."
  value       = module.landing_zone.vpc_names
}

output "vsi_list" {
  description = "List of VSI details (name, id, zone, IP, VPC, floating IP)."
  value       = module.landing_zone.vsi_list
}

output "vsi_names" {
  description = "List of VSI names."
  value       = module.landing_zone.vsi_names
}

########################################################
# Oracle AIX Instance
########################################################

output "oracle_aix_instance_name" {
  description = "Name of the Oracle AIX instance."
  value       = module.pi_instance_aix.pi_instance_name
}

output "oracle_aix_instance_id" {
  description = "ID of the Oracle AIX instance."
  value       = module.pi_instance_aix.pi_instance_id
}

output "oracle_aix_instance_management_ip" {
  description = "Management IP address of the Oracle AIX instance."
  value       = module.pi_instance_aix.pi_instance_primary_ip
}

output "oracle_aix_instance_private_ips" {
  description = "All private IP addresses of the Oracle AIX instance."
  value       = module.pi_instance_aix.pi_instance_private_ips
}

output "oracle_aix_storage_configuration" {
  description = "Storage configuration of the Oracle AIX instance."
  value       = module.pi_instance_aix.pi_storage_configuration
}

########################################################
# Oracle Database Configuration
########################################################

output "oracle_sid" {
  description = "Oracle System Identifier (SID)."
  value       = var.oracle_sid
}

output "oracle_install_type" {
  description = "Oracle installation type (ASM or JFS2)."
  value       = var.oracle_install_type
}

########################################################
# Optional: Monitoring
########################################################

output "monitoring_instance" {
  description = "IBM Cloud Monitoring instance details."
  value       = module.landing_zone.monitoring_instance
}

########################################################
# Optional: Security and Compliance
########################################################

output "scc_wp_instance" {
  description = "Security and Compliance Center Workload Protection instance details."
  value       = module.landing_zone.scc_wp_instance
}

########################################################
# SSH Access Instructions
########################################################

output "ssh_access_instructions" {
  description = "Instructions for SSH access to the Oracle AIX instance."
  value = <<-EOT
    
    ========================================
    SSH Access Instructions
    ========================================
    
    1. Access Management (Bastion) Host:
       ssh root@${module.landing_zone.access_host_or_ip}
    
    2. From Bastion, access Oracle AIX instance:
       ssh root@${module.pi_instance_aix.pi_instance_primary_ip}
    
    3. Oracle Database Connection:
       - SID: ${var.oracle_sid}
       - Connect as SYSDBA: sqlplus / as sysdba
    
    4. Network Services:
       - Proxy: ${module.landing_zone.proxy_host_or_ip_port}
       - DNS: ${module.landing_zone.dns_host_or_ip}
       - NTP: ${module.landing_zone.ntp_host_or_ip}
       - NFS: ${module.landing_zone.nfs_host_or_ip_path}
    
    ========================================
  EOT
}