(function () {
    var state = { mode: 'ops', data: { players: [], stats: {}, audit: [], self: {} }, selected: null, search: '' };
    var titles = { ops: 'Operacje live', players: 'Gracze online', economy: 'Ekonomia i rangi', audit: 'Audit administracji' };

    function $(q) { return document.querySelector(q); }
    function $$(q, root) { return Array.prototype.slice.call((root || document).querySelectorAll(q)); }
    function unwrap(v) { return Array.isArray(v) && v.length === 1 && typeof v[0] === 'object' ? v[0] : v; }
    function arg(v) { return v && typeof v === 'object' ? JSON.stringify(v) : v; }
    function emit(name, a, b) {
        if (window.mta && typeof window.mta.triggerEvent === 'function') {
            if (typeof b !== 'undefined') window.mta.triggerEvent(name, arg(a), arg(b));
            else if (typeof a !== 'undefined') window.mta.triggerEvent(name, arg(a));
            else window.mta.triggerEvent(name);
        } else console.log('[admin]', name, a, b);
    }
    function html(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
    function money(v) { return '$' + Math.floor(Number(v) || 0).toLocaleString('en-US'); }
    function pct(v) { v = Math.max(0, Math.min(100, Number(v) || 0)); return Math.floor(v); }
    function shortSerial(v) { v = String(v || ''); return v ? v.slice(0, 6) + '...' + v.slice(-5) : '-'; }
    function time(ts) { var d = new Date((Number(ts) || 0) * 1000); return isNaN(d.getTime()) ? '-' : d.toLocaleString('pl-PL'); }
    function selectedSerial() { return state.selected && state.selected.serial; }

    function players() {
        var q = state.search.toLowerCase();
        return (state.data.players || []).filter(function (p) {
            if (!q) return true;
            return [p.name, p.character, p.accountId, p.characterId, p.serial, p.adminRole].join(' ').toLowerCase().indexOf(q) !== -1;
        });
    }

    function select(serial) {
        state.selected = (state.data.players || []).filter(function (p) { return p.serial === serial; })[0] || null;
        renderAll();
    }

    function sendAction(action, extra) {
        extra = extra || {};
        if (action !== 'announce') {
            if (!selectedSerial()) return;
            extra.serial = selectedSerial();
        }
        emit('HeavyRPG:UI:admin:action', action, extra);
    }

    function setMode(mode) {
        state.mode = mode;
        $$('.nav-btn').forEach(function (b) { b.classList.toggle('active', b.dataset.mode === mode); });
        $$('.mode').forEach(function (v) { v.classList.toggle('active', v.dataset.mode === mode); });
        $('#screenTitle').textContent = titles[mode] || 'Staff Command';
    }

    function renderMetrics() {
        var s = state.data.stats || {};
        var list = [
            ['Gracze online', s.online || 0],
            ['Konta', s.accounts || 0],
            ['Postacie', s.characters || 0],
            ['Staff', s.staff || 0],
            ['Notatki w swiecie', s.notes || 0]
        ];
        $('#metrics').innerHTML = list.map(function (m) { return '<div class="metric"><span>' + html(m[0]) + '</span><strong>' + html(m[1]) + '</strong></div>'; }).join('');
        $('#railOnline').textContent = s.online || 0;
        $('#railStaff').textContent = s.staff || 0;
        $('#railNotes').textContent = s.notes || 0;
    }

    function playerCard(p) {
        var active = state.selected && state.selected.serial === p.serial ? ' active' : '';
        var flag = p.frozen ? '<span class="chip bad">freeze</span>' : '<span class="chip good">live</span>';
        return '<button class="player-card' + active + '" data-serial="' + html(p.serial) + '"><div><strong>' + html(p.character || p.name) + '</strong><small>' + html(p.name) + ' | ' + html(shortSerial(p.serial)) + ' | ping ' + html(p.ping || 0) + '</small></div>' + flag + '</button>';
    }

    function renderRoster() {
        var list = players();
        $('#onlineCount').textContent = list.length + ' graczy';
        $('#playerList').innerHTML = list.length ? list.map(playerCard).join('') : '<div class="empty-state">Brak graczy pasujacych do filtra.</div>';
        $$('#playerList .player-card').forEach(function (el) { el.onclick = function () { select(el.dataset.serial); }; });
    }

    function vital(label, value, type) {
        value = pct(value);
        return '<div class="vital"><span>' + html(label) + '</span><div class="bar"><div class="fill ' + (type || '') + '" style="width:' + value + '%"></div></div><strong>' + value + '</strong></div>';
    }

    function renderInspector() {
        var p = state.selected;
        $('#selectedName').textContent = p ? (p.character || p.name) : 'Nie wybrano celu';
        if (!p) {
            $('#inspector').className = 'empty-state';
            $('#inspector').innerHTML = 'Wybierz gracza z rosteru, a tutaj pojawi sie stan postaci, lokalizacja, ekonomia i akcje administracyjne.';
            return;
        }
        var pos = p.position || {};
        $('#inspector').className = '';
        $('#inspector').innerHTML = '' +
            '<div class="identity"><div><h3>' + html(p.character || p.name) + '</h3><p>' + html(p.name) + ' | konto #' + html(p.accountId || '-') + ' | postac #' + html(p.characterId || '-') + '</p></div><span class="chip">' + html(p.adminRole || 'Gracz') + '</span></div>' +
            '<div class="vitals">' + vital('HP', p.health, '') + vital('Armor', p.armor, 'armor') + '</div>' +
            '<div class="detail-grid">' +
                detail('Gotowka', money(p.money)) + detail('Ping', (p.ping || 0) + ' ms') + detail('Skin', p.skin || '-') + detail('Freeze', p.frozen ? 'tak' : 'nie') +
                detail('Dim / Int', (p.dimension || 0) + ' / ' + (p.interior || 0)) + detail('Pojazd', p.vehicle || 'pieszo') + detail('Pozycja X/Y/Z', [pos.x || 0, pos.y || 0, pos.z || 0].join(' / ')) + detail('Serial', shortSerial(p.serial)) +
            '</div>' +
            '<div class="action-grid">' +
                '<button data-action="heal">HP 100</button><button data-action="armor">Armor 100</button><button data-action="freeze">Freeze</button>' +
                '<button data-action="goto">Idz do</button><button data-action="bring">Przyciagnij</button><button data-action="fixVehicle">Napraw pojazd</button>' +
                '<button data-action="slap">Slap</button><button data-action="giveCash">+ gotowka</button><button data-action="takeCash">- gotowka</button>' +
                '<button data-action="kick" class="danger">Kick</button>' +
            '</div>' +
            '<div class="form-row"><input id="healthValue" type="number" min="1" max="100" value="100"><button data-action="setHealth">Ustaw HP</button><input id="armorValue" type="number" min="0" max="100" value="100"><button data-action="setArmor">Ustaw armor</button><input id="dimValue" type="number" min="0" value="0"><button data-action="setDimension">Dimension</button></div>';
        bindActionButtons($('#inspector'));
    }

    function detail(label, value) {
        return '<div class="detail"><span>' + html(label) + '</span><strong>' + html(value) + '</strong></div>';
    }

    function renderPlayersTable() {
        var list = players();
        $('#playersTable').innerHTML = list.length ? list.map(function (p) {
            return '<tr><td>' + html(p.name) + '</td><td>' + html(p.character || '-') + '</td><td>' + html(p.health) + '</td><td>' + html(p.armor) + '</td><td>' + html(p.skin || '-') + '</td><td>' + money(p.money) + '</td><td>' + html((p.dimension || 0) + ' / ' + (p.interior || 0)) + '</td><td>' + html(p.ping || 0) + '</td><td><button data-serial="' + html(p.serial) + '" data-a="heal">HP</button><button data-serial="' + html(p.serial) + '" data-a="goto">TP</button><button data-serial="' + html(p.serial) + '" data-a="bring">Bring</button></td></tr>';
        }).join('') : '<tr><td colspan="9">Brak graczy.</td></tr>';
        $$('#playersTable button').forEach(function (b) { b.onclick = function () { select(b.dataset.serial); sendAction(b.dataset.a, {}); }; });
    }

    function renderAudit() {
        var rows = state.data.audit || [];
        var compact = rows.slice(0, 8);
        $('#auditCompact').innerHTML = compact.length ? compact.map(function (r) {
            return '<div class="timeline-row"><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + html(shortSerial(r.target || '')) + '</span><span>' + time(r.created_at) + '</span></div>';
        }).join('') : '<div class="empty-state">Brak wpisow audytu.</div>';
        $('#auditLog').innerHTML = rows.length ? rows.map(function (r) {
            return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + html(r.target || '-') + '</span><span>' + html(r.detail_json || '{}') + '</span></div><code>#' + html(r.id) + '</code></div>';
        }).join('') : '<div class="empty-state">Brak wpisow audytu.</div>';
    }

    function bindActionButtons(root) {
        $$('[data-action]', root || document).forEach(function (b) {
            b.onclick = function () {
                var action = b.dataset.action;
                var extra = {};
                if (action === 'giveCash' || action === 'takeCash') extra.amount = Number($('#cashAmount') && $('#cashAmount').value) || 500;
                if (action === 'setAdmin') extra.level = Number($('#adminLevel').value) || 0;
                if (action === 'setHealth') extra.amount = Number($('#healthValue').value) || 100;
                if (action === 'setArmor') extra.amount = Number($('#armorValue').value) || 100;
                if (action === 'setDimension') extra.amount = Number($('#dimValue').value) || 0;
                if (action === 'slap') extra.amount = 10;
                if (action === 'kick') extra.reason = 'Decyzja administracji.';
                if (action === 'announce') extra.message = ($('#announceText').value || '').trim();
                sendAction(action, extra);
            };
        });
    }

    function runCommand() {
        var raw = ($('#commandInput').value || '').trim();
        if (!raw) return;
        var parts = raw.split(/\s+/);
        var cmd = parts.shift().toLowerCase();
        var rest = parts.join(' ');
        var map = { hp: 'heal', heal: 'heal', armor: 'armor', freeze: 'freeze', goto: 'goto', tp: 'goto', bring: 'bring', slap: 'slap', fix: 'fixVehicle' };
        if (map[cmd]) sendAction(map[cmd], cmd === 'slap' ? { amount: Number(rest) || 10 } : {});
        else if (cmd === 'cash') sendAction('giveCash', { amount: Number(parts[0] || rest) || 500 });
        else if (cmd === 'takecash') sendAction('takeCash', { amount: Number(parts[0] || rest) || 500 });
        else if (cmd === 'hp') sendAction('setHealth', { amount: Number(rest) || 100 });
        else if (cmd === 'rank') sendAction('setAdmin', { level: Number(rest) || 0 });
        else if (cmd === 'dim') sendAction('setDimension', { amount: Number(rest) || 0 });
        else if (cmd === 'int') sendAction('setInterior', { amount: Number(rest) || 0 });
        else if (cmd === 'announce') sendAction('announce', { message: rest });
        $('#commandInput').value = '';
    }

    function renderAll() {
        var self = state.data.self || {};
        $('#selfRole').textContent = (self.role || 'Admin') + ' | lvl ' + (self.level || 0);
        renderMetrics(); renderRoster(); renderInspector(); renderPlayersTable(); renderAudit();
        bindActionButtons(document);
    }

    function applyData(data) {
        var previous = selectedSerial();
        state.data = unwrap(data) || state.data;
        if (previous) state.selected = (state.data.players || []).filter(function (p) { return p.serial === previous; })[0] || null;
        renderAll();
    }

    $$('.nav-btn').forEach(function (b) { b.onclick = function () { setMode(b.dataset.mode); }; });
    $('#refresh').onclick = function () { emit('HeavyRPG:UI:admin:request'); };
    $('#close').onclick = function () { emit('HeavyRPG:UI:admin:close'); };
    $('#search').oninput = function () { state.search = this.value || ''; renderRoster(); renderPlayersTable(); };
    $('#runCommand').onclick = runCommand;
    $('#commandInput').onkeydown = function (e) { if (e.key === 'Enter') runCommand(); };
    $('#copySerial').onclick = function () {
        if (!selectedSerial()) return;
        var input = document.createElement('input');
        input.value = selectedSerial(); document.body.appendChild(input); input.select();
        try { document.execCommand('copy'); } catch (e) {}
        input.remove();
    };

    window.HeavyRPGAdmin = { receive: function (packet) {
        packet = unwrap(packet) || {};
        var name = packet.name;
        var detail = unwrap(packet.detail || {});
        if (name === 'admin:open') { state.data.self = detail; renderAll(); }
        if (name === 'admin:data') applyData(detail);
    } };

    setMode('ops');
    renderAll();
}());
