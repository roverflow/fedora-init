#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/roverflow/fedora-init.git"
INSTALL_DIR="/opt/fedora-init"

cleanup() {
    rm -f /tmp/fedora-init.sh
}
trap cleanup EXIT

if [[ $EUID -ne 0 ]]; then
    echo "Error: this script must be run as root (use sudo)"
    exit 1
fi

exec < /dev/tty

echo ""
echo "=============================="
echo "  Fedora Init - Desktop Setup"
echo "=============================="
echo ""

# --- Desktop Environment ---

while true; do
    echo "Choose your desktop environment:"
    echo "  1) KDE Plasma"
    echo "  2) GNOME"
    read -rp "Selection [1]: " DE_CHOICE
    DE_CHOICE="${DE_CHOICE:-1}"

    case "$DE_CHOICE" in
        1) DESKTOP_ENV="kde"; break ;;
        2) DESKTOP_ENV="gnome"; break ;;
        *) echo "Invalid selection. Please enter 1 or 2."; echo "" ;;
    esac
done

echo ""

# --- NVIDIA Drivers ---

read -rp "Install NVIDIA proprietary drivers? [y/N]: " NVIDIA_CHOICE
NVIDIA_CHOICE="${NVIDIA_CHOICE:-n}"

case "$NVIDIA_CHOICE" in
    [yY]|[yY][eE][sS]) ENABLE_NVIDIA="true" ;;
    *) ENABLE_NVIDIA="false" ;;
esac

echo ""

# --- User Account ---

NON_ROOT_USERS=()
while IFS= read -r user; do
    NON_ROOT_USERS+=("$user")
done < <(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

if [[ ${#NON_ROOT_USERS[@]} -eq 0 ]]; then
    echo "No non-root user found. Creating one now."

    while true; do
        read -rp "Enter username: " NEW_USER
        if [[ -n "$NEW_USER" ]]; then
            break
        fi
        echo "Username cannot be empty."
    done

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

    while true; do
        read -rp "Select user (number): " SELECTION
        if [[ -n "$SELECTION" ]] && [[ "$SELECTION" -ge 1 ]] && [[ "$SELECTION" -le ${#NON_ROOT_USERS[@]} ]] 2>/dev/null; then
            TARGET_USER="${NON_ROOT_USERS[$((SELECTION - 1))]}"
            echo "Selected user: $TARGET_USER"
            break
        fi
        echo "Invalid selection. Please enter a number between 1 and ${#NON_ROOT_USERS[@]}."
    done
fi

# --- Summary + Confirmation ---

DESKTOP_DISPLAY="KDE Plasma"
if [[ "$DESKTOP_ENV" == "gnome" ]]; then
    DESKTOP_DISPLAY="GNOME"
fi

NVIDIA_DISPLAY="No"
if [[ "$ENABLE_NVIDIA" == "true" ]]; then
    NVIDIA_DISPLAY="Yes"
fi

echo ""
echo "=============================="
echo "  Setup Summary"
echo "=============================="
echo "  Desktop:  $DESKTOP_DISPLAY"
echo "  NVIDIA:   $NVIDIA_DISPLAY"
echo "  User:     $TARGET_USER"
echo "=============================="
echo ""

read -rp "Proceed with installation? [Y/n]: " PROCEED
PROCEED="${PROCEED:-y}"

case "$PROCEED" in
    [yY]|[yY][eE][sS]|"") ;;
    *)
        echo "Installation cancelled."
        exit 0
        ;;
esac

echo ""

# --- Install Dependencies ---

echo "[1/4] Installing Ansible and git..."
if ! dnf install -y ansible git; then
    echo "Failed to install dependencies. Check your internet connection."
    exit 1
fi

echo ""

# --- Clone Repository ---

echo "[2/4] Setting up fedora-init repository..."
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Repository already exists at $INSTALL_DIR, updating..."
    if ! git -C "$INSTALL_DIR" pull; then
        echo "Failed to update repository. Check your internet connection."
        exit 1
    fi
else
    echo "Cloning repository to $INSTALL_DIR..."
    if ! git clone "$REPO_URL" "$INSTALL_DIR"; then
        echo "Failed to clone repository. Check your internet connection."
        exit 1
    fi
fi

echo ""

# --- Ensure User Groups ---

echo "[3/4] Ensuring $TARGET_USER is in wheel group..."
usermod -aG wheel "$TARGET_USER"

echo ""

# --- Run Ansible Playbook ---

echo "[4/4] Running Ansible playbook..."
echo "Target user: $TARGET_USER"
echo "Desktop: $DESKTOP_DISPLAY"
echo "NVIDIA: $NVIDIA_DISPLAY"
echo ""

cd "$INSTALL_DIR"

ansible-playbook \
    playbooks/site.yml \
    -e "target_user=$TARGET_USER" \
    -e "desktop_environment=$DESKTOP_ENV" \
    -e "enable_nvidia=$ENABLE_NVIDIA"

echo ""
echo "=============================="
echo "  Setup complete!"
echo "=============================="
echo "A reboot is recommended to apply all changes."
echo "Run: sudo reboot"
