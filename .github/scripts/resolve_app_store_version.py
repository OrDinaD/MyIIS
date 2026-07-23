#!/usr/bin/env python3
"""Resolve a TestFlight marketing version from App Store Connect."""

from __future__ import annotations

import argparse
import base64
import json
import re
import subprocess
import time
import urllib.parse
import urllib.request


VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}$")


def base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def read_der_length(data: bytes, offset: int) -> tuple[int, int]:
    length = data[offset]
    offset += 1
    if length < 0x80:
        return length, offset

    byte_count = length & 0x7F
    return int.from_bytes(data[offset : offset + byte_count], "big"), offset + byte_count


def raw_es256_signature(der_signature: bytes) -> bytes:
    offset = 0
    if der_signature[offset] != 0x30:
        raise ValueError("Expected an ASN.1 sequence")
    _, offset = read_der_length(der_signature, offset + 1)

    values: list[int] = []
    for _ in range(2):
        if der_signature[offset] != 0x02:
            raise ValueError("Expected an ASN.1 integer")
        length, offset = read_der_length(der_signature, offset + 1)
        values.append(int.from_bytes(der_signature[offset : offset + length], "big"))
        offset += length

    return b"".join(value.to_bytes(32, "big") for value in values)


def make_token(key_id: str, issuer_id: str, key_path: str) -> str:
    now = int(time.time())
    header = base64url(
        json.dumps(
            {"alg": "ES256", "kid": key_id, "typ": "JWT"},
            separators=(",", ":"),
        ).encode()
    )
    payload = base64url(
        json.dumps(
            {
                "iss": issuer_id,
                "iat": now - 30,
                "exp": now + 15 * 60,
                "aud": "appstoreconnect-v1",
            },
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input,
        check=True,
        capture_output=True,
    )
    return f"{header}.{payload}.{base64url(raw_es256_signature(result.stdout))}"


def request_json(path: str, token: str) -> dict:
    request = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def version_tuple(version: str) -> tuple[int, int, int]:
    components = [int(component) for component in version.split(".")]
    return tuple((components + [0, 0])[:3])


def increment_patch(version: str) -> str:
    major, minor, patch = version_tuple(version)
    return f"{major}.{minor}.{patch + 1}"


def resolve_version(
    project_version: str,
    requested_version: str,
    bundle_id: str,
    key_id: str,
    issuer_id: str,
    key_path: str,
) -> tuple[str, str]:
    if requested_version:
        if not VERSION_PATTERN.fullmatch(requested_version):
            raise ValueError(
                f"release_version '{requested_version}' must look like 1.0 or 1.0.7"
            )
        return requested_version, "workflow input"

    if not VERSION_PATTERN.fullmatch(project_version):
        raise ValueError(
            f"MARKETING_VERSION '{project_version}' must look like 1.0 or 1.0.7"
        )

    token = make_token(key_id, issuer_id, key_path)
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": "1"})
    apps = request_json(f"/v1/apps?{query}", token).get("data", [])
    if not apps:
        raise RuntimeError(f"App Store Connect app '{bundle_id}' was not found")

    versions = request_json(
        f"/v1/apps/{apps[0]['id']}/appStoreVersions?limit=200",
        token,
    ).get("data", [])
    semantic_versions = [
        item
        for item in versions
        if VERSION_PATTERN.fullmatch(item.get("attributes", {}).get("versionString", ""))
    ]
    if not semantic_versions:
        return project_version, "Xcode project (no App Store versions found)"

    latest = max(
        semantic_versions,
        key=lambda item: version_tuple(item["attributes"]["versionString"]),
    )
    latest_version = latest["attributes"]["versionString"]

    if version_tuple(project_version) > version_tuple(latest_version):
        return project_version, "Xcode project"
    return increment_patch(latest_version), f"App Store Connect after {latest_version}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-version", required=True)
    parser.add_argument("--requested-version", default="")
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--key-path", required=True)
    args = parser.parse_args()

    version, source = resolve_version(
        project_version=args.project_version,
        requested_version=args.requested_version,
        bundle_id=args.bundle_id,
        key_id=args.key_id,
        issuer_id=args.issuer_id,
        key_path=args.key_path,
    )
    print(json.dumps({"version": version, "source": source}))


if __name__ == "__main__":
    main()
