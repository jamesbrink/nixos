"""Unlock the running gnome-keyring login collection from a password file.

`gnome-keyring-daemon --unlock` cannot do this for a D-Bus-activated daemon:
it starts a second daemon instead. This talks to the running one over D-Bus
through the internal interface Seahorse uses (UnlockWithMasterPassword),
which takes the password directly instead of showing a prompt.

Exit codes: 0 unlocked (or already unlocked), 1 unlock failed, 2 bad usage.
"""

import sys
from pathlib import Path
from typing import Any

from jeepney import DBusAddress, Message, MessageType, new_method_call
from jeepney.io.blocking import DBusConnection, open_dbus_connection

BUS_NAME = "org.freedesktop.secrets"
SERVICE = DBusAddress(
    "/org/freedesktop/secrets",
    bus_name=BUS_NAME,
    interface="org.freedesktop.Secret.Service",
)
INTERNAL = DBusAddress(
    "/org/freedesktop/secrets",
    bus_name=BUS_NAME,
    interface="org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
)


def call(conn: DBusConnection, msg: Message) -> tuple[Any, ...]:
    reply = conn.send_and_get_reply(msg, timeout=30)
    if reply.header.message_type == MessageType.error:
        raise RuntimeError(f"D-Bus error: {reply.body!r}")
    return reply.body


def is_locked(conn: DBusConnection, collection: str) -> bool:
    props = DBusAddress(
        collection, bus_name=BUS_NAME, interface="org.freedesktop.DBus.Properties"
    )
    ((_sig, value),) = call(
        conn,
        new_method_call(
            props, "Get", "ss", ("org.freedesktop.Secret.Collection", "Locked")
        ),
    )
    return bool(value)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: keyring-autounlock PASSWORD_FILE", file=sys.stderr)
        return 2
    password = Path(sys.argv[1]).read_bytes().rstrip(b"\r\n")

    conn = open_dbus_connection(bus="SESSION")
    try:
        (collection,) = call(
            conn, new_method_call(SERVICE, "ReadAlias", "s", ("default",))
        )
        if collection == "/":
            collection = "/org/freedesktop/secrets/collection/login"
        if not is_locked(conn, collection):
            print(f"{collection} already unlocked")
            return 0

        # The "plain" session sends the secret unencrypted, which is fine on
        # the local session bus; the session lives as long as this connection.
        _output, session = call(
            conn, new_method_call(SERVICE, "OpenSession", "sv", ("plain", ("s", "")))
        )
        secret = (session, b"", password, "text/plain")
        try:
            call(
                conn,
                new_method_call(
                    INTERNAL,
                    "UnlockWithMasterPassword",
                    "o(oayays)",
                    (collection, secret),
                ),
            )
        except RuntimeError as err:
            print(f"unlock of {collection} rejected: {err}", file=sys.stderr)
            return 1

        if is_locked(conn, collection):
            print(
                f"{collection} still locked after unlock call (wrong password?)",
                file=sys.stderr,
            )
            return 1
        print(f"{collection} unlocked")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
