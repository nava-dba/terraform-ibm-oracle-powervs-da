
output "powervs_aix_instance_private_ip" {
  description = "IP address of the primary network interface of IBM PowerVS instance."
  value       = module.pi_instance_aix.pi_instance_primary_ip
}
