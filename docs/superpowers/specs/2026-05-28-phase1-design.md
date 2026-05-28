# Phase 1 Design: Fedora Everything → Developer + Gaming Desktop

## Overview

Ansible-based automation that takes a bare Fedora Everything minimal install (TTY + network only) and transforms it into a fully configured developer workstation with optional NVIDIA drivers. Six roles, one playbook, one bootstrap script.

**Target**: Fedora Everything minimal install, NVIDIA GPU
**Tool**: Ansible with dnf5 module
**Philosophy**: Idempotent, RPM Fusion only (no COPR), stock Fedora kernel, prefer DNF groups over hand-picked packages for stability

## Project Structure

```
ansible.cfg              # Ansible config (inventory path, roles path, defaults)
inventory/
  hosts.yml              # localhost, connection: local
playbooks/
  site.yml               # Main entry point — includes all roles in dependency order
roles/
  base/
    tasks/main.yml
    defaults/main.yml
  nvidia/
    tasks/main.yml
    defaults/main.yml
  desktop/
    tasks/main.yml
    defaults/main.yml
  devtools/
    tasks/main.yml
    defaults/main.yml
  multimedia/
    tasks/main.yml
    defaults/main.yml
  language/
    tasks/main.yml
    defaults/main.yml
scripts/
  bootstrap.sh           # First script to run on fresh install
```

## Configuration Approach

- All options controlled via Ansible variables with sensible defaults
- Override via `-e` flag: `ansible-playbook site.yml -e enable_nvidia=true -e desktop_environment=gnome`
- Package lists in `defaults/main.yml` per role so users can override
- Optional roles gated by boolean flags (default `false`)

## Global Variable

```yaml
target_user: "{{ ansible_user_id }}"
```

Used by roles that do user-level installs (devtools, base group membership). Defaults to whoever runs the playbook. Overridable with `-e target_user=someuser`.

## Bootstrap Script (`scripts/bootstrap.sh`)

The only thing run manually. Bridges "I have a TTY" to "Ansible is running."

**Flow:**

1. Check running as root
2. `dnf install -y ansible git`
3. Check if a non-root user exists:
   - **No non-root user**: prompt for username, create user, add to `wheel`, set password, create home directory
   - **One non-root user**: use that user
   - **Multiple non-root users**: prompt which one to use
4. Ensure user is in groups: `wheel`, `libvirt`, `mock`
5. Pass any extra CLI arguments through to the playbook
6. Run `ansible-playbook playbooks/site.yml --ask-become-pass` as the target user

```bash
#!/bin/bash
set -euo pipefail
# Usage: sudo ./bootstrap.sh [extra ansible-playbook args]
# Example: sudo ./bootstrap.sh -e enable_nvidia=true -e desktop_environment=gnome
```

## site.yml

Includes all six roles in dependency order:

1. base
2. nvidia (when `enable_nvidia`)
3. desktop
4. devtools
5. multimedia
6. language

## Role 1: Base

**Purpose**: System foundation — repos, updates, system tuning, essential tools, virtualization.

**Tags**: `base`

**Tasks:**

1. **Enable RPM Fusion** — install free + nonfree release packages using `rpm -E %fedora` URL pattern
2. **Configure dnf performance** — write to `/etc/dnf/dnf.conf`: `max_parallel_downloads=10`, `fastestmirror=True`, `defaultyes=True`
3. **Full system update** — `dnf5 update -y`
4. **Install essential CLI tools** — from `base_cli_packages` list
5. **Enable and start firewalld** — install, enable, start
6. **Enable Flathub** — add Flathub remote to Flatpak system-wide
7. **Install virtualization stack** — `@virtualization` DNF group, enable/start `libvirtd`, add `target_user` to `libvirt` group

**Defaults:**

```yaml
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

## Role 2: NVIDIA

**Purpose**: Full Nobara-style NVIDIA setup via RPM Fusion. Gated by `enable_nvidia: false`.

**Tags**: `nvidia`

**Tasks:**

1. **Install NVIDIA driver stack** — `akmod-nvidia`, `xorg-x11-drv-nvidia`, `xorg-x11-drv-nvidia-cuda`, `xorg-x11-drv-nvidia-cuda-libs`
2. **Install NVIDIA VAAPI/VDPAU support** — `nvidia-vaapi-driver`, `libva-utils`, `vdpauinfo` for hardware video decode
3. **Run `dnf groupupdate multimedia`** — RPM Fusion multimedia group with NVIDIA-aware codec builds (with `--with-optional`)
4. **Wait for akmod build** — `akmods --force`, wait for kernel module compilation
5. **Rebuild initramfs** — `dracut --force` to include nvidia modules
6. **Blacklist nouveau** — verify RPM Fusion's blacklist is in place, add if not
7. **Enable NVIDIA modesetting** — add `nvidia-drm.modeset=1` to kernel args for Wayland support

**Defaults:**

```yaml
enable_nvidia: false

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

## Role 3: Desktop

**Purpose**: Install full desktop environment based on user choice.

**Tags**: `desktop`

**Tasks:**

1. **Install desktop environment**:
   - `kde` → `@kde-desktop-environment` DNF group
   - `gnome` → `@workstation-product-environment` DNF group
   - Fail with clear error if value is not `kde` or `gnome`
2. **Set default target to graphical** — `systemctl set-default graphical.target`
3. **Enable display manager** — `sddm` for KDE, `gdm` for GNOME

**Defaults:**

```yaml
desktop_environment: kde
```

## Role 4: Devtools

**Purpose**: Complete developer environment — C/C++, packaging tools, language version managers.

**Tags**: `devtools`

**Tasks:**

1. **Install C/C++ development stack** — `@c-development` and `@development-tools` DNF groups (gcc, g++, make, gdb, strace, ltrace, valgrind, autoconf, automake, cmake, etc.)
2. **Install additional dev libraries** — `kernel-devel`, `kernel-headers`, `glibc-devel`, `libstdc++-devel`
3. **Install packaging/build tools** — `mock`, `rpm-build`, `rpmdevtools`, `fedora-packager`, `fedpkg`
4. **Add user to `mock` group** — `target_user` added to mock group for unprivileged builds
5. **Install Rust via rustup** — download and run `rustup-init` as `target_user`. User-level install to `~/.rustup`. Provides `rustup update` for self-management.
6. **Install nvm** — official install script as `target_user`. User-level install to `~/.nvm`.
7. **Install gvm** — official install script as `target_user`. User-level install to `~/.gvm`.

**Defaults:**

```yaml
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
```

## Role 5: Multimedia

**Purpose**: Full audio/video codec support.

**Tags**: `multimedia`

**Tasks:**

1. **Install GStreamer codec plugins** — the full set from `multimedia_gstreamer_packages`
2. **Install FFmpeg** — `ffmpeg` and `ffmpeg-libs` from RPM Fusion
3. **Run `dnf groupupdate multimedia sound-and-video`** — RPM Fusion's recommended multimedia stack as a tested group

**Defaults:**

```yaml
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

## Role 6: Language

**Purpose**: Locale configuration, fonts, and optional input method support.

**Tags**: `language`

**Tasks:**

1. **Configure system locale** — set `LANG` via `localectl` from `language_locale` variable
2. **Install language packs** — `glibc-langpack-en` + any extras from `language_extra_langpacks`
3. **Install fonts** — comprehensive coverage for Latin, CJK, emoji, monospace, and Ubuntu family from `language_fonts` list
4. **Install fontconfig tweaks** — subpixel rendering, hinting defaults
5. **Install input methods** (optional) — `ibus` or `fcitx5`, gated by `language_install_input_methods`

**Defaults:**

```yaml
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

## Role Execution Order

```
base → nvidia (optional) → desktop → devtools → multimedia → language
```

**Why this order:**
- Base must come first (repos, updates, system config)
- NVIDIA before desktop (driver must be present before the display manager starts)
- Desktop before devtools (some dev tools may have GUI components)
- Multimedia and language are independent but run last as they're cosmetic

## Conventions (from CLAUDE.md)

- All tasks have a `name:` field
- Use `ansible.builtin.dnf5` module
- Every task tagged with its role name
- Shell tasks use `set -euo pipefail`
- Package lists in `defaults/main.yml` for user overrides

## Usage Examples

```bash
# Bootstrap on fresh install (creates user if needed)
sudo ./scripts/bootstrap.sh

# Full developer workstation (no NVIDIA)
sudo ./scripts/bootstrap.sh -e desktop_environment=gnome

# Developer + NVIDIA workstation
sudo ./scripts/bootstrap.sh -e enable_nvidia=true

# Developer + NVIDIA + GNOME
sudo ./scripts/bootstrap.sh -e enable_nvidia=true -e desktop_environment=gnome

# Run specific roles after initial setup
ansible-playbook playbooks/site.yml --tags devtools
ansible-playbook playbooks/site.yml --tags multimedia,language

# Dry run
ansible-playbook playbooks/site.yml --check --diff
```
