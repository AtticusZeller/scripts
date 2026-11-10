#!/usr/bin/python3
"""Interactive screenshot via xdg-desktop-portal. Prints the saved file path."""
import os
import sys
from urllib.parse import unquote, urlparse

from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop()
result = {}
token = f"ocr{os.getpid()}"
sender = bus.get_unique_name()[1:].replace(".", "_")
handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"


def on_response(_conn, _sender, _path, _iface, _sig, params):
    result["r"] = params.unpack()
    loop.quit()


bus.signal_subscribe(
    "org.freedesktop.portal.Desktop",
    "org.freedesktop.portal.Request",
    "Response",
    handle,
    None,
    Gio.DBusSignalFlags.NONE,
    on_response,
)
bus.call_sync(
    "org.freedesktop.portal.Desktop",
    "/org/freedesktop/portal/desktop",
    "org.freedesktop.portal.Screenshot",
    "Screenshot",
    GLib.Variant(
        "(sa{sv})",
        (
            "",
            {
                "interactive": GLib.Variant("b", True),
                "handle_token": GLib.Variant("s", token),
            },
        ),
    ),
    None,
    Gio.DBusCallFlags.NONE,
    -1,
)
loop.run()

code, res = result["r"]
if code != 0:
    print(f"portal response={code} {res}", file=sys.stderr)
    sys.exit(1)
print(unquote(urlparse(res["uri"]).path))
