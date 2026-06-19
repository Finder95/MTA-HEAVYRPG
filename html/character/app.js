(function () {
    var fallbackSkins = [46, 47, 48, 60, 98, 101, 170, 171, 180, 184, 185, 186, 187, 188, 227, 240, 250, 261];
    var state = {
        busy: false,
        skins: fallbackSkins.slice(0),
        selectedIndex: 0,
        selectedSkin: 46,
        responseTimer: null
    };

    function $(selector) { return document.querySelector(selector); }
    function $$(selector, root) {
        return Array.prototype.slice.call((root || document).querySelectorAll(selector));
    }

    var status = $('#status');
    var form = $('#characterForm');
    var skinId = $('#skinId');
    var prevSkin = $('#prevSkin');
    var nextSkin = $('#nextSkin');

    function isArray(value) {
        return Object.prototype.toString.call(value) === '[object Array]';
    }

    function unwrapMtaJson(value) {
        if (isArray(value) && value.length === 1 && value[0] && typeof value[0] === 'object') {
            return value[0];
        }
        return value;
    }

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

    function formData(formElement) {
        var data = {};
        new FormData(formElement).forEach(function (value, key) {
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
        var list = [];
        var key;

        value = unwrapMtaJson(value);

        if (isArray(value)) {
            list = value;
        } else if (value && typeof value === 'object') {
            var keys = Object.keys(value).sort(function (a, b) { return Number(a) - Number(b); });
            for (var i = 0; i < keys.length; i += 1) {
                key = keys[i];
                list.push(value[key]);
            }
        }

        list = list.map(function (skin) { return Number(skin); }).filter(function (skin) {
            return isFiniteNumber(skin) && skin >= 0;
        });

        if (!list.length) {
            list = fallbackSkins.slice(0);
        }

        var fallbackSkin = Number(fallback);
        if (isFiniteNumber(fallbackSkin) && list.indexOf(fallbackSkin) === -1) {
            list.unshift(fallbackSkin);
        }

        return list;
    }

    function formatSkin(value) {
        var text = String(value || 0);
        while (text.length < 3) text = '0' + text;
        return text;
    }

    function updateSkinDisplay(skin) {
        var numericSkin = Number(skin);
        if (!isFiniteNumber(numericSkin)) return;

        state.selectedSkin = numericSkin;
        for (var i = 0; i < state.skins.length; i += 1) {
            if (Number(state.skins[i]) === state.selectedSkin) {
                state.selectedIndex = i;
                break;
            }
        }
        skinId.textContent = formatSkin(state.selectedSkin);
    }

    function selectSkinOffset(offset) {
        if (state.busy) return;
        if (!state.skins.length) state.skins = fallbackSkins.slice(0);

        var nextIndex = state.selectedIndex + offset;
        if (nextIndex < 0) nextIndex = state.skins.length - 1;
        if (nextIndex >= state.skins.length) nextIndex = 0;

        state.selectedIndex = nextIndex;
        updateSkinDisplay(state.skins[nextIndex]);
    }

    prevSkin.addEventListener('click', function () {
        selectSkinOffset(-1);
        emit('HeavyRPG:UI:character:prevSkin', {});
    });

    nextSkin.addEventListener('click', function () {
        selectSkinOffset(1);
        emit('HeavyRPG:UI:character:nextSkin', {});
    });

    form.addEventListener('submit', function (event) {
        event.preventDefault();
        if (state.busy) return;

        var data = formData(form);
        var selectedSkin = Number(state.selectedSkin);
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
        receive: function (nameOrPacket, detailArg) {
            var packet = unwrapMtaJson(nameOrPacket);
            var name = packet;
            var detail = unwrapMtaJson(detailArg || {});

            if (packet && typeof packet === 'object') {
                name = packet.name;
                detail = unwrapMtaJson(packet.detail || {});
            }

            if (!name) return;

            if (name === 'creator:show') {
                state.skins = normalizeSkins(detail.skins, detail.defaultSkin);
                setBusy(false);
                updateSkinDisplay(Number(detail.defaultSkin || state.skins[0] || 46));
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

    updateSkinDisplay(state.selectedSkin);
}());
