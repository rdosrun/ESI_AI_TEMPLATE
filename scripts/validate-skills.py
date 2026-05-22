#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


CATALOG_DIR = Path("skills/catalog")
REQUIRED_STRING_FIELDS = [
    "skillId",
    "name",
    "department",
    "taskType",
    "agentType",
    "description",
    "riskLevel",
    "status",
    "version",
]
REQUIRED_LIST_FIELDS = [
    "allowedChannels",
    "allowedDataSources",
    "inputs",
    "outputs",
]
ALLOWED_RISK_LEVELS = {"low", "medium", "high"}
ALLOWED_STATUSES = {"draft", "business_reviewed", "security_reviewed", "approved", "deprecated", "revoked"}
SECRET_PATTERNS = [
    re.compile(r"api[_-]?key", re.IGNORECASE),
    re.compile(r"secret", re.IGNORECASE),
    re.compile(r"password", re.IGNORECASE),
    re.compile(r"token", re.IGNORECASE),
    re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)


def contains_secret(value: object) -> bool:
    text = json.dumps(value, sort_keys=True)
    return any(pattern.search(text) for pattern in SECRET_PATTERNS)


def validate_manifest(path: Path) -> list[str]:
    errors: list[str] = []

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"{path}: invalid JSON: {exc}"]

    for field in REQUIRED_STRING_FIELDS:
        if not isinstance(data.get(field), str) or not data[field].strip():
            errors.append(f"{path}: missing non-empty string field '{field}'")

    for field in REQUIRED_LIST_FIELDS:
        if not isinstance(data.get(field), list) or not data[field]:
            errors.append(f"{path}: missing non-empty list field '{field}'")
        elif not all(isinstance(item, str) and item.strip() for item in data[field]):
            errors.append(f"{path}: list field '{field}' must contain only non-empty strings")

    owners = data.get("owners")
    if not isinstance(owners, dict):
        errors.append(f"{path}: missing owners object")
    else:
        for owner_type in ("business", "technical"):
            if not isinstance(owners.get(owner_type), str) or not owners[owner_type].strip():
                errors.append(f"{path}: missing owners.{owner_type}")

    if data.get("riskLevel") not in ALLOWED_RISK_LEVELS:
        errors.append(f"{path}: riskLevel must be one of {sorted(ALLOWED_RISK_LEVELS)}")

    if data.get("status") not in ALLOWED_STATUSES:
        errors.append(f"{path}: status must be one of {sorted(ALLOWED_STATUSES)}")

    if not isinstance(data.get("requiresHumanApproval"), bool):
        errors.append(f"{path}: requiresHumanApproval must be true or false")

    review = data.get("review")
    if not isinstance(review, dict):
        errors.append(f"{path}: missing review object")
    elif data.get("status") == "approved":
        for field in ("businessApprovedBy", "securityApprovedBy", "approvedAt"):
            if not isinstance(review.get(field), str) or not review[field].strip():
                errors.append(f"{path}: approved skills require review.{field}")

    if contains_secret(data):
        errors.append(f"{path}: manifest appears to contain a secret-like value")

    if data.get("skillId") and path.name != f"{data['skillId']}.skill.json":
        errors.append(f"{path}: filename must match skillId, expected {data['skillId']}.skill.json")

    return errors


def main() -> int:
    if not CATALOG_DIR.exists():
        fail(f"Missing skill catalog directory: {CATALOG_DIR}")
        return 1

    manifest_paths = sorted(CATALOG_DIR.glob("*.skill.json"))
    if not manifest_paths:
        fail(f"No skill manifests found under {CATALOG_DIR}")
        return 1

    all_errors: list[str] = []
    for path in manifest_paths:
        all_errors.extend(validate_manifest(path))

    if all_errors:
        for error in all_errors:
            fail(error)
        return 1

    print(f"Validated {len(manifest_paths)} skill manifest(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
