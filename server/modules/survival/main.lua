HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Survival = HRP.Survival or {}
local Survival = HRP.Survival

local states = {}
local tickTimer = nil

local function clamp(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function copyDefaults()
    local defaults = (HRP.Config.survival and HRP.Config.survival.defaults) or {}
    return {
        hunger = clamp(defaults.hunger or 92),
        thirst = clamp(defaults.thirst or 88),
        energy = clamp(defaults.energy or 86),
        hygiene = clamp(defaults.hygiene or 75),
        stress = clamp(defaults.stress or 8),
        ticks = 0
    }
end

local function normalizeNeeds(needs)
    local state = copyDefaults()
    needs = type(needs) == "table" and needs or {}

    state.hunger = clamp(needs.hunger or state.hunger)
    state.thirst = clamp(needs.thirst or state.thirst)
    state.energy = clamp(needs.energy or state.energy)
    state.hygiene = clamp(needs.hygiene or state.hygiene)
    state.stress = clamp(needs.stress or state.stress)
    return state
end

local function publicState(state)
    return {
        hunger = clamp(state and state.hunger),
        thirst = clamp(state and state.thirst),
        energy = clamp(state and state.energy),
        hygiene = clamp(state and state.hygiene),
        stress = clamp(state and state.stress)
    }
end

local function getCharacterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function movementSpeed(player)
    local vx, vy, vz = getElementVelocity(player)
    return ((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0) + (vz or 0) * (vz or 0)) ^ 0.5
end

local function setPlayerNeedsData(player, state)
    local public = publicState(state)
    setElementData(player, "hrp:needs", public, false)
    triggerClientEvent(player, "HeavyRPG:Survival:sync", resourceRoot, public)
end

function Survival.sync(player)
    if not isElement(player) then return false end
    local state = states[player]
    if not state then return false end
    setPlayerNeedsData(player, state)
    return true
end

function Survival.save(player)
    if not isElement(player) then return false end
    local state = states[player]
    local characterId = getCharacterId(player)
    if not state or not characterId then return false end

    return HRP.DB.exec([[UPDATE characters
        SET hunger = ?, thirst = ?, energy = ?, hygiene = ?, stress = ?, updated_at = ?
        WHERE id = ?]], {
            clamp(state.hunger),
            clamp(state.thirst),
            clamp(state.energy),
            clamp(state.hygiene),
            clamp(state.stress),
            HRP.Utils.now(),
            characterId
        })
end

function Survival.set(player, key, value, saveNow)
    if not isElement(player) then return false end
    local state = states[player]
    if not state or state[key] == nil then return false end

    state[key] = clamp(value)
    setPlayerNeedsData(player, state)
    if saveNow then Survival.save(player) end
    return true
end

function Survival.add(player, key, amount, saveNow)
    if not isElement(player) then return false end
    local state = states[player]
    if not state or state[key] == nil then return false end

    return Survival.set(player, key, (tonumber(state[key]) or 0) + (tonumber(amount) or 0), saveNow)
end

function Survival.get(player)
    return publicState(states[player])
end

local function applyCriticalEffects(player, state)
    local cfg = HRP.Config.survival or {}
    local critical = cfg.critical or {}
    local damage = cfg.damage or {}
    local hp = getElementHealth(player)
    local totalDamage = 0

    if state.hunger <= (critical.hunger or 8) then totalDamage = totalDamage + (damage.hunger or 2) end
    if state.thirst <= (critical.thirst or 8) then totalDamage = totalDamage + (damage.thirst or 4) end
    if state.energy <= (critical.energy or 6) then totalDamage = totalDamage + (damage.energy or 1) end
    if state.stress >= (critical.stress or 92) then totalDamage = totalDamage + (damage.stress or 1) end

    if totalDamage > 0 and hp > 5 then
        setElementHealth(player, math.max(5, hp - totalDamage))
    end
end

local function tickPlayer(player, state)
    if not isElement(player) or isPedDead(player) then return end

    local cfg = HRP.Config.survival or {}
    local decay = cfg.decay or {}
    local regen = cfg.regeneration or {}
    local multiplier = 1
    local speed = movementSpeed(player)
    local vehicle = getPedOccupiedVehicle(player)
    local inVehicle = vehicle and true or false

    if speed > 0.12 and not inVehicle then multiplier = multiplier * (cfg.sprintMultiplier or 1.6) end
    if inVehicle then multiplier = multiplier * (cfg.vehicleEnergyMultiplier or 0.55) end

    state.hunger = clamp(state.hunger - (decay.hunger or 1) * multiplier)
    state.thirst = clamp(state.thirst - (decay.thirst or 1.2) * multiplier)
    state.energy = clamp(state.energy - (decay.energy or 0.8) * multiplier)
    state.hygiene = clamp(state.hygiene - (decay.hygiene or 0.4))
    state.stress = clamp(state.stress - (decay.stress or 0))

    if speed < 0.02 and not inVehicle then
        state.energy = clamp(state.energy + (regen.energyPerMinuteResting or 0))
        state.stress = clamp(state.stress + (regen.stressPerMinuteResting or 0))
    end

    state.ticks = (state.ticks or 0) + 1
    applyCriticalEffects(player, state)
    setPlayerNeedsData(player, state)

    if state.ticks % (cfg.saveEveryTicks or 5) == 0 then
        Survival.save(player)
    end
end

local function tickAll()
    for player, state in pairs(states) do
        tickPlayer(player, state)
    end
end

local function attachPlayer(player, character)
    if not isElement(player) then return end
    character = type(character) == "table" and character or {}

    setElementData(player, "hrp:character:id", tonumber(character.id), false)
    setElementData(player, "hrp:account:id", tonumber(character.accountId), false)
    states[player] = normalizeNeeds(character.needs)
    setPlayerNeedsData(player, states[player])
end

local function detachPlayer(player)
    if not isElement(player) then return end
    Survival.save(player)
    states[player] = nil
    setElementData(player, "hrp:needs", false, false)
end

local module = {}
function module.onStart()
    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, attachPlayer)
    addEventHandler("onPlayerQuit", root, function() detachPlayer(source) end)
    addEventHandler("onPlayerWasted", root, function()
        if states[source] then
            Survival.add(source, "stress", 12, true)
            Survival.add(source, "energy", -18, true)
        end
    end)

    tickTimer = setTimer(tickAll, (HRP.Config.survival and HRP.Config.survival.tickMs) or 60000, 0)
    HRP.Logger.info("survival", "System glodu, pragnienia, energii i stresu gotowy.")
end

addEventHandler("onResourceStop", resourceRoot, function()
    if tickTimer and isTimer(tickTimer) then killTimer(tickTimer) end
    for player in pairs(states) do
        Survival.save(player)
    end
end)

function getPlayerNeeds(player)
    return Survival.get(player)
end

function setPlayerNeed(player, key, value, saveNow)
    return Survival.set(player, key, value, saveNow)
end

function addPlayerNeed(player, key, amount, saveNow)
    return Survival.add(player, key, amount, saveNow)
end

HRP.Modules.register("survival", module)
