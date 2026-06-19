(() => {
    const state = {
        busy: false,
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

    function setBusy(value) {
        state.busy = value;
        $$('button, input').forEach((el) => { el.disabled = value; });
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
            return;
        }
        window.mta.triggerEvent(name, JSON.stringify(payload || {}));
    }

    function switchTab(name) {
        $$('.tab').forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === name));
        loginForm.classList.toggle('active', name === 'login');
        registerForm.classList.toggle('active', name === 'register');
        setStatus(name === 'login' ? 'Wpisz dane konta, aby wejsc do gry.' : 'Stworz nowe konto HeavyRPG.', 'muted');
    }

    function passwordScore(value) {
        let score = 0;
        if (value.length >= state.config.minPassword) score += 25;
        if (/[a-z]/.test(value)) score += 18;
        if (/[A-Z]/.test(value)) score += 18;
        if (/\d/.test(value)) score += 18;
        if (/[^A-Za-z0-9]/.test(value)) score += 21;
        return Math.min(100, score);
    }

    function updatePasswordMeter() {
        const value = registerForm.password.value || '';
        const score = passwordScore(value);
        meterBar.style.width = `${score}%`;
        passwordHint.textContent = score < 50
            ? 'Slabe haslo: dodaj dluzszy tekst, cyfry lub znaki specjalne.'
            : score < 80
                ? 'Srednie haslo: mozesz je jeszcze wzmocnic.'
                : 'Mocne haslo.';
    }

    $$('.tab').forEach((tab) => tab.addEventListener('click', () => switchTab(tab.dataset.tab)));
    registerForm.password.addEventListener('input', updatePasswordMeter);

    loginForm.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;
        const data = formData(loginForm);
        if (!data.identifier || !data.password) {
            setStatus('Wpisz login/e-mail oraz haslo.', 'error');
            return;
        }
        setBusy(true);
        setStatus('Sprawdzam dane logowania...', 'muted');
        emit('HeavyRPG:UI:auth:login', data);
    });

    registerForm.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;
        const data = formData(registerForm);
        if (!data.username || !data.email || !data.password || !data.passwordRepeat) {
            setStatus('Uzupelnij wszystkie pola rejestracji.', 'error');
            return;
        }
        if (data.password !== data.passwordRepeat) {
            setStatus('Hasla nie sa takie same.', 'error');
            return;
        }
        setBusy(true);
        setStatus('Tworze konto i hashuje haslo...', 'muted');
        emit('HeavyRPG:UI:auth:register', data);
    });

    window.HeavyRPG = {
        setConfig(config) {
            state.config = { ...state.config, ...(config || {}) };
            $('#serverName').textContent = state.config.serverName || 'HeavyRPG';
            registerForm.username.placeholder = `${state.config.usernameMin}-${state.config.usernameMax} znaki`;
            registerForm.password.placeholder = `Minimum ${state.config.minPassword} znakow`;
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
                    setStatus('Wpisz dane konta lub utworz nowe konto.', 'muted');
                }
            }
            if (name === 'auth:hide') {
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
