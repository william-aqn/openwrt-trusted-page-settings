import { readfile, writefile } from 'fs';

let settings = json(readfile(ARGV[0]));
if (type(settings) != 'object')
    die('Invalid Transmission settings.\n');
settings['rpc-whitelist'] = ARGV[2];
settings['rpc-whitelist-enabled'] = true;
settings['rpc-host-whitelist'] = ARGV[3];
settings['rpc-host-whitelist-enabled'] = true;
if (!writefile(ARGV[1], sprintf('%J\n', settings)))
    die('Cannot prepare Transmission settings.\n');
