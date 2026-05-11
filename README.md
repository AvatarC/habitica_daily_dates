# Habitica Daily Date Updater

Automatically adds or updates a next-due-date stamp in the title of every Habitica daily.

**Before:** `Take vitamins`
**After:** `Take vitamins [Tue 2026-05-13]`

On subsequent runs the date is updated in place. The day-of-week + date format makes it easy to glance at your dailies and know exactly when each one is coming up next.

## Why this exists

Habitica has no built-in due-date notifications. When a daily is due tomorrow, Habitica gives you no advance warning — you only discover it the moment the day rolls over and the task appears as overdue. For anything that needs preparation or a time block, that leaves you with at most one day's notice, often less. Running this script regularly (e.g. as a scheduled task or cron job) stamps each daily's title with its next due date so you can see at a glance what is coming up, plan ahead, and avoid last-minute scrambles.

## Requirements

- Python 3.10+
- [requests](https://pypi.org/project/requests/) (`pip install requests`)

## Setup

1. Get your credentials from [habitica.com/user/settings/api](https://habitica.com/user/settings/api).

2. Copy the appropriate env file and fill in your credentials:

   | Platform   | File               |
   |------------|--------------------|
   | Linux/macOS | `habitica_env.sh` |
   | Windows     | `habitica_env.ps1` |

3. Source the file before running the script (see Usage below).

## Usage

### Linux / macOS

```bash
source ./habitica_env.sh
python habitica_update_daily_dates.py --dry-run   # preview
python habitica_update_daily_dates.py             # apply
```

### Windows (PowerShell)

```powershell
. .\habitica_env.ps1
python habitica_update_daily_dates.py --dry-run   # preview
python habitica_update_daily_dates.py             # apply
```

## How it works

- Fetches all dailies via the Habitica API (`GET /tasks/user?type=dailys`)
- Uses each task's built-in `nextDue` field — no manual recurrence calculation
- Looks for an existing `[Ddd YYYY-MM-DD]` bracket in the title:
  - **Found, same date** — skips (already up to date)
  - **Found, different date** — replaces with the new date
  - **Not found** — appends the date to the title
- Handles the legacy `[YYYY-MM-DD]` format (no day-of-week) so old titles migrate cleanly on first run
- Tasks with no upcoming due date are skipped with a notice

## Security

Keep `habitica_env.sh` / `habitica_env.ps1` out of version control — they contain your API token. Add them to `.gitignore`:

```
habitica_env.sh
habitica_env.ps1
```
