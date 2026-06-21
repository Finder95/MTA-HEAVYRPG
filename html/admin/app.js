(function () {
    var state = { mode: 'ops', data: { players: [], stats: {}, audit: [], punishments: [], items: [], world: {}, self: {} }, selected: null, search: '' };
    var titles = {
        ops: 'Operacje live', players: 'Gracze online', moderation: 'Moderacja', punishments: 'Kary i blokady', teleports: 'Teleporty', vehicles: 'Pojazdy',
        character: 'Postac', survival: 'Survival', inventory: 'Inventory', bank: 'Bank i payday', world: 'Swiat serwera', audit: 'Audit administracji'
    };
    var globalActions = { announce: true, setWeather: true, setTime: true };

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
    function num(id, fallback) { var el = $('#' + id); var value = Number(el && el.value); return isNaN(value) ? (fallback || 0) : value; }
    function text(id, fallback) { var el = $('#' + id); return ((el && el.value) || fallback || '').trim(); }
    function money(v) { return '$' + Math.floor(Number(v) || 0).toLocaleString('en-US'); }
    function pct(v) { v = Math.max(0, Math.min(100, Number(v) || 0)); return Math.floor(v); }
    function shortSerial(v) { v = String(v || ''); return v ? v.slice(0, 6) + '...' + v.slice(-5) : '-'; }
    function time(ts) { var d = new Date((Number(ts) || 0) * 1000); return isNaN(d.getTime()) ? '-' : d.toLocaleString('pl-PL'); }
    function playtime(sec) { sec = Math.max(0, Math.floor(Number(sec) || 0)); var h = Math.floor(sec / 3600); var m = Math.floor((sec % 3600) / 60); return h + 'h ' + m + 'm'; }
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
        if (!globalActions[action]) {
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
        var list = [['Online', s.online || 0], ['Konta', s.accounts || 0], ['Postacie', s.characters || 0], ['Staff', s.staff || 0], ['Kary', s.punishments || 0], ['Dropy', s.drops || 0], ['Pojazdy', s.vehicles || 0]];
        $('#metrics').innerHTML = list.map(function (m) { return '<div class="metric"><span>' + html(m[0]) + '</span><strong>' + html(m[1]) + '</strong></div>'; }).join('');
        $('#railOnline').textContent = s.online || 0;
        $('#railStaff').textContent = s.staff || 0;
        $('#railPunishments').textContent = s.punishments || 0;
        $('#railDrops').textContent = s.drops || 0;
    }

    function playerCard(p) {
        var active = state.selected && state.selected.serial === p.serial ? ' active' : '';
        var flag = p.muted ? '<span class="chip bad">mute</span>' : (p.frozen ? '<span class="chip bad">freeze</span>' : '<span class="chip good">live</span>');
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

    function detail(label, value) { return '<div class="detail"><span>' + html(label) + '</span><strong>' + html(value) + '</strong></div>'; }

    function renderInspector() {
        var p = state.selected;
        $('#selectedName').textContent = p ? (p.character || p.name) : 'Nie wybrano celu';
        $('#targetHint').textContent = p ? ('Cel: ' + (p.character || p.name) + ' | ' + shortSerial(p.serial)) : 'Brak wybranego gracza';
        if (!p) { $('#inspector').className = 'empty-state'; $('#inspector').innerHTML = 'Wybierz gracza z rosteru.'; return; }
        var pos = p.position || {}, needs = p.needs || {};
        $('#inspector').className = '';
        $('#inspector').innerHTML = '' +
            '<div class="identity"><div><h3>' + html(p.character || p.name) + '</h3><p>' + html(p.name) + ' | konto #' + html(p.accountId || '-') + ' | postac #' + html(p.characterId || '-') + '</p></div><span class="chip">' + html(p.adminRole || 'Gracz') + '</span></div>' +
            '<div class="vitals">' + vital('HP', p.health) + vital('Armor', p.armor, 'armor') + vital('Glod', needs.hunger, 'warn') + vital('Pragn.', needs.thirst, 'warn') + vital('Stres', needs.stress, 'bad') + '</div>' +
            '<div class="detail-grid">' + detail('Cash', money(p.money)) + detail('Bank', money(p.bank)) + detail('Ping', (p.ping || 0) + ' ms') + detail('Skin', p.skin || '-') + detail('Freeze/Mute', (p.frozen ? 'freeze ' : '') + (p.muted ? 'mute' : '')) + detail('Pojazd', p.vehicle || 'pieszo') + detail('Dim / Int', (p.dimension || 0) + ' / ' + (p.interior || 0)) + detail('Pozycja X/Y/Z', [pos.x || 0, pos.y || 0, pos.z || 0].join(' / ')) + '</div>' +
            '<div class="action-grid"><button data-action="heal">HP 100</button><button data-action="armor">Armor 100</button><button data-action="freeze">Freeze</button><button data-action="goto">Idz do</button><button data-action="bring">Przyciagnij</button><button data-action="fixVehicle">Napraw pojazd</button><button data-action="slap">Slap</button><button data-action="giveCash">+ cash</button><button data-action="takeCash">- cash</button><button data-action="kick" class="danger">Kick</button></div>';
        bindActionButtons($('#inspector'));
    }

    function renderPlayersTable() {
        var list = players();
        $('#playersTable').innerHTML = list.length ? list.map(function (p) {
            return '<tr><td>' + html(p.name) + '</td><td>' + html(p.character || '-') + '</td><td>' + html(p.health) + '</td><td>' + html(p.armor) + '</td><td>' + html(p.skin || '-') + '</td><td>' + money(p.money) + '</td><td>' + money(p.bank) + '</td><td>' + html((p.dimension || 0) + ' / ' + (p.interior || 0)) + '</td><td>' + html(p.ping || 0) + '</td><td><button data-serial="' + html(p.serial) + '" data-a="heal">HP</button><button data-serial="' + html(p.serial) + '" data-a="goto">TP</button><button data-serial="' + html(p.serial) + '" data-a="bring">Bring</button></td></tr>';
        }).join('') : '<tr><td colspan="10">Brak graczy.</td></tr>';
        $$('#playersTable button').forEach(function (b) { b.onclick = function () { select(b.dataset.serial); sendAction(b.dataset.a, {}); }; });
    }

    function renderLists() {
        renderAudit(); renderPunishments(); renderStatePanels(); renderItemOptions();
    }

    function renderAudit() {
        var rows = state.data.audit || [];
        $('#auditCompact').innerHTML = rows.slice(0, 8).map(function (r) { return '<div class="timeline-row"><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + html(shortSerial(r.target || '')) + '</span><span>' + time(r.created_at) + '</span></div>'; }).join('') || '<div class="empty-state">Brak wpisow audytu.</div>';
        $('#auditLog').innerHTML = rows.map(function (r) { return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + html(r.target || '-') + '</span><span>' + html(r.detail_json || '{}') + '</span></div><code>#' + html(r.id) + '</code></div>'; }).join('') || '<div class="empty-state">Brak wpisow audytu.</div>';
    }

    function renderPunishments() {
        var rows = state.data.punishments || [];
        $('#punishmentLog').innerHTML = rows.map(function (r) { return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.type) + ' | ' + html(r.target_name || '-') + '</strong><span>' + html(r.reason || '-') + '</span><span>Admin: ' + html(r.admin_name || '-') + ' | wygasa: ' + html(r.expires_at ? time(r.expires_at) : 'nigdy') + '</span></div><code>#' + html(r.id) + '</code></div>'; }).join('') || '<div class="empty-state">Brak kar.</div>';
    }

    function row(label, value) { return '<div class="system-item"><span>' + html(label) + '</span><strong>' + html(value) + '</strong></div>'; }
    function renderStatePanels() {
        var p = state.selected || {}, needs = p.needs || {}, stats = p.stats || {}, world = state.data.world || {};
        $('#vehicleState').innerHTML = row('Pojazd celu', p.vehicle || 'pieszo') + row('Dimension', p.dimension || 0) + row('Interior', p.interior || 0);
        $('#characterState').innerHTML = row('Skin', p.skin || '-') + row('Playtime', playtime(p.playtime)) + row('Sila', stats.strength || 0) + row('Wytrzymalosc', stats.endurance || 0) + row('Zrecznosc', stats.agility || 0) + row('Inteligencja', stats.intelligence || 0) + row('Charyzma', stats.charisma || 0) + row('Opanowanie', stats.focus || 0);
        $('#needsState').innerHTML = row('Glod', pct(needs.hunger)) + row('Pragnienie', pct(needs.thirst)) + row('Energia', pct(needs.energy)) + row('Higiena', pct(needs.hygiene)) + row('Stres', pct(needs.stress));
        $('#inventoryState').innerHTML = row('Dostepne definicje', (state.data.items || []).length) + row('Dropy w swiecie', (state.data.stats && state.data.stats.drops) || 0) + row('Notatki w swiecie', (state.data.stats && state.data.stats.notes) || 0);
        $('#worldState').innerHTML = row('Pogoda', world.weather || 0) + row('Czas', (world.hour || 0) + ':' + String(world.minute || 0).padStart(2, '0')) + row('Game speed', world.gameSpeed || 1);
    }

    function renderItemOptions() {
        var items = (state.data.items || []).filter(function (i) { return i.id !== 'cash'; });
        var options = items.map(function (i) { return '<option value="' + html(i.id) + '">' + html(i.id + ' - ' + i.label) + '</option>'; }).join('');
        if ($('#itemId') && $('#itemId').innerHTML !== options) $('#itemId').innerHTML = options;
        if ($('#takeItemId') && $('#takeItemId').innerHTML !== options) $('#takeItemId').innerHTML = options;
    }

    function bindActionButtons(root) {
        $$('[data-action]', root || document).forEach(function (b) {
            b.onclick = function () { sendAction(b.dataset.action, payloadFor(b.dataset.action)); };
        });
        $$('[data-preset-need]', root || document).forEach(function (b) {
            b.onclick = function () { applyNeedPreset(b.dataset.presetNeed); };
        });
    }

    function payloadFor(action) {
        var extra = {};
        if (action === 'giveCash' || action === 'takeCash') extra.amount = num('cashAmount', 500);
        if (action === 'setBank') extra.amount = num('bankAmount', 0);
        if (action === 'payday') extra.periods = num('paydayPeriods', 1);
        if (action === 'setAdmin') extra.level = num('adminLevel', 0);
        if (action === 'setHealth') extra.amount = num('healthValue', 100);
        if (action === 'setArmor') extra.amount = num('armorValue', 100);
        if (action === 'setDimension') extra.amount = num('dimValue', 0);
        if (action === 'setInterior') extra.amount = num('intValue', 0);
        if (action === 'teleportCoords') { extra.x = num('tpX', 0); extra.y = num('tpY', 0); extra.z = num('tpZ', 3); extra.dimension = num('tpDim', 0); extra.interior = num('tpInt', 0); }
        if (action === 'slap') extra.amount = 10;
        if (action === 'kick') extra.reason = 'Decyzja administracji.';
        if (action === 'warn') extra.reason = text('warnReason', 'Ostrzezenie administracji.');
        if (action === 'mute') { extra.reason = text('muteReason', 'Mute administracji.'); extra.duration = num('muteMinutes', 30) * 60; }
        if (action === 'tempBan') { extra.reason = text('banReason', 'Tymczasowa blokada administracyjna.'); extra.duration = num('banHours', 24) * 3600; }
        if (action === 'announce') extra.message = text('announceText', '');
        if (action === 'spawnVehicle') { extra.model = num('vehicleModel', 411); extra.warp = !!($('#vehicleWarp') && $('#vehicleWarp').checked); }
        if (action === 'setSkin') extra.amount = num('skinValue', 46);
        if (action === 'setStat') { extra.key = $('#statKey').value; extra.amount = num('statValue', 1); }
        if (action === 'setNeed') { extra.key = $('#needKey').value; extra.amount = num('needValue', 100); }
        if (action === 'addItem') { extra.itemId = $('#itemId').value; extra.quantity = num('itemQty', 1); extra.quality = num('itemQuality', 100); }
        if (action === 'takeItem') { extra.itemId = $('#takeItemId').value; extra.quantity = num('takeItemQty', 1); }
        if (action === 'setWeather') extra.amount = num('weatherValue', 0);
        if (action === 'setTime') { extra.hour = num('worldHour', 12); extra.minute = num('worldMinute', 0); }
        return extra;
    }

    function applyNeedPreset(name) {
        var presets = { healthy: { hunger: 100, thirst: 100, energy: 100, hygiene: 100, stress: 0 }, tired: { hunger: 55, thirst: 45, energy: 12, hygiene: 35, stress: 45 }, critical: { hunger: 5, thirst: 5, energy: 4, hygiene: 10, stress: 95 } };
        var preset = presets[name] || presets.healthy;
        Object.keys(preset).forEach(function (key) { sendAction('setNeed', { key: key, amount: preset[key] }); });
    }

    function runCommand() {
        var raw = ($('#commandInput').value || '').trim(); if (!raw) return;
        var parts = raw.split(/\s+/); var cmd = parts.shift().toLowerCase(); var rest = parts.join(' ');
        var map = { heal: 'heal', armor: 'armor', freeze: 'freeze', unfreeze: 'unfreeze', goto: 'goto', tp: 'goto', bring: 'bring', slap: 'slap', fix: 'fixVehicle', flip: 'flipVehicle', kick: 'kick' };
        if (map[cmd]) sendAction(map[cmd], cmd === 'slap' ? { amount: Number(rest) || 10 } : {});
        else if (cmd === 'cash') sendAction('giveCash', { amount: Number(parts[0] || rest) || 500 });
        else if (cmd === 'takecash') sendAction('takeCash', { amount: Number(parts[0] || rest) || 500 });
        else if (cmd === 'bank') sendAction('setBank', { amount: Number(parts[0] || rest) || 0 });
        else if (cmd === 'rank') sendAction('setAdmin', { level: Number(rest) || 0 });
        else if (cmd === 'dim') sendAction('setDimension', { amount: Number(rest) || 0 });
        else if (cmd === 'int') sendAction('setInterior', { amount: Number(rest) || 0 });
        else if (cmd === 'skin') sendAction('setSkin', { amount: Number(rest) || 46 });
        else if (cmd === 'veh') sendAction('spawnVehicle', { model: Number(rest) || 411, warp: true });
        else if (cmd === 'item') sendAction('addItem', { itemId: parts[0] || 'water_bottle', quantity: Number(parts[1]) || 1, quality: 100 });
        else if (cmd === 'need') sendAction('setNeed', { key: parts[0] || 'hunger', amount: Number(parts[1]) || 100 });
        else if (cmd === 'announce') sendAction('announce', { message: rest });
        $('#commandInput').value = '';
    }

    function renderAll() {
        var self = state.data.self || {};
        $('#selfRole').textContent = (self.role || 'Admin') + ' | lvl ' + (self.level || 0);
        renderMetrics(); renderRoster(); renderInspector(); renderPlayersTable(); renderLists(); bindActionButtons(document);
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
        var input = document.createElement('input'); input.value = selectedSerial(); document.body.appendChild(input); input.select(); try { document.execCommand('copy'); } catch (e) {} input.remove();
    };

    window.HeavyRPGAdmin = { receive: function (packet) {
        packet = unwrap(packet) || {}; var name = packet.name; var detail = unwrap(packet.detail || {});
        if (name === 'admin:open') { state.data.self = detail; renderAll(); }
        if (name === 'admin:data') applyData(detail);
    } };

    setMode('ops'); renderAll();
}());
