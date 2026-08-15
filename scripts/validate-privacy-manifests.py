#!/usr/bin/env python3
"""Validate the privacy-manifest tracking keys Apple enforces at upload time."""

from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path


DOMAIN_PATTERN = re.compile(
    r"^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+"
    r"[A-Za-z]{2,63}$"
)


def privacy_manifests(root: Path) -> list[Path]:
    if root.is_file():
        return [root]
    return sorted(root.rglob("PrivacyInfo.xcprivacy"))


def validate_manifest(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        with path.open("rb") as manifest_file:
            manifest = plistlib.load(manifest_file)
    except Exception as error:  # plistlib reports both XML and binary plist failures.
        return [f"{path}: invalid property list: {error}"]

    if not isinstance(manifest, dict):
        return [f"{path}: root value must be a dictionary"]

    tracking_present = "NSPrivacyTracking" in manifest
    tracking = manifest.get("NSPrivacyTracking", False)
    if tracking_present and not isinstance(tracking, bool):
        errors.append(f"{path}: NSPrivacyTracking must be a Boolean")

    domains_present = "NSPrivacyTrackingDomains" in manifest
    domains = manifest.get("NSPrivacyTrackingDomains")
    if domains_present:
        if not isinstance(domains, list):
            errors.append(f"{path}: NSPrivacyTrackingDomains must be an array")
        elif not domains:
            errors.append(f"{path}: NSPrivacyTrackingDomains must not be an empty array")
        else:
            for domain in domains:
                if not isinstance(domain, str) or not DOMAIN_PATTERN.fullmatch(domain):
                    errors.append(f"{path}: invalid tracking domain {domain!r}")

        if tracking is not True:
            errors.append(
                f"{path}: NSPrivacyTrackingDomains requires NSPrivacyTracking=true"
            )
    elif tracking is True:
        errors.append(
            f"{path}: NSPrivacyTracking=true requires one or more tracking domains"
        )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--app-manifest",
        required=True,
        type=Path,
        help="The app target's root PrivacyInfo.xcprivacy",
    )
    parser.add_argument("roots", nargs="+", type=Path)
    arguments = parser.parse_args()

    app_manifest = arguments.app_manifest.resolve()
    manifests: set[Path] = set()
    for root in arguments.roots:
        manifests.update(path.resolve() for path in privacy_manifests(root))

    if app_manifest not in manifests:
        manifests.add(app_manifest)
    if not app_manifest.is_file():
        raise SystemExit(f"App privacy manifest not found: {app_manifest}")

    errors: list[str] = []
    for manifest in sorted(manifests):
        errors.extend(validate_manifest(manifest))

    with app_manifest.open("rb") as manifest_file:
        app_values = plistlib.load(manifest_file)
    if app_values.get("NSPrivacyTracking") is not False:
        errors.append(
            f"{app_manifest}: the app manifest must declare NSPrivacyTracking=false"
        )
    if "NSPrivacyTrackingDomains" in app_values:
        errors.append(
            f"{app_manifest}: the app manifest must not declare tracking domains"
        )

    if errors:
        raise SystemExit("\n".join(errors))

    print(f"Validated {len(manifests)} privacy manifest(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
