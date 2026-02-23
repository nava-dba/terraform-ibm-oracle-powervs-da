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
    read -r NEWPASSWORD
    stty echo
    echo
fi

# Confirm
echo "Resetting password for user: $USERNAME"

# Update password
if ! echo "${USERNAME}:${NEWPASSWORD}" | chpasswd; then
    echo "ERROR: chpasswd failed."
    exit 1
fi


# Clear login failures
if ! pwdadm -c "$USERNAME"; then
    echo "WARNING: pwdadm could not clear login failures."
else
    echo "Login failures cleared for $USERNAME."
fi

echo "Password reset successfully."

exit 0
