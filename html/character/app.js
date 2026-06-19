(function () {
    var fallbackSkins = [46, 47, 48, 60, 98, 101, 170, 171, 180, 184, 185, 186, 187, 188, 227, 240, 250, 261];
    var fallbackStats = {
        points: 24,
        min: 1,
        max: 8,
        attributes: [
            { id: 'strength', label: 'Sila', description: 'Walka, noszenie i ciezkie prace.' },
            { id: 'endurance', label: 'Wytrzymalosc', description: 'Sprint, odpornosc i dluzsze zmiany.' },
            { id: 'agility', label: 'Zrecznosc', description: 'Prowadzenie, refleks i precyzja.' },
            { id: 'intelligence', label: 'Inteligencja', description: 'Nauka, crafting i specjalizacje.' },
            { id: 'charisma', label: 'Charyzma', description: 'Negocjacje, reputacja i frakcje.' },
            { id: 'focus', label: 'Opanowanie', description: 'Presja, stres i ryzykowne akcje.' }
        ]
    };

    var state = {
        busy: false,
        view: 'slots',
        characters: [],
        maxSlots: 3,
        canCreate: true,
        skins: fallbackSkins.slice(0),
        selectedIndex: 0,
        selectedSkin: 46,
        genders: [
            { id: 'male', label: 'Mezczyzna' },
            { id: 'female', label: 'Kobieta' },
            { id: 'other', label: 'Inna' }
        ],
        age: { min: 18, max: 65, default: 24 },
        origins: [],
        archetypes: [],
        statsConfig: fallbackStats,
        stats: {},
        responseTimer: null
    };

    function $(selector) { return document.querySelector(selector); }
    function $$(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
    function isArray(value) { return Object.prototype.toString.call(value) === '[object Array]'; }
    function isFiniteNumber(value) { return typeof value === 'number' && isFinite(value); }
    function unwrapMtaJson(value) {
        if (isArray(value) && value.length === 1 && value[0] && typeof value[0] === 'object') return value[0];
        return value;
    }

    var panelTitle = $('#panelTitle');
    var panelLead = $('#panelLead');
    var tabSlots = $('#tabSlots');
    var tabCreate = $('#tabCreate');
    var slotsView = $('#slotsView');
    var createView = $('#createView');
    var slotCount = $('#slotCount');
    var newCharacter = $('#newCharacter');
    var characterSlots = $('#characterSlots');
    var status = $('#status');
    var form = $('#characterForm');
    var skinId = $('#skinId');
    var prevSkin = $('#prevSkin');
    var nextSkin = $('#nextSkin');
    var genderSelect = $('#genderSelect');
    var ageInput = $('#ageInput');
    var originSelect = $('#originSelect');
    var archetypeSelect = $('#archetypeSelect');
    var choiceHint = $('#choiceHint');
    var statsList = $('#statsList');
    var pointsLeft = $('#pointsLeft');

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
        $$('button, input, select').forEach(function (el) { el.disabled = state.busy; });
        if (!state.busy) clearResponseTimer();
        renderControls();
    }

    function waitForResponse() {
        clearResponseTimer();
        state.responseTimer = setTimeout(function () {
            setBusy(false);
            setStatus('Serwer nie odpowiedzial. Sprobuj ponownie albo sprawdz konsole serwera.', 'error');
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

    function normalizeList(value, fallback) {
        value = unwrapMtaJson(value);
        if (isArray(value)) return value;
        if (value && typeof value === 'object') {
            return Object.keys(value).sort(function (a, b) { return Number(a) - Number(b); }).map(function (key) { return value[key]; });
        }
        return fallback || [];
    }

    function normalizeSkins(value, fallback) {
        var list = normalizeList(value, fallbackSkins).map(function (skin) { return Number(skin); }).filter(function (skin) {
            return isFiniteNumber(skin) && skin >= 0;
        });
        if (!list.length) list = fallbackSkins.slice(0);
        var fallbackSkin = Number(fallback);
        if (isFiniteNumber(fallbackSkin) && list.indexOf(fallbackSkin) === -1) list.unshift(fallbackSkin);
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

    function setView(view) {
        state.view = view;
        tabSlots.classList.toggle('active', view === 'slots');
        tabCreate.classList.toggle('active', view === 'create');
        slotsView.classList.toggle('active', view === 'slots');
        createView.classList.toggle('active', view === 'create');
        panelTitle.textContent = view === 'slots' ? 'Twoje postacie' : 'Nowa postac';
        panelLead.textContent = view === 'slots'
            ? 'Wybierz istniejaca postac albo stworz nowa karte obywatela Los Santos.'
            : 'Zbuduj profil HeavyRPG: tozsamosc, pochodzenie, archetyp i statystyki startowe.';
        renderControls();
    }

    function renderControls() {
        var full = state.characters.length >= state.maxSlots;
        tabCreate.disabled = state.busy || full;
        newCharacter.disabled = state.busy || full;
        if (full && state.view === 'create') setView('slots');
    }

    function optionLabel(item) { return item && (item.label || item.id) || ''; }
    function optionValue(item) { return item && (item.id || item.label) || ''; }

    function fillSelect(select, items) {
        select.innerHTML = '';
        for (var i = 0; i < items.length; i += 1) {
            var opt = document.createElement('option');
            opt.value = optionValue(items[i]);
            opt.textContent = optionLabel(items[i]);
            select.appendChild(opt);
        }
    }

    function getById(items, id) {
        for (var i = 0; i < items.length; i += 1) {
            if (optionValue(items[i]) === id) return items[i];
        }
        return null;
    }

    function updateChoiceHint() {
        var origin = getById(state.origins, originSelect.value);
        var archetype = getById(state.archetypes, archetypeSelect.value);
        var parts = [];
        if (origin && origin.description) parts.push(origin.description);
        if (archetype && archetype.bonus) parts.push(archetype.bonus);
        choiceHint.textContent = parts.join(' ');
    }

    function statSum() {
        var sum = 0;
        var attrs = state.statsConfig.attributes || [];
        for (var i = 0; i < attrs.length; i += 1) sum += Number(state.stats[attrs[i].id]) || 0;
        return sum;
    }

    function renderStats() {
        var attrs = state.statsConfig.attributes || [];
        var total = Number(state.statsConfig.points) || 24;
        var left = total - statSum();
        pointsLeft.textContent = left === 0 ? '0 wolnych' : (left > 0 ? '+' + left + ' wolnych' : left + ' ponad limit');
        pointsLeft.className = left === 0 ? 'ok' : 'warn';
        statsList.innerHTML = '';

        for (var i = 0; i < attrs.length; i += 1) {
            (function (attr) {
                var row = document.createElement('div');
                row.className = 'stat-row';
                var info = document.createElement('div');
                info.className = 'stat-info';
                info.innerHTML = '<strong>' + attr.label + '</strong><span>' + (attr.description || '') + '</span>';
                var controls = document.createElement('div');
                controls.className = 'stat-controls';
                var minus = document.createElement('button');
                minus.type = 'button';
                minus.textContent = '-';
                var value = document.createElement('b');
                value.textContent = String(state.stats[attr.id] || 0);
                var plus = document.createElement('button');
                plus.type = 'button';
                plus.textContent = '+';
                minus.onclick = function () { adjustStat(attr.id, -1); };
                plus.onclick = function () { adjustStat(attr.id, 1); };
                controls.appendChild(minus);
                controls.appendChild(value);
                controls.appendChild(plus);
                row.appendChild(info);
                row.appendChild(controls);
                statsList.appendChild(row);
            }(attrs[i]));
        }
    }

    function resetStats() {
        var attrs = state.statsConfig.attributes || [];
        var total = Number(state.statsConfig.points) || 24;
        var min = Number(state.statsConfig.min) || 1;
        var base = Math.floor(total / Math.max(1, attrs.length));
        state.stats = {};
        for (var i = 0; i < attrs.length; i += 1) state.stats[attrs[i].id] = Math.max(min, base);
        var diff = total - statSum();
        var index = 0;
        while (diff !== 0 && attrs.length) {
            var id = attrs[index % attrs.length].id;
            state.stats[id] += diff > 0 ? 1 : -1;
            diff += diff > 0 ? -1 : 1;
            index += 1;
        }
        renderStats();
    }

    function adjustStat(id, delta) {
        if (state.busy) return;
        var min = Number(state.statsConfig.min) || 1;
        var max = Number(state.statsConfig.max) || 8;
        var total = Number(state.statsConfig.points) || 24;
        var current = Number(state.stats[id]) || min;
        if (delta > 0 && statSum() >= total) return;
        var next = current + delta;
        if (next < min || next > max) return;
        state.stats[id] = next;
        renderStats();
    }

    function renderSlots() {
        characterSlots.innerHTML = '';
        slotCount.textContent = state.characters.length + '/' + state.maxSlots + ' sloty';

        if (!state.characters.length) {
            var empty = document.createElement('div');
            empty.className = 'empty-slot';
            empty.innerHTML = '<strong>Brak postaci</strong><span>Stworz pierwsza postac i rozpocznij historie w HeavyRPG.</span>';
            characterSlots.appendChild(empty);
            setView('create');
            return;
        }

        for (var i = 0; i < state.characters.length; i += 1) {
            (function (character) {
                var card = document.createElement('button');
                card.className = 'slot-card';
                card.type = 'button';
                var stats = character.stats || {};
                card.innerHTML = '<span class="slot-skin">' + formatSkin(character.skin) + '</span>'
                    + '<strong>' + character.firstname + ' ' + character.lastname + '</strong>'
                    + '<small>' + (character.age || 18) + ' lat · ' + (character.archetype || 'worker') + '</small>'
                    + '<em>STR ' + (stats.strength || 4) + ' / END ' + (stats.endurance || 4) + ' / AGI ' + (stats.agility || 4) + '</em>';
                card.onclick = function () { selectCharacter(character.id); };
                characterSlots.appendChild(card);
            }(state.characters[i]));
        }

        var missing = state.maxSlots - state.characters.length;
        if (missing > 0) {
            var add = document.createElement('button');
            add.className = 'slot-card add';
            add.type = 'button';
            add.innerHTML = '<strong>+ Nowa postac</strong><small>Wolne sloty: ' + missing + '</small>';
            add.onclick = function () { setView('create'); };
            characterSlots.appendChild(add);
        }
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

    function selectCharacter(id) {
        if (state.busy) return;
        setBusy(true);
        setStatus('Laduje wybrana postac...', 'muted');
        if (emit('HeavyRPG:UI:character:select', { id: id })) waitForResponse();
        else {
            setBusy(false);
            setStatus('Nie udalo sie polaczyc panelu z gra.', 'error');
        }
    }

    prevSkin.addEventListener('click', function () { selectSkinOffset(-1); emit('HeavyRPG:UI:character:prevSkin', {}); });
    nextSkin.addEventListener('click', function () { selectSkinOffset(1); emit('HeavyRPG:UI:character:nextSkin', {}); });
    tabSlots.addEventListener('click', function () { setView('slots'); });
    tabCreate.addEventListener('click', function () { setView('create'); });
    newCharacter.addEventListener('click', function () { setView('create'); });
    originSelect.addEventListener('change', updateChoiceHint);
    archetypeSelect.addEventListener('change', updateChoiceHint);

    form.addEventListener('submit', function (event) {
        event.preventDefault();
        if (state.busy) return;

        var data = {};
        new FormData(form).forEach(function (value, key) { data[key] = value; });
        data.firstname = (data.firstname || '').trim();
        data.lastname = (data.lastname || '').trim();
        data.age = Number(data.age);
        data.skin = Number(state.selectedSkin);
        data.stats = state.stats;

        if (data.firstname.length < 3 || data.lastname.length < 3) {
            setStatus('Imie i nazwisko musza miec minimum 3 litery.', 'error');
            return;
        }
        if (!isFiniteNumber(data.skin)) {
            setStatus('Wybierz poprawny skin postaci.', 'error');
            return;
        }
        if (statSum() !== (Number(state.statsConfig.points) || 24)) {
            setStatus('Rozdziel dokladnie wszystkie punkty statystyk.', 'error');
            return;
        }

        setBusy(true);
        setStatus('Tworze pelna karte postaci...', 'muted');
        if (emit('HeavyRPG:UI:character:create', data)) waitForResponse();
        else {
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
                state.characters = normalizeList(detail.characters, []);
                state.maxSlots = Number(detail.maxSlots) || 3;
                state.canCreate = detail.canCreate !== false;
                state.skins = normalizeSkins(detail.skins, detail.defaultSkin);
                state.genders = normalizeList(detail.genders, state.genders);
                state.age = detail.age || state.age;
                state.origins = normalizeList(detail.origins, state.origins);
                state.archetypes = normalizeList(detail.archetypes, state.archetypes);
                state.statsConfig = detail.stats || fallbackStats;
                ageInput.min = state.age.min || 18;
                ageInput.max = state.age.max || 65;
                ageInput.value = state.age.default || 24;
                fillSelect(genderSelect, state.genders);
                fillSelect(originSelect, state.origins);
                fillSelect(archetypeSelect, state.archetypes);
                resetStats();
                setBusy(false);
                updateSkinDisplay(Number(detail.defaultSkin || state.skins[0] || 46));
                renderSlots();
                updateChoiceHint();
                setStatus('Wybierz postac albo przygotuj nowa.', 'muted');
            }

            if (name === 'creator:setSkin') updateSkinDisplay(detail.skin);

            if (name === 'creator:response') {
                setBusy(false);
                if (detail.ok) setStatus(detail.message || 'Postac gotowa.', 'success');
                else setStatus(detail.message || 'Nie udalo sie wykonac operacji.', 'error');
            }
        }
    };

    updateSkinDisplay(state.selectedSkin);
    fillSelect(genderSelect, state.genders);
    resetStats();
    renderSlots();
}());
