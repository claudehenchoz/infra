# infra — desired-state config for the VPS fleet

Every VPS pulls this repo every 15 minutes via `ansible-pull` and
applies `local.yml`. Edit, commit, push — within a tick every box
converges. There is no central server.

## Layout

```
.
├── ansible.cfg              # local-mode defaults
├── inventory                # just localhost
├── local.yml                # entry point ansible-pull runs
├── group_vars/              # (unused for now — single group)
├── host_vars/
│   └── us.henchoz.net.yml   # per-host overrides, matched by FQDN
├── roles/
│   └── baseline/
│       ├── defaults/main.yml   # packages + PUBLIC ssh keys
│       ├── tasks/main.yml      # the actual work
│       └── handlers/main.yml   # reload sshd on config change
├── bootstrap/
│   └── bootstrap.sh         # one-shot: turns a fresh VPS into a managed one
└── systemd/
    ├── ansible-pull.service
    └── ansible-pull.timer
```

## What it does on every host

1. Installs `sudo`, `tmux`, `mc`.
2. Creates user `claude` with the public keys listed in
   `roles/baseline/defaults/main.yml`.
3. Grants `claude` passwordless sudo via `/etc/sudoers.d/10-claude`.
4. Hardens `sshd`: pubkey-only, no passwords, no keyboard-interactive.
5. On `us.henchoz.net` only: also installs `neofetch`.

## Bootstrapping a fresh VPS

```bash
curl -fsSL https://raw.githubusercontent.com/claudehenchoz/infra/main/bootstrap/bootstrap.sh \
  | sudo REPO_URL=https://github.com/claudehenchoz/infra.git bash
```

That installs Ansible + git, runs the playbook once synchronously
(so you'll see any errors immediately), then enables the systemd
timer for ongoing reconciliation.

## Watching the runs

```bash
# On any managed box:
systemctl status ansible-pull.timer
journalctl -u ansible-pull.service -n 50

# When's the next run?
systemctl list-timers ansible-pull.timer
```

For fleet-wide visibility (which `ansible-pull` deliberately doesn't
provide), add a `uri:` task at the end of `tasks/main.yml` that
pings a [healthchecks.io](https://healthchecks.io) URL per host —
you'll get an alert the moment any box stops converging.

## Common gotchas

- **You locked yourself out.** The role disables password auth.
  Make sure `claude`'s public key is in `defaults/main.yml` AND
  that you have the matching private key on your laptop BEFORE
  running the bootstrap. Use the VPS provider's web console to
  recover.
- **The hostname doesn't match `host_vars/`.** The play matches on
  `ansible_fqdn` first, then `ansible_hostname`. Check what your
  box reports: `ansible localhost -m setup -a 'filter=ansible_fqdn'`.
- **`apt` cache is stale on first run.** The playbook refreshes it,
  but only on Debian-family. On other distros, `package:` handles it.
