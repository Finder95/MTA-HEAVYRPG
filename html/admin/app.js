(function () {
    var state = { view: 'overview', data: { players: [], stats: {}, audit: [], self: {} }, selected: null, search: '' };
    var titles = {
        overview: ['Przeglad', 'Stan serwera, gracze online i ostatnie akcje administracji.'],
        players: ['Gracze', 'Pelna lista online, status postaci i szybkie akcje.'],
        economy: ['Ekonomia', 'Gotowka graczy i uprawnienia administracyjne.'],
        audit: ['Audit', 'Ostatnie akcje wykonane przez administracje.'],
        system: ['System', 'Stan gamemode, limity i komendy techniczne.']
    };
    function $(q) { return document.querySelector(q); }
    function $$(q, root) { return Array.prototype.slice.call((root || document).querySelectorAll(q)); }
    function unwrap(v) { return Array.isArray(v) && v.length === 1 && typeof v[0] === 'object' ? v[0] : v; }
    function emit(name, a, b) { if (window.mta && typeof window.mta.triggerEvent === 'function') window.mta.triggerEvent(name, a, b); else console.log('[admin]', name, a, b); }
    function html(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
    function money(v) { return '$' + Math.floor(Number(v) || 0).toLocaleString('en-US'); }
    function time(ts) { var d = new Date((Number(ts) || 0) * 1000); return isNaN(d.getTime()) ? '-' : d.toLocaleString('pl-PL'); }
    function currentPlayers() {
        var q = state.search.toLowerCase();
        return (state.data.players || []).filter(function (p) {
            if (!q) return true;
            return [p.name, p.character, p.accountId, p.characterId, p.serial].join(' ').toLowerCase().indexOf(q) !== -1;
        });
    }
    function select(serial) {
        state.selected = (state.data.players || []).filter(function (p) { return p.serial === serial; })[0] || null;
        renderAll();
    }
    function selectedSerial() { return state.selected && state.selected.serial; }
    function sendAction(action, extra) {
        if (!selectedSerial()) return;
        extra = extra || {};
        extra.serial = selectedSerial();
        emit('HeavyRPG:UI:admin:action', action, JSON.stringify(extra));
    }
    function setView(view) {
        state.view = view;
        $$('.tab').forEach(function (b) { b.classList.toggle('active', b.dataset.view === view); });
        $$('.view').forEach(function (v) { v.classList.toggle('active', v.dataset.view === view); });
        $('#viewTitle').textContent = titles[view][0];
        $('#viewSubtitle').textContent = titles[view][1];
    }
    function renderMetrics() {
        var s = state.data.stats || {};
        $('#metrics').innerHTML = [
            ['Online', s.online || 0], ['Konta', s.accounts || 0], ['Postacie', s.characters || 0], ['Notatki', s.notes || 0]
        ].map(function (m) { return '<div class="metric"><span>' + m[0] + '</span><strong>' + m[1] + '</strong></div>'; }).join('');
    }
    function playerRow(p) {
        return '<div class="player ' + (state.selected && state.selected.serial === p.serial ? 'active' : '') + '" data-serial="' + html(p.serial) + '"><div><strong>' + html(p.name) + '</strong><small>' + html(p.character || '-') + ' | ID konta ' + html(p.accountId || '-') + ' | ping ' + html(p.ping || 0) + '</small></div><span class="badge">' + html(p.adminRole || 'Gracz') + '</span></div>';
    }
    function renderPlayers() {
        var players = currentPlayers();
        $('#onlineCount').textContent = players.length;
        $('#onlineList').innerHTML = players.length ? players.map(playerRow).join('') : '<div class="mutedbox">Brak graczy online.</div>';
        $$('#onlineList .player').forEach(function (el) { el.onclick = function () { select(el.dataset.serial); }; });
        $('#playersTable').innerHTML = players.map(function (p) {
            return '<tr><td>' + html(p.name) + '</td><td>' + html(p.character || '-') + '</td><td>' + html(p.health) + '</td><td>' + html(p.armor) + '</td><td>' + money(p.money) + '</td><td>' + html(p.ping) + '</td><td>' + html(p.adminRole || 'Gracz') + '</td><td><button data-a="heal" data-s="' + html(p.serial) + '">HP</button><button data-a="goto" data-s="' + html(p.serial) + '">TP</button><button data-a="bring" data-s="' + html(p.serial) + '">Bring</button></td></tr>';
        }).join('');
        $$('#playersTable button').forEach(function (b) { b.onclick = function () { select(b.dataset.s); sendAction(b.dataset.a, {}); }; });
    }
    function renderQuickActions() {
        var p = state.selected;
        $('#selectedName').textContent = p ? (p.character || p.name) : 'Brak wyboru';
        if (!p) { $('#quickActions').className = 'actions mutedbox'; $('#quickActions').textContent = 'Wybierz gracza z listy.'; return; }
        $('#quickActions').className = 'actions';
        $('#quickActions').innerHTML = '<button data-action="heal">Ulecz HP</button><button data-action="armor">Daj armor</button><button data-action="freeze">Freeze / unfreeze</button><button data-action="goto">Teleport do gracza</button><button data-action="bring">Przyciagnij gracza</button><button data-action="kick">Kick</button>';
        $$('#quickActions button').forEach(function (b) { b.onclick = function () { sendAction(b.dataset.action, b.dataset.action === 'kick' ? { reason: 'Decyzja administracji.' } : {}); }; });
    }
    function renderAudit() {
        var rows = state.data.audit || [];
        $('#auditLog').innerHTML = rows.length ? rows.map(function (r) {
            return '<div class="audit-row"><span>' + time(r.created_at) + '</span><div><strong>' + html(r.action) + '</strong><br><small>' + html(r.admin_name || '-') + ' -> ' + html(r.target || '-') + '</small></div><code>#' + html(r.id) + '</code></div>';
        }).join('') : '<div class="mutedbox">Brak wpisow audytu.</div>';
    }
    function renderSystem() {
        var s = state.data.stats || {};
        $('#systemState').innerHTML = [
            ['Status panelu', 'aktywny'], ['Poziom sesji', (state.data.self && state.data.self.role) || '-'], ['Graczy online', s.online || 0], ['Limit notatek / postac', '25'], ['Limit notatek globalny', '500']
        ].map(function (row) { return '<div class="system-item"><span>' + html(row[0]) + '</span><strong>' + html(row[1]) + '</strong></div>'; }).join('');
    }
    function renderAll() {
        $('#selfRole').textContent = ((state.data.self && state.data.self.role) || 'Admin') + ' | lvl ' + ((state.data.self && state.data.self.level) || 0);
        renderMetrics(); renderPlayers(); renderQuickActions(); renderAudit(); renderSystem();
    }
    function applyData(data) { state.data = unwrap(data) || state.data; if (state.selected) select(state.selected.serial); else renderAll(); }
    $$('.tab').forEach(function (b) { b.onclick = function () { setView(b.dataset.view); }; });
    $('#refresh').onclick = function () { emit('HeavyRPG:UI:admin:request', {}); };
    $('#close').onclick = function () { emit('HeavyRPG:UI:admin:close', {}); };
    $('#search').oninput = function () { state.search = this.value || ''; renderPlayers(); };
    $$('[data-action]').forEach(function (b) { b.onclick = function () {
        var action = b.dataset.action;
        var extra = {};
        if (action === 'giveCash' || action === 'takeCash') extra.amount = Number($('#cashAmount').value) || 1;
        if (action === 'setAdmin') extra.level = Number($('#adminLevel').value) || 0;
        sendAction(action, extra);
    }; });
    window.HeavyRPGAdmin = { receive: function (packet) { packet = unwrap(packet) || {}; var name = packet.name; var detail = unwrap(packet.detail || {}); if (name === 'admin:open') { state.data.self = detail; renderAll(); } if (name === 'admin:data') applyData(detail); } };
    setView('overview'); renderAll();
}());