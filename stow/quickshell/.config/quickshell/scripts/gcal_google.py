"""Google Calendar API half of gcal-sync.py: OAuth login + event fetch.

One OAuth client (a "Desktop app" in any Google Cloud project) serves every
account; each account logs in once and gets its own refresh token. Private
files (never in the dots repo), all in ~/.local/share/quickshell/:

  google-client.json   the downloaded client_secret_*.json (`dots calendar client`)
  google-tokens.json   { "<email>": { "refresh_token", "access_token", "expiry" } }

Stdlib only: loopback redirect + PKCE (RFC 8252), plain REST calls.
"""
import base64
import contextlib
import fcntl
import glob
import hashlib
import http.server
import json
import os
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

DATA = os.path.expanduser("~/.local/share/quickshell")
CLIENT = os.path.join(DATA, "google-client.json")
TOKENS = os.path.join(DATA, "google-tokens.json")

AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
REVOKE_URL = "https://oauth2.googleapis.com/revoke"
API = "https://www.googleapis.com/calendar/v3"
CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
SCOPES = "openid email " + CALENDAR_SCOPE


class LoginExpired(Exception):
    pass


# ── Private files ──────────────────────────────────────────────────────────

def write_private(path, data):
    """Atomic 0600 write; unique temp name, so concurrent writers never share it."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")  # mkstemp → 0600
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


@contextlib.contextmanager
def locked(name):
    """Exclusive lock across processes (quickshell's sync vs. `dots calendar`)."""
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, f".{name}.lock"), "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        yield


def load_tokens():
    try:
        with open(TOKENS) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def update_tokens(change):
    """Read-modify-write of the tokens file under the lock: `change(tokens)`
    edits the fresh on-disk state, so concurrent logins/logouts/refreshes
    never overwrite each other with a stale copy."""
    with locked("tokens"):
        tokens = load_tokens()
        result = change(tokens)
        write_private(TOKENS, tokens)
        return result


def load_client():
    with open(CLIENT) as f:
        data = json.load(f)
    c = data.get("installed") or data.get("web") or data
    return c["client_id"], c["client_secret"]


# ── HTTP ───────────────────────────────────────────────────────────────────

def post_form(url, fields):
    body = urllib.parse.urlencode(fields).encode()
    with urllib.request.urlopen(urllib.request.Request(url, data=body), timeout=20) as r:
        return json.load(r)


class ApiError(Exception):
    pass


def api_get(token, path, params):
    url = API + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:  # Google's message instead of a bare "HTTP Error 403"
            message = json.load(e)["error"]["message"]
        except Exception:
            message = str(e)
        raise ApiError(f"{e.code}: {message}") from None


def api_pages(token, path, params):
    params = dict(params)
    while True:
        page = api_get(token, path, params)
        yield from page.get("items", [])
        if not page.get("nextPageToken"):
            return
        params["pageToken"] = page["nextPageToken"]


def jwt_claims(id_token):
    # Received straight from Google's token endpoint over TLS → no signature check needed
    payload = id_token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))


# ── Login / logout ─────────────────────────────────────────────────────────

def is_desktop_client(path):
    try:
        with open(path) as f:
            return "installed" in json.load(f)
    except Exception:
        return False


def set_client(path=None):
    """Install the OAuth client JSON. No path → newest Desktop client in ~/Downloads."""
    if path is None:
        downloads = glob.glob(os.path.expanduser("~/Downloads/client_secret_*.json"))
        candidates = sorted((p for p in downloads if is_desktop_client(p)),
                            key=os.path.getmtime, reverse=True)
        if not candidates:
            raise SystemExit(
                "No Desktop OAuth client in ~/Downloads. Cloud console → Google Auth Platform → "
                "Clients → your Desktop client → Download JSON (or create one: type \"Desktop app\").")
        path = candidates[0]
    path = os.path.expanduser(path)
    if not is_desktop_client(path):
        raise SystemExit(f"{path}: not a Desktop OAuth client (\"installed\") — a \"Web\" client "
                         "can't do the loopback login. Create one of type \"Desktop app\".")
    os.makedirs(DATA, exist_ok=True)
    shutil.copyfile(path, CLIENT)
    os.chmod(CLIENT, 0o600)
    print(f"OAuth client installed from {path}")


def login(login_hint=None):
    if not os.path.exists(CLIENT):
        raise SystemExit("No OAuth client set up yet — run: dots calendar client")
    client_id, client_secret = load_client()

    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(16)
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [""])[0] != state:
                self.send_response(400); self.end_headers(); return
            result["code"] = q.get("code", [None])[0]
            result["error"] = q.get("error", [None])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Logged in — you can close this tab." if result["code"] else "Login failed: " + str(result["error"])
            self.wfile.write(f"<html><body style='font:16px sans-serif;padding:2em'>{msg}</body></html>".encode())

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}"
    params = {
        "client_id": client_id, "redirect_uri": redirect, "response_type": "code",
        "scope": SCOPES, "access_type": "offline", "prompt": "consent select_account",
        "code_challenge": challenge, "code_challenge_method": "S256", "state": state,
    }
    if login_hint:
        params["login_hint"] = login_hint
    url = AUTH_URL + "?" + urllib.parse.urlencode(params)
    print("Opening the browser for Google login. If nothing opens, visit:\n" + url)
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    server.timeout = 300
    deadline = time.time() + 300
    while "code" not in result and time.time() < deadline:
        server.handle_request()
    server.server_close()
    if not result.get("code"):
        raise SystemExit("Login failed: " + str(result.get("error") or "timed out"))

    tok = post_form(TOKEN_URL, {
        "code": result["code"], "client_id": client_id, "client_secret": client_secret,
        "redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": verifier,
    })
    email = jwt_claims(tok["id_token"])["email"]
    if CALENDAR_SCOPE not in tok.get("scope", "").split():
        raise SystemExit(f"{email}: calendar access was not granted — run login again and "
                         "tick \"See and download any calendar …\" on the consent screen.")
    def add(tokens):
        tokens[email] = {
            "refresh_token": tok.get("refresh_token") or tokens.get(email, {}).get("refresh_token"),
            "access_token": tok["access_token"],
            "expiry": int(time.time()) + int(tok.get("expires_in", 3600)),
        }
    update_tokens(add)
    print(f"Logged in as {email}.")
    return email


def logout(email):
    tok = update_tokens(lambda tokens: tokens.pop(email, None))
    if tok is None:
        raise SystemExit(f"Not logged in: {email}")
    try:
        post_form(REVOKE_URL, {"token": tok["refresh_token"]})
    except Exception:
        pass  # revoking is best effort; the local token is gone either way
    print(f"Logged out {email}.")


def access_token(email, tokens):
    tok = tokens[email]
    if tok.get("access_token") and tok.get("expiry", 0) > time.time() + 60:
        return tok["access_token"]
    client_id, client_secret = load_client()
    try:
        fresh = post_form(TOKEN_URL, {
            "client_id": client_id, "client_secret": client_secret,
            "refresh_token": tok["refresh_token"], "grant_type": "refresh_token",
        })
    except urllib.error.HTTPError as e:
        if e.code in (400, 401):  # invalid_grant: revoked, or 7-day "Testing" expiry
            raise LoginExpired(f"{email}: login expired — run: dots calendar login {email}")
        raise
    tok["access_token"] = fresh["access_token"]
    tok["expiry"] = int(time.time()) + int(fresh.get("expires_in", 3600))

    # Store only this account's new access token, into the CURRENT file — an
    # account logged out meanwhile stays out (no resurrection from `tokens`)
    def store(current):
        if email in current:
            current[email].update(access_token=tok["access_token"], expiry=tok["expiry"])
    update_tokens(store)
    return tok["access_token"]


# ── Calendars / events ─────────────────────────────────────────────────────

def calendars(token):
    """All calendars of the account. `selected` = checked in Google's sidebar
    (the default visibility; the shell's calendar settings override it)."""
    out = []
    for c in api_pages(token, "/users/me/calendarList", {"minAccessRole": "reader"}):
        if c.get("deleted") or c.get("hidden"):
            continue
        out.append({"gid": c["id"], "name": c.get("summaryOverride") or c.get("summary") or c["id"],
                    "color": c.get("backgroundColor", ""), "selected": bool(c.get("selected")),
                    "primary": bool(c.get("primary"))})
    # Primary first, then Google's order is arbitrary → by name
    out.sort(key=lambda c: (not c["primary"], c["name"].lower()))
    return out


def join_url(ev):
    if ev.get("hangoutLink"):
        return ev["hangoutLink"]
    for ep in ev.get("conferenceData", {}).get("entryPoints", []):
        if ep.get("entryPointType") == "video" and ep.get("uri"):
            return ep["uri"]
    return ""


def events(token, calendar_id, time_min, time_max):
    """→ raw API events, recurrences already expanded by Google (singleEvents)."""
    for ev in api_pages(token, f"/calendars/{urllib.parse.quote(calendar_id)}/events", {
        "timeMin": time_min, "timeMax": time_max, "singleEvents": "true",
        "orderBy": "startTime", "maxResults": 2500,
        "fields": "nextPageToken,items(id,status,summary,location,description,start,end,"
                  "htmlLink,hangoutLink,conferenceData/entryPoints,attendees(self,responseStatus),eventType)",
    }):
        if ev.get("status") == "cancelled" or ev.get("eventType") == "workingLocation":
            continue
        if any(a.get("self") and a.get("responseStatus") == "declined" for a in ev.get("attendees", [])):
            continue
        yield ev
