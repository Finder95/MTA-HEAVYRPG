(function () {
    var state = { view: 'home', history: ['home'], number: '555000000', contacts: [], messages: [] };
    function $(selector) { return document.querySelector(selector); }
    function $$(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
    function isArray(value) { return Object.prototype.toString.call(value) === '[object Array]'; }
    function unwrap(value) { if (isArray(value) && value.length === 1 && value[0] && typeof value[0] === 'object') return value[0]; return value; }
    function emit(name, payload) { if (window.mta && typeof window.mta.triggerEvent === 'function') window.mta.triggerEvent(name, JSON.stringify(payload || {})); else console.log('[phone]', name, payload); }
    function digits(value) { return String(value || '').replace(/\D/g, '').slice(0, 12); }

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

    function renderChrome() {
        $('#homeNumber').textContent = state.number || '555000000';
        $('#statusNumber').textContent = state.number || '555000000';
        var d = new Date();
        $('#clock').textContent = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
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
            div.innerHTML = '<small>' + (msg.incoming ? 'Od ' + msg.from : 'Do ' + msg.to) + '</small>' + String(msg.body || '');
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
            row.className = 'contact';
            row.innerHTML = '<span><strong>' + String(contact.name || 'Kontakt') + '</strong><small>' + String(contact.number || '') + '</small></span><button>SMS</button>';
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
        $('#callHint').textContent = 'Laczenie z numerem ' + number + '...';
        emit('HeavyRPG:UI:phone:call', { number: number });
    };
    $('#sendSms').onclick = function () {
        var number = digits($('#smsNumber').value);
        var body = $('#smsBody').value || '';
        if (!number || !body.trim()) return;
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
        }
    };

    setInterval(renderChrome, 10000);
    renderChrome();
    renderMessages();
    renderContacts();
}());