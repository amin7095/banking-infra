from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os, time, requests

TFC = "https://app.terraform.io/api/v2"
HEADERS = {
    "Authorization": f"Bearer {os.environ.get('TFC_TOKEN','')}
",
    "Content-Type": "application/vnd.api+json"
}
ORG = os.environ.get("TFC_ORG", "")
WS_NAME = os.environ.get("TFC_WORKSPACE", "")

app = FastAPI()

class ProvisionReq(BaseModel):
    env_name: str
    payment_mode: str = "wiremock"
    variables: dict | None = None

class DestroyReq(BaseModel):
    env_name: str


def _check_env():
    if not (HEADERS["Authorization"].strip().startswith("Bearer ") and ORG and WS_NAME):
        raise HTTPException(500, "TFC_TOKEN/TFC_ORG/TFC_WORKSPACE not set")

def get_workspace_id():
    _check_env()
    r = requests.get(f"{TFC}/organizations/{ORG}/workspaces/{WS_NAME}", headers=HEADERS)
    if r.status_code != 200:
        raise HTTPException(500, f"Workspace lookup failed: {r.text}")
    return r.json()["data"]["id"]

def create_run(workspace_id, is_destroy=False, per_run_vars=None, message="Triggered by API"):
    payload = {
        "data": {
            "type": "runs",
            "attributes": {
                "message": message,
                "is-destroy": is_destroy,
                "auto-apply": True
            },
            "relationships": {"workspace": {"data": {"type": "workspaces", "id": workspace_id}}}
        }
    }
    if per_run_vars:
        payload["data"]["attributes"]["variables"] = [{"key": k, "value": str(v)} for k, v in per_run_vars.items()]
    r = requests.post(f"{TFC}/runs", json=payload, headers=HEADERS)
    if r.status_code not in (201, 202):
        raise HTTPException(500, f"Run create failed: {r.text}")
    return r.json()["data"]["id"]

def poll_run(run_id, timeout=3600, interval=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = requests.get(f"{TFC}/runs/{run_id}", headers=HEADERS)
        r.raise_for_status()
        st = r.json()["data"]["attributes"]["status"]
        if st in {"applied","planned_and_finished","policy_soft_failed","errored","canceled","discarded"}:
            return st
        time.sleep(interval)
    raise HTTPException(504, "Run polling timed out")

def fetch_outputs_from_current_state(workspace_id):
    r = requests.get(f"{TFC}/workspaces/{workspace_id}/current-state-version?include=outputs", headers=HEADERS)
    r.raise_for_status()
    included = r.json().get("included", [])
    outs = {}
    for inc in included:
        if inc.get("type") == "state-version-outputs":
            wsout_id = inc["id"]
            r2 = requests.get(f"{TFC}/state-version-outputs/{wsout_id}", headers=HEADERS)
            r2.raise_for_status()
            data = r2.json()["data"]["attributes"]
            outs[data["name"]] = data["value"]
    return outs

@app.post("/provision")
def provision(req: ProvisionReq):
    ws_id = get_workspace_id()
    per_run = (req.variables or {}) | {"env_name": req.env_name, "payment_mode": req.payment_mode}
    run_id = create_run(ws_id, is_destroy=False, per_run_vars=per_run, message=f"Provision {req.env_name} via API")
    status = poll_run(run_id)
    if status not in {"applied","planned_and_finished"}:
        raise HTTPException(500, f"Run ended in state {status}")
    outputs = fetch_outputs_from_current_state(ws_id)
    return {"status": status, "outputs": outputs}

@app.post("/destroy")
def destroy(req: DestroyReq):
    ws_id = get_workspace_id()
    run_id = create_run(ws_id, is_destroy=True, message=f"Destroy {req.env_name} via API")
    status = poll_run(run_id)
    return {"status": status}
