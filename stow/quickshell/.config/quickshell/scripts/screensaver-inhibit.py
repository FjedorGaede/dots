#!/usr/bin/env python3
"""D-Bus idle-inhibit bridge for services/IdleService.qml.

Apps ask "don't go idle" over D-Bus — browsers playing video, VLC, Steam,
gamemode, SDL games under XWayland, xdg-desktop-portal's Inhibit backend.
hypridle used to answer these; since it was replaced, nobody owned the names
and the requests were silently dropped. This daemon owns them:

  org.freedesktop.ScreenSaver         at /org/freedesktop/ScreenSaver and /ScreenSaver
  org.freedesktop.PowerManagement     at /org/freedesktop/PowerManagement/Inhibit

and prints one line per change to stdout:  `inhibitors <count> <app>, <app>, …`
IdleService pauses every idle step while count > 0.

Inhibits die with their client (NameOwnerChanged), so a crashed browser can't
keep the machine awake forever. Unknown UnInhibit cookies are ignored.
Exits 0 if another process already owns the names.
"""
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

SS_XML = """
<node>
  <interface name="org.freedesktop.ScreenSaver">
    <method name="Inhibit">
      <arg type="s" name="application_name" direction="in"/>
      <arg type="s" name="reason_for_inhibit" direction="in"/>
      <arg type="u" name="cookie" direction="out"/>
    </method>
    <method name="UnInhibit">
      <arg type="u" name="cookie" direction="in"/>
    </method>
    <method name="SimulateUserActivity"/>
  </interface>
</node>"""

PM_XML = """
<node>
  <interface name="org.freedesktop.PowerManagement.Inhibit">
    <method name="Inhibit">
      <arg type="s" name="application" direction="in"/>
      <arg type="s" name="reason" direction="in"/>
      <arg type="u" name="cookie" direction="out"/>
    </method>
    <method name="UnInhibit">
      <arg type="u" name="cookie" direction="in"/>
    </method>
    <method name="HasInhibit">
      <arg type="b" name="has_inhibit" direction="out"/>
    </method>
    <signal name="HasInhibitChanged">
      <arg type="b" name="has_inhibit"/>
    </signal>
  </interface>
</node>"""

MAX_INHIBITS = 256

inhibits = {}          # cookie -> (sender, app, reason)
next_cookie = 1
conn = None
names_wanted = 2
names_owned = 0


def publish():
    apps = sorted({app or "?" for _, app, _ in inhibits.values()})
    print(f"inhibitors {len(inhibits)} {', '.join(apps)}".rstrip(), flush=True)
    conn.emit_signal(None, "/org/freedesktop/PowerManagement/Inhibit",
                     "org.freedesktop.PowerManagement.Inhibit", "HasInhibitChanged",
                     GLib.Variant("(b)", (len(inhibits) > 0,)))


def add(sender, app, reason):
    global next_cookie
    cookie = next_cookie
    next_cookie = next_cookie % 0xFFFFFFFF + 1
    inhibits[cookie] = (sender, app[:64], reason[:128])
    publish()
    return cookie


def remove(cookie):
    if inhibits.pop(cookie, None) is not None:
        publish()


def on_call(_conn, sender, _path, iface, method, params, invocation):
    if method == "Inhibit":
        if len(inhibits) >= MAX_INHIBITS:
            invocation.return_dbus_error("org.freedesktop.DBus.Error.LimitsExceeded",
                                         "too many inhibitors")
            return
        app, reason = params.unpack()
        invocation.return_value(GLib.Variant("(u)", (add(sender, app, reason),)))
    elif method == "UnInhibit":
        (cookie,) = params.unpack()
        remove(cookie)                      # unknown cookie → ignored
        invocation.return_value(None)
    elif method == "HasInhibit":
        invocation.return_value(GLib.Variant("(b)", (len(inhibits) > 0,)))
    elif method == "SimulateUserActivity":
        invocation.return_value(None)
    else:
        invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)


def on_name_owner_changed(_c, _s, _p, _i, _sig, params):
    name, _old, new = params.unpack()
    if new == "":                           # a client left the bus → drop its inhibits
        dead = [c for c, (s, _, _) in inhibits.items() if s == name]
        for c in dead:
            del inhibits[c]
        if dead:
            publish()


def main():
    global conn
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    loop = GLib.MainLoop()

    ss = Gio.DBusNodeInfo.new_for_xml(SS_XML).interfaces[0]
    pm = Gio.DBusNodeInfo.new_for_xml(PM_XML).interfaces[0]
    # register_object_with_closures2 = non-deprecated API (PyGObject ≥ 3.52)
    register = getattr(conn, "register_object_with_closures2", conn.register_object)
    for path in ("/org/freedesktop/ScreenSaver", "/ScreenSaver"):
        register(path, ss, on_call, None, None)
    register("/org/freedesktop/PowerManagement/Inhibit", pm, on_call, None, None)

    conn.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                          "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE,
                          on_name_owner_changed)

    def acquired(_c, name):
        global names_owned
        names_owned += 1
        print(f"owned {name}", file=sys.stderr, flush=True)
        if names_owned == names_wanted:
            publish()

    def lost(_c, name):
        print(f"could not own {name} (someone else serves it) — exiting", file=sys.stderr, flush=True)
        loop.quit()

    for name in ("org.freedesktop.ScreenSaver", "org.freedesktop.PowerManagement"):
        Gio.bus_own_name_on_connection(conn, name, Gio.BusNameOwnerFlags.DO_NOT_QUEUE,
                                       acquired, lost)
    loop.run()


if __name__ == "__main__":
    main()
