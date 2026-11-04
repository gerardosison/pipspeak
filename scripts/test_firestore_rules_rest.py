#!/usr/bin/env python3
"""Exercise real Firestore rules against a loopback-only demo emulator.

Start an emulator with this repository's firestore.rules before running.
No production project, credentials, external services or third-party Python
packages are used. This supplements firestore-tests/rules.test.js.
"""

import base64
import datetime as dt
import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


PROJECT = "demo-pipspeak"
HOST = os.environ.get("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8088")
parsed = urllib.parse.urlparse("http://" + HOST)
if parsed.hostname not in ("127.0.0.1", "localhost", "::1") or not parsed.port:
    raise SystemExit("Only a loopback Firestore emulator is permitted.")
BASE = "http://" + HOST
PREFIX = f"projects/{PROJECT}/databases/(default)/documents"
ROOT = BASE + "/v1/" + PREFIX
SUFFIX = uuid.uuid4().hex[:10]
ALICE, BOB = "alice-" + SUFFIX, "bob-" + SUFFIX
checks = 0


def token(uid):
    def encode(value):
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    now = int(time.time())
    return ".".join((encode({"alg": "none", "typ": "JWT"}), encode({
        "iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT,
        "sub": uid, "user_id": uid, "iat": now, "exp": now + 3600,
        "firebase": {"sign_in_provider": "password"},
    }), ""))


def request(method, url, data=None, uid=None, admin=False):
    headers = {"Content-Type": "application/json"}
    if uid or admin:
        headers["Authorization"] = "Bearer " + ("owner" if admin else token(uid))
    raw = None if data is None else json.dumps(data).encode()
    # Loopback emulator traffic does not use a public Internet proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(urllib.request.Request(url, raw, headers, method=method), timeout=20) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


def fields(data):
    result = {}
    for key, value in data.items():
        if isinstance(value, bool):
            result[key] = {"booleanValue": value}
        elif isinstance(value, int):
            result[key] = {"integerValue": str(value)}
        elif isinstance(value, float):
            result[key] = {"doubleValue": "NaN" if math.isnan(value) else value}
        elif isinstance(value, dict):
            result[key] = value  # An explicit REST value, e.g. timestampValue.
        else:
            result[key] = {"stringValue": value}
    return result


def write(path, data, uid=None, admin=False, server_time=False):
    update = {"update": {"name": PREFIX + "/" + path, "fields": fields(data)}}
    if server_time:
        update["updateTransforms"] = [{"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"}]
    return request("POST", ROOT + ":commit", {"writes": [update]}, uid, admin)


def get(path, uid=None):
    return request("GET", ROOT + "/" + path, uid=uid)


def check(label, result, expected=200):
    global checks
    status, body = result
    if status != expected:
        raise AssertionError(f"{label}: expected HTTP {expected}, got {status}: {body[:800]}")
    checks += 1
    print("PASS:", label)


def main():
    profile = dict(fullName="Alice Santos", nickname="Alice", username="alice",
                   language="English (US)", practicePurpose="Debate", school="",
                   onboardingComplete=True, revision="r1")
    path = "users/" + ALICE
    check("owner profile write", write(path, profile, ALICE, server_time=True))
    check("owner profile read", get(path, ALICE))
    check("other account profile read denied", get(path, BOB), 403)
    check("anonymous profile read denied", get(path), 403)
    check("other account profile write denied", write(path, profile, BOB, server_time=True), 403)
    check("extra profile field denied", write(path, {**profile, "admin": True}, ALICE, server_time=True), 403)
    check("invalid profile type denied", write(path, {**profile, "fullName": 5}, ALICE, server_time=True), 403)
    check("client profile timestamp denied", write(path, {**profile, "updatedAt": {
        "timestampValue": "2026-01-01T00:00:00Z"}}, ALICE), 403)

    timestamp = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=100)).isoformat().replace("+00:00", "Z")
    session = dict(userId=ALICE, completedAt={"timestampValue": timestamp},
                   practicePurpose="presentation", language="en-US", durationSeconds=60,
                   starsEarned=1, baselineSessionId="base", scoringVersion="v1",
                   isTest=False, overallScore=72.5, wordsPerMinute=140, fillerCount=3)
    session_path = path + "/sessions/s1"
    check("owner session write", write(session_path, session, ALICE))
    check("identical retry accepted", write(session_path, session, ALICE))
    check("owner session read", get(session_path, ALICE))
    check("session mutation denied", write(session_path, {**session, "starsEarned": 3}, ALICE), 403)
    check("other account session read denied", get(session_path, BOB), 403)
    check("anonymous session read denied", get(session_path), 403)
    invalid = path + "/sessions/invalid"
    for label, changes in (
        ("wrong owner", {"userId": BOB}), ("raw transcript", {"transcript": "private speech"}),
        ("excess stars", {"starsEarned": 4}), ("negative duration", {"durationSeconds": -1}),
        ("invalid score", {"overallScore": 101}), ("non-finite metric", {"wordsPerMinute": float("nan")}),
    ):
        check(label + " denied", write(invalid, {**session, **changes}, ALICE), 403)

    reservation = "usernames/test_" + SUFFIX
    check("owner username reservation", write(reservation, {"uid": ALICE}, ALICE))
    check("UID-only reservation publicly readable", get(reservation))
    check("reservation cannot expose email", write("usernames/email_" + SUFFIX,
          {"uid": ALICE, "email": "alice@example.test"}, ALICE), 403)
    check("username hijacking denied", write(reservation, {"uid": BOB}, BOB), 403)
    check("username listing denied", get("usernames"), 403)
    check("non-owner username delete denied", request("DELETE", ROOT + "/" + reservation, uid=BOB), 403)
    legacy = "usernames/old_" + SUFFIX
    check("seed legacy reservation via emulator admin", write(legacy,
          {"uid": ALICE, "email": "alice@example.test"}, admin=True))
    check("legacy email private from anonymous", get(legacy), 403)
    check("legacy email private from other accounts", get(legacy, BOB), 403)
    check("owner can read legacy reservation", get(legacy, ALICE))
    check("owner migrates reservation to UID only", write(legacy, {"uid": ALICE}, ALICE))
    check("migrated reservation publicly readable", get(legacy))
    check("owner username delete", request("DELETE", ROOT + "/" + reservation, uid=ALICE))
    check("owner session delete", request("DELETE", ROOT + "/" + session_path, uid=ALICE))
    check("owner profile delete", request("DELETE", ROOT + "/" + path, uid=ALICE))
    print(f"All {checks} Firestore rule checks passed (demo emulator only).")


if __name__ == "__main__":
    main()
