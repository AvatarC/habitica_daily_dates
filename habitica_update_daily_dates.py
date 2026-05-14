"""
Habitica Daily Date Updater

Fetches all dailies, then adds or updates a [Ddd YYYY-MM-DD] date stamp in each
title with the task's next due date (from Habitica's nextDue field).

Setup:
  Set HABITICA_USER_ID and HABITICA_API_TOKEN as environment variables,
  or fill in the constants below.

  Your credentials are at: https://habitica.com/user/settings/api

Usage:
  python habitica_update_daily_dates.py           # live run
  python habitica_update_daily_dates.py --dry-run # preview only
"""

import os
import re
import sys
import requests
from datetime import datetime, timezone

BASE_URL = "https://habitica.com/api/v3"

USER_ID  = os.getenv("HABITICA_USER_ID",  "")
API_TOKEN = os.getenv("HABITICA_API_TOKEN", "")

# group(1) = optional "Ddd " prefix, group(2) = YYYY-MM-DD
DATE_RE = re.compile(r"\s*\[(\w{3} )?(\d{4}-\d{2}-\d{2})\]")


def headers():
    if not USER_ID or not API_TOKEN:
        sys.exit(
            "Error: set HABITICA_USER_ID and HABITICA_API_TOKEN env vars "
            "(or fill in the constants at the top of the script)."
        )
    return {
        "x-api-user": USER_ID,
        "x-api-key": API_TOKEN,
        "x-client": "habitica-date-updater",
        "Content-Type": "application/json",
    }


def get_dailies():
    r = requests.get(f"{BASE_URL}/tasks/user", params={"type": "dailys"}, headers=headers())
    r.raise_for_status()
    return r.json()["data"]


def is_every_day(task) -> bool:
    freq = task.get("frequency", "")
    if freq == "daily" and task.get("everyX", 1) == 1:
        return True
    if freq == "weekly":
        repeat = task.get("repeat", {})
        return all(repeat.get(d, False) for d in ("su", "m", "t", "w", "th", "f", "s"))
    return False


def next_due_date(task) -> str | None:
    """Return the first nextDue date as 'Ddd YYYY-MM-DD', or None."""
    slots = task.get("nextDue") or []
    if not slots:
        return None
    raw = slots[0]  # e.g. "2026-05-11T05:00:00.000Z"
    try:
        dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        dt = dt.astimezone(timezone.utc)
    except ValueError:
        dt = datetime.strptime(raw[:10], "%Y-%m-%d")
    return dt.strftime("%a %Y-%m-%d")  # e.g. "Tue 2026-05-12"


def update_task_title(task_id: str, new_title: str):
    r = requests.put(f"{BASE_URL}/tasks/{task_id}", headers=headers(), json={"text": new_title})
    r.raise_for_status()


def main(dry_run: bool):
    dailies = get_dailies()
    print(f"Found {len(dailies)} dailies.{' (dry run — no changes will be saved)' if dry_run else ''}\n")

    # DAILY is the longest action label (5 chars), UPDATE is 6
    W = len("UPDATE")

    changed = skipped = 0
    for task in dailies:
        title    = task["text"]
        task_id  = task["id"]
        due_date = next_due_date(task)

        if is_every_day(task):
            print(f"  {'DAILY':<{W}}  {title}")
            skipped += 1
            continue

        if due_date is None:
            print(f"  {'SKIP':<{W}}  {title}  (no nextDue)")
            skipped += 1
            continue

        existing = DATE_RE.search(title)
        if existing:
            has_dow   = existing.group(1) is not None
            same_date = existing.group(2) == due_date[-10:]
            if has_dow and same_date:
                print(f"  {'OK':<{W}}  {title}")
                continue
            new_title = DATE_RE.sub("", title).rstrip() + f" [{due_date}]"
            action = "UPDATE"
        else:
            new_title = title.rstrip() + f" [{due_date}]"
            action = "ADD"

        print(f"  {action:<{W}}  {title}  →  {new_title}")
        changed += 1
        if not dry_run:
            update_task_title(task_id, new_title)

    print(f"\nDone. {changed} updated, {skipped} skipped.")


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    main(dry_run)
