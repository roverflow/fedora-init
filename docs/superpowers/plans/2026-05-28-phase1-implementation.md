# Phase 1 Implementation Plan: Fedora Desktop Setup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Ansible playbooks that take a bare Fedora Everything minimal install to a fully configured developer workstation with optional NVIDIA drivers.

**Architecture:** Six Ansible roles (base, nvidia, desktop, devtools, multimedia, language) orchestrated by a single `site.yml` playbook. A bootstrap shell script handles first-run user creation and Ansible installation. Optional features gated by boolean variables.

**Tech Stack:** Ansible (dnf5 module), Bash, Fedora RPM Fusion repos

---

## File Structure

```
ansible.cfg                        # Ansible config — inventory path, roles path
inventory/hosts.yml                # localhost with local connection
group_vars/all.yml                 # Global variables (target_user, enable_nvidia, desktop_environment)
playbooks/site.yml                 # Main playbook — includes all roles in order
roles/base/defaults/main.yml       # Base role package lists
roles/base/tasks/main.yml          # Base role tasks (RPM Fusion, dnf config, updates, CLI tools, firewall, Flathub, virt)
roles/nvidia/defaults/main.yml     # NVIDIA role package lists
roles/nvidia/tasks/main.yml        # NVIDIA role tasks (driver, VAAPI, akmod, dracut, nouveau, modesetting)
roles/desktop/defaults/main.yml    # Desktop role config (DE choice)
roles/desktop/tasks/main.yml       # Desktop role tasks (DE install, graphical target, display manager)
roles/devtools/defaults/main.yml   # Devtools role package lists and flags
roles/devtools/tasks/main.yml      # Devtools role tasks (C/C++, packaging, rustup, nvm, gvm)
roles/multimedia/defaults/main.yml # Multimedia role package lists
roles/multimedia/tasks/main.yml    # Multimedia role tasks (GStreamer, FFmpeg, group update)
roles/language/defaults/main.yml   # Language role config (locale, fonts, input methods)
roles/language/tasks/main.yml      # Language role tasks (locale, langpacks, fonts, fontconfig, input methods)
scripts/bootstrap.sh               # First-run script (user creation, Ansible install, playbook launch)
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `ansible.cfg`
- Create: `inventory/hosts.yml`
- Create: `group_vars/all.yml`
- Create: `playbooks/site.yml`

- [ ] **Step 1: Create `ansible.cfg`**

```ini
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
host_key_checking = False
```

- [ ] **Step 2: Create `inventory/hosts.yml`**

```yaml
---
all:
  hosts:
    localhost:
      ansible_connection: local
```

- [ ] **Step 3: Create `group_vars/all.yml`**

```yaml
---
target_user: "{{ ansible_user_id }}"
enable_nvidia: false
desktop_environment: kde
```

- [ ] **Step 4: Create `playbooks/site.yml`**

```yaml
---
- name: Fedora Desktop Setup
  hosts: localhost
  connection: local
  become: true

  roles:
    - role: base
      tags: base

    - role: nvidia
      tags: nvidia
      when: enable_nvidia | bool

    - role: desktop
      tags: desktop

    - role: devtools
      tags: devtools

    - role: multimedia
      tags: multimedia

    - role: language
      tags: language
```

- [ ] **Step 5: Create empty role skeletons for all six roles**

Create empty `tasks/main.yml` and `defaults/main.yml` for each role so the syntax check passes:

`roles/base/tasks/main.yml`:
```yaml
---
```

`roles/base/defaults/main.yml`:
```yaml
---
```

`roles/nvidia/tasks/main.yml`:
```yaml
---
```

`roles/nvidia/defaults/main.yml`:
```yaml
---
```

`roles/desktop/tasks/main.yml`:
```yaml
---
```

`roles/desktop/defaults/main.yml`:
```yaml
---
```

`roles/devtools/tasks/main.yml`:
```yaml
---
```

`roles/devtools/defaults/main.yml`:
```yaml
---
```

`roles/multimedia/tasks/main.yml`:
```yaml
---
```

`roles/multimedia/defaults/main.yml`:
```yaml
---
```

`roles/language/tasks/main.yml`:
```yaml
---
```

`roles/language/defaults/main.yml`:
```yaml
---
```

- [ ] **Step 6: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 7: Commit**

```bash
git add ansible.cfg inventory/ group_vars/ playbooks/ roles/
git commit -m "feat: add project scaffolding with role skeletons"
```

---

### Task 2: Base Role

**Files:**
- Modify: `roles/base/defaults/main.yml`
- Modify: `roles/base/tasks/main.yml`

- [ ] **Step 1: Write `roles/base/defaults/main.yml`**

```yaml
---
base_cli_packages:
  - git
  - curl
  - wget
  - htop
  - btop
  - unzip
  - tar
  - vim
  - tmux
  - fastfetch
```

- [ ] **Step 2: Write `roles/base/tasks/main.yml`**

```yaml
---
- name: Install RPM Fusion free repository
  ansible.builtin.dnf5:
    name: "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-{{ ansible_distribution_major_version }}.noarch.rpm"
    state: present
    disable_gpg_check: true
  tags: base

- name: Install RPM Fusion nonfree repository
  ansible.builtin.dnf5:
    name: "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-{{ ansible_distribution_major_version }}.noarch.rpm"
    state: present
    disable_gpg_check: true
  tags: base

- name: Configure dnf max parallel downloads
  ansible.builtin.lineinfile:
    path: /etc/dnf/dnf.conf
    regexp: '^max_parallel_downloads='
    line: 'max_parallel_downloads=10'
    insertafter: '^\[main\]'
  tags: base

- name: Configure dnf fastest mirror
  ansible.builtin.lineinfile:
    path: /etc/dnf/dnf.conf
    regexp: '^fastestmirror='
    line: 'fastestmirror=True'
    insertafter: '^\[main\]'
  tags: base

- name: Configure dnf default yes
  ansible.builtin.lineinfile:
    path: /etc/dnf/dnf.conf
    regexp: '^defaultyes='
    line: 'defaultyes=True'
    insertafter: '^\[main\]'
  tags: base

- name: Update all packages
  ansible.builtin.dnf5:
    name: "*"
    state: latest
  tags: base

- name: Install essential CLI tools
  ansible.builtin.dnf5:
    name: "{{ base_cli_packages }}"
    state: present
  tags: base

- name: Install firewalld
  ansible.builtin.dnf5:
    name: firewalld
    state: present
  tags: base

- name: Enable and start firewalld
  ansible.builtin.systemd_service:
    name: firewalld
    enabled: true
    state: started
  tags: base

- name: Install flatpak
  ansible.builtin.dnf5:
    name: flatpak
    state: present
  tags: base

- name: Add Flathub remote
  ansible.builtin.command:
    cmd: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  changed_when: false
  tags: base

- name: Install virtualization group
  ansible.builtin.dnf5:
    name: "@virtualization"
    state: present
  tags: base

- name: Enable and start libvirtd
  ansible.builtin.systemd_service:
    name: libvirtd
    enabled: true
    state: started
  tags: base

- name: Add user to libvirt group
  ansible.builtin.user:
    name: "{{ target_user }}"
    groups: libvirt
    append: true
  tags: base
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/base/
git commit -m "feat: implement base role with RPM Fusion, dnf tuning, CLI tools, firewall, Flathub, virtualization"
```

---

### Task 3: NVIDIA Role

**Files:**
- Modify: `roles/nvidia/defaults/main.yml`
- Modify: `roles/nvidia/tasks/main.yml`

- [ ] **Step 1: Write `roles/nvidia/defaults/main.yml`**

```yaml
---
nvidia_driver_packages:
  - akmod-nvidia
  - xorg-x11-drv-nvidia
  - xorg-x11-drv-nvidia-cuda
  - xorg-x11-drv-nvidia-cuda-libs

nvidia_support_packages:
  - nvidia-vaapi-driver
  - libva-utils
  - vdpauinfo
```

- [ ] **Step 2: Write `roles/nvidia/tasks/main.yml`**

```yaml
---
- name: Install NVIDIA driver packages
  ansible.builtin.dnf5:
    name: "{{ nvidia_driver_packages }}"
    state: present
  tags: nvidia

- name: Install NVIDIA video acceleration packages
  ansible.builtin.dnf5:
    name: "{{ nvidia_support_packages }}"
    state: present
  tags: nvidia

- name: Update multimedia group with NVIDIA-aware builds
  ansible.builtin.command:
    cmd: dnf5 groupupdate multimedia --setopt=install_weak_deps=False --with-optional -y
  changed_when: true
  tags: nvidia

- name: Build NVIDIA kernel module
  ansible.builtin.command:
    cmd: akmods --force
  changed_when: true
  tags: nvidia

- name: Wait for NVIDIA kernel module build
  ansible.builtin.command:
    cmd: akmods --check
  register: akmod_check
  until: akmod_check.rc == 0
  retries: 30
  delay: 10
  changed_when: false
  tags: nvidia

- name: Rebuild initramfs with NVIDIA modules
  ansible.builtin.command:
    cmd: dracut --force
  changed_when: true
  tags: nvidia

- name: Blacklist nouveau driver
  ansible.builtin.copy:
    dest: /etc/modprobe.d/blacklist-nouveau.conf
    content: |
      blacklist nouveau
      options nouveau modeset=0
    mode: "0644"
  tags: nvidia

- name: Check current kernel args
  ansible.builtin.command:
    cmd: grubby --info=ALL
  register: grubby_info
  changed_when: false
  tags: nvidia

- name: Enable NVIDIA DRM modesetting for Wayland
  ansible.builtin.command:
    cmd: grubby --update-kernel=ALL --args="nvidia-drm.modeset=1"
  when: "'nvidia-drm.modeset=1' not in grubby_info.stdout"
  tags: nvidia
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/nvidia/
git commit -m "feat: implement NVIDIA role with akmod driver, VAAPI, modesetting, nouveau blacklist"
```

---

### Task 4: Desktop Role

**Files:**
- Modify: `roles/desktop/defaults/main.yml`
- Modify: `roles/desktop/tasks/main.yml`

- [ ] **Step 1: Write `roles/desktop/defaults/main.yml`**

```yaml
---
# desktop_environment is set in group_vars/all.yml (kde or gnome)
```

- [ ] **Step 2: Write `roles/desktop/tasks/main.yml`**

```yaml
---
- name: Validate desktop environment choice
  ansible.builtin.fail:
    msg: "desktop_environment must be 'kde' or 'gnome', got '{{ desktop_environment }}'"
  when: desktop_environment not in ['kde', 'gnome']
  tags: desktop

- name: Install KDE desktop environment
  ansible.builtin.dnf5:
    name: "@kde-desktop-environment"
    state: present
  when: desktop_environment == 'kde'
  tags: desktop

- name: Install GNOME desktop environment
  ansible.builtin.dnf5:
    name: "@workstation-product-environment"
    state: present
  when: desktop_environment == 'gnome'
  tags: desktop

- name: Set default target to graphical
  ansible.builtin.file:
    src: /usr/lib/systemd/system/graphical.target
    dest: /etc/systemd/system/default.target
    state: link
  tags: desktop

- name: Enable SDDM display manager for KDE
  ansible.builtin.systemd_service:
    name: sddm
    enabled: true
  when: desktop_environment == 'kde'
  tags: desktop

- name: Enable GDM display manager for GNOME
  ansible.builtin.systemd_service:
    name: gdm
    enabled: true
  when: desktop_environment == 'gnome'
  tags: desktop
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/desktop/
git commit -m "feat: implement desktop role with KDE/GNOME support and display manager setup"
```

---

### Task 5: Devtools Role

**Files:**
- Modify: `roles/devtools/defaults/main.yml`
- Modify: `roles/devtools/tasks/main.yml`

- [ ] **Step 1: Write `roles/devtools/defaults/main.yml`**

```yaml
---
devtools_c_groups:
  - "@c-development"
  - "@development-tools"

devtools_c_packages:
  - kernel-devel
  - kernel-headers
  - glibc-devel
  - libstdc++-devel

devtools_packaging_packages:
  - mock
  - rpm-build
  - rpmdevtools
  - fedora-packager
  - fedpkg

devtools_install_rust: true
devtools_install_nvm: true
devtools_install_gvm: true

devtools_nvm_install_url: "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
devtools_gvm_install_url: "https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer"
```

- [ ] **Step 2: Write `roles/devtools/tasks/main.yml`**

```yaml
---
- name: Install C/C++ development groups
  ansible.builtin.dnf5:
    name: "{{ devtools_c_groups }}"
    state: present
  tags: devtools

- name: Install additional development libraries
  ansible.builtin.dnf5:
    name: "{{ devtools_c_packages }}"
    state: present
  tags: devtools

- name: Install packaging and build tools
  ansible.builtin.dnf5:
    name: "{{ devtools_packaging_packages }}"
    state: present
  tags: devtools

- name: Add user to mock group
  ansible.builtin.user:
    name: "{{ target_user }}"
    groups: mock
    append: true
  tags: devtools

# --- Rust via rustup ---

- name: Check if rustup is installed
  ansible.builtin.stat:
    path: "/home/{{ target_user }}/.rustup"
  register: rustup_dir
  when: devtools_install_rust
  tags: devtools

- name: Download rustup installer
  ansible.builtin.get_url:
    url: https://sh.rustup.rs
    dest: /tmp/rustup-init.sh
    mode: "0755"
  when: devtools_install_rust and not rustup_dir.stat.exists
  tags: devtools

- name: Install rustup
  ansible.builtin.command:
    cmd: sh /tmp/rustup-init.sh -y
  become_user: "{{ target_user }}"
  environment:
    HOME: "/home/{{ target_user }}"
  when: devtools_install_rust and not rustup_dir.stat.exists
  tags: devtools

- name: Clean up rustup installer
  ansible.builtin.file:
    path: /tmp/rustup-init.sh
    state: absent
  when: devtools_install_rust
  tags: devtools

# --- nvm ---

- name: Check if nvm is installed
  ansible.builtin.stat:
    path: "/home/{{ target_user }}/.nvm"
  register: nvm_dir
  when: devtools_install_nvm
  tags: devtools

- name: Download nvm install script
  ansible.builtin.get_url:
    url: "{{ devtools_nvm_install_url }}"
    dest: /tmp/nvm-install.sh
    mode: "0755"
  when: devtools_install_nvm and not nvm_dir.stat.exists
  tags: devtools

- name: Install nvm
  ansible.builtin.command:
    cmd: bash /tmp/nvm-install.sh
  become_user: "{{ target_user }}"
  environment:
    HOME: "/home/{{ target_user }}"
  when: devtools_install_nvm and not nvm_dir.stat.exists
  tags: devtools

- name: Clean up nvm installer
  ansible.builtin.file:
    path: /tmp/nvm-install.sh
    state: absent
  when: devtools_install_nvm
  tags: devtools

# --- gvm ---

- name: Install gvm dependencies
  ansible.builtin.dnf5:
    name:
      - bison
      - mercurial
    state: present
  when: devtools_install_gvm
  tags: devtools

- name: Check if gvm is installed
  ansible.builtin.stat:
    path: "/home/{{ target_user }}/.gvm"
  register: gvm_dir
  when: devtools_install_gvm
  tags: devtools

- name: Download gvm install script
  ansible.builtin.get_url:
    url: "{{ devtools_gvm_install_url }}"
    dest: /tmp/gvm-installer.sh
    mode: "0755"
  when: devtools_install_gvm and not gvm_dir.stat.exists
  tags: devtools

- name: Install gvm
  ansible.builtin.command:
    cmd: bash /tmp/gvm-installer.sh
  become_user: "{{ target_user }}"
  environment:
    HOME: "/home/{{ target_user }}"
  when: devtools_install_gvm and not gvm_dir.stat.exists
  tags: devtools

- name: Clean up gvm installer
  ansible.builtin.file:
    path: /tmp/gvm-installer.sh
    state: absent
  when: devtools_install_gvm
  tags: devtools
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/devtools/
git commit -m "feat: implement devtools role with C/C++, packaging tools, rustup, nvm, gvm"
```

---

### Task 6: Multimedia Role

**Files:**
- Modify: `roles/multimedia/defaults/main.yml`
- Modify: `roles/multimedia/tasks/main.yml`

- [ ] **Step 1: Write `roles/multimedia/defaults/main.yml`**

```yaml
---
multimedia_gstreamer_packages:
  - gstreamer1-plugins-base
  - gstreamer1-plugins-good
  - gstreamer1-plugins-bad-free
  - gstreamer1-plugins-bad-freeworld
  - gstreamer1-plugins-ugly
  - gstreamer1-libav

multimedia_extra_packages:
  - ffmpeg
  - ffmpeg-libs
```

- [ ] **Step 2: Write `roles/multimedia/tasks/main.yml`**

```yaml
---
- name: Install GStreamer codec plugins
  ansible.builtin.dnf5:
    name: "{{ multimedia_gstreamer_packages }}"
    state: present
  tags: multimedia

- name: Install FFmpeg
  ansible.builtin.dnf5:
    name: "{{ multimedia_extra_packages }}"
    state: present
  tags: multimedia

- name: Update multimedia and sound-and-video groups
  ansible.builtin.command:
    cmd: dnf5 groupupdate multimedia sound-and-video -y
  changed_when: true
  tags: multimedia
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/multimedia/
git commit -m "feat: implement multimedia role with GStreamer codecs, FFmpeg, group updates"
```

---

### Task 7: Language Role

**Files:**
- Modify: `roles/language/defaults/main.yml`
- Modify: `roles/language/tasks/main.yml`

- [ ] **Step 1: Write `roles/language/defaults/main.yml`**

```yaml
---
language_locale: en_US.UTF-8

language_extra_langpacks: []

language_fonts:
  - google-noto-sans-fonts
  - google-noto-serif-fonts
  - google-noto-emoji-fonts
  - google-noto-cjk-fonts
  - liberation-fonts
  - jetbrains-mono-fonts
  - ubuntu-family-fonts

language_install_input_methods: false
language_input_method: ibus
```

- [ ] **Step 2: Write `roles/language/tasks/main.yml`**

```yaml
---
- name: Check current locale
  ansible.builtin.command:
    cmd: localectl status
  register: locale_status
  changed_when: false
  tags: language

- name: Set system locale
  ansible.builtin.command:
    cmd: localectl set-locale LANG={{ language_locale }}
  when: language_locale not in locale_status.stdout
  tags: language

- name: Install English language pack
  ansible.builtin.dnf5:
    name: glibc-langpack-en
    state: present
  tags: language

- name: Install extra language packs
  ansible.builtin.dnf5:
    name: "{{ language_extra_langpacks }}"
    state: present
  when: language_extra_langpacks | length > 0
  tags: language

- name: Install fonts
  ansible.builtin.dnf5:
    name: "{{ language_fonts }}"
    state: present
  tags: language

- name: Configure font rendering
  ansible.builtin.copy:
    dest: /etc/fonts/local.conf
    content: |
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="font">
          <edit name="antialias" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hinting" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
          </edit>
          <edit name="rgba" mode="assign">
            <const>rgb</const>
          </edit>
          <edit name="lcdfilter" mode="assign">
            <const>lcddefault</const>
          </edit>
        </match>
      </fontconfig>
    mode: "0644"
  tags: language

- name: Install input method framework
  ansible.builtin.dnf5:
    name: "{{ language_input_method }}"
    state: present
  when: language_install_input_methods
  tags: language
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Commit**

```bash
git add roles/language/
git commit -m "feat: implement language role with locale, fonts, fontconfig, input methods"
```

---

### Task 8: Bootstrap Script

**Files:**
- Create: `scripts/bootstrap.sh`

- [ ] **Step 1: Write `scripts/bootstrap.sh`**

```bash
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
```

- [ ] **Step 2: Make bootstrap script executable**

Run: `chmod +x scripts/bootstrap.sh`

- [ ] **Step 3: Verify script syntax**

Run: `bash -n scripts/bootstrap.sh`
Expected: no output (no syntax errors)

- [ ] **Step 4: Commit**

```bash
git add scripts/bootstrap.sh
git commit -m "feat: add bootstrap script with user creation and Ansible kickoff"
```

---

### Task 9: Final Integration Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full syntax check**

Run: `ansible-playbook playbooks/site.yml --syntax-check`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 2: Run syntax check with NVIDIA enabled**

Run: `ansible-playbook playbooks/site.yml --syntax-check -e enable_nvidia=true`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 3: Run syntax check with GNOME desktop**

Run: `ansible-playbook playbooks/site.yml --syntax-check -e desktop_environment=gnome`
Expected: `playbook: playbooks/site.yml` (no errors)

- [ ] **Step 4: Verify all roles are tagged correctly**

Run: `ansible-playbook playbooks/site.yml --list-tags`
Expected: tags listed include `base`, `nvidia`, `desktop`, `devtools`, `multimedia`, `language`

- [ ] **Step 5: Verify all tasks are listed**

Run: `ansible-playbook playbooks/site.yml --list-tasks`
Expected: all tasks from all roles listed with their names

- [ ] **Step 6: Verify bootstrap script is executable**

Run: `ls -la scripts/bootstrap.sh`
Expected: `-rwxr-xr-x` permissions

- [ ] **Step 7: Commit any final fixes if needed, then tag the milestone**

```bash
git tag -a v0.1.0 -m "Phase 1: base, nvidia, desktop, devtools, multimedia, language roles"
```
