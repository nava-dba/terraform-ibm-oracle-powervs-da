# RAC Network Configuration Fix Summary

## Problem Statement

The RAC-ready-to-go deployment was failing with the error:
```
Error: option UserAccount is required
```

This occurred because the `ibm_pi_network` resources were missing the provider alias specification, and the network configuration didn't match Oracle RAC requirements.

## Root Causes Identified

1. **Missing Provider Alias**: All three `ibm_pi_network` resources lacked `provider = ibm.ibm-pi`
2. **Incorrect CIDR Block**: RAC Public network used `192.168.100.0/24` instead of `172.16.10.0/24`
3. **Missing ARP Broadcast**: All RAC networks require `pi_network_jumbo = true` to enable ARP
4. **Incorrect Network Order**: Networks weren't properly ordered for RAC deployment

## Oracle RAC Network Requirements

RAC requires **4 PowerVS networks** in this specific order:

| Index | Network Name | Purpose | CIDR | IP Range | ARP | MTU |
|-------|--------------|---------|------|----------|-----|-----|
| 0 | Management | Ansible/Management | `10.55.0.0/24` | 10.55.0.2 - 10.55.0.254 | ❌ Disabled | 1450 |
| 1 | RAC Public | Client connections, VIPs | `172.16.10.0/24` | 172.16.10.2 - 172.16.10.240 | ✅ Enabled | 1450 |
| 2 | RAC Private1 | RAC interconnect 1 | `10.60.30.0/28` | 10.60.30.2 - 10.60.30.14 | ✅ Enabled | 9000 |
| 3 | RAC Private2 | RAC interconnect 2 | `10.50.20.0/28` | 10.50.20.2 - 10.50.20.14 | ✅ Enabled | 9000 |

**Important Notes:**
- Management network is created by the VPC Landing Zone module
- RAC Public network reserves IPs `172.16.10.241-254` for Oracle RAC VIPs (SCAN and Node-VIPs)
- The `pi_network_jumbo` parameter controls **ARP broadcast**, not just jumbo frames
- All RAC networks (Public, Private1, Private2) must have ARP enabled

## Changes Made

### 1. Fixed main.tf (Lines 123-172)

#### Added Provider Alias to All Networks
```hcl
resource "ibm_pi_network" "rac_public" {
  provider = ibm.ibm-pi  # ADDED
  # ...
}

resource "ibm_pi_network" "rac_private1" {
  provider = ibm.ibm-pi  # ADDED
  # ...
}

resource "ibm_pi_network" "rac_private2" {
  provider = ibm.ibm-pi  # ADDED
  # ...
}
```

#### Corrected RAC Public Network Configuration
```hcl
resource "ibm_pi_network" "rac_public" {
  provider = ibm.ibm-pi
  
  pi_network_name  = "${var.prefix}-rac-pub"  # Changed from -rac-public
  pi_cidr          = "172.16.10.0/24"         # Changed from 192.168.100.0/24
  pi_gateway       = "172.16.10.1"            # Changed from 192.168.100.1
  pi_network_mtu   = 1450
  pi_network_jumbo = true                     # ADDED - Enable ARP broadcast
}
```

#### Enabled ARP on All RAC Networks
```hcl
# RAC Private1
resource "ibm_pi_network" "rac_private1" {
  provider = ibm.ibm-pi
  # ...
  pi_network_jumbo = true  # ADDED - Enable ARP + jumbo frames
}

# RAC Private2
resource "ibm_pi_network" "rac_private2" {
  provider = ibm.ibm-pi
  # ...
  pi_network_jumbo = true  # ADDED - Enable ARP + jumbo frames
}
```

### 2. Fixed locals.tf (Lines 75-92 and 221-226)

#### Corrected Network Order in powervs_rac_networks_auto
```hcl
# BEFORE: Only 3 networks, missing management
powervs_rac_networks_auto = [
  { name = ibm_pi_network.rac_public.pi_network_name, ... },
  { name = ibm_pi_network.rac_private1.pi_network_name, ... },
  { name = ibm_pi_network.rac_private2.pi_network_name, ... }
]

# AFTER: All 4 networks in correct order
powervs_rac_networks_auto = [
  # Index 0: Management network (from landing zone)
  module.landing_zone.powervs_management_subnet,
  # Index 1: RAC Public network
  { name = ibm_pi_network.rac_public.pi_network_name, ... },
  # Index 2: RAC Private1 network
  { name = ibm_pi_network.rac_private1.pi_network_name, ... },
  # Index 3: RAC Private2 network
  { name = ibm_pi_network.rac_private2.pi_network_name, ... }
]
```

#### Fixed Network References
```hcl
# BEFORE: Incorrect indices
mgmt_network   = module.landing_zone.powervs_management_subnet
public_network = local.powervs_rac_networks_auto[0]  # Wrong!
priv1_network  = local.powervs_rac_networks_auto[1]  # Wrong!
priv2_network  = local.powervs_rac_networks_auto[2]  # Wrong!

# AFTER: Correct indices
mgmt_network   = local.powervs_rac_networks_auto[0]  # Management
public_network = local.powervs_rac_networks_auto[1]  # RAC Public
priv1_network  = local.powervs_rac_networks_auto[2]  # RAC Private1
priv2_network  = local.powervs_rac_networks_auto[3]  # RAC Private2
```

## What VPC Landing Zone Creates vs What RAC Needs

### VPC Landing Zone Module Creates:
- ✅ 4 VPC subnets (VPN, Management, VPE, Edge)
- ✅ 1 PowerVS management network (`10.55.0.0/24`)

### RAC-Ready-to-Go Must Create:
- ✅ 3 additional PowerVS networks (Public, Private1, Private2)

### Total PowerVS Networks for RAC:
**4 networks** = 1 (management from landing zone) + 3 (RAC networks created by main.tf)

## Network Deployment Order

When deploying RAC instances, the networks must be passed in this exact order:

```hcl
powervs_rac_networks = [
  {
    name = "ora_net"           # Index 0: Management
    id   = "<management-id>"
  },
  {
    name = "ora-rac-pub"       # Index 1: RAC Public
    id   = "<public-id>"
  },
  {
    name = "ora-rac-priv1"     # Index 2: RAC Private1
    id   = "<private1-id>"
  },
  {
    name = "ora-rac-priv2"     # Index 3: RAC Private2
    id   = "<private2-id>"
  }
]
```

## Validation Steps

After applying these changes, verify:

1. **Provider Configuration**: All `ibm_pi_network` resources have `provider = ibm.ibm-pi`
2. **CIDR Blocks**: 
   - RAC Public: `172.16.10.0/24` ✅
   - RAC Private1: `10.60.30.0/28` ✅
   - RAC Private2: `10.50.20.0/28` ✅
3. **ARP Broadcast**: All three RAC networks have `pi_network_jumbo = true`
4. **Network Order**: Management at index 0, Public at 1, Private1 at 2, Private2 at 3
5. **VIP Reservation**: IPs `172.16.10.241-254` are documented as reserved

## Testing

To test the configuration:

```bash
cd solutions/oracle/rac-ready-to-go
terraform init
terraform validate
terraform plan
```

Expected result: No errors about missing provider or UserAccount.

## Files Modified

1. **solutions/oracle/rac-ready-to-go/main.tf**
   - Lines 123-172: Added provider aliases, corrected CIDRs, enabled ARP

2. **solutions/oracle/rac-ready-to-go/locals.tf**
   - Lines 75-92: Fixed network order to include management network
   - Lines 221-226: Corrected network reference indices

## Additional Notes

- The `pi_network_jumbo` parameter serves dual purpose:
  - For standard MTU (1450): Enables ARP broadcast only
  - For jumbo MTU (9000): Enables both ARP broadcast and jumbo frames
- Without ARP enabled, RAC cluster communication will fail
- The network order is critical for Oracle Grid Infrastructure installation
- VIP range reservation is mandatory for RAC SCAN and Node VIPs

## References

- IBM PowerVS Network Documentation
- Oracle RAC Network Requirements
- Terraform IBM Provider Documentation for `ibm_pi_network`