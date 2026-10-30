import { cursor } from 'uci';

let c = cursor(ARGV[0] || '/etc/config');
let seen = {};
let addresses = [];
if (!c.load('tailtrust'))
    die('Cannot load the trusted device configuration.\n');
c.foreach('tailtrust', 'device', function(s) {
    let ip = s.ip;
    if (type(ip) != 'string' || !match(ip, /^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/))
        die('Each device must have one Tailscale IPv4 address.\n');
    let octets = split(ip, '.');
    for (let i = 0; i < 4; i++) {
        if (int(octets[i]) > 255 || sprintf('%d', int(octets[i])) != octets[i])
            die('Invalid IPv4 address.\n');
    }
    if (int(octets[1]) < 64 || int(octets[1]) > 127)
        die('Addresses must belong to 100.64.0.0/10.\n');
    if (seen[ip])
        die('Duplicate device address.\n');
    seen[ip] = true;
    if (s.enabled != '0' && s.enabled != '1')
        die('Each device must explicitly be enabled or disabled.\n');
    if (s.enabled == '1')
        push(addresses, ip);
});
for (let ip in sort(addresses))
    print(ip, '\n');
