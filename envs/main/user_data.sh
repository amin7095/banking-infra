#!/usr/bin/env bash
set -euxo pipefail

############################################
# 0) Base packages (apt or yum)
############################################
if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y git jq curl python3 python3-venv
else
  yum -y update || true
  yum -y install git jq curl python3 || true
fi

############################################
# 1) Templated values from Terraform
#    (ONLY these names are used by templatefile)
############################################
APP_REPO="${app_repo}"
PAYMENT_MODE="${payment_mode}"
ENV_NAME="${env_name}"

# Datadog
DD_API_KEY="${datadog_api_key}"
DD_SITE="${datadog_site}"

# Gremlin
GREM_TEAM_ID="${gremlin_team_id}"
GREM_SECRET="${gremlin_secret}"

# Database
DB_HOST="${db_host}"
DB_USER="${db_username}"
DB_PASS="${db_password}"

############################################
# 2) App bootstrap and config
############################################
APP_DIR=/opt/banking
mkdir -p "$APP_DIR" && cd "$APP_DIR"

# Pull app sources (idempotent)
git clone "$APP_REPO" . || (test -d .git && git pull) || true

# Payment gateway base URL
if [ "$PAYMENT_MODE" = "wiremock" ]; then
  PAYMENT_BASE_URL="http://wiremock.internal:8080"
else
  PAYMENT_BASE_URL="https://real-gateway.example.com"
fi

# Persist runtime config (adapt if your app uses .env files)
cat >/etc/banking.env <<EOF
ENV_NAME=$ENV_NAME
PAYMENT_BASE_URL=$PAYMENT_BASE_URL
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF

############################################
# 3) Start the banking app on 0.0.0.0:8080
#    (Python example; Java example commented)
############################################
# If your repo has app.py, start it. Otherwise, replace with your real start command.
if command -v python3 >/dev/null && [ -f "app.py" ]; then
  # Optional venv:
  # python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
  nohup python3 app.py --host 0.0.0.0 --port 8080 > /var/log/banking.log 2>&1 &
fi

# Java example (uncomment if you ship a JAR):
# if [ -f "banking-app.jar" ]; then
#   nohup java -jar banking-app.jar --server.port=8080 --server.address=0.0.0.0 \
#     > /var/log/banking.log 2>&1 &
# fi

############################################
# 4) Datadog Agent v7 (EU site, remote updates)
############################################
# Tag host with env; allow remote config updates
DD_API_KEY="$DD_API_KEY" \
DD_SITE="$DD_SITE" \
DD_REMOTE_UPDATES=true \
DD_ENV="$ENV_NAME" \
bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

# Make sure service comes up
systemctl restart datadog-agent || true

############################################
# 5) Gremlin Agent (VM install)
############################################
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

GREMLIN_TEAM_ID="$GREM_TEAM_ID" \
GREMLIN_TEAM_SECRET="$GREM_SECRET" \
gremlin init --tag env="$ENV_NAME" --tag service=banking-api || true

systemctl enable --now gremlind || true

############################################
# 6) SSM Session Manager (ensure agent is enabled)
############################################
# On Amazon Linux 2023 the agent is preinstalled, but be explicit:
systemctl enable --now amazon-ssm-agent || true

############################################
# 7) Handy markers for quick troubleshooting
############################################
echo "User data completed for ${ENV_NAME}."
echo "App log: /var/log/banking.log"
command -v datadog-agent >/dev/null && sudo datadog-agent status || true
systemctl status gremlind --no-pager || true