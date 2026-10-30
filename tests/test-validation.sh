#!/bin/sh
set -eu
fixture=$(mktemp -d /tmp/tailtrust-test.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

write_device() {
    printf "config device\n option ip '%s'\n option enabled '%s'\n" "$1" "$2" >> "$fixture/tailtrust"
}
expect_rejected() {
    : > "$fixture/tailtrust"
    write_device "$1" 1
    if /usr/libexec/tailtrust-apply check "$fixture" >/dev/null 2>&1; then
        echo "Unexpectedly accepted: $1"
        exit 1
    fi
}
for ip in 192.168.8.2 100.63.0.1 100.128.0.1 100.64.0.256 100.064.0.1 100.64.0.1/32 '100.64.0.1;reboot'; do
    expect_rejected "$ip"
done
: > "$fixture/tailtrust"
write_device 100.64.0.1 1
write_device 100.64.0.1 0
if /usr/libexec/tailtrust-apply check "$fixture" >/dev/null 2>&1; then
    echo 'Duplicate address accepted.'
    exit 1
fi
: > "$fixture/tailtrust"
write_device 100.64.0.1 0
[ -z "$(/usr/libexec/tailtrust-apply check "$fixture")" ]
: > "$fixture/tailtrust"
write_device 100.127.255.254 1
write_device 100.64.0.1 1
[ "$(/usr/libexec/tailtrust-apply check "$fixture" | wc -l)" -eq 2 ]
cat > "$fixture/empty-set.nft" <<'NFT'
table inet tailtrust_validation {
    set trusted { type ipv4_addr; }
    chain test {
        ip saddr != @trusted drop
        ip saddr @trusted accept
    }
}
NFT
nft -c -f "$fixture/empty-set.nft"
echo 'Validation passed: address range, malformed input, duplicates, disabled devices, boundary addresses and empty set.'
