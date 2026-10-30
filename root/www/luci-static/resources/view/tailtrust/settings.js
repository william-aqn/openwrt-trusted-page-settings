'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require poll';

var STATUS_PATH = '/var/run/tailtrust/status.json';

function validAddress(value) {
    if (!/^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/.test(value))
        return false;
    var parts = value.split('.');
    return parts.every(function(part) {
        return Number(part) <= 255 && String(Number(part)) === part;
    }) && Number(parts[1]) >= 64 && Number(parts[1]) <= 127;
}

return view.extend({
    load: function() {
        return uci.load('tailtrust');
    },

    render: function() {
        var m = new form.Map('tailtrust', _('Trusted devices'),
            _('Add a device once to enable internet through Podkop, both home networks, router panels, Samba and Transmission. Existing service passwords still apply.'));
        var s = m.section(form.TableSection, 'device', _('Tailscale devices'));
        s.anonymous = true;
        s.addremove = true;
        s.sortable = true;
        var o = s.option(form.Flag, 'enabled', _('Trusted'));
        o.default = '1';
        o.rmempty = false;
        o = s.option(form.Value, 'name', _('Device name'));
        o.placeholder = _('For example: Laptop');
        o.datatype = 'maxlength(64)';
        o = s.option(form.Value, 'ip', _('Tailscale IPv4 address'));
        o.placeholder = '100.x.x.x';
        o.rmempty = false;
        o.validate = function(section, value) {
            if (!validAddress(value))
                return _('Enter one address in 100.64.0.0/10, without a subnet mask.');
            var option = this;
            var duplicate = s.cfgsections().some(function(other) {
                return other !== section && option.formvalue(other) === value;
            });
            return duplicate ? _('This address is already listed.') : true;
        };

        var status = E('div', { 'class': 'cbi-section' }, _('Loading apply status...'));
        function refreshStatus() {
            return fs.read(STATUS_PATH).then(function(text) {
                var data = JSON.parse(text);
                status.replaceChildren(
                    E('strong', {}, data.state === 'ok' ? _('Applied') : data.state === 'applying' ? _('Applying') : _('Apply failed')),
                    E('p', {}, data.message),
                    E('small', {}, _('Enabled devices: %s. Updated: %s').format(data.count, data.updated))
                );
                status.style.borderLeft = '4px solid ' + (data.state === 'ok' ? '#3c9b57' : data.state === 'error' ? '#c83c3c' : '#d49b20');
            }).catch(function() {
                status.textContent = _('No apply result is available yet. Save and apply the device list.');
            });
        }
        poll.add(refreshStatus, 5);
        refreshStatus();
        return m.render().then(function(node) {
            return E('div', {}, [
                node,
                E('div', { 'class': 'cbi-section' }, [
                    E('h3', {}, _('Connecting a new device')),
                    E('ol', {}, [
                        E('li', {}, _('Install the AWG-compatible Tailscale client, use the existing AWG profile and sign in to the same tailnet.')),
                        E('li', {}, _('Add its Tailscale IPv4 address above, then select Save & Apply.')),
                        E('li', {}, _('On that device, select this router as the exit node and enable subnet routes if the client requires it.'))
                    ]),
                    E('p', {}, _('Access follows the home networks and services already configured on this router. Disable or remove a device to revoke its access. An empty list blocks these resources through Tailscale. Keep LAN access available when removing your current device.'))
                ]),
                status
            ]);
        });
    }
});
