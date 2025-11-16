#!/usr/bin/env bash
set -euxo pipefail

if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y git jq curl
else
  yum -y update || true
  yum -y install git jq curl
fi

APP_DIR=/opt/banking
mkdir -p "$APP_DIR" && cd "$APP_DIR"

APP_REPO="${app_repo}"
PAYMENT_MODE="${payment_mode}"
ENV_NAME="${env_name}"
DD_KEY="${datadog_api_key}"
DD_SITE="${datadog_site}"
GREM_TEAM_ID="${gremlin_team_id}"
GREM_SECRET="${gremlin_secret}"
DB_HOST="${db_host}"
DB_USER="${db_username}"
DB_PASS="${db_password}"

git clone "$APP_REPO" . || (test -d .git && git pull) || true

if [ "$PAYMENT_MODE" = "wiremock" ]; then
  PAYMENT_BASE_URL="http://wiremock.internal:8080"
else
  PAYMENT_BASE_URL="https://real-gateway.example.com"
fi

cat >/etc/banking.env <<EOF
ENV_NAME=$ENV_NAME
PAYMENT_BASE_URL=$PAYMENT_BASE_URL
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF

# TODO: start your app here (systemd unit or script)
# ./bootstrap.sh || true

# Datadog Agent (v7) install, EU site
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$DD_KEY" DD_SITE="$DD_SITE"   bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
systemctl restart datadog-agent || true

# Gremlin Agent install & init
if command -v apt-get >/dev/null; then
  curl -fsSL https://deb.gremlin.com/release/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/gremlin.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/gremlin.gpg] https://deb.gremlin.com/ release non-free" > /etc/apt/sources.list.d/gremlin.list
  apt-get update -y && apt-get install -y gremlin gremlind
else
  rpm --import https://rpm.gremlin.com/release/pubkey.gpg || true
  cat >/etc/yum.repos.d/gremlin.repo <<'YUM'
[gremlin]
name=Gremlin
baseurl=https://rpm.gremlin.com/release/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://rpm.gremlin.com/release/pubkey.gpg
YUM
  yum install -y gremlin gremlind
fi

GREMLIN_TEAM_ID="$GREM_TEAM_ID" GREMLIN_TEAM_SECRET="$GREM_SECRET"   gremlin init --tag env="$ENV_NAME" --tag service=banking-api || true
systemctl enable --now gremlind || true
