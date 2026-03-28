## Overview
This module creates a Oracle 19c Database Single Instance(SI) or Real Application Cluster(RAC) on IBM PowerVS Public or Private AIX VSI.

## Deployment variations

### Single Instance Database
https://github.ibm.com/Shiva-Laveti/oracle_da_readme/blob/da-dev/da-si.md

<img width="342" alt="image" src="https://raw.githubusercontent.com/nava-dba/terraform-ibm-oracle-powervs-da/3f48b4caf7a1b28941949c0ccc6120f461a876e2/images/Oracle_DA_SI.svg" />

### RAC Database
https://github.ibm.com/Shiva-Laveti/oracle_da_readme/blob/da-dev/da-rac.md

<img width="342" alt="image" src="https://raw.githubusercontent.com/nava-dba/terraform-ibm-oracle-powervs-da/3f48b4caf7a1b28941949c0ccc6120f461a876e2/images/Oracle_DA_RAC.svg" />

### Tested Environment

| Tile | AIX OS Version | Management OS Version | Oracle Database Version |
|------|--------|--------------------|------------|
| PowerVS Public - SI | 7200-05-11, 7300-03-01, 7300-04-00| RHEL 9.6 | 19.27, 19.28, 19.30|
| PowerVS Public - RAC | 7200-05-11, 7300-03-01, 7300-04-00| RHEL 9.6  | 19.27, 19.28, 19.30|
| PowerVS Private - SI | **Not Tested**|
| PowerVS Private - RAC | **Not Tested** |

Note: Versions not listed above can also be used with this Deployment Architecture.
