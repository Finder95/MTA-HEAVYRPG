(function () {
    var state = {
        busy: false,
        responseTimer: null,
        config: {
            serverName: 'HeavyRPG',
            minPassword: 8,
            usernameMin: 3,
            usernameMax: 24
        }
    };

    function $(selector) { return document.querySelector(selector); }
    function $$(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
    function isArray(value) { return Object.prototype.toString.call(value) === '[object Array]'; }
    function unwrapMtaJson(value) {
        if (isArray(value) && value.length === 1 && value[0] && typeof value[0] === 'object') return value[0];
        return value;
    }
    function addClass(el, name) { if (el && el.classList) el.classList.add(name); }
    function removeClass(el, name) { if (el && el.classList) el.classList.remove(name); }
    function setActive(el, active) { if (active) addClass(el, 'active'); else removeClass(el, 'active'); }

    var status = $('#status');
    var loginForm = $('#loginForm');
    var registerForm = $('#registerForm');
    var meterBar = $('#meterBar');
    var passwordHint = $('#passwordHint');

    function setStatus(message, type) {
        status.textContent = message || '';
        status.className = 'status ' + (type || 'muted');
    }

    function clearResponseTimer() {
        if (state.responseTimer) {
            clearTimeout(state.responseTimer);
            state.responseTimer = null;
        }
    }

    function setBusy(value) {
        state.busy = value === true;
        $$('button, input').forEach(function (el) { el.disabled = state.busy; });
        if (!state.busy) clearResponseTimer();
    }

    function waitForResponse() {
        clearResponseTimer();
        state.responseTimer = setTimeout(function () {
            setBusy(false);
            setStatus('Serwer nie odpowiedzial. Sprobuj ponownie albo sprawdz konsole serwera.', 'error');
        }, 15000);
    }

    function formData(form) {
        var data = {};
        for (var i = 0; i < form.elements.length; i += 1) {
            var input = form.elements[i];
            if (!input.name) continue;
            if (input.type === 'checkbox') data[input.name] = input.checked;
            else data[input.name] = input.value;
        }
        return data;
    }

    function emit(name, payload) {
        if (!window.mta || typeof window.mta.triggerEvent !== 'function') {
            console.log('[HeavyRPG mock event]', name, payload);
            return false;
        }
        window.mta.triggerEvent(name, JSON.stringify(payload || {}));
        return true;
    }

    function switchTab(name) {
        $$('.tab').forEach(function (tab) { setActive(tab, tab.dataset.tab === name); });
        setActive(loginForm, name === 'login');
        setActive(registerForm, name === 'register');
        setBusy(false);
        setStatus(name === 'login' ? 'Wpisz login i haslo, aby wejsc do gry.' : 'Wpisz login i haslo, aby stworzyc konto.', 'muted');
    }

    function passwordScore(value) {
        var score = 0;
        if (value.length >= state.config.minPassword) score += 40;
        if (/[a-z]/.test(value)) score += 15;
        if (/[A-Z]/.test(value)) score += 15;
        if (/\d/.test(value)) score += 15;
        if (/[^A-Za-z0-9]/.test(value)) score += 15;
        return Math.min(100, score);
    }

    function updatePasswordMeter() {
        var value = registerForm.elements.password.value || '';
        var score = passwordScore(value);
        meterBar.style.width = score + '%';
        passwordHint.textContent = value.length < state.config.minPassword
            ? 'Haslo musi miec minimum ' + state.config.minPassword + ' znakow.'
            : score < 70
                ? 'Haslo jest poprawne, mozesz je wzmocnic cyfra lub znakiem specjalnym.'
                : 'Haslo wyglada dobrze.';
    }

    $$('.tab').forEach(function (tab) {
        tab.onclick = function () { switchTab(tab.dataset.tab); };
    });
    registerForm.elements.password.oninput = updatePasswordMeter;

    loginForm.onsubmit = function (event) {
        if (event && event.preventDefault) event.preventDefault();
        if (state.busy) return false;
        var data = formData(loginForm);
        if (!data.identifier || !data.password) {
            setStatus('Wpisz login oraz haslo.', 'error');
            return false;
        }
        setBusy(true);
        setStatus('Sprawdzam dane logowania...', 'muted');
        if (emit('HeavyRPG:UI:auth:login', data)) waitForResponse();
        else setBusy(false);
        return false;
    };

    registerForm.onsubmit = function (event) {
        if (event && event.preventDefault) event.preventDefault();
        if (state.busy) return false;
        var data = formData(registerForm);
        if (!data.username || !data.password) {
            setStatus('Wpisz login oraz haslo.', 'error');
            return false;
        }
        if (data.password.length < state.config.minPassword) {
            setStatus('Haslo musi miec minimum ' + state.config.minPassword + ' znakow.', 'error');
            return false;
        }
        setBusy(true);
        setStatus('Tworze konto...', 'muted');
        if (emit('HeavyRPG:UI:auth:register', data)) waitForResponse();
        else setBusy(false);
        return false;
    };

    window.HeavyRPG = {
        setConfig: function (config) {
            config = config || {};
            for (var key in config) {
                if (Object.prototype.hasOwnProperty.call(config, key)) state.config[key] = config[key];
            }
            var serverName = $('#serverName');
            if (serverName) serverName.textContent = state.config.serverName || 'HeavyRPG';
            registerForm.elements.username.placeholder = state.config.usernameMin + '-' + state.config.usernameMax + ' znaki';
            registerForm.elements.password.placeholder = 'Minimum ' + state.config.minPassword + ' znakow';
            updatePasswordMeter();
        },

        receive: function (nameOrPacket, detailArg) {
            var packet = unwrapMtaJson(nameOrPacket);
            var name = packet;
            var detail = unwrapMtaJson(detailArg || {});
            if (packet && typeof packet === 'object') {
                name = packet.name;
                detail = unwrapMtaJson(packet.detail || {});
            }
            if (!name) return;

            if (name === 'auth:boot') {
                setStatus('Panel gotowy. Probuje przywrocic sesje...', 'muted');
            }
            if (name === 'auth:show') {
                removeClass(document.body, 'hidden');
                setBusy(false);
                if (detail && detail.reason === 'SESSION_INVALID') {
                    setStatus('Sesja wygasla. Zaloguj sie ponownie.', 'error');
                } else {
                    setStatus('Wpisz login i haslo albo utworz nowe konto.', 'muted');
                }
            }
            if (name === 'auth:hide') {
                clearResponseTimer();
                setStatus('Zalogowano. Wchodzisz do gry...', 'success');
            }
            if (name === 'auth:response') {
                setBusy(false);
                var response = detail.response || {};
                if (detail.ok) {
                    var account = response.payload && response.payload.account;
                    setStatus(account ? 'Witaj, ' + account.username + '. Ladowanie postaci...' : 'Sukces.', 'success');
                } else {
                    setStatus(response.message || 'Operacja nie powiodla sie.', 'error');
                }
            }
        }
    };
}());
