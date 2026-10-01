#!/usr/bin/env python3
"""Offline helpers only. Never connects to Gmail or Supabase."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ("investor-intro", "follow-up-1", "follow-up-2")
TOKEN = re.compile(r"{{\s*([a-z_]+)\s*}}")


def read_json(path):
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def email(value):
    if not isinstance(value, str):
        raise ValueError("Email must be text")
    value = value.strip().lower()
    if not re.fullmatch(r"[^\s<>@,;]+@[^\s<>@,;]+\.[^\s<>@,;]+", value):
        raise ValueError("Use one plain email address, without a display name")
    return value


def settings(root=ROOT):
    value = read_json(root / "config/outreach.json")
    for key in ("first_follow_up_days", "second_follow_up_days"):
        if type(value.get(key)) is not int or not 1 <= value[key] <= 365:
            raise ValueError(f"{key} must be an integer from 1 to 365")
    if value.get("time_basis") != "elapsed_24_hour_days" or value.get("max_standard_follow_ups") != 2:
        raise ValueError("Changing time basis or sequence length also requires updating SQL and workflows")
    return value


def profile_errors(profile):
    errors = []
    for key in ("sender_name", "company_name", "company_summary", "fundraising_context", "call_to_action", "signature"):
        if not isinstance(profile.get(key), str) or not profile[key].strip():
            errors.append(f"Fill in {key}")
    try:
        email(profile.get("sender_email"))
    except ValueError:
        errors.append("Fill in sender_email")
    try:
        ZoneInfo(profile.get("timezone") or "invalid")
    except (ValueError, TypeError, ZoneInfoNotFoundError):
        errors.append("Set timezone to an IANA timezone, such as America/New_York")
    if profile.get("templates_approved") is not True:
        errors.append("Review templates and set templates_approved to true")
    return errors


def render(template, data, profile, root=ROOT):
    if template not in TEMPLATES:
        raise ValueError("Unknown template")
    errors = profile_errors(profile)
    if errors:
        raise ValueError("; ".join(errors))
    # Profile fields are authoritative; recipient data cannot replace Maggie's identity.
    if set(data) & set(profile):
        raise ValueError("Recipient data must not override profile fields")
    recipient = email(data.get("recipient_email"))
    raw = (root / "templates" / f"{template}.md").read_bytes()
    source = raw.decode("utf-8").replace("\r\n", "\n")
    header_source, separator, body_source = source.partition("\n\n")
    if not separator or not header_source.startswith("Subject: "):
        raise ValueError("Template needs Subject: followed by a blank line and body")
    values = {**data, **profile}
    required = set(TOKEN.findall(source))
    for key in required:
        if not isinstance(values.get(key), str) or not values[key].strip():
            raise ValueError(f"Missing template value: {key}")
    substitute = lambda text: TOKEN.sub(lambda match: values[match[1]].strip(), text)
    header = substitute(header_source)
    body = substitute(body_source)
    text = header + "\n\n" + body
    if "{{" in text or "}}" in text or re.search(r"\b(?:TODO|TBD|REPLACE_ME)\b", text):
        raise ValueError("Unresolved placeholder in message")
    subject = header[len("Subject: "):].strip()
    if not subject or "\n" in subject or "\r" in subject:
        raise ValueError("Subject must be a single nonempty line")
    if not body.strip():
        raise ValueError("Body is empty")
    try:
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        revision = None
    result = {
        "sender_email": email(profile["sender_email"]),
        "recipient_email": recipient,
        "subject": subject,
        "body_text": body.strip() + "\n",
        "template_path": f"templates/{template}.md",
        "template_sha256": hashlib.sha256(raw).hexdigest(),
        "repo_revision": revision,
    }
    if template != "investor-intro":
        for key in ("gmail_thread_id", "in_reply_to_message_id"):
            if not isinstance(data.get(key), str) or not data[key].strip():
                raise ValueError(f"Missing verified reply field: {key}")
            result[key] = data[key]
        cadence = settings(root)
        result.update({key: cadence[key] for key in ("first_follow_up_days", "second_follow_up_days")})
    return result


def sql_literal(value):
    if "\x00" in value:
        raise ValueError("NUL is not valid SQL text")
    return "'" + value.replace("'", "''") + "'"


def due_sql(as_of, root=ROOT):
    parsed = datetime.fromisoformat(as_of.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("as-of needs a timezone offset")
    cadence = settings(root)
    return (f"select * from margot.due_followups({sql_literal(parsed.isoformat())}::timestamptz, "
            f"{cadence['first_follow_up_days']}, {cadence['second_follow_up_days']});")


def demo_profile():
    return {
        "sender_name": "Maggie", "sender_email": "maggie@example.com",
        "company_name": "Pink Fitness Club",
        "company_summary": "Demo only: Maggie will supply the company description.",
        "fundraising_context": "Demo only: Maggie will supply the fundraising details.",
        "call_to_action": "Would you be open to a conversation?",
        "signature": "Maggie\nPink Fitness Club",
        "timezone": "UTC", "templates_approved": True,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init", help="Create ignored local profile without overwriting it")
    sub.add_parser("doctor", help="Check local setup only; no live connection checks")
    render_parser = sub.add_parser("render")
    render_parser.add_argument("template", choices=TEMPLATES)
    render_parser.add_argument("--data", required=True, type=Path)
    render_parser.add_argument("--demo", action="store_true")
    render_parser.add_argument("--output", type=Path)
    due = sub.add_parser("due-sql", help="Print, never execute, the due-follow-up query")
    due.add_argument("--as-of", required=True)
    args = parser.parse_args()
    try:
        if args.command == "init":
            target = ROOT / "config/local.json"
            if target.exists():
                print("Kept existing config/local.json")
            else:
                with target.open("x", encoding="utf-8") as out:
                    out.write((ROOT / "config/local.example.json").read_text(encoding="utf-8"))
                print("Created config/local.json. Fill it in with Maggie; see docs/SETUP.md.")
        elif args.command == "doctor":
            settings()
            for name in TEMPLATES:
                render(name, read_json(ROOT / "examples" / ("intro.json" if name == "investor-intro" else "follow-up.json")), demo_profile())
            target = ROOT / "config/local.json"
            problems = profile_errors(read_json(target)) if target.exists() else ["Run: python3 scripts/margot.py init"]
            if target.exists():
                project_ref = read_json(target).get("supabase_project_ref")
                if not isinstance(project_ref, str) or not re.fullmatch(r"[a-z0-9]{20}", project_ref):
                    problems.append("Set the Supabase project reference")
            print("PASS: local cadence and all three templates")
            for problem in problems:
                print(f"SETUP: {problem}")
            print("UNVERIFIED: Gmail identity/actions, Supabase access/migration. Check these in Codex using docs/SETUP.md.")
            return 1 if problems else 0
        elif args.command == "render":
            profile = demo_profile() if args.demo else read_json(ROOT / "config/local.json")
            result = render(args.template, read_json(args.data), profile)
            result["demo_only"] = args.demo
            output = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
            if args.output:
                path = args.output.resolve()
                local = (ROOT / ".local").resolve()
                if not path.is_relative_to(local):
                    raise ValueError("Rendered files must be under the ignored .local/ directory")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(output, encoding="utf-8")
                print(f"Saved {path}")
            else:
                print(output, end="")
        elif args.command == "due-sql":
            print(due_sql(args.as_of))
    except (ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
