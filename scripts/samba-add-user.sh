#!/usr/bin/env bash
# Script to add or update a Samba user password
# Usage: samba-add-user.sh [username]

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [username]"
    echo "Add or update a Samba user password"
    echo ""
    echo "If no username is provided, defaults to the current user"
    exit 1
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Get username (default to current user)
USERNAME="${1:-$(whoami)}"

# Check if user exists in system
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "Error: User '$USERNAME' does not exist in the system"
    echo "Please create the system user first"
    exit 1
fi

# Check if running with appropriate permissions
if [[ $EUID -ne 0 ]] && [[ "$USERNAME" != "$(whoami)" ]]; then
    echo "Error: You need to run this script as root to add other users"
    echo "Try: sudo $0 $USERNAME"
    exit 1
fi

echo "Setting Samba password for user: $USERNAME"
echo "Note: The user must exist in the system before adding to Samba"
echo ""

# Add or update the Samba user
if [[ $EUID -eq 0 ]]; then
    # Running as root
    if smbpasswd -a "$USERNAME"; then
        success=true
    else
        success=false
    fi
else
    # Running as regular user - need sudo
    if sudo smbpasswd -a "$USERNAME"; then
        success=true
    else
        success=false
    fi
fi

if [[ $success == true ]]; then
    echo ""
    echo "Samba password for '$USERNAME' has been set successfully!"
    echo ""
    echo "You can now connect to Samba shares using:"
    printf "  - Windows: \\\\\\\\hal9000\\\\storage-fast\n"
    echo "  - macOS/Linux: smb://hal9000/storage-fast"
    echo ""
    echo "Use username '$USERNAME' and the password you just set"
else
    echo "Error: Failed to set Samba password"
    exit 1
fi