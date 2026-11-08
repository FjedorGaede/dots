#!/usr/bin/env python3
"""Prints AI provider usage as one JSON object (read by AiUsageService).

Credentials come from Pi's ~/.config/pi/agent/auth.json — read-only, never
written (Pi refreshes its own OAuth token). Tokens are never printed.

Output: {"anthropic": {...}, "openrouter": {...}}, only providers found in
auth.json, plus "unknown": [names in auth.json without usage support]; each one is either
{"ok": true, ...} or {"ok": false, "error": "<short reason>"}.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

AUTH = os.path.expanduser("~/.config/pi/agent/auth.json")


def get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def anthropic(cred):
    if time.time() * 1000 >= cred.get("expires", 0):
        return {"ok": False, "error": "token expired – start Pi"}
    d = get("https://api.anthropic.com/api/oauth/usage", {
        "Authorization": "Bearer " + cred["access"],
        "anthropic-beta": "oauth-2025-04-20",
    })

    def win(w):
        if not w:
            return None
        return {"percent": w.get("utilization"), "resetsAt": w.get("resets_at")}

    extra = d.get("extra_usage") or {}
    out = {
        "ok": True,
        "session": win(d.get("five_hour")),
        "weekly": win(d.get("seven_day")),
        "sonnet": win(d.get("seven_day_sonnet")),
        "opus": win(d.get("seven_day_opus")),
    }
    if extra.get("is_enabled"):
        div = 10 ** extra.get("decimal_places", 2)
        out["extra"] = {
            "used": (extra.get("used_credits") or 0) / div,
            "limit": (extra.get("monthly_limit") or 0) / div,
            "percent": extra.get("utilization"),
            "currency": extra.get("currency", ""),
        }
    return out


def openrouter(cred):
    h = {"Authorization": "Bearer " + cred["key"]}
    credits = get("https://openrouter.ai/api/v1/credits", h)["data"]
    key = get("https://openrouter.ai/api/v1/key", h)["data"]
    total, used = credits["total_credits"], credits["total_usage"]
    return {
        "ok": True,
        "total": total,
        "used": used,
        "remaining": total - used,
        "daily": key.get("usage_daily"),
        "weekly": key.get("usage_weekly"),
        "monthly": key.get("usage_monthly"),
    }


def run(fn, cred):
    try:
        return fn(cred)
    except urllib.error.HTTPError as e:
        return {"ok": False, "error": "HTTP %d" % e.code}
    except Exception as e:  # network down, bad JSON, …
        return {"ok": False, "error": type(e).__name__}


def main():
    try:
        with open(AUTH) as f:
            auth = json.load(f)
    except Exception:
        auth = {}
    # Only providers that have credentials; the rest is left out entirely
    providers = {"anthropic": anthropic, "openrouter": openrouter}
    out = {}
    for name, fn in providers.items():
        if auth.get(name):
            out[name] = run(fn, auth[name])
    # Providers in auth.json we have no usage code for (shown as a warning)
    out["unknown"] = sorted(n for n in auth if n not in providers)
    json.dump(out, sys.stdout)


main()
