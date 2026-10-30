# Integration gotchas

## Firewall4 preserves set elements

On the tested firmware, `fw4 reload` retained old elements of the named set.
Removing an address from UCI therefore did not initially revoke live access.
The helper now flushes and repopulates only `inet fw4 ts_trusted` in one nft
transaction. It does not flush unrelated sets.

The input and forward guards run before the normal established-connection
acceptance. Removed peers also have their matching conntrack entries deleted.
An empty set stays empty; it must never become an unrestricted ACCEPT rule.

## Router addresses use input, subnet devices use forward

A connection to another home device is forwarded. A connection to the router's
own LAN or WAN address is local input. The `ts_mesh_admin` rule needs the
router addresses users actually open, not only its Tailscale address.

## Podkop and DNS are separate prerequisites

Adding an address to this page does not configure Podkop. The original setup
processes `br-lan` and `tailscale0` and routes exit-node DNS through local
dnsmasq into Podkop. That DNS integration and the private resolver mount
namespace for tailscaled are outside this repository.

## Samba point-to-point binding

The installed Samba version did not bind as expected to the Tailscale `/32`
interface with `bind interfaces only = yes`. The original setup uses host
allow/deny lists and firewall restrictions instead. Do not expose SMB on WAN
merely to make a VPN connection work.

The helper updates both the Samba template and the generated runtime file,
then signals running smbd processes. It expects exactly one `hosts allow`
line in each file and does not alter share definitions or authentication.

## Transmission's jail pins an inode

OpenWrt bind-mounts `settings.json` into the running Transmission jail.
Replacing the path with `sed -i` leaves the daemon seeing the old inode. The
helper prepares validated JSON separately, writes it into the existing file,
then sends SIGHUP. All unrelated JSON settings are preserved.

`rpc-whitelist` controls client addresses; `rpc-host-whitelist` controls HTTP
hosts. Both matter. The service's enabled flag, password and torrent paths
are not changed by this module.

## LuCI needs readable static files

An installation performed under `umask 077` initially produced a mode-700
view directory and mode-600 JavaScript. The HTTP 403 caused misleading session
errors in LuCI. Use mode 755 for the static directory and 644 for the view;
keep the apply helper and init script executable.

The page uses standard LuCI UCI Save & Apply. A procd `config.change` trigger
invokes the helper, and the page polls a non-secret apply-status JSON file.
The ACL only grants configuration access to `tailtrust` and read access to
that status file.

## Legacy AWG resource access is a separate migration

The original Flint setup removed the rules named `awg_nas_smb`,
`awg_nas_resilio_gui` and `awg_nas_transmission`, removed the old VPN network
from application allowlists, and added an input/forward guard for connections
initiated through `awg31`. Replies for outbound Podkop traffic remained valid.

An optional guard is provided in `examples/legacy-awg-outbound-only.nft`.
It is not installed automatically and is appropriate only if the interface
is intended exclusively for outbound use. Preserve any existing such guard
when updating the module on the original router.

## Shell and upgrade behavior

Keep shell files LF-terminated and without a UTF-8 BOM. The tested BusyBox
did not provide `nohup`, `stat`, `cksum` or `find -delete`; the shipped runtime
does not depend on them. Temporary test-account helpers are intentionally
not distributed.

Custom module files need sysupgrade preservation. Preservation is not a
compatibility guarantee: verify nftables include locations, LuCI behavior
and service configuration paths after a firmware change.
