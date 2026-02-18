#!/bin/ksh

###############################################################################
# Rename Shared Disks Across RAC Nodes
# Node1 is reference, current node aligns to Node1
#
# Usage:
#   rename_disk.sh <shared_disk_tag> <node1_lsmpio_output_file>
#
# Example:
#   rename_disk.sh asm /tmp/node1_lsmpio.out
###############################################################################

# -------------------------------
# AIX safety check
# -------------------------------
if [ "$(uname -s)" != "AIX" ]; then
    echo "ERROR: This script is for AIX only"
    exit 1
fi

# -------------------------------
# Argument validation
# -------------------------------
if [ $# -ne 2 ]; then
    echo "Usage: $0 <shared_disk_tag> <node1_lsmpio_output_file>"
    exit 1
fi

TAG="$1"
REF_FILE="$2"

if [ ! -f "$REF_FILE" ]; then
    echo "ERROR: Reference file $REF_FILE not found"
    exit 1
fi

HOST=$(hostname)

echo "--------------------------------------------------"
echo "Renaming disks on node: $HOST"
echo "Reference node: Node1"
echo "--------------------------------------------------"

# -------------------------------
# Collect local lsmpio
# -------------------------------
CUR_FILE="/tmp/current_lsmpio.out"
lsmpio -q > "$CUR_FILE"

# -------------------------------
# Filter only shared disks
# -------------------------------
REF_DATA="/tmp/node1_data.out"
CUR_DATA="/tmp/current_data.out"

grep "$TAG" "$REF_FILE" > "$REF_DATA"
grep "$TAG" "$CUR_FILE" > "$CUR_DATA"

if [ ! -s "$REF_DATA" ]; then
    echo "ERROR: No '$TAG' disks found in Node1 reference"
    exit 1
fi

if [ ! -s "$CUR_DATA" ]; then
    echo "ERROR: No '$TAG' disks found on $HOST"
    exit 1
fi

# -------------------------------
# Step 1: Temporarily rename local disks
# -------------------------------
echo "Assigning temporary names on $HOST..."
while read line; do
    disk=$(echo "$line" | awk '{print $1}')
    temp="${disk}_tmp"

    if lsdev -Cc disk | awk '{print $1}' | grep -q "^${temp}$"; then
        continue
    fi

    echo "  $disk → $temp"
    /usr/sbin/rendev -l "$disk" -n "$temp"
done < "$CUR_DATA"

# Refresh lsmpio after temp rename
lsmpio -q > "$CUR_FILE"
grep "$TAG" "$CUR_FILE" > "$CUR_DATA"

# -------------------------------
# Step 2: Rename to Node1 names
# -------------------------------
echo "Aligning disk names to Node1..."
while read ref_line; do
    ref_disk=$(echo "$ref_line" | awk '{print $1}')
    ref_vol=$(echo "$ref_line" | awk '{print $NF}')

    cur_line=$(grep "$ref_vol" "$CUR_DATA")
    if [ -z "$cur_line" ]; then
        echo "WARNING: Volume $ref_vol not found on $HOST"
        continue
    fi

    cur_disk=$(echo "$cur_line" | awk '{print $1}')
    temp_disk="${cur_disk}"

    echo "  $temp_disk → $ref_disk"
    /usr/sbin/rendev -l "$temp_disk" -n "$ref_disk"
done < "$REF_DATA"

echo "--------------------------------------------------"
echo "Final disk layout on $HOST"
echo "--------------------------------------------------"
lsmpio -q

exit 0
