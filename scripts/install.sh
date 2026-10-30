#!/bin/sh
set -eu
umask 077

[ ! -e /etc/config/tailtrust ] || {
    echo 'Already installed. Preserve /etc/config/tailtrust when updating files.' >&2
    exit 1
}
for chain in input forward; do
    [ ! -e "/usr/share/nftables.d/chain-pre/$chain/50-tailtrust.nft" ] || {
        echo 'Existing tailtrust guards found. Review the current installation before proceeding.' >&2
        exit 1
    }
done
for tool in uci ucode fw4 nft flock testparm conntrack tar; do
    command -v "$tool" >/dev/null || {
        echo "Missing dependency: $tool" >&2
        exit 1
    }
done
for rule in ts_mesh_admin ts_mesh_ping ts_mesh_exit ts_mesh_home ts_mesh_podkop; do
    [ "$(uci -q get "firewall.$rule")" = rule ] || {
        echo "Missing prerequisite firewall rule: $rule" >&2
        exit 1
    }
done
[ -z "$(uci changes firewall)" ] && [ -z "$(uci changes transmission)" ]
[ -f /etc/samba/smb.conf.template ]
settings_dir=$(uci -q get transmission.main.config_dir)
archive=${1:-/tmp/tailtrust-files.tar}
[ -f "$archive" ]
stage=$(mktemp -d /tmp/tailtrust-install.XXXXXX)
trap 'rm -rf "$stage"' EXIT
tar -xf "$archive" -C "$stage"
ucode "$stage/usr/libexec/tailtrust-validate.uc" "$stage/etc/config" > "$stage/initial-ips"
[ -s "$stage/initial-ips" ] || {
    echo 'Configure at least one real enabled device before installing.' >&2
    exit 1
}
for option in samba_allow transmission_allow transmission_hosts; do
    [ -n "$(uci -c "$stage/etc/config" -q get "tailtrust.settings.$option")" ]
done
sh -n "$stage/usr/libexec/tailtrust-apply"

backup=/root/tailtrust-backups/install-$(date +%Y%m%d-%H%M%S)
mkdir -p "$backup"
for path in /etc/config/firewall /etc/config/transmission /etc/samba/smb.conf.template /var/etc/smb.conf "$settings_dir/settings.json" /etc/sysupgrade.conf; do
    if [ -f "$path" ]; then
        mkdir -p "$backup$(dirname "$path")"
        cp -p "$path" "$backup$path"
    fi
done
printf '%s\n' "$backup" > /root/tailtrust-install-backup-path

mkdir -p /var/run/tailtrust
cp "$stage/initial-ips" /var/run/tailtrust/applied-ips
rm "$stage/initial-ips"
cp -R "$stage"/. /
chmod 755 /usr/libexec/tailtrust-apply /etc/init.d/tailtrust
chmod 644 /usr/libexec/tailtrust-validate.uc /usr/libexec/tailtrust-json.uc
chmod 755 /www/luci-static/resources/view/tailtrust
chmod 644 /www/luci-static/resources/view/tailtrust/settings.js
chmod 644 /usr/share/luci/menu.d/luci-app-tailtrust.json /usr/share/rpcd/acl.d/luci-app-tailtrust.json
chmod 600 /etc/config/tailtrust

# The apply helper prepares the shared set before fw4 loads the guard snippets.
if ! /etc/init.d/tailtrust start; then
    # The helper may have restored a firewall config without the new set.
    # Remove only the newly installed guards before reloading that config.
    for chain in input forward; do
        rm -f "/usr/share/nftables.d/chain-pre/$chain/50-tailtrust.nft"
    done
    /etc/init.d/tailtrust stop >/dev/null 2>&1 || true
    /etc/init.d/firewall reload || true
    echo "Installation did not finish. Configuration backup: $backup" >&2
    echo 'The helper restores prior service settings; inspect the installed files before retrying.' >&2
    exit 1
fi
/etc/init.d/tailtrust enable
find "$stage" -type f | while IFS= read -r source_path; do
    path=${source_path#"$stage"}
    grep -qxF "$path" /etc/sysupgrade.conf 2>/dev/null || printf '%s\n' "$path" >> /etc/sysupgrade.conf
done
rm -f /tmp/luci-indexcache
find /tmp -maxdepth 1 -name 'luci-indexcache.*' -type f -exec rm -f '{}' ';'
/etc/init.d/rpcd reload
cat /var/run/tailtrust/status.json
printf '\nBackup: %s\n' "$backup"
