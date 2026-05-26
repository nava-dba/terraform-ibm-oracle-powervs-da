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
# Oracle RAC Cluster
########################################################

output "rac_node_count" {
  description = "Number of nodes in the RAC cluster."
  value       = var.rac_node_count
}

output "rac_cluster_nodes" {
  description = "List of RAC cluster node details."
  value = [
    for idx in range(var.rac_node_count) : {
      name         = local.rac_instances[idx].server_name
      id           = local.rac_instances[idx].pvm_instance_id
      management_ip = local.rac_node_ips[idx].management
      public_ip     = local.rac_node_ips[idx].public
      private1_ip   = local.rac_node_ips[idx].private1
      private2_ip   = local.rac_node_ips[idx].private2
    }
  ]
}

output "rac_scan_name" {
  description = "Oracle RAC SCAN name."
  value       = local.scan_name
}

output "rac_scan_ips" {
  description = "Oracle RAC SCAN IP addresses."
  value       = local.scan_ips_list
}

########################################################
# Oracle Database Configuration
########################################################

output "oracle_sid" {
  description = "Oracle System Identifier (SID)."
  value       = var.oracle_sid
}

output "oracle_database_name" {
  description = "Oracle RAC database name (typically SID for RAC)."
  value       = var.oracle_sid
}

########################################################
# Network Configuration
########################################################

output "rac_networks" {
  description = "RAC network configuration."
  value = {
    management = module.landing_zone.powervs_management_subnet
    public     = local.public_network
    private1   = local.priv1_network
    private2   = local.priv2_network
  }
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
  description = "Instructions for SSH access to the Oracle RAC cluster."
  value = <<-EOT
    
    ========================================
    SSH Access Instructions - Oracle RAC
    ========================================
    
    1. Access Management (Bastion) Host:
       ssh root@${module.landing_zone.access_host_or_ip}
    
    2. From Bastion, access RAC nodes:
       ${join("\n       ", [for idx in range(var.rac_node_count) : "ssh root@${local.rac_node_ips[idx].management}  # ${local.rac_instances[idx].server_name}"])}
    
    3. Oracle RAC Database Connection:
       - Database Name: ${var.oracle_sid}
       - SCAN Name: ${local.scan_name}
       - SCAN IPs: ${join(", ", local.scan_ips_list)}
       - Connect String: ${var.oracle_sid}/${var.oracle_sid}@${local.scan_name}:1521/${var.oracle_sid}
       - Connect as SYSDBA: sqlplus / as sysdba
    
    4. Network Services:
       - Proxy: ${module.landing_zone.proxy_host_or_ip_port}
       - DNS: ${module.landing_zone.dns_host_or_ip}
       - NTP: ${module.landing_zone.ntp_host_or_ip}
       - NFS: ${module.landing_zone.nfs_host_or_ip_path}
    
    5. RAC Cluster Management:
       - Check cluster status: crsctl stat res -t
       - Check ASM status: asmcmd lsdg
       - Check database status: srvctl status database -d ${var.oracle_sid}
    
    ========================================
  EOT
}

########################################################
# RAC Cluster Summary
########################################################

output "rac_cluster_summary" {
  description = "Summary of the Oracle RAC cluster configuration."
  value = {
    cluster_name  = "${var.prefix}-rac"
    node_count    = var.rac_node_count
    scan_name     = local.scan_name
    scan_ips      = local.scan_ips_list
    database_name = var.oracle_sid
    nodes = [
      for idx in range(var.rac_node_count) : {
        hostname      = local.rac_instances[idx].server_name
        management_ip = local.rac_node_ips[idx].management
        public_ip     = local.rac_node_ips[idx].public
      }
    ]
  }
}