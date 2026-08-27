#!/usr/bin/env python3
"""
Lakebase Branch Provisioning Script
Creates and configures Lakebase Postgres branches with scale-to-zero.

Usage:
    python scripts/provision_branches.py

Requires: DATABRICKS_HOST and DATABRICKS_TOKEN environment variables
"""

import os
import sys
import json
import time
import requests

HOST = os.environ.get("DATABRICKS_HOST", "https://fe-sandbox-sds-serverless-sandbox-ts.cloud.databricks.com")
TOKEN = os.environ.get("DATABRICKS_TOKEN")
PROJECT = "meridian-retention"

HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
BASE = f"{HOST}/api/2.0/postgres"

def create_branch(branch_id: str, parent: str = "production", no_expiry: bool = True):
    """Create a Lakebase branch off the specified parent."""
    payload = {
        "spec": {
            "parent_branch": f"projects/{PROJECT}/branches/{parent}",
            "no_expiry": no_expiry
        }
    }
    resp = requests.post(
        f"{BASE}/projects/{PROJECT}/branches?branch_id={branch_id}",
        headers=HEADERS, json=payload
    )
    print(f"Create branch '{branch_id}': {resp.status_code}")
    if resp.status_code == 200:
        # Wait for ready
        for _ in range(30):
            r = requests.get(f"{BASE}/projects/{PROJECT}/branches/{branch_id}", headers=HEADERS)
            if r.json().get("status", {}).get("current_state") == "READY":
                print(f"  ✓ Branch '{branch_id}' is READY")
                return r.json()
            time.sleep(2)
    return resp.json()

def configure_scale_to_zero(branch_id: str, suspend_timeout_seconds: int = 300):
    """Configure scale-to-zero on a branch endpoint (suspend after N seconds idle)."""
    # Get the endpoint
    resp = requests.get(
        f"{BASE}/projects/{PROJECT}/branches/{branch_id}/endpoints",
        headers=HEADERS
    )
    endpoints = resp.json().get("endpoints", [])
    if not endpoints:
        print(f"  ✗ No endpoints found for branch '{branch_id}'")
        return None
    
    endpoint_id = endpoints[0]["endpoint_id"]
    endpoint_name = endpoints[0]["name"]
    
    # PATCH endpoint with scale-to-zero timeout
    patch_payload = {
        "status": {
            "suspend_timeout_duration": f"{suspend_timeout_seconds}s",
            "autoscaling_limit_min_cu": 0.25,
            "autoscaling_limit_max_cu": 0.25
        }
    }
    resp = requests.patch(
        f"{BASE}/{endpoint_name}",
        headers=HEADERS, json=patch_payload
    )
    print(f"  Configure scale-to-zero ({suspend_timeout_seconds}s) on '{branch_id}': {resp.status_code}")
    return resp.json() if resp.status_code == 200 else resp.text

def delete_branch(branch_id: str):
    """Delete a branch (for throwaway forecasting branches)."""
    resp = requests.delete(
        f"{BASE}/projects/{PROJECT}/branches/{branch_id}",
        headers=HEADERS
    )
    print(f"Delete branch '{branch_id}': {resp.status_code}")
    return resp.status_code in (200, 204)

if __name__ == "__main__":
    if not TOKEN:
        print("ERROR: DATABRICKS_TOKEN not set")
        sys.exit(1)
    
    # Create dev branch with scale-to-zero (5 min idle timeout)
    print("=== Creating dev branch ===")
    create_branch("dev", parent="production")
    configure_scale_to_zero("dev", suspend_timeout_seconds=300)
    
    print("\n=== Branch provisioning complete ===")
    print(f"  dev: scale-to-zero after 300s idle (cost ≈ $0 when unused)")
    print(f"  production: 24h suspend timeout (always-warm for app traffic)")
