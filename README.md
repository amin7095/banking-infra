# Banking Infra Starter (AWS + Terraform Cloud)

This repository provisions a **new VPC**, **ALB → AutoScaling app tier (EC2)**, **RDS MySQL**, **DynamoDB** (for test data), and a **WireMock** payment stub service. App instances install **Datadog Agent** (EU site) and **Gremlin Agent** on bootstrap.

It is designed to be driven by **Terraform Cloud** (TFC) via API with the included FastAPI service.

## Quick start

1. Push this repo to GitHub and connect your TFC workspace to `envs/main`.
2. Set TFC variables (mark secrets Sensitive):
   - `aws_region` (e.g., `eu-west-2`)
   - `env_name` (e.g., `dev-123`)
   - `instance_type` (e.g., `t3.medium`)
   - `app_repo` (your app Git URL)
   - `payment_mode` = `wiremock`
   - `db_username` (Sensitive)
   - `db_password` (Sensitive)
   - `dynamodb_table_name` (default `test-data`)
   - `ssh_public_key`
   - `datadog_api_key` (Sensitive)
   - `datadog_site` = `datadoghq.eu`
   - `gremlin_team_id` (Sensitive)
   - `gremlin_secret` (Sensitive)

3. Trigger runs using the `api/app.py` FastAPI service (see below) or from the TFC UI.

## API service (optional)
The `api/app.py` exposes `/provision` and `/destroy` endpoints to trigger TFC runs and return outputs.
Set env vars before running:

```
export TFC_TOKEN=<team_token>
export TFC_ORG=<your_org>
export TFC_WORKSPACE=<your_workspace>
uvicorn app:app --host 0.0.0.0 --port 8000
```

Then:
```
curl -X POST http://localhost:8000/provision -H 'Content-Type: application/json'   -d '{"env_name":"dev-123","payment_mode":"wiremock"}'

curl -X POST http://localhost:8000/destroy -H 'Content-Type: application/json'   -d '{"env_name":"dev-123"}'
```

## Notes
- WireMock is internal-only and reachable from the app tier. Stubs for `authorize` and `refund` are in `envs/main/wiremock_mappings/`.
- RDS is single-AZ MySQL 8 by default; adjust in `modules/rds_mysql/variables.tf`.
- Security groups restrict app port 8080 to ALB; DB port 3306 to app SG.
