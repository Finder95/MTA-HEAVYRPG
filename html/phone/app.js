(function () {
    var state = {
        view: 'home',
        history: ['home'],
        number: '555000000',
        contacts: [],
        messages: [],
        time: null,
        settings: { theme: 'forest', volume: 75, ringtone: 'classic', airplane: false, animations: true }
    };
    var themes = [
        { id: 'night', label: 'Noc' },
        { id: 'forest', label: 'Las' },
        { id: 'city', label: 'Miasto' },
        { id: 'clean', label: 'Czysty' }
    ];
    function $(selector) { return document.querySelector(selector); }
    function $$(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
    function isArray(value) { return Object.prototype.toString.call(value) === '[object Array]'; }
    function unwrap(value) { if (isArray(value) && value.length === 1 && value[0] && typeof value[0] === 'object') return value[0]; return value; }
    function emit(name, payload) { if (window.mta && typeof window.mta.triggerEvent === 'function') window.mta.triggerEvent(name, JSON.stringify(payload || {})); else console.log('[phone]', name, payload); }
    function digits(value) { return String(value || '').replace(/\D/g, '').slice(0, 12); }
    function pad(value) { value = String(value || 0); return value.length < 2 ? '0' + value : value; }
    function escapeHtml(value) {
        return String(value || '').replace(/[&<>"']/g, function (ch) {
            return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
        });
    }

    function loadSettings() {
        try {
            var saved = JSON.parse(localStorage.getItem('hrp-phone-settings') || '{}');
            Object.keys(saved).forEach(function (key) { if (state.settings.hasOwnProperty(key)) state.settings[key] = saved[key]; });
        } catch (e) {}
    }

    function saveSettings() {
        try { localStorage.setItem('hrp-phone-settings', JSON.stringify(state.settings)); } catch (e) {}
    }

    function setView(view, push) {
        view = view || 'home';
        state.view = view;
        $$('.view').forEach(function (el) { el.classList.toggle('active', el.dataset.view === view); });
        if (push !== false && state.history[state.history.length - 1] !== view) state.history.push(view);
    }

    function goBack() {
        if (state.history.length > 1) state.history.pop();
        setView(state.history[state.history.length - 1] || 'home', false);
    }

    function applySettings() {
        var screen = $('#screen');
        if (screen) {
            screen.className = 'screen theme-' + state.settings.theme + (state.settings.animations ? '' : ' no-motion');
        }
        $('#statusIcons').textContent = state.settings.airplane ? 'AIR' : 'LTE ' + String(state.settings.volume || 0) + '%';
        $$('.theme-dot').forEach(function (button) { button.classList.toggle('active', button.dataset.theme === state.settings.theme); });
        var volume = $('#volumeRange');
        var ringtone = $('#ringtoneSelect');
        var airplane = $('#airplaneToggle');
        var animations = $('#animationsToggle');
        if (volume) volume.value = state.settings.volume;
        if (ringtone) ringtone.value = state.settings.ringtone;
        if (airplane) airplane.checked = state.settings.airplane === true;
        if (animations) animations.checked = state.settings.animations !== false;
    }

    function setTheme(theme) {
        state.settings.theme = theme || 'forest';
        saveSettings();
        applySettings();
    }

    function renderThemes() {
        var row = $('#themeRow');
        if (!row) return;
        row.innerHTML = '';
        themes.forEach(function (theme) {
            var button = document.createElement('button');
            button.className = 'theme-dot theme-' + theme.id + '-dot';
            button.dataset.theme = theme.id;
            button.title = theme.label;
            button.onclick = function () { setTheme(theme.id); };
            row.appendChild(button);
        });
        applySettings();
    }

    function bindSettings() {
        $('#volumeRange').oninput = function () { state.settings.volume = Number(this.value) || 0; saveSettings(); applySettings(); };
        $('#ringtoneSelect').onchange = function () { state.settings.ringtone = this.value || 'classic'; saveSettings(); applySettings(); };
        $('#airplaneToggle').onchange = function () { state.settings.airplane = this.checked === true; saveSettings(); applySettings(); };
        $('#animationsToggle').onchange = function () { state.settings.animations = this.checked === true; saveSettings(); applySettings(); };
    }

    function renderChrome() {
        var time = state.time || {};
        var hour = typeof time.hour === 'number' ? time.hour : 0;
        var minute = typeof time.minute === 'number' ? time.minute : 0;
        $('#clock').textContent = pad(hour) + ':' + pad(minute);
        $('#timezone').textContent = time.timezone || 'CEST';
        applySettings();
    }

    function renderMessages() {
        var box = $('#messages');
        box.innerHTML = '';
        if (!state.messages.length) {
            box.innerHTML = '<div class="msg"><small>System</small>Brak wiadomosci.</div>';
            return;
        }
        state.messages.slice(0, 20).forEach(function (msg) {
            var div = document.createElement('div');
            div.className = 'msg ' + (msg.incoming ? 'in' : 'out');
            var caption = msg.incoming ? 'Od ' + String(msg.from || '') : 'Do ' + String(msg.to || '');
            div.innerHTML = '<small>' + escapeHtml(caption) + '</small>' + escapeHtml(msg.body || '');
            box.appendChild(div);
        });
    }

    function renderContacts() {
        var box = $('#contacts');
        box.innerHTML = '';
        if (!state.contacts.length) {
            box.innerHTML = '<div class="contact"><span>Brak kontaktow</span></div>';
            return;
        }
        state.contacts.forEach(function (contact) {
            var row = document.createElement('div');
            row.className = 'contact' + (contact.system ? ' system' : '') + (contact.placeholder ? ' placeholder' : '');
            row.innerHTML = '<span><strong>' + escapeHtml(contact.name || 'Kontakt') + '</strong><small>' + escapeHtml(contact.number || '') + '</small></span><button>SMS</button>';
            row.querySelector('button').onclick = function () {
                $('#smsNumber').value = contact.number || '';
                setView('sms');
            };
            box.appendChild(row);
        });
    }

    function applyData(data) {
        data = unwrap(data) || {};
        state.number = data.number || state.number;
        state.contacts = isArray(data.contacts) ? data.contacts : [];
        state.messages = isArray(data.messages) ? data.messages : [];
        state.time = data.time || state.time;
        renderChrome();
        renderMessages();
        renderContacts();
    }

    $$('.app, [data-open]').forEach(function (button) {
        button.onclick = function () { setView(button.dataset.open); };
    });

    ['1','2','3','4','5','6','7','8','9','*','0','#'].forEach(function (key) {
        var btn = document.createElement('button');
        btn.textContent = key;
        btn.onclick = function () { $('#callNumber').value += key; };
        $('#dialPad').appendChild(btn);
    });

    $('#callButton').onclick = function () {
        var number = digits($('#callNumber').value);
        if (!number) return;
        if (state.settings.airplane) { $('#callHint').textContent = 'Tryb samolotowy jest wlaczony.'; return; }
        $('#callHint').textContent = 'Laczenie z numerem ' + number + '...';
        emit('HeavyRPG:UI:phone:call', { number: number });
    };
    $('#sendSms').onclick = function () {
        var number = digits($('#smsNumber').value);
        var body = $('#smsBody').value || '';
        if (!number || !body.trim()) return;
        if (state.settings.airplane) { $('#smsBody').value = 'Tryb samolotowy jest wlaczony.'; return; }
        emit('HeavyRPG:UI:phone:sendSms', { number: number, body: body });
        $('#smsBody').value = '';
    };
    $('#addContact').onclick = function () {
        var name = $('#contactName').value || '';
        var number = digits($('#contactNumber').value);
        if (!name.trim() || !number) return;
        emit('HeavyRPG:UI:phone:addContact', { name: name, number: number });
        $('#contactName').value = '';
        $('#contactNumber').value = '';
    };
    $('#selfieButton').onclick = function () {
        $('#selfieStatus').textContent = 'Robie selfie...';
        emit('HeavyRPG:UI:phone:selfie', {});
    };
    $('#backButton').onclick = goBack;
    $('#homeButton').onclick = function () { setView('home'); };
    $('#recentButton').onclick = function () { setView('recent'); };
    $('#powerButton').onclick = function () { emit('HeavyRPG:UI:phone:close', {}); };
    $('#volumeButton').onclick = function () { emit('HeavyRPG:UI:phone:request', {}); };

    window.HeavyRPGPhone = {
        receive: function (packet) {
            packet = unwrap(packet) || {};
            var name = packet.name;
            var detail = unwrap(packet.detail || {});
            if (name === 'phone:open') { applyData(detail); setView('home', false); }
            if (name === 'phone:data') applyData(detail);
            if (name === 'phone:callStatus') $('#callHint').textContent = detail.message || 'Polaczenie zakonczone.';
            if (name === 'phone:selfieStatus') $('#selfieStatus').textContent = detail.message || 'Selfie zapisane.';
            if (name === 'phone:back') goBack();
        }
    };

    loadSettings();
    renderThemes();
    bindSettings();
    renderChrome();
    renderMessages();
    renderContacts();
    setInterval(function () { emit('HeavyRPG:UI:phone:request', {}); }, 60000);
}());