output "rac_node_ids" {
  description = "List of RAC node instance IDs"
  value       = ibm_pi_instance.rac_nodes.instance_id
}

output "rac_node_names" {
  description = "List of RAC node names"
  value       = [for idx in range(var.rac_nodes) : "${var.prefix}-aix-${idx}"]
}

output "rac_node_networks" {
  description = "Network details for all RAC nodes"
  value = {
    for idx in range(var.rac_nodes) : "${var.prefix}-aix-${idx}" => {
      mgmt_ip  = length(ibm_pi_instance.rac_nodes.pi_network) > 0 ? ibm_pi_instance.rac_nodes.pi_network[0].ip_address : null
      pub_ip   = length(ibm_pi_instance.rac_nodes.pi_network) > 1 ? ibm_pi_instance.rac_nodes.pi_network[1].ip_address : null
      priv1_ip = length(ibm_pi_instance.rac_nodes.pi_network) > 2 ? ibm_pi_instance.rac_nodes.pi_network[2].ip_address : null
      priv2_ip = length(ibm_pi_instance.rac_nodes.pi_network) > 3 ? ibm_pi_instance.rac_nodes.pi_network[3].ip_address : null
    }
  }
}

output "network_details" {
  description = "Network configuration details"
  value = {
    mgmt = {
      name    = local.mgmt_network_name
      netmask = local.netmask_mgmt
      cidr    = local.mgmt_network_name != null ? local.network_details[local.mgmt_network_name].cidr : null
      gateway = local.mgmt_network_name != null ? local.network_details[local.mgmt_network_name].gateway : null
    }
    pub = {
      name    = local.pub_network_name
      netmask = local.netmask_pub
      cidr    = local.pub_network_name != null ? local.network_details[local.pub_network_name].cidr : null
      gateway = local.pub_network_name != null ? local.network_details[local.pub_network_name].gateway : null
    }
    priv1 = {
      name    = local.priv1_network_name
      netmask = local.netmask_priv1
      cidr    = local.priv1_network_name != null ? local.network_details[local.priv1_network_name].cidr : null
      gateway = local.priv1_network_name != null ? local.network_details[local.priv1_network_name].gateway : null
    }
    priv2 = {
      name    = local.priv2_network_name
      netmask = local.netmask_priv2
      cidr    = local.priv2_network_name != null ? local.network_details[local.priv2_network_name].cidr : null
      gateway = local.priv2_network_name != null ? local.network_details[local.priv2_network_name].gateway : null
    }
  }
}