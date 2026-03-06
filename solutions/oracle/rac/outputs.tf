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
