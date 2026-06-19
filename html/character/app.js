(() => {
    const state = {
        busy: false,
        skins: [],
        selectedIndex: 0,
        selectedSkin: 0,
        responseTimer: null
    };

    const $ = (selector) => document.querySelector(selector);
    const $$ = (selector, root = document) => Array.prototype.slice.call(root.querySelectorAll(selector));
    const status = $('#status');
    const form = $('#characterForm');
    const skinId = $('#skinId');
    const prevSkin = $('#prevSkin');
    const nextSkin = $('#nextSkin');

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

    function formData(formElement) {
        const data = {};
        new FormData(formElement).forEach((value, key) => {
            data[key] = value;
        });
        return data;
    }

    function emit(name, payload) {
        if (!window.mta || typeof window.mta.triggerEvent !== 'function') {
            console.log('[HeavyRPG character mock event]', name, payload);
            return false;
        }
        window.mta.triggerEvent(name, JSON.stringify(payload || {}));
        return true;
    }

    function isFiniteNumber(value) {
        return typeof value === 'number' && isFinite(value);
    }

    function normalizeSkins(value, fallback) {
        let list = [];
        if (Array.isArray(value)) {
            list = value;
        } else if (value && typeof value === 'object') {
            list = Object.keys(value)
                .sort((a, b) => Number(a) - Number(b))
                .map((key) => value[key]);
        }

        list = list.map((skin) => Number(skin)).filter((skin) => isFiniteNumber(skin) && skin >= 0);
        if (!list.length) list = [isFiniteNumber(Number(fallback)) ? Number(fallback) : 46];
        return list;
    }

    function formatSkin(value) {
        return String(value || 0).padStart(3, '0');
    }

    function updateSkinDisplay(skin) {
        const numericSkin = Number(skin);
        if (!isFiniteNumber(numericSkin)) return;

        state.selectedSkin = numericSkin;
        const foundIndex = state.skins.findIndex((item) => Number(item) === state.selectedSkin);
        if (foundIndex >= 0) state.selectedIndex = foundIndex;
        skinId.textContent = formatSkin(state.selectedSkin);
    }

    function selectSkinOffset(offset) {
        if (state.busy || !state.skins.length) return;

        let nextIndex = state.selectedIndex + offset;
        if (nextIndex < 0) nextIndex = state.skins.length - 1;
        if (nextIndex >= state.skins.length) nextIndex = 0;

        state.selectedIndex = nextIndex;
        updateSkinDisplay(state.skins[nextIndex]);
    }

    prevSkin.addEventListener('click', () => {
        selectSkinOffset(-1);
        emit('HeavyRPG:UI:character:prevSkin', {});
    });

    nextSkin.addEventListener('click', () => {
        selectSkinOffset(1);
        emit('HeavyRPG:UI:character:nextSkin', {});
    });

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;

        const data = formData(form);
        const selectedSkin = Number(state.selectedSkin);
        data.firstname = (data.firstname || '').trim();
        data.lastname = (data.lastname || '').trim();
        data.skin = selectedSkin;

        if (data.firstname.length < 3 || data.lastname.length < 3) {
            setStatus('Imie i nazwisko musza miec minimum 3 litery.', 'error');
            return;
        }

        if (!isFiniteNumber(selectedSkin)) {
            setStatus('Wybierz poprawny skin postaci.', 'error');
            return;
        }

        setBusy(true);
        setStatus('Tworze postac...', 'muted');
        if (emit('HeavyRPG:UI:character:create', data)) {
            waitForResponse();
        } else {
            setBusy(false);
            setStatus('Nie udalo sie polaczyc panelu z gra.', 'error');
        }
    });

    window.HeavyRPGCharacter = {
        receive(packet) {
            if (!packet || !packet.name) return;
            const { name, detail } = packet;

            if (name === 'creator:show') {
                state.skins = normalizeSkins(detail.skins, detail.defaultSkin);
                const defaultSkin = Number(detail.defaultSkin || state.skins[0]);
                setBusy(false);
                updateSkinDisplay(defaultSkin);
                setStatus('Wybierz skin i nadaj postaci imie oraz nazwisko.', 'muted');
            }

            if (name === 'creator:setSkin') {
                updateSkinDisplay(detail.skin);
            }

            if (name === 'creator:response') {
                setBusy(false);
                if (detail.ok) {
                    setStatus(detail.message || 'Postac utworzona.', 'success');
                } else {
                    setStatus(detail.message || 'Nie udalo sie utworzyc postaci.', 'error');
                }
            }
        }
    };
})();
