(() => {
    const state = {
        busy: false,
        responseTimer: null,
        config: {
            serverName: 'HeavyRPG',
            minPassword: 8,
            usernameMin: 3,
            usernameMax: 24
        }
    };

    const $ = (selector) => document.querySelector(selector);
    const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

    const status = $('#status');
    const loginForm = $('#loginForm');
    const registerForm = $('#registerForm');
    const meterBar = $('#meterBar');
    const passwordHint = $('#passwordHint');

    function setStatus(message, type = 'muted') {
        status.textContent = message || '';
        status.className = `status ${type}`;
    }

    function clearResponseTimer() {
        if (state.responseTimer) {
            clearTimeout(state.responseTimer);
            state.responseTimer = null;
        }
    }

    function setBusy(value) {
        state.busy = value;
        $$('button, input').forEach((el) => { el.disabled = value; });
        if (!value) clearResponseTimer();
    }

    function waitForResponse() {
        clearResponseTimer();
        state.responseTimer = setTimeout(() => {
            setBusy(false);
            setStatus('Serwer nie odpowiedzial. Sprobuj ponownie albo sprawdz konsole serwera.', 'error');
        }, 15000);
    }

    function formData(form) {
        const data = {};
        new FormData(form).forEach((value, key) => {
            data[key] = value;
        });
        $$('input[type="checkbox"]', form).forEach((input) => {
            data[input.name] = input.checked;
        });
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
        $$('.tab').forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === name));
        loginForm.classList.toggle('active', name === 'login');
        registerForm.classList.toggle('active', name === 'register');
        setBusy(false);
        setStatus(name === 'login' ? 'Wpisz login i haslo, aby wejsc do gry.' : 'Wpisz login i haslo, aby stworzyc konto.', 'muted');
    }

    function passwordScore(value) {
        let score = 0;
        if (value.length >= state.config.minPassword) score += 40;
        if (/[a-z]/.test(value)) score += 15;
        if (/[A-Z]/.test(value)) score += 15;
        if (/\d/.test(value)) score += 15;
        if (/[^A-Za-z0-9]/.test(value)) score += 15;
        return Math.min(100, score);
    }

    function updatePasswordMeter() {
        const value = registerForm.password.value || '';
        const score = passwordScore(value);
        meterBar.style.width = `${score}%`;
        passwordHint.textContent = value.length < state.config.minPassword
            ? `Haslo musi miec minimum ${state.config.minPassword} znakow.`
            : score < 70
                ? 'Haslo jest poprawne, mozesz je wzmocnic cyfra lub znakiem specjalnym.'
                : 'Haslo wyglada dobrze.';
    }

    $$('.tab').forEach((tab) => tab.addEventListener('click', () => switchTab(tab.dataset.tab)));
    registerForm.password.addEventListener('input', updatePasswordMeter);

    loginForm.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;
        const data = formData(loginForm);
        if (!data.identifier || !data.password) {
            setStatus('Wpisz login oraz haslo.', 'error');
            return;
        }
        setBusy(true);
        setStatus('Sprawdzam dane logowania...', 'muted');
        if (emit('HeavyRPG:UI:auth:login', data)) {
            waitForResponse();
        } else {
            setBusy(false);
        }
    });

    registerForm.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;
        const data = formData(registerForm);
        if (!data.username || !data.password) {
            setStatus('Wpisz login oraz haslo.', 'error');
            return;
        }
        if (data.password.length < state.config.minPassword) {
            setStatus(`Haslo musi miec minimum ${state.config.minPassword} znakow.`, 'error');
            return;
        }
        setBusy(true);
        setStatus('Tworze konto...', 'muted');
        if (emit('HeavyRPG:UI:auth:register', data)) {
            waitForResponse();
        } else {
            setBusy(false);
        }
    });

    window.HeavyRPG = {
        setConfig(config) {
            state.config = { ...state.config, ...(config || {}) };
            const serverName = $('#serverName');
            if (serverName) serverName.textContent = state.config.serverName || 'HeavyRPG';
            registerForm.username.placeholder = `${state.config.usernameMin}-${state.config.usernameMax} znaki`;
            registerForm.password.placeholder = `Minimum ${state.config.minPassword} znakow`;
            updatePasswordMeter();
        },

        receive(packet) {
            if (!packet || !packet.name) return;
            const { name, detail } = packet;
            if (name === 'auth:boot') {
                setStatus('Panel gotowy. Probuje przywrocic sesje...', 'muted');
            }
            if (name === 'auth:show') {
                document.body.classList.remove('hidden');
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
                const response = detail.response || {};
                if (detail.ok) {
                    const account = response.payload && response.payload.account;
                    setStatus(account ? `Witaj, ${account.username}. Ladowanie postaci...` : 'Sukces.', 'success');
                } else {
                    setStatus(response.message || 'Operacja nie powiodla sie.', 'error');
                }
            }
        }
    };
})();
