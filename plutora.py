import requests
import os

TFC_TOKEN = os.getenv("TFC_TOKENy8BjAZiSmKS35w.atlasv1.usrIzlPt3tnsqCIlpyIqLapWruITQz9IKkfcai9kpaHqCF2zlZ88OtoMFwdR5RqBfgI")
WORKSPACE_ID = os.getenv("ws-ic393RE3DKdrXpsx")

def trigger_run():
    url = "https://app.terraform.io/api/v2/runs"
    headers = {
        "Authorization": f"Bearer {TFC_TOKEN}",
        "Content-Type": "application/vnd.api+json"
    }
    payload = {
        "data": {
            "attributes": {
                "is-destroy": False,
                "message": "Provision banking app environment"
            },
            "type": "runs",
            "relationships": {
                "workspace": {
                    "data": {
                        "type": "workspaces",
                        "id": WORKSPACE_ID
                    }
                }
            }
        }
    }
    response = requests.post(url, json=payload, headers=headers)
    return response.json()