#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
#  bootstrap.sh — run this ONCE on a fresh VPS.
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/claudehenchoz/infra/main/bootstrap/bootstrap.sh | sudo bash
#
#  After this script finishes, the box will pull and apply this repo
#  every 15 minutes via systemd timer. You don't need to log back in.
# ────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/claudehenchoz/infra.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

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
curl -fsSL "${REPO_URL%.git}/raw/${REPO_BRANCH}/requirements.yml" \
    -o /tmp/ap-bootstrap/requirements.yml || \
curl -fsSL "${REPO_URL%.git}/-/raw/${REPO_BRANCH}/requirements.yml" \
    -o /tmp/ap-bootstrap/requirements.yml
ansible-galaxy collection install -r /tmp/ap-bootstrap/requirements.yml

# ---- First run, synchronously, so we know it works -----------------
ansible-pull -U "$REPO_URL" -C "$REPO_BRANCH" -i localhost, local.yml

# ---- Install the systemd timer for repeated runs -------------------
install -m 0644 /tmp/ansible-pull.service /etc/systemd/system/ansible-pull.service 2>/dev/null || \
    curl -fsSL "https://raw.githubusercontent.com/claudehenchoz/infra/${REPO_BRANCH}/systemd/ansible-pull.service" \
        -o /etc/systemd/system/ansible-pull.service

curl -fsSL "https://raw.githubusercontent.com/claudehenchoz/infra/${REPO_BRANCH}/systemd/ansible-pull.timer" \
    -o /etc/systemd/system/ansible-pull.timer

# Pass repo URL/branch to the unit via an env file the unit reads.
cat >/etc/default/ansible-pull <<EOF
REPO_URL=${REPO_URL}
REPO_BRANCH=${REPO_BRANCH}
EOF

systemctl daemon-reload
systemctl enable --now ansible-pull.timer

echo "✔ Bootstrap done. Next run: $(systemctl show -p NextElapseUSecRealtime --value ansible-pull.timer)"
