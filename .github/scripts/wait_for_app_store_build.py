#!/usr/bin/env python3
"""Wait until an uploaded build finishes App Store Connect processing."""

from __future__ import annotations

import argparse
import time
import urllib.parse

from resolve_app_store_version import make_token, request_json


TERMINAL_SUCCESS_STATE = "VALID"
TERMINAL_FAILURE_STATES = {"FAILED", "INVALID"}


def find_app_id(bundle_id: str, token: str) -> str:
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": "1"})
    apps = request_json(f"/v1/apps?{query}", token).get("data", [])
    if not apps:
        raise RuntimeError(f"App Store Connect app '{bundle_id}' was not found")
    return apps[0]["id"]


def find_build(
    app_id: str,
    marketing_version: str,
    build_number: str,
    token: str,
) -> dict | None:
    query = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[version]": build_number,
            "filter[preReleaseVersion.version]": marketing_version,
            "fields[builds]": "version,uploadedDate,processingState",
            "limit": "10",
        }
    )
    builds = request_json(f"/v1/builds?{query}", token).get("data", [])
    return builds[0] if builds else None


def wait_for_build(
    *,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
    key_id: str,
    issuer_id: str,
    key_path: str,
    timeout_seconds: int,
    poll_interval_seconds: int,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    last_status = ""
    app_id: str | None = None

    while time.monotonic() < deadline:
        token = make_token(key_id, issuer_id, key_path)
        if app_id is None:
            app_id = find_app_id(bundle_id, token)

        build = find_build(app_id, marketing_version, build_number, token)
        if build is None:
            status = "not visible yet"
        else:
            attributes = build.get("attributes", {})
            status = attributes.get("processingState") or "unknown"
            if status == TERMINAL_SUCCESS_STATE:
                print(
                    f"App Store Connect build {marketing_version} "
                    f"({build_number}) is VALID."
                )
                return
            if status in TERMINAL_FAILURE_STATES:
                raise RuntimeError(
                    f"App Store Connect build {marketing_version} "
                    f"({build_number}) finished as {status}."
                )

        if status != last_status:
            print(
                f"App Store Connect build {marketing_version} "
                f"({build_number}): {status}."
            )
            last_status = status
        time.sleep(poll_interval_seconds)

    raise TimeoutError(
        f"Timed out waiting for App Store Connect build {marketing_version} "
        f"({build_number}) to become VALID. The upload may still be processing."
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--marketing-version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--key-path", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--poll-interval-seconds", type=int, default=20)
    args = parser.parse_args()

    wait_for_build(
        bundle_id=args.bundle_id,
        marketing_version=args.marketing_version,
        build_number=args.build_number,
        key_id=args.key_id,
        issuer_id=args.issuer_id,
        key_path=args.key_path,
        timeout_seconds=args.timeout_seconds,
        poll_interval_seconds=args.poll_interval_seconds,
    )


if __name__ == "__main__":
    main()
