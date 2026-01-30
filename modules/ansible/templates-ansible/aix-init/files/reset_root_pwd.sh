#!/bin/ksh

###############################################################################
# Reset root password on AIX
# Prompts for new password unless provided as argument
###############################################################################

USERNAME="root"


if [ -n "$1" ]; then
    NEWPASSWORD="$1"
else
    echo "Enter new password for $USERNAME:"
    stty -echo
    read NEWPASSWORD
    stty echo
    echo
fi

# Confirm
echo "Resetting password for user: $USERNAME"

# Update password
echo "${USERNAME}:${NEWPASSWORD}" | chpasswd

if [ $? -ne 0 ]; then
    echo "ERROR: chpasswd failed."
    exit 1
fi

# Clear login failures
pwdadm -c "$USERNAME"

if [ $? -ne 0 ]; then
    echo "WARNING: pwdadm could not clear login failures."
else
    echo "Login failures cleared for $USERNAME."
fi

echo "Password reset successfully."

exit 0
