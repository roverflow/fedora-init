# Bootstrap Script Improvement: Internet-Pipeable Interactive Installer

## Overview

Rewrite `scripts/bootstrap.sh` to be a fully self-contained installer that can be downloaded and run from the internet with a one-liner. The script handles all interactive setup (desktop environment, NVIDIA, user account), clones the repo, and runs the Ansible playbook.

**One-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/roverflow/fedora-init/main/scripts/bootstrap.sh -o /tmp/fedora-init.sh && sudo bash /tmp/fedora-init.sh
```

## Script Flow

### 1. Initialization

- `set -euo pipefail` for safety
- Set up a `trap` to clean up `/tmp/fedora-init.sh` on exit (success or failure)
- Check running as root — exit with clear error if not

### 2. Banner

Print a visible header so the user knows what's running:

```
==============================
  Fedora Init - Desktop Setup
==============================
```

### 3. Interactive Prompts

Three questions, asked one at a time:

**Desktop Environment:**
```
Choose your desktop environment:
  1) KDE Plasma
  2) GNOME
Selection [1]:
```
- Default: 1 (KDE) if user presses enter
- Re-prompt on invalid input (anything other than 1 or 2)
- Maps to: `desktop_environment=kde` or `desktop_environment=gnome`

**NVIDIA Drivers:**
```
Install NVIDIA proprietary drivers? [y/N]:
```
- Default: N (no) if user presses enter
- Accepts: y/Y/yes/Yes/YES for true, anything else for false
- Maps to: `enable_nvidia=true` or `enable_nvidia=false`

**User Account:**
- Detect non-root users (UID >= 1000 and < 65534 from `/etc/passwd`)
- **No non-root user found:**
  ```
  No non-root user found. Creating one now.
  Enter username:
  ```
  - Validate: non-empty
  - Create user with `useradd -m -G wheel`
  - Set password with `passwd`
- **One non-root user found:**
  ```
  Found user: username
  ```
  - Use automatically
- **Multiple non-root users found:**
  ```
  Multiple users found:
    1. user1
    2. user2
  Select user (number):
  ```
  - Validate: valid number in range
  - Re-prompt on invalid input

### 4. Summary + Confirmation

Display a summary of all choices and ask for confirmation before proceeding:

```
==============================
  Setup Summary
==============================
  Desktop:  KDE Plasma
  NVIDIA:   Yes
  User:     roverflow
==============================

Proceed with installation? [Y/n]:
```
- Default: Y (yes) if user presses enter
- Exit cleanly if user says no

### 5. Install Dependencies

```bash
dnf install -y ansible git
```
- If `dnf` fails, print "Failed to install dependencies. Check your internet connection." and exit

### 6. Clone Repository

```bash
git clone https://github.com/roverflow/fedora-init.git /opt/fedora-init
```
- **If `/opt/fedora-init` already exists:** run `git -C /opt/fedora-init pull` to update instead of cloning
- If `git clone`/`pull` fails, print "Failed to clone repository. Check your internet connection." and exit

### 7. Ensure User Groups

```bash
usermod -aG wheel "$TARGET_USER"
```

### 8. Run Ansible Playbook

```bash
ansible-playbook /opt/fedora-init/playbooks/site.yml \
    -e "target_user=$TARGET_USER" \
    -e "desktop_environment=$DESKTOP_ENV" \
    -e "enable_nvidia=$ENABLE_NVIDIA"
```
- Exit with Ansible's exit code if it fails
- The repo stays at `/opt/fedora-init` so the user can re-run manually

### 9. Completion Message

```
==============================
  Setup complete!
==============================
A reboot is recommended to apply all changes.
Run: sudo reboot
```

## Error Handling

- **No network**: clear message on `curl`, `git clone`, or `dnf` failure — exit
- **dnf install fails**: print what failed, exit — don't continue without Ansible
- **Ansible playbook fails**: exit with Ansible's exit code. Repo stays at `/opt/fedora-init` for manual re-run
- **Invalid input at prompts**: re-prompt with clear message, don't exit. Give user a chance to correct
- **Trap cleanup**: always remove `/tmp/fedora-init.sh` on exit via `trap`

## What Changes From Current Script

| Aspect | Current | New |
|--------|---------|-----|
| How to run | Must have repo locally first | One-liner from internet |
| Repo location | Assumes repo is present | Clones to `/opt/fedora-init` |
| DE choice | Not asked, must pass `-e` flag | Interactive prompt |
| NVIDIA choice | Not asked, must pass `-e` flag | Interactive prompt |
| Confirmation | None, runs immediately | Summary + "Proceed?" prompt |
| Error handling | `set -euo pipefail` only | Specific error messages + re-prompts |
| Cleanup | None | Trap removes `/tmp/fedora-init.sh` |
| Extra args | Passes `$@` through to ansible | Not needed — all choices are prompted |

## Conventions

- `#!/bin/bash` with `set -euo pipefail`
- Script must be the single file at `scripts/bootstrap.sh`
- Clean, readable output with section headers
- Idempotent: safe to run multiple times (clone or pull, Ansible roles are idempotent)
