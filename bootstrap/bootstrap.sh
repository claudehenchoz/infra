#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
#  bootstrap.sh — run this ONCE on a fresh VPS.
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/YOU/infra/main/bootstrap/bootstrap.sh | sudo bash
#
#  After this script finishes, the box will pull and apply this repo
#  every 15 minutes via systemd timer. You don't need to log back in.
# ────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/claudehenchoz/infra}"
REPO_BRANCH="${REPO_BRANCH:-main}"

# Defensive: strip any accidental trailing `.git` so the same URL works
# for both `git clone` (which accepts either form) and the systemd unit's
# raw-file curl (which needs the bare form).
REPO_URL="${REPO_URL%.git}"

# ---- Detect distro & install ansible + git -------------------------
if   command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ansible git
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ansible-core git
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache ansible git
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm ansible git
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install ansible git
else
    echo "ERROR: no supported package manager found" >&2
    exit 1
fi

# ---- Install required Ansible collections --------------------------
# We fetch requirements.yml directly so we don't need a local clone yet.
mkdir -p /tmp/ap-bootstrap
curl -fsSL "${REPO_URL}/raw/${REPO_BRANCH}/requirements.yml" \
    -o /tmp/ap-bootstrap/requirements.yml
ansible-galaxy collection install -r /tmp/ap-bootstrap/requirements.yml

# ---- Env file the systemd units read for ${REPO_URL}/${REPO_BRANCH} -
# Has to exist BEFORE the first ansible-pull, because the playbook
# itself drops the systemd units into place and they reference this.
cat >/etc/default/ansible-pull <<EOF
REPO_URL=${REPO_URL}
REPO_BRANCH=${REPO_BRANCH}
EOF

# ---- First run, synchronously, so we know it works -----------------
# The baseline role installs both systemd units (15-min change-detect
# + daily full) and enables their timers. After this returns, the box
# is fully self-managing — no further steps here.
ansible-pull -U "$REPO_URL" -C "$REPO_BRANCH" -i localhost, local.yml

echo "✔ Bootstrap done. Timers installed and enabled by the playbook."
echo "  Inspect: systemctl list-timers ansible-pull.timer ansible-pull-full.timer"
