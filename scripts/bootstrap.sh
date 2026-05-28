#!/bin/bash
set -euo pipefail

# Fedora Init Bootstrap Script
# Takes a bare Fedora Everything minimal install and kicks off Ansible setup.
#
# Usage: sudo ./bootstrap.sh [extra ansible-playbook args]
# Examples:
#   sudo ./bootstrap.sh
#   sudo ./bootstrap.sh -e enable_nvidia=true
#   sudo ./bootstrap.sh -e enable_nvidia=true -e desktop_environment=gnome

if [[ $EUID -ne 0 ]]; then
    echo "Error: this script must be run as root (use sudo)"
    exit 1
fi

echo "=== Fedora Init Bootstrap ==="
echo ""

# Step 1: Install Ansible and git
echo "[1/4] Installing Ansible and git..."
dnf install -y ansible git

# Step 2: Detect or create non-root user
echo ""
echo "[2/4] Setting up user account..."

NON_ROOT_USERS=()
while IFS= read -r user; do
    NON_ROOT_USERS+=("$user")
done < <(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

if [[ ${#NON_ROOT_USERS[@]} -eq 0 ]]; then
    echo "No non-root user found. Creating one now."
    read -rp "Enter username: " NEW_USER

    if [[ -z "$NEW_USER" ]]; then
        echo "Error: username cannot be empty"
        exit 1
    fi

    useradd -m -G wheel "$NEW_USER"
    echo "Set password for $NEW_USER:"
    passwd "$NEW_USER"
    TARGET_USER="$NEW_USER"
    echo "Created user: $TARGET_USER"

elif [[ ${#NON_ROOT_USERS[@]} -eq 1 ]]; then
    TARGET_USER="${NON_ROOT_USERS[0]}"
    echo "Found user: $TARGET_USER"

else
    echo "Multiple users found:"
    for i in "${!NON_ROOT_USERS[@]}"; do
        echo "  $((i + 1)). ${NON_ROOT_USERS[$i]}"
    done
    read -rp "Select user (number): " SELECTION

    if [[ -z "$SELECTION" ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -gt ${#NON_ROOT_USERS[@]} ]]; then
        echo "Error: invalid selection"
        exit 1
    fi

    TARGET_USER="${NON_ROOT_USERS[$((SELECTION - 1))]}"
    echo "Selected user: $TARGET_USER"
fi

# Step 3: Ensure user is in wheel group
echo ""
echo "[3/4] Ensuring $TARGET_USER is in wheel group..."
usermod -aG wheel "$TARGET_USER"

# Step 4: Run Ansible playbook
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "[4/4] Running Ansible playbook..."
echo "Target user: $TARGET_USER"
echo "Extra args: $*"
echo ""

ansible-playbook \
    "$REPO_DIR/playbooks/site.yml" \
    -e "target_user=$TARGET_USER" \
    "$@"

echo ""
echo "=== Setup complete! ==="
echo "A reboot is recommended to apply all changes."
echo "Run: sudo reboot"
