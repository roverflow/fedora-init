# fedora-init

Ansible-based Fedora workstation bootstrap for a single local machine.

## Quick start

As root (or with sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/roverflow/fedora-init/main/scripts/bootstrap.sh | sudo bash
```

The wizard asks for desktop environment (KDE/GNOME), optional NVIDIA drivers,
os-prober, gaming packages, and Cursor IDE, then clones this repo to
`/opt/fedora-init` and runs the playbook.

## Manual playbook run

From a clone of this repository:

```bash
sudo ansible-playbook playbooks/site.yml \
  -e target_user=YOUR_USER \
  -e desktop_environment=kde \
  -e enable_nvidia=false \
  -e enable_os_prober=false \
  -e enable_gaming=false \
  -e enable_cursor=false
```

Always pass a non-root `target_user`. Inventory defaults live in
`inventory/group_vars/all.yml`. Run roles via `playbooks/site.yml` (role order
matters; meta dependencies are intentionally empty).

### Useful tags

```bash
sudo ansible-playbook playbooks/site.yml -e target_user=YOUR_USER --tags base,multimedia
```

Tagged runs skip unrelated roles. Reboot prompting is handled by `bootstrap.sh`,
not by tagged playbook post-tasks.

## Feature flags

| Variable | Default | Meaning |
|----------|---------|---------|
| `target_user` | `ansible_user_id` | Non-root account to configure |
| `desktop_environment` | `kde` | `kde` or `gnome` |
| `enable_nvidia` | `false` | RPM Fusion akmod NVIDIA stack |
| `enable_os_prober` | `false` | Dual-boot GRUB entries |
| `enable_gaming` | `false` | Steam/Lutris/Wine stack |
| `enable_cursor` | `false` | Install Cursor IDE + `cursorupdater` |
| `firewall_allow_ssh` | `false` | Open SSH in firewalld |
| `firewall_allow_rdp` | `false` | Open RDP in firewalld |
| `firewall_tcp_ports` | `[]` | Extra TCP ports to open |

Firewall stays closed by default. Example:

```bash
-e 'firewall_allow_ssh=true' -e '{"firewall_tcp_ports":[8000,8080]}'
```

## NVIDIA and Secure Boot

When Secure Boot is enabled, the NVIDIA role warns and pauses. Proprietary
akmods need a Machine Owner Key (MOK) enrolled before modules will load.
After install, complete enrollment in the MOK manager on reboot
(`mokutil --import` / vendor docs), then reboot again.

## Cursor

With `enable_cursor=true`, the playbook installs Cursor from the official
download API (Ansible `get_url` + `dnf`) and installs
`/usr/local/bin/cursorupdater` for later manual updates.

## Role layout

1. `base` — RPM Fusion, dnf, firewalld, flatpak, libvirt, optional os-prober  
2. `multimedia` — ffmpeg swap, GStreamer, multimedia group  
3. `nvidia` (optional) — drivers, nouveau blacklist, initramfs, modeset  
4. `desktop` — DE + display manager (+ optional Cursor)  
5. `shell` — zsh + oh-my-zsh  
6. `gaming` (optional)  
7. `devtools` — toolchains + rustup/nvm/gvm/pyenv (zshrc wired)  
8. `language` — locales and fonts  

## License

MIT — see [LICENSE](LICENSE).
