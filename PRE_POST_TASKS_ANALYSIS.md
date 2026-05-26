# Comprehensive Analysis: Pre and Post Tasks Outside Ansible Collection

## Executive Summary
This document provides a detailed analysis of all tasks currently executed outside the Ansible collection in the terraform-ibm-oracle-powervs-da project. These tasks are candidates for migration into the Ansible collection to make the Terraform code leaner and more maintainable.

---

## 📋 TABLE OF CONTENTS
1. [Pre-Installation Tasks](#pre-installation-tasks)
2. [Post-Installation Tasks](#post-installation-tasks)
3. [Terraform Provisioner Tasks](#terraform-provisioner-tasks)
4. [Shell Script Tasks](#shell-script-tasks)
5. [Migration Recommendations](#migration-recommendations)

---

## PRE-INSTALLATION TASKS

### 1. **Squid Proxy Management on Bastion Host (START)**
**Location**: 
- `solutions/oracle/si/main.tf` (lines 117-133)
- `solutions/oracle/rac/main.tf` (lines 479-495)

**Resource Type**: `null_resource.squid_start`

**Tasks Performed**:
```bash
- Check if Squid is already running
- Start Squid service: systemctl start squid
- Enable Squid service: systemctl enable squid
```

**Connection**: Direct SSH to bastion host

**Can be moved to**: Ansible pre-task or dedicated role `squid_proxy_manager`

---

### 2. **Ansible Host Bootstrap and Configuration**
**Location**: 
- `modules/ansible/ansible_node_packages_private.sh` (257 lines)
- `modules/ansible/ansible_node_packages_public.sh` (250 lines)

**Triggered by**: `terraform_data.setup_ansible_host` in `modules/ansible/main.tf` (lines 47-79)

#### 2.1 Proxy Configuration
**Tasks**:
- Setup proxy environment variables in `/etc/bashrc` or `/etc/bash.bashrc`
- Configure http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY, no_proxy
- Export proxy for current shell session

**Lines**: Private (176-218), Public (173-214)

#### 2.2 /etc/hosts File Management
**Tasks**:
- Backup existing `/etc/hosts` file
- Add managed section markers
- Insert host entries for RAC nodes
- Update `/etc/hosts` with IP and hostname mappings

**Lines**: Private (60-99), Public (58-97)

#### 2.3 RHEL Subscription Registration (Private Cloud Only)
**Tasks**:
- Execute FLS (Full Linux Subscription) cloud-init script
- Register RHEL with subscription manager
- Configure repositories via squid proxy

**Lines**: Private (224-245)

**Script Location**: `/usr/share/powervs-fls/powervs-fls-readme.md`

#### 2.4 Package Installation
**Tasks**:
- Wait for subscription-manager processes to complete
- Install RHEL packages:
  - `rhel-system-roles`
  - `expect`
  - `perl`
  - `nfs-utils`
  - `python3-pip`
  - `net-tools`
  - `bind-utils`
  - `ansible-core`

**Lines**: Private (104-148), Public (102-130)

**Retry Logic**: 3 attempts with 3-second delays

#### 2.5 Ansible Galaxy Collections Installation
**Tasks**:
- Install Ansible collections:
  - `ibm.power_linux_sap:>=3.0.0,<4.0.0`
  - `ibm.power_aix:2.1.1`
  - `ibm.power_aix_oracle:1.3.3`
  - `ibm.power_aix_oracle_dba:2.0.9`
  - `ibm.power_aix_oracle_rac_asm:1.3.9`
  - `ansible.utils:6.0.0`
- Install dependencies from requirements.yml

**Lines**: Private (129-145), Public (135-167)

**Retry Logic**: 3 attempts with 3-second delays

#### 2.6 Python Pip Packages Installation
**Tasks**:
- Install/upgrade `netaddr` package via pip3

**Lines**: Private (153-172), Public (219-238)

**Retry Logic**: 3 attempts with 3-second delays

---

### 3. **IBM Cloud COS Download Operations**
**Location**: `modules/ibmcloud-cos/main.tf`

**Script Template**: `modules/ibmcloud-cos/templates/ibmcloud_cos.sh.tfpl` (83 lines)

**Triggered by**: Multiple module calls in main.tf:
- `module.ibmcloud_cos_oracle` - Oracle database software
- `module.ibmcloud_cos_patch` - Oracle RU patches
- `module.ibmcloud_cos_opatch` - Oracle OPatch utility
- `module.ibmcloud_cos_grid` - Oracle Grid software (ASM only)
- `module.ibmcloud_cos_cluvfy` - Oracle cluvfy utility (RAC only)

#### 3.1 IBM Cloud CLI Setup
**Tasks**:
```bash
- Clean previous IBM Cloud CLI state (~/.bluemix directory)
- Install IBM Cloud CLI via curl
- Disable version checking
- Install cloud-object-storage plugin
```

**Lines**: 46-56

#### 3.2 Authentication and Configuration
**Tasks**:
```bash
- Login to IBM Cloud with API key
- Configure COS CRN (Cloud Resource Name)
- Set region and bucket configuration
```

**Lines**: 58-68

#### 3.3 File Download
**Tasks**:
```bash
- List objects in COS bucket
- Filter by directory path
- Download each file if not already present
- Set permissions (chmod 777)
- Logout from IBM Cloud
```

**Lines**: 69-83

**Can be moved to**: Ansible role `ibmcloud_cos_download` with IBM Cloud collection

---

### 4. **Volume Attachment Wait Time (RAC Only)**
**Location**: `solutions/oracle/rac/main.tf` (lines 192-195)

**Resource Type**: `time_sleep.wait_after_rac_vm_creation`

**Task**: Wait 180 seconds after RAC VM creation before proceeding

**Reason**: Allow time for volume attachments to stabilize

**Can be moved to**: Ansible wait task with proper validation checks

---

### 5. **Ansible Execution Wrapper Scripts**
**Location**: `modules/ansible/templates-ansible/*/ansible_exec.sh.tftpl`

**Scripts**:
- `aix-init/ansible_exec.sh.tftpl` (23 lines)
- `configure-rhel-management/ansible_exec.sh.tftpl` (22 lines)
- `dns/ansible_exec.sh.tftpl` (49 lines)
- `oracle-grid-install/ansible_exec.sh.tftpl` (50 lines)
- `oracle-grid-install-rac/ansible_exec.sh.tftpl` (70 lines)

#### 5.1 Common Tasks Across All Scripts
**Tasks**:
```bash
- Create ansible.cfg with host_key_checking=False
- Set SSH timeout and connection parameters
- Configure ANSIBLE_LOG_PATH with timestamp
- Set ANSIBLE_PRIVATE_KEY_FILE
- Execute ansible-playbook with unbuffer
- Cleanup private key after execution
- Handle exit codes and error reporting
```

#### 5.2 RAC-Specific Additional Tasks
**Location**: `oracle-grid-install-rac/ansible_exec.sh.tftpl` (lines 34-47)

**Tasks**:
```bash
- Create roles directory structure (bootstrap, preconfig, config)
- Copy IBM collection role files to working directory:
  - bootstrap/files/*
  - preconfig/files/*
  - config/files/*
```

**Reason**: Workaround for IBM collection file access issues

**Can be moved to**: Ansible collection initialization or pre-task

---

### 6. **AIX Helper Scripts**
**Location**: `modules/ansible/templates-ansible/aix-init/files/`

#### 6.1 Disk Rename Script
**File**: `rename_disk.sh` (116 lines)

**Purpose**: Rename shared disks across RAC nodes to match Node1 naming

**Tasks**:
```bash
- Validate AIX environment
- Collect local lsmpio output
- Filter shared disks by tag (e.g., "asm")
- Temporarily rename local disks with "_tmp" suffix
- Align disk names to Node1 reference
- Verify final disk layout
```

**Usage**: `rename_disk.sh <shared_disk_tag> <node1_lsmpio_output_file>`

**Can be moved to**: Ansible module or role task

#### 6.2 Root Password Reset Script
**File**: `reset_root_pwd.sh` (40 lines)

**Purpose**: Reset root password on AIX systems

**Tasks**:
```bash
- Accept password as argument or prompt
- Update password using chpasswd
- Clear login failures with pwdadm
- Verify success
```

**Can be moved to**: Ansible user module with password management

---

### 7. **RHEL Management Node Configuration**
**Location**: `modules/ansible/templates-ansible/configure-rhel-management/playbook-configure-network-services.yml.tftpl`

**Playbook**: Uses `ibm.power_linux_sap` collection

**Tasks**:
```yaml
- Storage and swap setup (PowerVS storage configuration)
- NFS thread configuration for low-memory systems
- Network management services configuration:
  - Squid proxy server (port 3128)
  - NTP server
  - NFS server with export directories
```

**Variables from Terraform**:
- `pi_storage_config` - Storage configuration JSON
- `server_config` - Network services configuration
- `client_config` - NTP client configuration

---

### 8. **AIX Initialization Playbook**
**Location**: `modules/ansible/templates-ansible/aix-init/playbook-aix-init.yml.tftpl` (404 lines)

**Tasks Performed**:

#### 8.1 Rootvg Extension
**Lines**: 30-89
```yaml
- Run cfgmgr to discover new disks
- Find disk by WWN (EXTEND_ROOT_VOLUME_WWN)
- Update rootvg partition limit (chvg -t 16)
- Mark disk as physical volume (chdev -a pv=yes)
- Extend rootvg with new disk
- Update hd6 partition limit for RAC (chlv -x 1024)
```

#### 8.2 Disk Performance Tuning
**Lines**: 91-136
```yaml
- Get all hdisk devices
- Set queue_depth=64 (online)
- Set reserve_policy=no_reserve (online)
- Set max_transfer=0x100000 (persistent, requires reboot)
- Verify attributes
```

#### 8.3 Proxy Configuration
**Lines**: 138-216
```yaml
- Update /etc/profile with proxy variables
- Update /etc/environment with proxy variables
- Export proxy for current session
```

#### 8.4 Time Synchronization (RAC Only)
**Lines**: 218-246
```yaml
- Capture time from RHEL control node
- Set AIX system clock using RHEL time
- Sync across all RAC nodes
```

#### 8.5 Root Password Reset (RAC Only)
**Lines**: 248-283
```yaml
- Copy reset_root_pwd.sh script
- Execute password reset with provided password
- Verify success
```

#### 8.6 SSH Configuration for RAC
**Lines**: 285-342
```yaml
- Backup sshd_config
- Add HostkeyAlgorithms +ssh-rsa
- Add PubkeyAcceptedAlgorithms +ssh-rsa
- Restart sshd service
- Verify service status
```

**Reason**: Fix SSH negotiation errors in RAC environments

#### 8.7 Shared Disk Renaming (RAC Only)
**Lines**: 344-404
```yaml
- Generate Node1 lsmpio reference (first node only)
- Fetch reference to controller
- Copy reference to other nodes
- Execute rename_disk.sh script on other nodes
- Verify disk alignment
```

---

### 9. **DNS Configuration for RAC**
**Location**: `modules/ansible/templates-ansible/dns/playbook-dns-config.yml.tftpl` (117 lines)

**Tasks**:
```yaml
- Install BIND packages (bind, bind-utils)
- Enable named service
- Create named.conf configuration
- Create forward zone file with:
  - DNS server A record
  - RAC node public IP A records
  - RAC node VIP A records
  - SCAN name with multiple A records (3 IPs)
- Create root hints file
- Restore SELinux context
- Restart named service
- Verify service status
```

**Variables from Terraform**:
- `dns_server_ip` - RHEL management node IP
- `dns_domain_name` - Cluster domain
- `scan_name` - SCAN name (e.g., "orac-scan")
- `scan_ips` - List of 3 SCAN IPs
- `rac_nodes` - List of nodes with hostname, pub_ip, vip

---

### 10. **Oracle Grid/Database Installation Playbooks**

#### 10.1 Single Instance (SI)
**Location**: `modules/ansible/templates-ansible/oracle-grid-install/playbook-install-oracle-grid.yml.tftpl`

**Collections Used**:
- `ibm.power_aix_oracle`
- `ibm.power_aix_oracle_dba`
- `ibm.power_aix`

**Pre-tasks**:
```yaml
- Create Oracle groups (dba, oinstall, oper, asmdba, asmoper, asmadmin)
- Create Oracle users (oracle, grid)
- Discover disks by label for ASM
- Build disk dictionaries
```

**Main Installation** (handled by IBM collections):
- NFS mount configuration
- OS prerequisites
- Grid Infrastructure installation (if ASM)
- ASM diskgroup creation
- JFS2 filesystem creation (if non-ASM)
- Oracle RDBMS installation
- Database creation

#### 10.2 RAC Installation
**Location**: `modules/ansible/templates-ansible/oracle-grid-install-rac/playbook-install-oracle-grid.yml.tftpl`

**Collections Used**:
- `ibm.power_aix_oracle_rac_asm`
- `ibm.power_aix_oracle_dba`

**Pre-tasks**:
```yaml
- Create roles directory structure
- Discover all disks by label (oravg, CRSDG, DATA, REDO, GIMR, ARCH)
- Build discovered disks dictionary
- Extract disk numbers from volume names
- Map current disk numbers to target sequence
```

**Main Installation** (handled by IBM collections):
- RAC prerequisites
- Grid Infrastructure RAC installation
- ASM diskgroup creation (CRSDG, DATA, REDO, GIMR)
- Cluster configuration
- Oracle RDBMS RAC installation
- RAC database creation

---

## POST-INSTALLATION TASKS

### 1. **Squid Proxy Cleanup on Bastion Host (STOP)**
**Location**: 
- `solutions/oracle/si/main.tf` (lines 386-402)
- `solutions/oracle/rac/main.tf` (lines 849-865)

**Resource Type**: `null_resource.squid_stop`

**Tasks Performed**:
```bash
- Check if Squid is running
- Stop Squid service: systemctl stop squid
- Disable Squid service: systemctl disable squid
```

**Connection**: Direct SSH to bastion host

**Depends on**: `module.oracle_install` completion

**Can be moved to**: Ansible post-task or cleanup role

---

## TERRAFORM PROVISIONER TASKS

### 1. **File Provisioners**
**Location**: `modules/ansible/main.tf`

**Tasks**:
```terraform
- Create /root/terraform_files directory
- Copy ansible_node_packages.sh to Ansible host
- Copy playbook templates to Ansible host
- Copy vars templates to Ansible host
- Copy inventory templates to Ansible host
- Copy helper scripts (rename_disk.sh, reset_root_pwd.sh)
- Copy ansible execution wrapper scripts
```

**Lines**: 60-143 (execute_playbooks), 187-240 (execute_playbooks_with_vault)

**Can be moved to**: Ansible file module or template module

### 2. **Remote-exec Provisioners**
**Location**: `modules/ansible/main.tf`

**Tasks**:
```bash
- Create directories with permissions
- Write SSH private keys
- Execute shell scripts
- Delete private keys after execution
- Ansible vault encryption (if vault password provided)
```

**Lines**: 61-168 (execute_playbooks), 188-267 (execute_playbooks_with_vault)

**Can be moved to**: Ansible tasks with proper secret management

---

## SHELL SCRIPT TASKS

### 1. **Ansible Node Package Scripts**
**Files**:
- `ansible_node_packages_private.sh` (257 lines)
- `ansible_node_packages_public.sh` (250 lines)

**Functions**:
```bash
main::get_os_version()           - Detect RHEL
main::log_info()                 - Logging
main::log_error()                - Error logging with exit
main::log_system_info()          - Log instance ID and time
main::subscription_mgr_check_process() - Wait for subscription-manager
main::update_hosts_file()        - Update /etc/hosts
main::install_packages()         - Install RHEL packages
main::install_collections()      - Install Ansible collections (public only)
main::install_pip_packages()     - Install Python packages
main::setup_proxy()              - Configure proxy settings
main::run_cloud_init()           - FLS registration (private only)
```

**Can be moved to**: Ansible roles with proper task organization

### 2. **IBM Cloud COS Download Script**
**File**: `ibmcloud_cos.sh.tfpl` (83 lines)

**Functions**:
```bash
- Parse command-line arguments
- Set environment variables
- Clean previous IBM Cloud CLI state
- Install IBM Cloud CLI
- Install COS plugin
- Login to IBM Cloud
- Configure COS CRN
- List and download objects
- Logout
```

**Can be moved to**: Ansible module using IBM Cloud SDK or CLI

### 3. **AIX Helper Scripts**
**Files**:
- `rename_disk.sh` (116 lines) - Disk renaming for RAC
- `reset_root_pwd.sh` (40 lines) - Root password reset

**Can be moved to**: Ansible modules or tasks

---

## MIGRATION RECOMMENDATIONS

### Priority 1: High Impact, Low Complexity

1. **Squid Proxy Management**
   - Create Ansible role: `squid_proxy_lifecycle`
   - Tasks: start, stop, enable, disable
   - Use systemd module

2. **File and Directory Operations**
   - Replace Terraform file provisioners with Ansible file/template modules
   - Use Ansible copy module for scripts
   - Use Ansible template module for dynamic content

3. **SSH Key Management**
   - Use Ansible authorized_key module
   - Implement proper secret management (Ansible Vault)
   - Remove remote-exec for key operations

### Priority 2: Medium Impact, Medium Complexity

4. **Ansible Host Bootstrap**
   - Create role: `ansible_host_bootstrap`
   - Sub-roles:
     - `proxy_configuration`
     - `hosts_file_management`
     - `package_installation`
     - `ansible_collections_setup`
   - Replace shell scripts with Ansible tasks

5. **IBM Cloud COS Downloads**
   - Create role: `ibmcloud_cos_downloader`
   - Use IBM Cloud Ansible collection or CLI module
   - Implement retry logic and validation
   - Support multiple file downloads in parallel

6. **DNS Configuration**
   - Already in Ansible playbook
   - Can be enhanced with validation tasks
   - Add idempotency checks

### Priority 3: Lower Impact, Higher Complexity

7. **AIX Initialization Tasks**
   - Already in Ansible playbook
   - Consider breaking into smaller roles:
     - `aix_storage_management`
     - `aix_disk_tuning`
     - `aix_proxy_configuration`
     - `aix_time_sync`
     - `aix_ssh_configuration`
     - `aix_disk_renaming`

8. **Ansible Execution Wrappers**
   - Consolidate into single wrapper with parameters
   - Move ansible.cfg creation to Ansible itself
   - Use Ansible's native logging capabilities

9. **Volume Attachment Wait**
   - Replace time_sleep with Ansible wait_for module
   - Add validation checks for volume attachment
   - Implement retry logic

### Priority 4: Already in Ansible, Needs Enhancement

10. **Oracle Installation Playbooks**
    - Already using IBM collections
    - Add pre-validation tasks
    - Add post-installation verification
    - Improve error handling and rollback

---

## BENEFITS OF MIGRATION

### 1. **Reduced Terraform Complexity**
- Remove 90% of null_resource and terraform_data resources
- Eliminate shell script dependencies
- Simplify main.tf files by 50-70%

### 2. **Improved Maintainability**
- Centralized configuration in Ansible
- Version-controlled playbooks
- Easier testing and debugging

### 3. **Better Error Handling**
- Ansible's built-in retry mechanisms
- Detailed error reporting
- Rollback capabilities

### 4. **Enhanced Idempotency**
- Ansible ensures tasks are idempotent
- Safe to re-run playbooks
- Reduced risk of configuration drift

### 5. **Improved Security**
- Ansible Vault for secrets
- No SSH keys in Terraform state
- Better credential management

### 6. **Better Logging and Auditing**
- Structured Ansible logs
- Task-level reporting
- Easier troubleshooting

### 7. **Increased Reusability**
- Ansible roles can be shared
- Collections can be versioned
- Easier to adapt for different environments

---

## IMPLEMENTATION STRATEGY

### Phase 1: Foundation (Weeks 1-2)
1. Create Ansible collection structure
2. Migrate squid proxy management
3. Migrate file operations
4. Migrate SSH key management

### Phase 2: Bootstrap (Weeks 3-4)
5. Migrate Ansible host bootstrap scripts
6. Migrate package installation
7. Migrate Ansible collections setup
8. Test in development environment

### Phase 3: Infrastructure (Weeks 5-6)
9. Migrate IBM Cloud COS downloads
10. Enhance DNS configuration
11. Migrate volume attachment waits
12. Test in staging environment

### Phase 4: AIX Operations (Weeks 7-8)
13. Enhance AIX initialization tasks
14. Migrate helper scripts to modules
15. Consolidate execution wrappers
16. Full integration testing

### Phase 5: Validation (Week 9)
17. End-to-end testing
18. Performance benchmarking
19. Documentation updates
20. Production deployment

---

## ESTIMATED EFFORT

| Task Category | Lines of Code | Estimated Effort |
|--------------|---------------|------------------|
| Shell Scripts | ~800 lines | 2-3 weeks |
| Terraform Provisioners | ~300 lines | 1-2 weeks |
| Ansible Enhancements | ~600 lines | 2-3 weeks |
| Testing & Documentation | N/A | 2 weeks |
| **Total** | **~1700 lines** | **7-10 weeks** |

---

## CONCLUSION

This comprehensive analysis identifies **10 major categories** of tasks currently outside the Ansible collection, comprising approximately **1700 lines of code** across shell scripts, Terraform provisioners, and helper utilities. 

Migrating these tasks into the Ansible collection will:
- Reduce Terraform code by 50-70%
- Improve maintainability and testability
- Enhance security and error handling
- Provide better logging and auditing
- Increase reusability across projects

The recommended phased approach allows for incremental migration with continuous testing and validation at each stage.