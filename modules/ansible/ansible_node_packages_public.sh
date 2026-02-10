#!/bin/bash
############################################################
# OS_Support: RHEL only                                    #
# This bash script performs                                #
# - installation of packages                               #
# - ansible galaxy collections.                            #
#                                                          #
############################################################

GLOBAL_RHEL_PACKAGES="rhel-system-roles expect perl nfs-utils python3-pip net-tools bind-utils ansible-core"
GLOBAL_GALAXY_COLLECTIONS="ibm.power_linux_sap:>=3.0.0,<4.0.0 ibm.power_aix:2.1.1 ibm.power_aix_oracle:1.3.2 ibm.power_aix_oracle_dba:2.0.8 ibm.power_aix_oracle_rac_asm:1.3.5 ansible.utils:6.0.0"

############################################################
# Start functions
############################################################

main::get_os_version() {
  if grep -q "Red Hat" /etc/os-release; then
    readonly LINUX_DISTRO="RHEL"
  else
    main::log_error "Unsupported Linux distribution. Only RHEL is supported."
  fi
  #readonly LINUX_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '\"' '{ print $2 }')
}

main::log_info() {
  local log_entry=${1}
  echo "INFO - ${log_entry}"
}

main::log_error() {
  local log_entry=${1}
  echo "ERROR - Deployment exited - ${log_entry}"
  exit 1
}

main::log_system_info() {
  local instance_id utc_time
  instance_id=$(dmidecode -s system-family)
  utc_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  main::log_info "Virtual server instance ID: ${instance_id}"
  main::log_info "System Time (UTC): ${utc_time}"
}

main::subscription_mgr_check_process() {

  main::log_info "Sleeping 30 seconds for all subscription-manager process to finish."
  sleep 30

  ## check if subscription-manager is still running
  while pgrep subscription-manager; do
    main::log_info "--- subscription-manager is still running. Waiting 10 seconds before attempting to continue"
    sleep 10s
  done

}
############################################################
# Update /etc/hosts with IP and hostname entries          #
############################################################
main::update_hosts_file() {
  # shellcheck disable=SC2154  # variables come from Terraform template
  local hosts_entries="${hosts_file_entries}"
  
  if [[ -z "${hosts_entries}" ]]; then
    main::log_info "No host entries provided, skipping /etc/hosts update"
    return 0
  fi

  main::log_info "Updating /etc/hosts file"
  
  # Backup existing hosts file
  if [[ ! -f /etc/hosts.backup ]]; then
    cp /etc/hosts /etc/hosts.backup
    main::log_info "Created backup: /etc/hosts.backup"
  fi

  # Add marker for managed entries
  local marker_start="# BEGIN ANSIBLE MANAGED HOSTS"
  local marker_end="# END ANSIBLE MANAGED HOSTS"

  # Remove old managed section if it exists
  sed -i "/${marker_start}/,/${marker_end}/d" /etc/hosts

  # Add new entries
  cat <<EOF >> /etc/hosts

${marker_start}
${hosts_entries}
${marker_end}
EOF

  main::log_info "/etc/hosts updated successfully"
  main::log_info "Added entries:"
  echo "${hosts_entries}" | while IFS= read -r line; do
    [[ -n "$line" ]] && main::log_info "  $line"
  done
}

############################################################
# RHEL : Install Packages                                  #
############################################################
main::install_packages() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then

    main::subscription_mgr_check_process

    ## hotfix for subscription-manager broken pipe error in next step
    subscription-manager list --available --all

    ## enable repository for RHEL sap roles
    #subscription-manager repos --enable="rhel-$(rpm -E %rhel)-for-$(uname -m)-sap-solutions-rpms"

    ## Install packages
    for package in $GLOBAL_RHEL_PACKAGES; do
      local count=0
      local max_count=3
      while ! dnf -y install "${package}"; do
        count=$((count + 1))
        sleep 3
        # shellcheck disable=SC2317
        if [[ ${count} -gt ${max_count} ]]; then
          main::log_error "Failed to install ${package}"
          break
        fi
      done
    done

  fi
}

############################################################
# RHEL : Install ansible collection                        #
############################################################
main::install_collections() {

  # shellcheck disable=SC2154  # variable comes from Terraform template
  local proxy_url="http://${squid_server_ip}:3128"
  # Export for current shell
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"
  export no_proxy="localhost,127.0.0.1,::1"

  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then

    ## Download and install collections from ansible-galaxy

    for collection in $GLOBAL_GALAXY_COLLECTIONS; do
      local count=0
      local max_count=3
      while ! ansible-galaxy collection install "${collection}" -f; do
        count=$((count + 1))
        sleep 3
        # shellcheck disable=SC2317
        if [[ ${count} -gt ${max_count} ]]; then
          main::log_error "Failed to install ansible galaxy collection ${collection}"
          break
        fi
      done
    done

    ansible-galaxy collection install -r '/root/.ansible/collections/ansible_collections/ibm/power_linux_sap/requirements.yml' -f
    main::log_info "All packages installed successfully"
  fi

}

############################################################
# Setup proxy                                              #
############################################################
main::setup_proxy() {
  # shellcheck disable=SC2154  # variable comes from Terraform template
  local proxy_url="http://${squid_server_ip}:3128"

  # Determine correct bashrc file
  if [[ -f /etc/bashrc ]]; then
    bashrc_file="/etc/bashrc"
  elif [[ -f /etc/bash.bashrc ]]; then
    bashrc_file="/etc/bash.bashrc"
  else
    main::log_error "No global bashrc file found!"
    # shellcheck disable=SC2317 # ignore
    return 1
  fi

  # Export for current shell
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"
  export no_proxy="localhost,127.0.0.1,::1"

  # Clean existing entries
  sed -i '/http_proxy=/d' "$bashrc_file"
  sed -i '/https_proxy=/d' "$bashrc_file"
  sed -i '/HTTP_PROXY=/d' "$bashrc_file"
  sed -i '/HTTPS_PROXY=/d' "$bashrc_file"
  sed -i '/no_proxy=/d' "$bashrc_file"

  # Append new entries
  cat <<EOF >> "$bashrc_file"

# Proxy Settings
export http_proxy=$proxy_url
export https_proxy=$proxy_url
export HTTP_PROXY=$proxy_url
export HTTPS_PROXY=$proxy_url
export no_proxy=localhost,127.0.0.1,::1
EOF

  main::log_info "Proxy configured in $bashrc_file: $proxy_url"
}

############################################################
# RHEL : Install python pip packages                       #
############################################################
main::install_pip_packages() {

  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    main::log_info "Installing python pip packages"

    local count=0
    local max_count=3
    while ! pip3 install --upgrade netaddr; do
      count=$((count + 1))
      sleep 3
      if [[ ${count} -gt ${max_count} ]]; then
        main::log_error "Failed to install python package: netaddr"
        break
      fi
    done

    main::log_info "Python package netaddr installed successfully"
  fi
}


############################################################
# Main start here                                          #
############################################################
main::get_os_version
main::log_system_info
main::update_hosts_file
main::install_packages
main::setup_proxy
main::install_pip_packages
main::install_collections