"""Extra HTTP checks for ledger memberships, receipts, and tracked recovery cases."""
import json
import os
from pathlib import Path
import secrets
from urllib.parse import urlsplit

import httpx


class User:
    def __init__(self, client, alias):
        self.client = client
        self.alias = alias
        self.login = {"email": f"{alias}-{secrets.token_hex(8)}@qa.example.com",
                      "password": secrets.token_urlsafe(24)}
        self.web = self.session("web", register=True)
        self.app = self.session("app")

    def session(self, kind, register=False):
        action = "register" if register else "login"
        response = self.client.post("/api/v1/auth/" + action, json={
            **self.login, "client_type": kind, "device_name": f"QA {self.alias} {kind}",
        })
        response.raise_for_status()
        return response.json()

    def request(self, method, path, *, session=None, body=None, status=200):
        auth = session or self.web
        response = self.client.request(method, "/api/v1" + path, json=body, headers={
            "Authorization": "Bearer " + auth["access_token"], "X-Device-ID": auth["device_id"],
        })
        if response.status_code != status:
            raise AssertionError(f"{self.alias}: {method} {path.split('?')[0]}: "
                                 f"expected HTTP {status}, got {response.status_code}")
        return response.json()

    def ledger(self, name):
        return self.request("POST", "/write/ledgers", body={"ledger_name": name, "currency": "CNY"})["entity_id"]

    def push(self, event, session=None):
        login = session or self.app
        result = self.request("POST", "/sync/push", session=login, body={
            "device_id": login["device_id"], "changes": [event], "return_results": True,
        })
        return result["results"][0]


def check(name, actual, expected):
    if actual != expected:
        raise AssertionError(f"{name}: expected {expected!r}, got {actual!r}")


def shared(client):
    owner, editor = User(client, "owner"), User(client, "member")
    family = owner.ledger("家庭共享")
    private = editor.ledger("成员私人账")
    def dictionary(user, ledger):
        base = f"/write/ledgers/{ledger}"
        root = user.request("POST", base + "/categories", body={
            "base_change_id": 0, "name": "餐饮", "kind": "expense", "level": 1})["entity_id"]
        child = user.request("POST", base + "/categories", body={
            "base_change_id": 0, "name": "早餐", "kind": "expense", "level": 2,
            "parent_name": "餐饮", "parent_sync_id": root})["entity_id"]
        tag = user.request("POST", base + "/tags", body={"base_change_id": 0, "name": "出差"})["entity_id"]
        return root, child, tag
    own, personal = dictionary(owner, family), dictionary(editor, private)
    check("independent dictionary IDs", set(own).isdisjoint(personal), True)
    invitation = owner.request("POST", f"/ledgers/{family}/invites",
                               body={"role": "editor"}, status=201)
    accepted = editor.request("POST", f"/invites/{invitation['code']}/accept")
    check("accepted role", accepted["role"], "editor")
    check("visible ledgers", {x["ledger_id"] for x in editor.request("GET", "/sync/ledgers")},
          {family, private})
    resources = editor.request("GET", f"/ledgers/{family}/shared-resources")
    check("dictionary owner", resources["owner_user_id"], owner.web["user"]["id"])
    check("shared parent", {x["sync_id"]: x["parent_sync_id"] for x in resources["categories"]},
          {own[0]: None, own[1]: own[0]})
    check("shared tags", [x["sync_id"] for x in resources["tags"]], [own[2]])
    tx = editor.request("POST", f"/write/ledgers/{family}/transactions", body={
        "base_change_id": 0, "tx_type": "expense", "amount": 28.5, "happened_at": "2026-01-31T16:00:00Z",
        "category_id": own[1], "category_name": "早餐", "category_kind": "expense",
        "tag_ids": [own[2]], "tags": ["出差"], "note": "成员记早餐",
    })["entity_id"]
    for reader in (owner, editor):
        rows = reader.request("GET", f"/read/ledgers/{family}/transactions")
        check(reader.alias + " transaction", [(r["id"], r["category_id"], r["tag_ids"], r["amount"]) for r in rows],
              [(tx, own[1], [own[2]], 28.5)])
    check("no private transaction", editor.request("GET", f"/read/ledgers/{private}/transactions"), [])
    # The shipped invitation schema supports editor only. A viewer acceptance exercise has no public entry point.
    viewer = owner.request("POST", f"/ledgers/{family}/invites", body={"role": "viewer"}, status=422)
    errors = viewer.get("validation", [])
    if not any(error["loc"][-1] == "role" for error in errors):
        raise AssertionError("Viewer invitation rejected for an unexpected reason")
    return {"case": "shared-ledger", "status": "PASS", "roles": ["owner", "editor"],
            "two_independent_dictionaries": True, "member_transaction": {"amount": 28.5, "tags": 1},
            "viewer": {"status": "UNSUPPORTED", "reason": "the public invite API accepts only editor"}}


def transaction(ledger, action, operation, stamp, amount=28.5):
    return {"operation_id": operation, "ledger_id": ledger, "entity_sync_id": "breakfast",
            "entity_type": "transaction", "action": action, "updated_at": stamp,
            "payload": {} if action == "delete" else {
                "type": "expense", "amount": amount, "happenedAt": "2026-02-10T08:00:00Z", "note": "早餐",
            }}


def recovery(client):
    user = User(client, "recover")
    ledger = user.ledger("主账本")
    other = user.ledger("对照账本")
    # Replay the same durable outbox entry after a simulated lost acknowledgement.
    first = transaction(ledger, "upsert", "write", "2026-02-10T08:00:10Z")
    accepted = user.push(first)
    check("initial push", accepted["status"], "accepted")
    other_device = user.session("app")
    check("two App sessions", other_device["device_id"] != user.app["device_id"], True)
    replay = user.push(first)
    check("receipt after retry", replay["change_id"], accepted["change_id"])
    changes = user.request("GET", f"/sync/pull?since=0&device_id={other_device['device_id']}", session=other_device)
    events = [e for e in changes["changes"] if e["entity_sync_id"] == "breakfast"]
    check("one event after retry", [e["change_id"] for e in events], [accepted["change_id"]])
    own = user.request("GET", f"/sync/pull?since=0&device_id={user.app['device_id']}", session=user.app)
    check("external ledger event control", other in {e["ledger_id"] for e in own["changes"]}, True)
    same_device = [e["change_id"] for e in own["changes"] if e["entity_sync_id"] == "breakfast"]
    deleted = user.push(transaction(ledger, "delete", "delete", "2026-02-10T08:00:20Z"))
    check("deletion receipt", deleted["status"], "accepted")
    # The same original operation remains a replay even after its entity is deleted.
    after_delete = user.push(first)
    check("original write cannot revive deletion", after_delete["winner"]["action"], "delete")
    rows = user.request("GET", f"/read/ledgers/{ledger}/transactions")
    check("transaction after exact retry", rows, [])
    # An independent operation that was queued before learning of the delete,
    # bearing a later client clock, is a distinct historical issue.
    late = user.push(transaction(ledger, "upsert", "independent", "2026-02-10T08:00:21Z", 7), other_device)
    late_rows = user.request("GET", f"/read/ledgers/{ledger}/transactions")
    latest = [(r["id"], r["amount"]) for r in late_rows]
    if latest not in ([], [("breakfast", 7)]):
        raise AssertionError(f"unexpected late operation result: {latest}")
    tag = {"operation_id": "tag", "entity_type": "tag", "entity_sync_id": "commute", "action": "upsert",
           "updated_at": "2026-02-10T08:00:22Z", "payload": {"name": "通勤", "syncId": "commute"}}
    tag_event = user.push(tag)
    check("user tag accepted", tag_event["status"], "accepted")
    full = user.request("GET", f"/sync/full?ledger_id={other}", session=other_device)
    snapshot = json.loads(full["snapshot"]["payload"]["content"])
    check("other ledger immediately contains the tag",
          [(t["syncId"], t["name"]) for t in snapshot["tags"]], [("commute", "通勤")])
    if same_device not in ([], [accepted["change_id"]]):
        raise AssertionError(f"unexpected own-device events: {same_device}")
    passed = bool(same_device) and not latest and full["latest_cursor"] >= tag_event["change_id"]
    return {"case": "recovery", "status": "PASS" if passed else "FAIL", "same_operation_retries": 2,
            "second_device_events_after_retry": len(events), "trashed_after_exact_retry": not rows,
            "tracked": [
                {"issue": 124, "status": "PASS" if same_device else "FAIL",
                 "expected_own_events_on_reset": 1, "observed": len(same_device)},
                {"issue": 125, "status": "FAIL" if latest else "PASS",
                 "expected_rows_after_independent_stale_write": 0, "observed": len(latest),
                 "receipt_status": late["status"]},
                {"issue": 127, "status": "PASS" if full["latest_cursor"] >= tag_event["change_id"] else "FAIL",
                 "snapshot_contains_new_tag": True, "expected_min_cursor": tag_event["change_id"],
                 "observed": full["latest_cursor"]}]}


def main():
    url = os.environ["CLOUD_SYNC_QA_URL"]
    dest = Path(os.environ["CLOUD_SYNC_QA_OUTPUT"])
    location = urlsplit(url)
    if location.scheme != "http" or location.hostname != "127.0.0.1" or location.path:
        raise ValueError("Expected a loopback QA origin")
    with httpx.Client(base_url=url, trust_env=False, timeout=30) as client:
        identity = client.get("/__qa__/identity").raise_for_status().json()
        if not identity.get("database_is_isolated") or not identity["run_id"].startswith("beecount-qa-"):
            raise ValueError("Unexpected Cloud identity")
        for filename, scenario in (("shared-ledger", shared), ("recovery", recovery)):
            data = scenario(client)
            (dest / (filename + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
            if data["status"] != "PASS":
                raise AssertionError(f"{filename}: check the per-issue expectations in the JSON result")


if __name__ == "__main__":
    main()
