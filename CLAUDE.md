# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Ansible-pull infrastructure for a VPS fleet. There is no central control node — each managed box clones this repo and runs `local.yml` against itself every 15 minutes via a systemd timer. Committing and pushing is the deployment mechanism.

## How the playbook runs

`ansible-pull` targets `localhost` with `connection: local`. Because of this, Ansible's normal host_vars auto-loading (which keys on `inventory_hostname`) does not work. `local.yml` manually loads the matching file from `host_vars/` using the box's real `ansible_fqdn` or `ansible_hostname` in a `pre_tasks` block. When adding a new host, create `host_vars/<fqdn>.yml` following the pattern in `host_vars/us.henchoz.net.yml`.

Two systemd timers drive the pull loop (both managed by the baseline role from `roles/baseline/files/`):

- **`ansible-pull.timer`** — fires every 15 min, invokes `ansible-pull -o` (change-detect). If the repo's HEAD didn't move, the run exits in a couple of seconds without applying anything.
- **`ansible-pull-full.timer`** — fires once a day (with up to 2h jitter), invokes `ansible-pull` without `-o`. This is the drift-correction run that re-converges anything that was changed locally.

A `Conflicts=ansible-pull-full.service` on the frequent service keeps the two from racing.

## Key variables (roles/baseline/defaults/main.yml)

- `baseline_packages` — installed on every host via cross-distro `package:` module
- `managed_user` — the user provisioned on every box (currently `claude`)
- `managed_user_authorized_keys` — list of public SSH keys; `exclusive: true` on the last iteration means keys removed from this list are revoked on the next tick
- `host_extra_packages` — empty by default; overridden per host in `host_vars/`

## SSH hardening approach

The role drops `/etc/ssh/sshd_config.d/99-baseline.conf` (wins via lexicographic order) rather than editing the distro's `sshd_config` directly. It also ensures the `Include` directive exists for older distros that don't have it. The `sshd` handler name differs by OS family: `ssh` on Debian, `sshd` everywhere else.

## Bootstrapping a new host

```bash
curl -fsSL https://raw.githubusercontent.com/claudehenchoz/infra/main/bootstrap/bootstrap.sh \
  | sudo REPO_URL=https://github.com/claudehenchoz/infra.git bash
```

The script detects the distro (apt / dnf / apk / pacman / zypper), installs Ansible + git, installs collections from `requirements.yml`, runs the playbook once synchronously, then enables the systemd timer.

## Watching live runs on a managed box

```bash
systemctl list-timers ansible-pull.timer ansible-pull-full.timer
journalctl -u ansible-pull.service -n 50         # 15-min change-detect runs
journalctl -u ansible-pull-full.service -n 50    # daily full runs
```

## Testing changes manually on a managed box

```bash
ansible-pull -U https://github.com/claudehenchoz/infra.git -C main -i localhost, local.yml
```

## Required Ansible collections

`ansible.posix` (>=1.5.0) and `community.general` (>=8.0.0), declared in `requirements.yml`. The systemd service refreshes these on every run via `ExecStartPre`.

## Gotchas

- **Key revocation**: delete the key from `managed_user_authorized_keys` in `defaults/main.yml` and push. Convergence happens within 15 minutes.
- **hostname matching**: the play matches `ansible_fqdn` first. Verify with `ansible localhost -m setup -a 'filter=ansible_fqdn'` if host_vars aren't loading.
- **Lock-out risk**: SSH password auth is disabled by the role. Confirm `claude`'s public key is in `defaults/main.yml` and you have the private key before bootstrapping.
