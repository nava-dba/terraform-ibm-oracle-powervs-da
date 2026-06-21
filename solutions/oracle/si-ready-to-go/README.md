# Oracle Database Single Instance (SI) - Ready to Go

## Overview

This fully automated deployable architecture creates a complete Oracle Database 19c Single Instance environment on IBM Power Virtual Server (PowerVS) with integrated VPC landing zone infrastructure. It eliminates the need for pre-existing PowerVS workspaces and manual configuration scripts.

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
- **Management Network**: Private network for Oracle instance communication
- **AIX Instance**: Hosts Oracle Database 19c with configurable resources
- **Storage**: Automatic configuration for ASM or JFS2 filesystems

### Automated Configuration
- Network services (proxy, DNS, NTP, NFS) configured via Ansible
- Oracle binaries downloaded from IBM Cloud Object Storage
- Oracle Grid Infrastructure installation (if using ASM)
- Oracle Database 19c installation and configuration
- Database creation with specified SID

## Key Features

✅ **Fully Automated**: No manual steps required after deployment  
✅ **Production Ready**: Based on IBM's standard-plus-vsi reference architecture  
✅ **No Pre-requisites**: Creates all infrastructure from scratch  
✅ **Flexible Storage**: Supports both ASM and JFS2 filesystems  
✅ **Secure**: Built-in VPN support, security groups, and compliance options  
✅ **Scalable**: Configurable compute and storage resources  

## Prerequisites

### Required
1. **IBM Cloud Account** with appropriate permissions
2. **IBM Cloud API Key** with Editor role or higher
3. **SSH Key Pair** (RSA format, 2048 or 4096 bits)
4. **Oracle Binaries** uploaded to IBM Cloud Object Storage:
   - Oracle Database 19c installation files
   - Oracle Grid Infrastructure 19c (if using ASM)
   - Latest Release Update (RU) patch
   - Latest OPatch utility
5. **IBM Cloud Object Storage Service Credentials** (JSON format)

### Permissions Required
- PowerVS workspace creation
- VPC infrastructure creation
- Transit Gateway creation
- Resource group access
- Object Storage access

## Quick Start

### 1. Prepare Oracle Binaries

Upload the following to IBM Cloud Object Storage:

```
my-oracle-bucket/
├── database/
│   └── LINUX.X64_193000_db_home.zip
├── grid/
│   └── LINUX.X64_193000_grid_home.zip
├── patches/
│   └── p34765931_190000_Linux-x86-64.zip
└── opatch/
    └── p6880880_190000_Linux-x86-64.zip
```

### 2. Create Service Credentials

Create IBM Cloud Object Storage service credentials with HMAC enabled:

```bash
ibmcloud resource service-key-create cos-credentials Writer \
  --instance-name <your-cos-instance> \
  --parameters '{"HMAC":true}'
```

Save the output JSON for the `ibmcloud_cos_service_credentials` variable.

### 3. Deploy via IBM Cloud Catalog

1. Navigate to IBM Cloud Catalog
2. Search for "Oracle on IBM Power Virtual Server"
3. Select "Oracle Database – Single Instance Ready to Go"
4. Fill in required parameters
5. Click "Install"

### 4. Deploy via Terraform CLI

```bash
# Clone the repository
git clone https://github.com/terraform-ibm-modules/terraform-ibm-oracle-powervs-da.git
cd terraform-ibm-oracle-powervs-da/solutions/oracle/si-ready-to-go

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
ibmcloud_api_key                = "your-api-key"
powervs_zone                    = "dal10"
powervs_resource_group_name     = "Default"
prefix                          = "oradb"
ssh_public_key                  = "ssh-rsa AAAAB3..."
ssh_private_key                 = "-----BEGIN RSA PRIVATE KEY-----..."
powervs_aix_image_name          = "7300-02-01"
pi_aix_instance = {
  memory_gb    = 32
  cores        = 2
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "none"
}
oracle_sid                      = "ORCL"
oracle_db_password              = "YourSecurePassword123!"
oracle_install_type             = "ASM"
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
}
EOF

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

## Configuration Options

### Storage Types

#### ASM (Automatic Storage Management) - Recommended
```hcl
oracle_install_type = "ASM"

powervs_data_volume = {
  size  = "100"  # GB per disk
  count = "2"    # Number of disks
  tier  = "tier1"
}

powervs_redo_volume = {
  size  = "50"
  count = "2"
  tier  = "tier1"
}
```

#### JFS2 (Journal File System)
```hcl
oracle_install_type = "JFS2"

powervs_data_volume = {
  size  = "200"  # Total size
  count = "1"
  tier  = "tier1"
}
```

### Instance Sizing

#### Small (Development/Test)
```hcl
pi_aix_instance = {
  memory_gb    = 16
  cores        = 1
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "none"
}
```

#### Medium (Production)
```hcl
pi_aix_instance = {
  memory_gb    = 64
  cores        = 4
  core_type    = "shared"
  machine_type = "s1022"
  pin_policy   = "soft"
}
```

#### Large (High Performance)
```hcl
pi_aix_instance = {
  memory_gb    = 128
  cores        = 8
  core_type    = "dedicated"
  machine_type = "e980"
  pin_policy   = "hard"
}
```

### Optional Features

#### Enable VPN Access
```hcl
client_to_site_vpn = {
  enable                        = true
  client_ip_pool                = "192.168.0.0/16"
  vpn_client_access_group_users = ["user1@example.com", "user2@example.com"]
}
```

#### Enable Monitoring
```hcl
enable_monitoring = true
```

#### Enable Security Compliance
```hcl
enable_scc_wp          = true
ansible_vault_password = "YourVaultPassword123!"
```

## Post-Deployment

### Access the Environment

1. **SSH to Management Host**:
   ```bash
   ssh root@<access_host_or_ip>
   ```

2. **SSH to Oracle AIX Instance**:
   ```bash
   ssh root@<oracle_aix_instance_management_ip>
   ```

3. **Connect to Oracle Database**:
   ```bash
   su - oracle
   sqlplus / as sysdba
   ```

### Verify Installation

```sql
-- Check database status
SELECT instance_name, status FROM v$instance;

-- Check ASM diskgroups (if using ASM)
SELECT name, state, total_mb, free_mb FROM v$asm_diskgroup;

-- Check tablespaces
SELECT tablespace_name, status FROM dba_tablespaces;
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
│  ┌──────────────────────────────────────────────────────┐  │
│  │              AIX Instance (Oracle DB)                 │  │
│  │  - Oracle Database 19c                                │  │
│  │  - Grid Infrastructure (ASM) or JFS2                  │  │
│  │  - Automated Installation                             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Management Network: 10.51.0.0/24                           │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

1. **Deployment Fails During Oracle Installation**
   - Check COS credentials are valid
   - Verify Oracle binaries are uploaded correctly
   - Check AIX instance has sufficient resources

2. **Cannot Access Management Host**
   - Verify `external_access_ip` includes your IP
   - Check security group rules
   - Ensure floating IP is assigned

3. **Network Services Not Working**
   - Check Transit Gateway connections
   - Verify PowerVS network configuration
   - Review Ansible execution logs

### Logs Location

- **Ansible Logs**: `/tmp/ansible-*.log` on Network Services VSI
- **Oracle Installation Logs**: `/tmp/oracle_install.log` on AIX instance
- **Terraform Logs**: Set `TF_LOG=DEBUG` for detailed output

## Cost Estimation

Approximate monthly costs (US South region):

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| VPC VSIs (2x) | cx2-2x4 | ~$60 |
| PowerVS AIX | 32GB, 2 cores | ~$400 |
| Storage (ASM) | 400GB tier1 | ~$160 |
| Transit Gateway | Local | ~$50 |
| **Total** | | **~$670/month** |

*Costs vary by region and configuration. Use IBM Cloud Cost Estimator for accurate pricing.*

## Support

- **GitHub Issues**: [terraform-ibm-oracle-powervs-da/issues](https://github.com/terraform-ibm-modules/terraform-ibm-oracle-powervs-da/issues)
- **IBM Cloud Docs**: [Power Virtual Server Documentation](https://cloud.ibm.com/docs/power-iaas)
- **Community**: IBM Cloud Community Forums

## License

This solution is licensed under the Apache License 2.0. See LICENSE file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## Related Solutions

- [Oracle RAC Ready to Go](../rac-ready-to-go/README.md) - Multi-node Oracle RAC cluster
- [Oracle SI (Existing Workspace)](../si/README.md) - Deploy to existing PowerVS workspace
- [Oracle RAC (Existing Workspace)](../rac/README.md) - RAC for existing workspace