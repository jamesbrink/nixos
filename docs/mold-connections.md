# Mold connections on Hal9000

The host enables `services.mold.allowDirectApi = true` alongside Secure
pairing. Clients choose Secure by default. Explicit Regular pairing supports
LAN, Tailscale, and WAN HTTP/HTTPS; the managed proxy always uses end-to-end
encryption. There is no automatic downgrade. Browser mixed-content and
private-network restrictions still apply to HTTP destinations.

The service advertises its persistent identity through `MOLD_PUBLIC_URL` and
uses `MOLD_SECURE_WEBSOCKET_URL` for the production Secure relay. The public URL
namespace was verified against the existing home identity before registration.
Regular invitations keep an explicit direct address; managed proxy URLs never
serve Regular HTTP. Preserve the home identity when restarting or upgrading.

The operator API key remains in `/var/lib/mold-credentials/api-key`, owned by
`mold:mold`, mode `0600`, inside a mode `0700` directory. It is provisioned once
and loaded at service start. Never copy its contents into Git, Nix expressions,
command arguments, or logs, or broaden its permissions for interactive access.
Regular clients redeem a separate one-use invitation and receive their own
scoped credential; they do not receive the operator key.

For privileged local administration, run `sudo -u mold mold-local server status`
or `sudo -u mold mold-local list`. The wrapper reads the existing private key at runtime, uses
numeric loopback, and preserves Secure mode. Existing sudo policy controls
access; this change grants no additional sudo permission. `mold-status` and
`mold-logs`, where available, continue to inspect systemd and the journal.
Ordinary remote CLI users should pair their own client and select its saved
host rather than borrowing the operator key.

Deploy only the final approved Mold release pin. Before activation verify the
queue is idle and retain the host's Mold home, database, identity, and phone
grants. After activation verify the exact live revision, authenticated API
status, GPU and queue state, both connection modes, restart count, and recent
logs without submitting generations. The Discord service reads the same private operator key into a mode `0600` runtime environment file and uses numeric loopback; inspect its health without sending messages.

The shared-media ACL timer excludes the private `secure` authority tree. It
repairs old named/default ACLs there to `0700` directories and `0600` files
without replacing identity or device grants. Repeated timer runs retain those
permissions; models and output retain their shared access.
