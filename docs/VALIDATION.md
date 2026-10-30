# Validation record

Original deployment checked on 2026-10-30, Europe/Moscow.

## Completed on the original Flint 2

- Validated Tailscale IPv4 range, malformed addresses, leading zeroes,
  duplicate addresses and disabled entries.
- Checked an empty nft set without applying it to the live router.
- Revoked the Windows client's trust and observed its real LuCI request
  time out; restored trust and observed authenticated services work again.
- Verified authenticated Samba share access, Resilio HTTP 200 and
  Transmission session-get RPC success.
- Verified UCI Save & Apply triggers automatic reconciliation.
- In the browser: rendered the page, changed a name, added a disabled test
  row, rejected a non-Tailscale address, saved, deleted the test row and saved
  again. Only the two original real devices remained enabled.
- Verified outbound HTTPS through the original AWG31 tunnel remained working.
- Verified AWG31, Podkop, network and DHCP configuration hashes were unchanged
  during the trusted-device and legacy-access migration.
- Verified exit-node DNS still returned a Podkop fake IP for YouTube and
  ordinary addresses for the control domain.
- Ran ShellCheck and JavaScript syntax checks.

## Repository extraction

The runtime and UI sources were copied from that implementation. Personal
addresses were replaced with a disabled example, local application baselines
were moved into UCI settings, and the legacy-AWG shutdown was separated into
documentation and an optional example. The installer now checks prerequisites
and refuses an empty effective allowlist on first installation.

These extraction changes have been checked locally for syntax and repository
hygiene. They have not been deployed back to the original router or tested on
other OpenWrt hardware. There is no packaged `.apk`/`.ipk` release or CI build
claim at this stage.

## Repeating checks

With Docker and Node.js on the workstation, from the repository root:

```sh
docker run --rm -v "$PWD:/src:ro" koalaman/shellcheck:v0.11.0 \
  -s sh /src/root/usr/libexec/tailtrust-apply \
  /src/root/etc/init.d/tailtrust /src/scripts/install.sh \
  /src/tests/test-validation.sh
node --check root/www/luci-static/resources/view/tailtrust/settings.js
```

After the module is installed on a compatible OpenWrt router, copy and run
`tests/test-validation.sh`. It uses temporary UCI fixtures and `nft -c`; it
does not modify live configuration or deliberately interrupt a client.

Real revocation, application authentication, route approval and DNS behavior
need an integration check with a controlled client and independent admin
access. The production-revocation and temporary-login scripts used during
development are not included as general-purpose tests.
