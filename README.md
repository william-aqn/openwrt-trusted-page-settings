# OpenWrt Trusted Devices

A LuCI page that manages one list of trusted Tailscale IPv4 addresses for an
existing OpenWrt router setup. Adding an address updates access to router
services, subnet routing, internet through Podkop, Samba and Transmission.

The implementation originated on a GL.iNet Flint 2 (GL-MT6000), running
GL.iNet 4.9.1-op25 / OpenWrt 25.12.5 with Tailscale AWG 1.104.4.

This is a source integration, not an official OpenWrt package or a complete
Tailscale/Podkop installer. It expects the routing and service setup described
below to exist already. No router is modified merely by cloning this repository.

## What the page does

Open **LuCI > Services > Trusted devices**:

1. Add a device name and its Tailscale IPv4 address.
2. Keep **Trusted** enabled and select **Save & Apply**.
3. Wait for the **Applied** status.

The device must already belong to the tailnet and use a compatible transport
profile. Select the router as the exit node on the client when internet through
Podkop is wanted; accept subnet routes where required by the client.

Disabling or deleting a row revokes resource access. An empty list denies these
resources through Tailscale. Existing application passwords and tailnet access
policies still apply. Keep a LAN or independent SSH connection available when
removing the device currently used for administration.

## Repository layout

| Path | Purpose |
|---|---|
| `root/www/luci-static/resources/view/tailtrust/settings.js` | LuCI form and apply-status display |
| `root/etc/config/tailtrust` | Common device list and local access baselines |
| `root/etc/init.d/tailtrust` | Boot integration and UCI reload trigger |
| `root/usr/libexec/tailtrust-apply` | Firewall, Samba and Transmission reconciliation |
| `root/usr/libexec/tailtrust-validate.uc` | Address validation and enabled-device selection |
| `root/usr/libexec/tailtrust-json.uc` | Transmission settings update |
| `root/usr/share/nftables.d/` | Guards before established-connection acceptance |
| `root/usr/share/luci/menu.d/` | Menu registration |
| `root/usr/share/rpcd/acl.d/` | Scoped LuCI permissions |
| `scripts/install.sh` | Initial installation onto the prerequisite layout |
| `tests/test-validation.sh` | Non-destructive validation checks on OpenWrt |
| `examples/legacy-awg-outbound-only.nft` | Optional legacy-AWG guard, not installed automatically |

## Prerequisites

- OpenWrt with LuCI JavaScript views, UCI, procd and firewall4/nftables.
- `ucode` with the `fs` and `uci` modules, `flock`, `conntrack` and Samba `testparm`.
- Working Tailscale on interface `tailscale0`; this integration manages IPv4
  clients and blocks IPv6 arriving from that interface.
- Working subnet routes, an approved exit node, forwarding and NAT.
- Podkop configured to process `tailscale0` in addition to the existing LAN.
- Samba with one `hosts allow` line in `/etc/samba/smb.conf.template` and, when
  running, `/var/etc/smb.conf`. Retain an appropriate `hosts deny` policy.
- Transmission configured in the UCI section `transmission.main`, with its
  existing `config_dir` and authentication settings.
- These five existing firewall rule sections:

| UCI section | Existing responsibility |
|---|---|
| `ts_mesh_admin` | Selected ports on the router's own addresses |
| `ts_mesh_ping` | ICMP echo to the router |
| `ts_mesh_exit` | Internet and the upstream home subnet |
| `ts_mesh_home` | The router's LAN subnet |
| `ts_mesh_podkop` | Podkop-selected traffic to the local proxy |

The helper replaces each rule's source-address list with the shared
`ts_trusted` set and enables the rule. It preserves the existing destinations,
ports, zones and marks. It does not create these rules or configure their scope.

## Initial installation

Read [INSTALL.md](docs/INSTALL.md) before running the installer. Adjust
`root/etc/config/tailtrust` to your networks and enable at least one real device.
The shipped device is a disabled example; the installer refuses that empty
effective allowlist to avoid an accidental first-install lockout.

On the workstation, from the repository root:

```sh
mkdir -p dist
tar -cf dist/tailtrust-files.tar -C root .
scp -O dist/tailtrust-files.tar scripts/install.sh root@ROUTER_IP:/tmp/
```

On the router:

```sh
sh /tmp/install.sh /tmp/tailtrust-files.tar
```

`scp -O` uses legacy SCP when the router has no SFTP server. Windows PuTTY
users can use `pscp -scp` instead. Do not run a new install over the existing
Flint deployment: the installer refuses an existing `tailtrust` configuration.

## Checks and known limitations

See [VALIDATION.md](docs/VALIDATION.md) for checks performed on the original
router and the distinction between the deployed implementation and this
extracted source. See [GOTCHAS.md](docs/GOTCHAS.md) for firewall set retention,
Transmission bind mounts, Samba interface binding and LuCI file permissions.

The original setup's private addresses, passwords, SSH keys, VPN profiles,
node state and temporary browser-login helpers are not included. The existing
MIT license is retained.
