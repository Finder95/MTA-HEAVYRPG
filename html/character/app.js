(() => {
    const state = {
        busy: false,
        skins: [],
        selectedIndex: 0,
        selectedSkin: 0,
        responseTimer: null
    };

    const $ = (selector) => document.querySelector(selector);
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
        [...document.querySelectorAll('button, input')].forEach((el) => { el.disabled = value; });
        if (!value) clearResponseTimer();
    }

    function waitForResponse() {
        clearResponseTimer();
        state.responseTimer = setTimeout(() => {
            setBusy(false);
            setStatus('Serwer nie odpowiedzial. Sprobuj ponownie albo sprawdz konsole.', 'error');
        }, 15000);
    }

    function emit(name, payload) {
        if (!window.mta || typeof window.mta.triggerEvent !== 'function') {
            console.log('[HeavyRPG character mock event]', name, payload);
            return false;
        }
        window.mta.triggerEvent(name, JSON.stringify(payload || {}));
        return true;
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

        list = list.map((skin) => Number(skin)).filter((skin) => Number.isFinite(skin) && skin >= 0);
        if (!list.length) list = [Number(fallback) || 46];
        return list;
    }

    function formatSkin(value) {
        return String(value || 0).padStart(3, '0');
    }

    function updateSkinDisplay(skin) {
        state.selectedSkin = Number(skin) || state.selectedSkin || 0;
        const foundIndex = state.skins.findIndex((item) => Number(item) === state.selectedSkin);
        if (foundIndex >= 0) state.selectedIndex = foundIndex;
        skinId.textContent = formatSkin(state.selectedSkin);
    }

    function selectSkin(index) {
        if (!state.skins.length) return;
        const count = state.skins.length;
        state.selectedIndex = ((index % count) + count) % count;
        updateSkinDisplay(state.skins[state.selectedIndex]);
        emit('HeavyRPG:UI:character:previewSkin', { skin: state.selectedSkin });
    }

    prevSkin.addEventListener('click', () => selectSkin(state.selectedIndex - 1));
    nextSkin.addEventListener('click', () => selectSkin(state.selectedIndex + 1));

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (state.busy) return;

        const data = Object.fromEntries(new FormData(form).entries());
        data.firstname = (data.firstname || '').trim();
        data.lastname = (data.lastname || '').trim();
        data.skin = state.selectedSkin;

        if (data.firstname.length < 3 || data.lastname.length < 3) {
            setStatus('Imie i nazwisko musza miec minimum 3 litery.', 'error');
            return;
        }

        setBusy(true);
        setStatus('Tworze postac...', 'muted');
        if (emit('HeavyRPG:UI:character:create', data)) {
            waitForResponse();
        } else {
            setBusy(false);
        }
    });

    window.HeavyRPGCharacter = {
        receive(packet) {
            if (!packet || !packet.name) return;
            const { name, detail } = packet;

            if (name === 'creator:show') {
                state.skins = normalizeSkins(detail.skins, detail.defaultSkin);
                const defaultSkin = Number(detail.defaultSkin || state.skins[0]);
                const defaultIndex = state.skins.findIndex((skin) => Number(skin) === defaultSkin);
                setBusy(false);
                selectSkin(defaultIndex >= 0 ? defaultIndex : 0);
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
