# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Unga bunga make Fedora go fast. This repo hold scripts and Ansible playbooks that take bare Fedora Everything minimal install and turn into fully configured desktop machine with NVIDIA drivers and gaming tools. No click-click GUI setup — everything automated, reproducible, run once and done.

## Target System

- **Base**: Fedora Everything ISO — minimal install only (no desktop, no extra groups selected during Anaconda). Bare bones. Just a TTY and a network connection.
- **GPU**: NVIDIA (proprietary drivers via RPM Fusion)
- **Goal**: Clean, stable desktop with full gaming stack — like Nobara but without the third-party distro maintenance burden
- **Assumption**: Fresh minimal install with nothing but base system. Playbooks must handle everything from "I have a terminal and `dnf`" to "fully working gaming desktop".

## What Gets Installed

Reference `INFORMATION.md` for the full Nobara-style package list. Key categories:

- **RPM Fusion** (free + nonfree) — the foundation for everything proprietary
- **NVIDIA drivers** — via RPM Fusion NVIDIA howto, not manual .run files
- **Desktop environment** — user's choice (KDE/GNOME), installed from Fedora repos
- **Gaming stack**: steam, lutris, gamemode, mangohud, goverlay, gamescope, wine, winetricks, protontricks
- **Multimedia codecs**: gstreamer1 plugins (bad-free, bad-freeworld, ugly, libav, good, base)
- **Optional extras**: obs-studio, protonup-qt, flatpak setup

## Architecture

Scripts and playbooks should be idempotent — safe to run multiple times without breaking things. Structure:

```
playbooks/           # Ansible playbooks (main entry points)
roles/               # Ansible roles (reusable units of work)
  nvidia/            # NVIDIA driver installation and config
  desktop/           # Desktop environment setup
  gaming/            # Gaming tools and optimizations
  multimedia/        # Codecs and media support
  base/              # System updates, RPM Fusion, core packages
scripts/             # Standalone shell scripts (for when Ansible is overkill)
```

## Key Design Decisions

- **Ansible over pure bash** for the main workflow — roles are composable, idempotent, and self-documenting. Shell scripts only for simple one-off tasks or bootstrapping Ansible itself.
- **RPM Fusion over COPR** — COPR repos from Nobara can cause dependency hell on updates. Stick to official Fedora + RPM Fusion packages unless there's a specific, documented reason.
- **No custom kernels or rebuilt packages** — this is "Fedora with extras", not a fork. Stock Fedora kernel with RPM Fusion drivers.
- **Flatpak for user apps** — system packages for drivers/libs/tools, Flatpak for desktop applications where it makes sense.

## Commands

```bash
# Bootstrap: install Ansible on fresh Fedora minimal
sudo dnf install -y ansible

# Run the full setup
ansible-playbook playbooks/site.yml --ask-become-pass

# Run only specific roles
ansible-playbook playbooks/site.yml --tags nvidia
ansible-playbook playbooks/site.yml --tags gaming
ansible-playbook playbooks/site.yml --tags desktop

# Test playbook syntax without running
ansible-playbook playbooks/site.yml --syntax-check

# Dry run (check mode)
ansible-playbook playbooks/site.yml --check --diff
```

## Conventions

- All Ansible tasks must have a `name:` field — no unnamed tasks
- Use `ansible.builtin.dnf5` module (Fedora 41+ uses dnf5 by default)
- Tag every task with its role name for selective runs
- Shell scripts use `set -euo pipefail` and target bash, not sh
- Variables for package lists go in role `defaults/main.yml` so users can override
