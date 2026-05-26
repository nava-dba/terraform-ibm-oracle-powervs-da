# Oracle Database Real Application Clusters (RAC) - Ready to Go

## Overview

This fully automated deployable architecture creates a complete Oracle Database 19c Real Application Clusters (RAC) environment on IBM Power Virtual Server (PowerVS) with integrated VPC landing zone infrastructure. It eliminates the need for pre-existing PowerVS workspaces and manual configuration scripts.

## Architecture

This solution deploys:

### VPC Landing Zone Infrastructure
- **Management VSI (Bastion Host)**: Secure SSH access point with floating IP
- **Network Services VSI**: Hosts SQUID proxy, DNS forwarder, NTP server, NFS server, and Ansible execution node
- **Transit Gateway**: Connects VPC to PowerVS workspace
- **VPC Networking**: Subnets, security groups, and network ACLs
- **Optional Components**: Client-to-site VPN, IBM Cloud Monitoring, Security and Compliance Center Workload Protection

### PowerVS Infrastructure
- **PowerVS Workspace**: Automatically created in specified zone
- **4 Private Networks**: Management, Public (client), Private1 (interconnect), Private2 (interconnect)
- **Multiple AIX Instances**: 2-8 RAC nodes with anti-affinity placement
- **Shared Storage**: ASM diskgroups for DATA, REDO, GIMR, and ARCH

### Automated Configuration
- Network services (proxy, DNS, NTP, NFS) configured via Ansible
- Oracle binaries downloaded from IBM Cloud Object Storage
- Oracle Grid Infrastructure for RAC installation
- Oracle RAC Database 19c installation and configuration
- SCAN (Single Client Access Name) configuration
- RAC cluster creation with specified number of nodes

## Key Features

✅ **Fully Automated**: No manual steps required after deployment  
✅ **Production Ready**: Based on IBM's standard-plus-vsi reference architecture  
✅ **No Pre-requisites**: Creates all infrastructure from scratch  
✅ **High Availability**: Anti-affinity placement across physical hosts  
✅ **Scalable**: 2-8 node clusters with automatic GIMR sizing  
✅ **Secure**: Built-in VPN support, security groups, and compliance options  

## Prerequisites

### Required
1. **IBM Cloud Account** with appropriate permissions
2. **IBM Cloud API Key** with Editor role or higher
3. **SSH Key Pair** (RSA format, 2048 or 4096 bits)
4. **3 Pre-created PowerVS Networks** for RAC:
   - Public network (for client connections)
   - Private interconnect network 1
   - Private interconnect network 2
5. **Oracle Binaries** uploaded to IBM Cloud Object Storage:
   - Oracle Database 19c installation files
   - Oracle Grid Infrastructure 19c for RAC
   - Latest Release Update (RU) patch
   - Latest OPatch utility
   - Oracle Cluster Verification Utility (cluvfy) - optional
6. **IBM Cloud Object Storage Service Credentials** (JSON format)

### Permissions Required
- PowerVS workspace creation
- PowerVS network creation
- VPC infrastructure creation
- Transit Gateway creation
- Resource group access
- Object Storage access

## Quick Start

### 1. Create PowerVS Networks

Before deployment, create 3 private networks in your PowerVS workspace:

```bash
# Public network (for client connections)
ibmcloud pi network-create-private <workspace-id> \
  --name "rac-public" \
  --cidr "10.52.0.0/24" \
  --dns-servers "9.9.9.9"

# Private interconnect 1
ibmcloud pi network-create-private <workspace-id> \
  --name "rac-priv1" \
  --cidr "192.168.1.0/24"

# Private interconnect 2
ibmcloud pi network-create-private <workspace-id> \
  --name "rac-priv2" \
  --cidr "192.168.2.0/24"
```

### 2. Prepare Oracle Binaries

Upload the following to IBM Cloud Object Storage:

```
my-oracle-bucket/
├── database/
│   └── LINUX.X64_193000_db_home.zip
├── grid/
│   └── LINUX.X64_193000_grid_home.zip
├── patches/
│   └── p34765931_190000_Linux-x86-64.zip
├── opatch/
│   └── p6880880_190000_Linux-x86-64.zip
└── cluvfy/
    └── cvupack_Linux_x86_64.zip (optional)
```

### 3. Deploy via Terraform CLI

```bash
# Clone the repository
git clone https://github.com/terraform-ibm-modules/terraform-ibm-oracle-powervs-da.git
cd terraform-ibm-oracle-powervs-da/solutions/oracle/rac-ready-to-go

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
ibmcloud_api_key                = "your-api-key"
powervs_zone                    = "dal10"
powervs_resource_group_name     = "Default"
prefix                          = "orarac"
ssh_public_key                  = "ssh-rsa AAAAB3..."
ssh_private_key                 = "-----BEGIN RSA PRIVATE KEY-----..."

# RAC Configuration
rac_node_count                  = 2
pi_replication_policy           = "anti-affinity"

# Pre-created RAC networks
powervs_rac_networks = [
  {
    name = "rac-public"
    id   = "network-id-1"
    cidr = "10.52.0.0/24"
  },
  {
    name = "rac-priv1"
    id   = "network-id-2"
    cidr = "192.168.1.0/24"
  },
  {
    name = "rac-priv2"
    id   = "network-id-3"
    cidr = "192.168.2.0/24"
  }
]

# AIX Instance Configuration
powervs_aix_image_name          = "7300-02-01"
powervs_aix_instance = {
  memory_gb    = 64
  cores        = 4
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "soft"
}

# Oracle Configuration
oracle_sid                      = "ORARAC"
oracle_db_password              = "YourSecurePassword123!"

# COS Configuration
ibmcloud_cos_service_credentials = <<-JSON
{
  "apikey": "your-cos-apikey",
  "resource_instance_id": "crn:v1:..."
}
JSON

ibmcloud_cos_configuration = {
  cos_region                  = "us-south"
  cos_bucket_name             = "my-oracle-bucket"
  cos_oracle_database_sw_path = "database"
  cos_oracle_grid_sw_path     = "grid"
  cos_oracle_ru_file_path     = "patches"
  cos_oracle_opatch_file_path = "opatch"
  cos_oracle_cluvfy_file_path = "cluvfy"
}
EOF

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

## Configuration Options

### Cluster Sizing

#### 2-Node RAC (Development/Test)
```hcl
rac_node_count = 2

powervs_aix_instance = {
  memory_gb    = 32
  cores        = 2
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "soft"
}
```

#### 4-Node RAC (Production)
```hcl
rac_node_count = 4

powervs_aix_instance = {
  memory_gb    = 64
  cores        = 4
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "soft"
}
```

#### 8-Node RAC (High Performance)
```hcl
rac_node_count = 8

powervs_aix_instance = {
  memory_gb    = 128
  cores        = 8
  core_type    = "dedicated"
  machine_type = "e980"
  pin_policy   = "hard"
}
```

### Storage Configuration

```hcl
# Oracle software volume group
powervs_oravg_volume = {
  size  = "50"
  count = "1"
  tier  = "tier3"
}

# ASM DATA diskgroup
powervs_data_volume = {
  size  = "200"  # GB per disk
  count = "4"    # Number of disks
  tier  = "tier1"
}

# ASM REDO diskgroup
powervs_redo_volume = {
  size  = "100"
  count = "4"
  tier  = "tier1"
}
```

### Placement Policy

```hcl
# Recommended for HA - spreads nodes across hosts
pi_replication_policy = "anti-affinity"

# Not recommended - places nodes on same host
pi_replication_policy = "affinity"

# No placement constraint
pi_replication_policy = "none"
```

## Post-Deployment

### Access the Environment

1. **SSH to Management Host**:
   ```bash
   ssh root@<access_host_or_ip>
   ```

2. **SSH to RAC Nodes**:
   ```bash
   ssh root@<rac_node_1_management_ip>
   ssh root@<rac_node_2_management_ip>
   ```

3. **Connect to Oracle RAC Database**:
   ```bash
   # Using SCAN name
   sqlplus system/<password>@<scan-name>:1521/<database-name>
   
   # From any RAC node
   su - oracle
   sqlplus / as sysdba
   ```

### Verify RAC Installation

```bash
# Check cluster status
su - grid
crsctl stat res -t

# Check ASM diskgroups
asmcmd lsdg

# Check database status
su - oracle
srvctl status database -d <database-name>

# Check RAC instances
srvctl status instance -d <database-name>

# Verify SCAN configuration
srvctl config scan
```

### RAC Management Commands

```bash
# Start/Stop database
srvctl start database -d <database-name>
srvctl stop database -d <database-name>

# Start/Stop specific instance
srvctl start instance -d <database-name> -i <instance-name>
srvctl stop instance -d <database-name> -i <instance-name>

# Check cluster interconnect
oifcfg getif

# Check voting disks
crsctl query css votedisk

# Check OCR location
ocrcheck
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        IBM Cloud VPC                         │
│  ┌────────────────┐              ┌─────────────────────┐   │
│  │  Management    │              │  Network Services   │   │
│  │  VSI (Bastion) │              │  VSI                │   │
│  │  - SSH Access  │              │  - SQUID Proxy      │   │
│  │  - Floating IP │              │  - DNS Forwarder    │   │
│  └────────────────┘              │  - NTP Server       │   │
│                                   │  - NFS Server       │   │
│                                   │  - Ansible Node     │   │
│                                   └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴────────┐
                    │ Transit Gateway │
                    └───────┬────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                   PowerVS Workspace                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ RAC Node 1   │  │ RAC Node 2   │  │ RAC Node N   │     │
│  │ - 4 Networks │  │ - 4 Networks │  │ - 4 Networks │     │
│  │ - ASM Disks  │  │ - ASM Disks  │  │ - ASM Disks  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  Networks:                                                   │
│  - Management: 10.51.0.0/24                                 │
│  - Public: 10.52.0.0/24 (SCAN IPs: .241, .242, .243)       │
│  - Private1: 192.168.1.0/24 (Interconnect)                  │
│  - Private2: 192.168.2.0/24 (Interconnect)                  │
│                                                              │
│  ASM Diskgroups:                                            │
│  - CRSDG (Cluster Registry)                                 │
│  - DATA (Database files)                                    │
│  - REDO (Redo logs)                                         │
│  - GIMR (Grid Infrastructure Management Repository)         │
│  - ARCH (Archive logs)                                      │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

1. **RAC Nodes Cannot Communicate**
   - Verify all 4 networks are attached to each node
   - Check private interconnect network configuration
   - Verify Transit Gateway connections

2. **SCAN IPs Not Resolving**
   - Check DNS forwarder configuration
   - Verify SCAN IPs are in public network range
   - Test DNS resolution from RAC nodes

3. **ASM Diskgroups Not Mounting**
   - Verify storage volumes are attached
   - Check ASM disk permissions
   - Review Grid Infrastructure logs

4. **Cluster Services Not Starting**
   - Check cluster interconnect configuration
   - Verify voting disk accessibility
   - Review CRS logs in $GRID_HOME/log

### Logs Location

- **Ansible Logs**: `/tmp/ansible-*.log` on Network Services VSI
- **Oracle Grid Logs**: `$GRID_HOME/log/<hostname>/` on each RAC node
- **Oracle Database Logs**: `$ORACLE_BASE/diag/rdbms/<db_name>/` on each RAC node
- **CRS Logs**: `$GRID_HOME/log/<hostname>/crs/` on each RAC node

## Cost Estimation

Approximate monthly costs for 2-node RAC (US South region):

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| VPC VSIs (2x) | cx2-2x4 | ~$60 |
| PowerVS AIX (2 nodes) | 64GB, 4 cores each | ~$1,600 |
| Storage (ASM) | 1TB tier1 total | ~$400 |
| Transit Gateway | Local | ~$50 |
| **Total** | | **~$2,110/month** |

*Costs scale linearly with node count. Use IBM Cloud Cost Estimator for accurate pricing.*

## Support

- **GitHub Issues**: [terraform-ibm-oracle-powervs-da/issues](https://github.com/terraform-ibm-modules/terraform-ibm-oracle-powervs-da/issues)
- **IBM Cloud Docs**: [Power Virtual Server Documentation](https://cloud.ibm.com/docs/power-iaas)
- **Oracle RAC Docs**: [Oracle Real Application Clusters Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/)

## License

This solution is licensed under the Apache License 2.0. See LICENSE file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## Related Solutions

- [Oracle SI Ready to Go](../si-ready-to-go/README.md) - Single instance Oracle Database
- [Oracle SI (Existing Workspace)](../si/README.md) - Deploy to existing PowerVS workspace
- [Oracle RAC (Existing Workspace)](../rac/README.md) - RAC for existing workspace