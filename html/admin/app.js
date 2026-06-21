(function () {
    var state = { mode: 'ops', selected: null, search: '', data: { players: [], stats: {}, audit: [], punishments: [], items: [], world: {}, self: {} }, advanced: { notes: [], watchlist: [], flags: {}, server: {} } };
    var titles = { ops: 'Operacje live', players: 'Gracze online', observe: 'Obserwacja', moderation: 'Moderacja', staff: 'Staff', notes: 'Notatki staff', watchlist: 'Watchlist', punishments: 'Kary i blokady', teleports: 'Teleporty', vehicles: 'Pojazdy', character: 'Postac', survival: 'Survival', inventory: 'Inventory', bank: 'Bank i payday', world: 'Swiat serwera', dev: 'Dev tools', audit: 'Audit administracji' };
    var globalActions = { announce: true, setWeather: true, setTime: true };
    var globalAdvanced = { stopSpectate: true, staffDuty: true, vanish: true, godmode: true, setGravity: true, setGameSpeed: true };

    function $(q) { return document.querySelector(q); }
    function $$(q, root) { return Array.prototype.slice.call((root || document).querySelectorAll(q)); }
    function unwrap(v) { return Array.isArray(v) && v.length === 1 && typeof v[0] === 'object' ? v[0] : v; }
    function arg(v) { return v && typeof v === 'object' ? JSON.stringify(v) : v; }
    function emit(name, a, b) { if (window.mta && typeof window.mta.triggerEvent === 'function') { if (typeof b !== 'undefined') window.mta.triggerEvent(name, arg(a), arg(b)); else if (typeof a !== 'undefined') window.mta.triggerEvent(name, arg(a)); else window.mta.triggerEvent(name); } else console.log('[admin]', name, a, b); }
    function html(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
    function num(id, fallback) { var el = $('#' + id); var value = Number(el && el.value); return isNaN(value) ? (fallback || 0) : value; }
    function text(id, fallback) { var el = $('#' + id); return ((el && el.value) || fallback || '').trim(); }
    function money(v) { return '$' + Math.floor(Number(v) || 0).toLocaleString('en-US'); }
    function pct(v) { return Math.max(0, Math.min(100, Math.floor(Number(v) || 0))); }
    function shortSerial(v) { v = String(v || ''); return v ? v.slice(0, 6) + '...' + v.slice(-5) : '-'; }
    function time(ts) { var d = new Date((Number(ts) || 0) * 1000); return isNaN(d.getTime()) ? '-' : d.toLocaleString('pl-PL'); }
    function playtime(sec) { sec = Math.max(0, Math.floor(Number(sec) || 0)); return Math.floor(sec / 3600) + 'h ' + Math.floor((sec % 3600) / 60) + 'm'; }
    function selectedSerial() { return state.selected && state.selected.serial; }
    function playerDisplayName(p) { return (p && (p.character || p.name)) || '-'; }
    function playerTechName(p) { return (p && (p.mtaName || p.name)) || '-'; }

    function players() { var q = state.search.toLowerCase(); return (state.data.players || []).filter(function (p) { if (!q) return true; return [p.name, p.mtaName, p.character, p.accountId, p.characterId, p.serial, p.adminRole].join(' ').toLowerCase().indexOf(q) !== -1; }); }
    function select(serial) { state.selected = (state.data.players || []).filter(function (p) { return p.serial === serial; })[0] || null; renderAll(); }
    function row(label, value) { return '<div class="system-item"><span>' + html(label) + '</span><strong>' + html(value) + '</strong></div>'; }
    function detail(label, value) { return '<div class="detail"><span>' + html(label) + '</span><strong>' + html(value) + '</strong></div>'; }
    function vital(label, value, type) { value = pct(value); return '<div class="vital"><span>' + html(label) + '</span><div class="bar"><div class="fill ' + (type || '') + '" style="width:' + value + '%"></div></div><strong>' + value + '</strong></div>'; }

    function riskScore(p) {
        if (!p) return { score: 0, label: 'brak celu', reasons: [] };
        var score = 0, reasons = [], needs = p.needs || {};
        if ((p.ping || 0) > 180) { score += 10; reasons.push('wysoki ping'); }
        if (p.muted || p.frozen) { score += 14; reasons.push('aktywny stan administracyjny'); }
        if (pct(needs.stress) > 80) { score += 12; reasons.push('wysoki stres postaci'); }
        if (pct(needs.hunger) < 12 || pct(needs.thirst) < 12) { score += 10; reasons.push('krytyczne potrzeby'); }
        if (watchFor(p.serial)) { score += 25; reasons.push('watchlista'); }
        var punish = (state.data.punishments || []).filter(function (r) { return r.target_serial === p.serial; }).length;
        if (punish > 0) { score += Math.min(25, punish * 8); reasons.push('historia kar: ' + punish); }
        score = Math.min(100, score);
        return { score: score, label: score >= 60 ? 'wysokie' : (score >= 30 ? 'srednie' : 'niskie'), reasons: reasons };
    }

    function watchFor(serial) { return (state.advanced.watchlist || []).filter(function (w) { return w.target_serial === serial; })[0]; }
    function targetNotes(serial) { return (state.advanced.notes || []).filter(function (n) { return n.target_serial === serial; }); }

    function sendAction(action, extra) { extra = extra || {}; if (!globalActions[action]) { if (!selectedSerial()) return; extra.serial = selectedSerial(); } emit('HeavyRPG:UI:admin:action', action, extra); }
    function sendAdvanced(action, extra) { extra = extra || {}; if (!globalAdvanced[action]) { if (!selectedSerial()) return; extra.serial = selectedSerial(); } emit('HeavyRPG:UI:admin:advanced', action, extra); }

    function setMode(mode) { state.mode = mode; $$('.nav-btn').forEach(function (b) { b.classList.toggle('active', b.dataset.mode === mode); }); $$('.mode').forEach(function (v) { v.classList.toggle('active', v.dataset.mode === mode); }); $('#screenTitle').textContent = titles[mode] || 'Staff Command'; }

    function renderMetrics() {
        var s = state.data.stats || {}, watch = (state.advanced.watchlist || []).length;
        var list = [['Online', s.online || 0], ['Konta', s.accounts || 0], ['Postacie', s.characters || 0], ['Staff', s.staff || 0], ['Kary', s.punishments || 0], ['Watch', watch], ['Pojazdy', s.vehicles || 0]];
        $('#metrics').innerHTML = list.map(function (m) { return '<div class="metric"><span>' + html(m[0]) + '</span><strong>' + html(m[1]) + '</strong></div>'; }).join('');
        $('#railOnline').textContent = s.online || 0; $('#railStaff').textContent = s.staff || 0; $('#railPunishments').textContent = s.punishments || 0; $('#railWatch').textContent = watch;
    }

    function renderRoster() {
        var list = players(); $('#onlineCount').textContent = list.length + ' graczy';
        $('#playerList').innerHTML = list.length ? list.map(function (p) { var active = state.selected && state.selected.serial === p.serial ? ' active' : ''; var risk = riskScore(p); var flag = watchFor(p.serial) ? '<span class="chip bad">watch</span>' : (p.muted ? '<span class="chip bad">mute</span>' : (p.frozen ? '<span class="chip bad">freeze</span>' : '<span class="chip good">' + risk.label + '</span>')); return '<button class="player-card' + active + '" data-serial="' + html(p.serial) + '"><div><strong>' + html(playerDisplayName(p)) + '</strong><small>Nick MTA: ' + html(playerTechName(p)) + ' | ' + shortSerial(p.serial) + ' | ping ' + html(p.ping || 0) + '</small></div>' + flag + '</button>'; }).join('') : '<div class="empty-state">Brak graczy pasujacych do filtra.</div>';
        $$('#playerList .player-card').forEach(function (el) { el.onclick = function () { select(el.dataset.serial); }; });
    }

    function renderInspector() {
        var p = state.selected; $('#selectedName').textContent = p ? playerDisplayName(p) : 'Nie wybrano celu'; $('#targetHint').textContent = p ? ('Cel: ' + playerDisplayName(p) + ' | ' + shortSerial(p.serial)) : 'Brak wybranego gracza';
        if (!p) { $('#inspector').className = 'empty-state'; $('#inspector').innerHTML = 'Wybierz gracza z rosteru.'; return; }
        var pos = p.position || {}, needs = p.needs || {}, risk = riskScore(p);
        $('#inspector').className = ''; $('#inspector').innerHTML = '<div class="identity"><div><h3>' + html(playerDisplayName(p)) + '</h3><p>Nick MTA: ' + html(playerTechName(p)) + ' | konto #' + html(p.accountId || '-') + ' | postac #' + html(p.characterId || '-') + '</p></div><span class="chip ' + (risk.score > 55 ? 'bad' : 'good') + '">risk ' + risk.score + '</span></div>' + '<div class="vitals">' + vital('HP', p.health) + vital('Armor', p.armor, 'armor') + vital('Glod', needs.hunger, 'warn') + vital('Pragn.', needs.thirst, 'warn') + vital('Stres', needs.stress, 'bad') + '</div>' + '<div class="detail-grid">' + detail('Cash', money(p.money)) + detail('Bank', money(p.bank)) + detail('Staff role', p.adminRole || 'Gracz') + detail('Skin', p.skin || '-') + detail('Freeze/Mute', (p.frozen ? 'freeze ' : '') + (p.muted ? 'mute' : 'czysto')) + detail('Pojazd', p.vehicle || 'pieszo') + detail('Dim / Int', (p.dimension || 0) + ' / ' + (p.interior || 0)) + detail('Pozycja', [pos.x || 0, pos.y || 0, pos.z || 0].join(' / ')) + '</div>' + '<div class="action-grid"><button data-advanced="spectate">Spectate</button><button data-action="goto">Idz do</button><button data-action="bring">Przyciagnij</button><button data-action="heal">HP</button><button data-action="armor">Armor</button><button data-action="freeze">Freeze</button><button data-advanced="addWatch">Watch</button><button data-advanced="addStaffNote">Note</button><button data-action="kick" class="danger">Kick</button></div>';
        bindButtons($('#inspector'));
    }

    function renderPlayersTable() {
        var heads = $$('[data-mode="players"] th'); if (heads[0]) heads[0].textContent = 'Postac'; if (heads[1]) heads[1].textContent = 'Nick MTA';
        var list = players(); $('#playersTable').innerHTML = list.length ? list.map(function (p) { var r = riskScore(p); return '<tr><td>' + html(playerDisplayName(p)) + '</td><td>' + html(playerTechName(p)) + '</td><td>' + html(p.health) + '</td><td>' + html(p.armor) + '</td><td>' + money(p.money) + '</td><td>' + money(p.bank) + '</td><td>' + html((p.dimension || 0) + ' / ' + (p.interior || 0)) + '</td><td>' + html(r.score + ' ' + r.label) + '</td><td><button data-serial="' + html(p.serial) + '" data-a="spectate" data-adv="1">Spec</button><button data-serial="' + html(p.serial) + '" data-a="goto">TP</button><button data-serial="' + html(p.serial) + '" data-a="bring">Bring</button></td></tr>'; }).join('') : '<tr><td colspan="9">Brak graczy.</td></tr>';
        $$('#playersTable button').forEach(function (b) { b.onclick = function () { select(b.dataset.serial); b.dataset.adv ? sendAdvanced(b.dataset.a, {}) : sendAction(b.dataset.a, {}); }; });
    }

    function renderStatePanels() {
        var p = state.selected || {}, needs = p.needs || {}, stats = p.stats || {}, world = state.data.world || {}, adv = state.advanced || {}, server = adv.server || {}, flags = adv.flags || {}, risk = riskScore(p), staff = (state.data.players || []).filter(function (x) { return (x.adminLevel || 0) > 0; });
        $('#riskState').innerHTML = row('Poziom', risk.label + ' (' + risk.score + ')') + row('Powody', risk.reasons.join(', ') || 'brak');
        $('#vehicleState').innerHTML = row('Pojazd celu', p.vehicle || 'pieszo') + row('Dimension', p.dimension || 0) + row('Interior', p.interior || 0);
        $('#characterState').innerHTML = row('Skin', p.skin || '-') + row('Playtime', playtime(p.playtime)) + row('Sila', stats.strength || 0) + row('Wytrzymalosc', stats.endurance || 0) + row('Zrecznosc', stats.agility || 0) + row('Inteligencja', stats.intelligence || 0) + row('Charyzma', stats.charisma || 0) + row('Opanowanie', stats.focus || 0);
        $('#needsState').innerHTML = row('Glod', pct(needs.hunger)) + row('Pragnienie', pct(needs.thirst)) + row('Energia', pct(needs.energy)) + row('Higiena', pct(needs.hygiene)) + row('Stres', pct(needs.stress));
        $('#inventoryState').innerHTML = row('Definicje itemow', (state.data.items || []).length) + row('Dropy', (state.data.stats && state.data.stats.drops) || 0) + row('Notatki swiata', (state.data.stats && state.data.stats.notes) || 0);
        $('#worldState').innerHTML = row('Pogoda', world.weather || 0) + row('Czas', (world.hour || 0) + ':' + String(world.minute || 0).padStart(2, '0')) + row('Game speed', world.gameSpeed || 1);
        $('#advancedState').innerHTML = row('Vanish', flags.vanished ? 'ON' : 'OFF') + row('Godmode', flags.godmode ? 'ON' : 'OFF') + row('Gravity', server.gravity || '-') + row('Game speed', server.gameSpeed || '-');
        $('#staffState').innerHTML = staff.length ? staff.map(function (s) { return row(playerDisplayName(s), (s.adminRole || 'Staff') + ' | lvl ' + (s.adminLevel || 0)); }).join('') : '<div class="empty-state">Brak staff online.</div>';
    }

    function renderLogs() {
        var audit = state.data.audit || [], punish = state.data.punishments || [], notes = state.advanced.notes || [], watch = state.advanced.watchlist || [], serial = selectedSerial();
        $('#auditCompact').innerHTML = audit.slice(0, 8).map(function (r) { return '<div class="timeline-row"><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + shortSerial(r.target || '') + '</span><span>' + time(r.created_at) + '</span></div>'; }).join('') || '<div class="empty-state">Brak audytu.</div>';
        $('#auditLog').innerHTML = audit.map(function (r) { return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.action) + '</strong><span>' + html(r.admin_name || '-') + ' -> ' + html(r.target || '-') + '</span><span>' + html(r.detail_json || '{}') + '</span></div><code>#' + html(r.id) + '</code></div>'; }).join('') || '<div class="empty-state">Brak audytu.</div>';
        $('#punishmentLog').innerHTML = punish.map(function (r) { return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.type) + ' | ' + html(r.target_name || '-') + '</strong><span>' + html(r.reason || '-') + '</span><span>Admin: ' + html(r.admin_name || '-') + ' | wygasa: ' + html(r.expires_at ? time(r.expires_at) : 'nigdy') + '</span></div><code>#' + html(r.id) + '</code></div>'; }).join('') || '<div class="empty-state">Brak kar.</div>';
        $('#staffNotesLog').innerHTML = notes.map(noteRow).join('') || '<div class="empty-state">Brak notatek.</div>';
        $('#targetNotes').innerHTML = serial ? targetNotes(serial).map(noteRow).join('') || '<div class="empty-state">Brak notatek celu.</div>' : '<div class="empty-state">Wybierz gracza.</div>';
        $('#watchList').innerHTML = watch.map(function (w) { return '<div class="audit-row"><span>prio ' + html(w.priority || 1) + '</span><div><strong>' + html(w.target_name || '-') + '</strong><span>' + html(w.reason || '-') + '</span><span>' + time(w.updated_at) + '</span></div><code>' + shortSerial(w.target_serial) + '</code></div>'; }).join('') || '<div class="empty-state">Watchlista pusta.</div>';
        var tw = serial && watchFor(serial); $('#targetWatch').innerHTML = tw ? row('Status', 'na watch') + row('Priorytet', tw.priority || 1) + row('Powod', tw.reason || '-') : row('Status', serial ? 'brak watch' : 'brak celu');
    }
    function noteRow(n) { return '<div class="audit-row"><span>' + time(n.created_at) + '</span><div><strong>' + html(n.target_name || '-') + '</strong><span>' + html(n.note || '-') + '</span><span>Admin: ' + html(n.admin_name || '-') + '</span></div><code>#' + html(n.id) + '</code></div>'; }

    function renderItemOptions() { var items = (state.data.items || []).filter(function (i) { return i.id !== 'cash'; }); var options = items.map(function (i) { return '<option value="' + html(i.id) + '">' + html(i.id + ' - ' + i.label) + '</option>'; }).join(''); if ($('#itemId') && $('#itemId').innerHTML !== options) $('#itemId').innerHTML = options; if ($('#takeItemId') && $('#takeItemId').innerHTML !== options) $('#takeItemId').innerHTML = options; }

    function payloadFor(action) {
        var extra = {};
        if (action === 'giveCash' || action === 'takeCash') extra.amount = num('cashAmount', 500);
        if (action === 'setBank') extra.amount = num('bankAmount', 0);
        if (action === 'payday') extra.periods = num('paydayPeriods', 1);
        if (action === 'setAdmin') extra.level = num('adminLevel', 0);
        if (action === 'setDimension') extra.amount = num('dimValue', 0); if (action === 'setInterior') extra.amount = num('intValue', 0);
        if (action === 'teleportCoords') { extra.x = num('tpX', 0); extra.y = num('tpY', 0); extra.z = num('tpZ', 3); extra.dimension = num('tpDim', 0); extra.interior = num('tpInt', 0); }
        if (action === 'slap') extra.amount = 10; if (action === 'kick') extra.reason = 'Decyzja administracji.';
        if (action === 'warn') extra.reason = text('warnReason', 'Ostrzezenie administracji.');
        if (action === 'mute') { extra.reason = text('muteReason', 'Mute administracji.'); extra.duration = num('muteMinutes', 30) * 60; }
        if (action === 'tempBan') { extra.reason = text('jailReason', 'Tymczasowa blokada administracyjna.'); extra.duration = num('banHours', 24) * 3600; }
        if (action === 'announce') extra.message = text('announceText', '');
        if (action === 'spawnVehicle') { extra.model = num('vehicleModel', 411); extra.warp = !!($('#vehicleWarp') && $('#vehicleWarp').checked); }
        if (action === 'setSkin') extra.amount = num('skinValue', 46);
        if (action === 'setStat') { extra.key = $('#statKey').value; extra.amount = num('statValue', 1); }
        if (action === 'setNeed') { extra.key = $('#needKey').value; extra.amount = num('needValue', 100); }
        if (action === 'addItem') { extra.itemId = $('#itemId').value; extra.quantity = num('itemQty', 1); extra.quality = num('itemQuality', 100); }
        if (action === 'takeItem') { extra.itemId = $('#takeItemId').value; extra.quantity = num('takeItemQty', 1); }
        if (action === 'setWeather') extra.amount = num('weatherValue', 0); if (action === 'setTime') { extra.hour = num('worldHour', 12); extra.minute = num('worldMinute', 0); }
        return extra;
    }
    function advancedPayload(action) { var extra = {}; if (action === 'addStaffNote') extra.note = text('staffNote', 'Szybka notatka staff z panelu.'); if (action === 'addWatch') { extra.reason = text('watchReason', text('watchReasonQuick', 'Wymaga obserwacji staff.')); extra.priority = num('watchPriority', 3); } if (action === 'jail') { extra.minutes = num('jailMinutes', 10); extra.reason = text('jailReason', 'Decyzja administracji.'); } if (action === 'setGravity') extra.value = num('gravityValue', 0.008); if (action === 'setGameSpeed') extra.value = num('gameSpeedValue', 1); return extra; }

    function bindButtons(root) { $$('[data-action]', root || document).forEach(function (b) { b.onclick = function () { sendAction(b.dataset.action, payloadFor(b.dataset.action)); }; }); $$('[data-advanced]', root || document).forEach(function (b) { b.onclick = function () { sendAdvanced(b.dataset.advanced, advancedPayload(b.dataset.advanced)); }; }); $$('[data-preset-need]', root || document).forEach(function (b) { b.onclick = function () { var presets = { healthy: { hunger: 100, thirst: 100, energy: 100, hygiene: 100, stress: 0 }, tired: { hunger: 55, thirst: 45, energy: 12, hygiene: 35, stress: 45 }, critical: { hunger: 5, thirst: 5, energy: 4, hygiene: 10, stress: 95 } }; var preset = presets[b.dataset.presetNeed] || presets.healthy; Object.keys(preset).forEach(function (key) { sendAction('setNeed', { key: key, amount: preset[key] }); }); }; }); }

    function runCommand() { var raw = ($('#commandInput').value || '').trim(); if (!raw) return; var parts = raw.split(/\s+/), cmd = parts.shift().toLowerCase(), rest = parts.join(' '); var map = { heal: 'heal', armor: 'armor', freeze: 'freeze', unfreeze: 'unfreeze', goto: 'goto', tp: 'goto', bring: 'bring', slap: 'slap', fix: 'fixVehicle', flip: 'flipVehicle', kick: 'kick' }; if (map[cmd]) sendAction(map[cmd], {}); else if (cmd === 'spec') sendAdvanced('spectate', {}); else if (cmd === 'duty') sendAdvanced('staffDuty', {}); else if (cmd === 'vanish') sendAdvanced('vanish', {}); else if (cmd === 'god') sendAdvanced('godmode', {}); else if (cmd === 'jail') sendAdvanced('jail', { minutes: Number(parts[0] || rest) || 10, reason: 'Komenda z panelu' }); else if (cmd === 'cash') sendAction('giveCash', { amount: Number(parts[0] || rest) || 500 }); else if (cmd === 'bank') sendAction('setBank', { amount: Number(parts[0] || rest) || 0 }); else if (cmd === 'rank') sendAction('setAdmin', { level: Number(rest) || 0 }); else if (cmd === 'veh') sendAction('spawnVehicle', { model: Number(rest) || 411, warp: true }); else if (cmd === 'item') sendAction('addItem', { itemId: parts[0] || 'water_bottle', quantity: Number(parts[1]) || 1, quality: 100 }); else if (cmd === 'need') sendAction('setNeed', { key: parts[0] || 'hunger', amount: Number(parts[1]) || 100 }); else if (cmd === 'announce') sendAction('announce', { message: rest }); $('#commandInput').value = ''; }

    function renderAll() { var self = state.data.self || {}; $('#selfRole').textContent = (self.role || 'Admin') + ' | lvl ' + (self.level || 0); renderMetrics(); renderRoster(); renderInspector(); renderPlayersTable(); renderStatePanels(); renderLogs(); renderItemOptions(); bindButtons(document); }
    function applyData(data) { var previous = selectedSerial(); state.data = unwrap(data) || state.data; if (previous) state.selected = (state.data.players || []).filter(function (p) { return p.serial === previous; })[0] || null; renderAll(); }
    function applyAdvanced(data) { state.advanced = unwrap(data) || state.advanced; renderAll(); }

    $$('.nav-btn').forEach(function (b) { b.onclick = function () { setMode(b.dataset.mode); }; });
    $('#refresh').onclick = function () { emit('HeavyRPG:UI:admin:request'); };
    $('#close').onclick = function () { emit('HeavyRPG:UI:admin:close'); };
    $('#search').oninput = function () { state.search = this.value || ''; renderRoster(); renderPlayersTable(); };
    $('#runCommand').onclick = runCommand; $('#commandInput').onkeydown = function (e) { if (e.key === 'Enter') runCommand(); };
    $('#copySerial').onclick = function () { if (!selectedSerial()) return; var input = document.createElement('input'); input.value = selectedSerial(); document.body.appendChild(input); input.select(); try { document.execCommand('copy'); } catch (e) {} input.remove(); };
    window.HeavyRPGAdmin = { receive: function (packet) { packet = unwrap(packet) || {}; var name = packet.name, detail = unwrap(packet.detail || {}); if (name === 'admin:open') { state.data.self = detail; renderAll(); } if (name === 'admin:data') applyData(detail); if (name === 'admin:advancedData') applyAdvanced(detail); } };
    setMode('ops'); renderAll();
}());
