# Installation and maintenance

## Scope

This module controls access to an already configured router. It does not
install Tailscale, AWG, Podkop, Samba or Transmission; approve routes in the
Tailscale console; or select an exit node on a client. The interface name
`tailscale0`, the five firewall rule IDs in the README, and the Transmission
section `main` are integration contracts.

The repository was extracted from a working Flint configuration. Review it
against the target router before installing. The repository installer and the
configurable access baselines have not been deployed back onto the original
router as part of this extraction.

## Configure the payload

Edit `root/etc/config/tailtrust` before building the archive.

- `settings.samba_allow`: baseline local Samba clients, using Samba syntax.
- `settings.transmission_allow`: baseline local Transmission RPC clients,
  using Transmission syntax, for example `192.168.8.*`.
- `settings.transmission_hosts`: allowed HTTP host names/addresses for the
  Transmission web interface, including the router's Tailscale address.
- Each `device` section: an optional name, one Tailscale IPv4 address, and
  `enabled` set explicitly to `1` or `0`.

Enabled device addresses are appended to the application baselines. Baselines
are authoritative: include every local source you intend to preserve. Do not
place the entire Tailscale range in a baseline, since that would defeat the
per-device application allowlist. The LuCI table edits device entries; edit
the settings section through UCI when changing the local network layout.

No real device is trusted in the shipped example. Use the addresses shown in
your own Tailscale device inventory. Every address must be a single IPv4 in
`100.64.0.0/10`, without a mask, leading zeroes or duplicates.

## What installation changes

The installer checks prerequisites, validates the payload, saves affected
service files under `/root/tailtrust-backups/`, and copies the module files.
The backup path is recorded in `/root/tailtrust-install-backup-path`.

The apply helper creates `firewall.ts_trusted`, switches the five prerequisite
rules to that set, rewrites Samba's `hosts allow` and Transmission RPC access
settings, and reloads the relevant services. It checks firewall syntax first.
The installer enables the `tailtrust` service and adds installed module files
to `/etc/sysupgrade.conf`.

The helper attempts to restore the prior service settings if application
fails. This is not a power-loss-safe transaction or a complete installer
uninstall: an interrupted initial installation can leave copied module files.
Keep independent router access and use the recorded backup for recovery.

No legacy AWG permission is removed by this repository's installer. The
original router's separate legacy-access shutdown is documented in GOTCHAS.

## Existing installations

Do not overwrite an existing `/etc/config/tailtrust` with the example payload.
For the original Flint deployment, migrating to this repository also requires
adding the new `settings` section with the existing local access baselines
before replacing `tailtrust-apply`.

Preserve any extra guards already present in the chain-pre files, especially
the original router's `awg31` guard. Review diffs rather than copying `root/`
blindly over an existing installation. Keep service scripts executable and
the LuCI static directory readable/traversable by the web server.

After an intentional update:

```sh
/usr/libexec/tailtrust-apply check
/etc/init.d/tailtrust reload
cat /var/run/tailtrust/status.json
nft list set inet fw4 ts_trusted
```

The `check` command validates only the device list. It does not test service
availability, route approval, application authentication or DNS behavior.

## Recovery

Use a LAN or independent SSH session. Stop further configuration edits, inspect
the apply status and `logread -e tailtrust`, and compare the affected files
against the recorded backup. Restore the relevant firewall, Transmission and
Samba files with their original ownership and permissions.

If reverting the shared firewall set, also remove or restore the two
`50-tailtrust.nft` guard files before reloading firewall4; they reference that
set. Restore Transmission's settings by writing into the existing file when
the running jail has it bind-mounted. Reload the affected daemons and verify
actual client access. The backup contains application settings and can contain
credentials; keep it private.
