#!/usr/bin/env python3
"""Google Calendar → JSON for the quickshell calendar.

Syncs every calendar checked in Google Calendar's sidebar of each logged-in
Google account (OAuth, gcal_google.py) — live, with Google's colors, shared
calendars included. Stdlib only.

  gcal-sync.py                  sync (run by services/CalendarService.qml)
  gcal-sync.py client [file]    install the OAuth client JSON (Desktop app;
                                no file → newest one in ~/Downloads)
  gcal-sync.py login [email]    add a Google account (browser)
  gcal-sync.py logout <email>
  gcal-sync.py accounts         logged-in accounts + their calendars (✓ = shown)
  gcal-sync.py emails           logged-in accounts, one per line

Usually driven through `dots calendar` (dots-cli/lib/calendar.sh).

All calendars are synced; which ones the shell SHOWS is its calendar settings
(⚙ in the calendar popup → ~/.local/share/quickshell/calendar-visibility.json,
{ "<calendar id>": true|false }), default = checked in Google's sidebar.

Optional colors, ~/.local/share/quickshell/calendars.json:
  { "google": { "colors": { "<calendar id or name>": "#89b4fa" } } }

Writes ~/.cache/quickshell/calendar-events.json atomically. An account or
calendar that fails keeps its events from the previous run (offline).
"""
import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta

sys.dont_write_bytecode = True  # no __pycache__ in the dots repo
import gcal_google as google  # noqa: E402

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".local/share/quickshell/calendars.json")
OUTPUT = os.path.join(HOME, ".cache/quickshell/calendar-events.json")
VISIBILITY = os.path.join(HOME, ".local/share/quickshell/calendar-visibility.json")
PAST_DAYS = 42
FUTURE_DAYS = 180

JOIN_RE = re.compile(
    r"https://(?:meet\.google\.com/[a-z0-9-]+"
    r"|[\w.-]*zoom\.us/(?:j|my)/[^\s<>\"']+"
    r"|teams\.microsoft\.com/l/meetup-join/[^\s<>\"']+"
    r"|teams\.live\.com/meet/[^\s<>\"']+"
    r"|meet\.jit\.si/[^\s<>\"']+)")


def to_ms(value):
    if type(value) is date:  # all-day: local midnight (mktime applies local DST)
        return int(time.mktime(value.timetuple()) * 1000)
    return int(value.timestamp() * 1000)


def local_midnight(d):
    """RFC 3339 local midnight of `d`, with that day's UTC offset."""
    return datetime(d.year, d.month, d.day).astimezone().isoformat()


def api_event(ev, cal_id, account):
    """Calendar API event → output event (see services/CalendarService.qml)."""
    s, e = ev["start"], ev["end"]
    all_day = "date" in s
    if all_day:
        start, end = date.fromisoformat(s["date"]), date.fromisoformat(e["date"])
    else:
        start, end = datetime.fromisoformat(s["dateTime"]), datetime.fromisoformat(e["dateTime"])
    link = ev.get("htmlLink", "")
    if link and account:  # open it in the right account when several are logged in
        link += "&authuser=" + urllib.parse.quote(account)
    join = google.join_url(ev)
    if not join:
        m = JOIN_RE.search(ev.get("location", "") + "\n" + ev.get("description", ""))
        join = m.group(0).rstrip(".,)>") if m else ""
    return {
        "id": hashlib.sha1(f"{cal_id}{ev['id']}".encode()).hexdigest()[:12],
        "cal": cal_id,
        "title": ev.get("summary") or "(No title)",
        "location": ev.get("location", "").split("\n")[0],
        "allDay": all_day,
        "start": to_ms(start),
        "end": to_ms(end),
        "url": link,
        "join": join,
    }


def load_options():
    try:
        with open(CONFIG) as f:
            return json.load(f).get("google", {})
    except FileNotFoundError:
        return {}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, ensure_ascii=False)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def fetch_calendar(token, email, c, cal_id, time_min, time_max):
    return [api_event(ev, cal_id, email)
            for ev in google.events(token, c["gid"], time_min, time_max)]


def sync():
    # One sync at a time: quickshell's timer, popup-open refreshes and the
    # sync after `dots calendar login` may overlap → the later one waits
    with google.locked("sync"):
        return _sync()


def _sync():
    now_ms = int(time.time() * 1000)
    tokens = google.load_tokens()
    errors = []
    try:
        options = load_options()
    except Exception as e:
        errors.append(f"calendars.json: {e}")
        options = {}
    try:
        with open(OUTPUT) as f:
            previous = json.load(f)
    except Exception:
        previous = {}

    today = date.today()
    range_start, range_end = today - timedelta(days=PAST_DAYS), today + timedelta(days=FUTURE_DAYS)
    time_min, time_max = local_midnight(range_start), local_midnight(range_end)
    colors = options.get("colors", {})

    # 1. Calendar lists per account (sequential, cheap). A failed account's
    #    calendars are only kept from the previous run AFTER the working
    #    accounts — a calendar shared into both then syncs live.
    jobs, failed, expired, seen = [], [], [], set()
    for email in tokens:
        try:
            token = google.access_token(email, tokens)
            cal_list = google.calendars(token)
        except google.LoginExpired:
            expired.append(email)  # the popup offers "Log in again" instead of an error
            failed.append(email)
            continue
        except Exception as e:
            errors.append(f"{email}: {e}")
            failed.append(email)
            continue
        for c in cal_list:
            if c["gid"] in seen:  # shared into several logged-in accounts
                continue
            seen.add(c["gid"])
            cal_id = hashlib.sha1(("google:" + c["gid"]).encode()).hexdigest()[:8]
            jobs.append((token, email, c, cal_id))

    # 2. Events of all calendars in parallel
    calendars, events = [], []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(fetch_calendar, *job, time_min, time_max) for job in jobs]
        for (token, email, c, cal_id), future in zip(jobs, futures):
            try:
                cal_events = future.result()
            except Exception as e:
                errors.append(f"{c['name']}: {e}")
                cal_events = [ev for ev in previous.get("events", []) if ev.get("cal") == cal_id]
            color = colors.get(c["gid"]) or colors.get(c["name"]) or c["color"]
            calendars.append({"id": cal_id, "gid": c["gid"], "account": email,
                              "name": c["name"], "color": color, "selected": c["selected"]})
            events.extend(cal_events)

    for email in failed:
        kept = [c for c in previous.get("calendars", [])
                if c.get("account") == email and c.get("gid") not in seen]
        ids = {c["id"] for c in kept}
        calendars.extend(kept)
        events.extend(ev for ev in previous.get("events", []) if ev.get("cal") in ids)
        seen.update(c.get("gid") for c in kept)

    events.sort(key=lambda e: (e["start"], not e["allDay"], e["title"].lower()))
    write_json(OUTPUT, {"configured": bool(tokens), "hasClient": os.path.exists(google.CLIENT),
                        "expired": expired, "updated": now_ms, "errors": errors,
                        "rangeStart": to_ms(range_start), "rangeEnd": to_ms(range_end),
                        "calendars": calendars, "events": events})
    return 0


def list_accounts():
    tokens = google.load_tokens()
    if not tokens:
        print("No Google accounts. Add one: dots calendar login")
    try:
        with open(VISIBILITY) as f:
            visible = json.load(f)
    except Exception:
        visible = {}
    for email in tokens:
        print(email)
        try:
            for c in google.calendars(google.access_token(email, tokens)):
                mark = "✓" if visible.get(c["gid"], c["selected"]) else " "
                print(f"  {mark} {c['name']}  ({c['gid']})")
        except Exception as e:
            print(f"  error: {e}")


def main(argv):
    cmd = argv[0] if argv else "sync"
    if cmd == "sync":
        return sync()
    if cmd == "client" and len(argv) <= 2:
        google.set_client(argv[1] if len(argv) == 2 else None)
        return 0
    if cmd == "login" and len(argv) <= 2:
        google.login(argv[1] if len(argv) == 2 else None)
        return sync()
    if cmd == "logout" and len(argv) == 2:
        google.logout(argv[1])
        return sync()
    if cmd == "accounts":
        list_accounts()
        return 0
    if cmd == "emails":
        print("\n".join(google.load_tokens()))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
