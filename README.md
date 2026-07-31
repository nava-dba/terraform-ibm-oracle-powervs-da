# Oracle Database Deployment Architecture on IBM PowerVS

## Overview

This module deploys an **Oracle 19c Database** as a Single Instance (SI) or Real Application Cluster (RAC) on an IBM PowerVS Public or Private AIX Virtual Server Instance (VSI).

## Deployment Variations

| Variation - Readme | Description | Availability |
|-----------|-------------|--------------|
| [**Single Instance Database**](https://github.com/nava-dba/terraform-ibm-oracle-powervs-da/blob/shiva-dev/solutions/oracle/si/README.md) | Oracle 19c SI on AIX VSI, manual steps are required | Public & Private |
| [**RAC Database**](https://github.com/nava-dba/terraform-ibm-oracle-powervs-da/blob/shiva-dev/solutions/oracle/rac/README.md) | Oracle 19c RAC on AIX VSI, manual steps are required | Public & Private |
| [**Oracle SI-One Click**](https://github.com/nava-dba/terraform-ibm-oracle-powervs-da/blob/shiva-dev/solutions/oracle/si-ready-to-go/README.md) | Fully automated Oracle SI deployment via PowerVS VPC landing zone | Public only |

## Tested Environments

| Tile | AIX OS Version | Management OS Version | Oracle Database Version |
|------|----------------|-----------------------|-------------------------|
| PowerVS Public — SI | 7200-05-11, 7300-03-01, 7300-04-00 | RHEL 9.6 | 19.27, 19.28, 19.30 |
| PowerVS Public — RAC | 7200-05-11, 7300-03-01, 7300-04-00 | RHEL 9.6 | 19.27, 19.28, 19.30 |
| PowerVS Private — SI | 7300-04-00 | RHEL 9.6 | 19.30 |
| PowerVS Private — RAC | 7300-04-00 | RHEL 9.6 | 19.30 |
|  PowerVS Public — SI One Click| 7300-04-00 | RHEL 9.6 | 19.30 |
## Notes

**Note 1:** Versions not listed in the table above can also be used with this Deployment Architecture.

**Note 2:** One prerequisite step for all deployment variations is, we need to have oracle binaries uploaded to COS bucket before starting deployment
