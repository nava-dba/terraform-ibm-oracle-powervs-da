output "rac_node_details" {
  description = "Per RAC node details including instance ID and IP addresses"

  value = {
    for inst in ibm_pi_instance.rac_nodes :
    inst.pi_instance_name => {
      id       = inst.instance_id
      mgmt_ip  = inst.pi_network[0].ip_address
      pub_ip   = inst.pi_network[1].ip_address
      priv1_ip = inst.pi_network[2].ip_address
      priv2_ip = inst.pi_network[3].ip_address
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
