## Overview
This module creates a Oracle 19c Database Single Instance(SI) or Real Application Cluster(RAC) on IBM PowerVS Public or Private AIX VSI.

## Deployment variations

### Single Instance Database
https://github.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/blob/main/solutions/oracle/si/README.md

<img width="342" alt="image" src="https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/0859fa3a4c1581e6db02c0cc7f8e9cf104976e05/images/Oracle_DA_SI.svg" />

### RAC Database
https://github.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/blob/main/solutions/oracle/rac/README.md

<img width="342" alt="image" src="https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/0859fa3a4c1581e6db02c0cc7f8e9cf104976e05/images/Oracle_DA_RAC.svg" />

### Tested Environment

| Tile | AIX OS Version | Management OS Version | Oracle Database Version |
|------|--------|--------------------|------------|
| PowerVS Public - SI | 7200-05-11, 7300-03-01, 7300-04-00| RHEL 9.6 | 19.27, 19.28, 19.30|
| PowerVS Public - RAC | 7200-05-11, 7300-03-01, 7300-04-00| RHEL 9.6  | 19.27, 19.28, 19.30|
| PowerVS Private - SI | 7300-04-00 | RHEL 9.6 | 19.30 |
| PowerVS Private - RAC | 7300-04-00 | RHEL 9.6 | 19.30 |

**Note 1**: Versions not listed above can also be used with this Deployment Architecture.
**<br>Note 2**: If you use "Power Virtual Server with VPC landing zone" for creating the VPC, you should use only the Management VSI/VPC and configure squid manually on this VSI. Currently the Network service VSI/VPC is not supported for Oracle DA deployment.
