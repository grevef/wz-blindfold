lib.locale()

local item = Config.blindfoldItem or 'blindfold' -- Item name from config

local function isBlindfolded(targetId)
    return Player(targetId).state.isBlindfolded or false
end

local function setBlindfolded(targetId, value)
    Player(targetId).state:set('isBlindfolded', value, true) -- replicated so every client (and other resources) can read it directly off the player's state bag
end

function ServerNotify(target, title, key, type)
    TriggerClientEvent('wz-blindfold:Notify', target, title, key, type)
end

local function isTargetTooFar(src, targetSrc, maxDistance)
    maxDistance = maxDistance or 2.5

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)

    if not DoesEntityExist(srcPed) or not DoesEntityExist(targetPed) then
        return true
    end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)

    return #(srcCoords - targetCoords) > maxDistance
end



lib.callback.register('blindfold:applyBlindfold', function(source, targetId) -- callback to apply blindfold to a player
    if not targetId or targetId == source then
        return false
    end
    if isBlindfolded(targetId) then
        return false -- Target is already blindfolded
    end
    if isTargetTooFar(source, targetId) then
        return false -- Target is too far away, cannot apply blindfold
    end
    local hasItem = exports.ox_inventory:Search(source, 'count', item) > 0
    if hasItem then
        exports.ox_inventory:RemoveItem(source, item, 1)
        setBlindfolded(targetId, true) -- clients react to this via AddStateBagChangeHandler, no manual event needed
        return true
    else
        return false
    end
end)

lib.callback.register('blindfold:removeBlindfold', function(source, targetId) -- Callback to remove blindfold from a player
    if not targetId or targetId == source then
        return false
    end

    if not isBlindfolded(targetId) then
        return false -- Target is not blindfolded
    end
    if isTargetTooFar(source, targetId) then
        return false -- Target is too far away, cannot remove blindfold
    end
    exports.ox_inventory:AddItem(source, item, 1)
    setBlindfolded(targetId, false)
    return true
end)

lib.callback.register('blindfold:removeOwnBlindfold', function(source) -- Callback for a player to remove their own blindfold
    if not isBlindfolded(source) then
        return false
    end
    exports.ox_inventory:AddItem(source, item, 1)
    setBlindfolded(source, false)
    return true
end)

-- Admin commands

lib.addCommand('forceblindfold', {
    help = locale('admin_force_blindfold'),
    params = {
        { name = 'target', help = locale('admin_force_blindfold_help'), type = 'playerId' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local targetId = args.target
    if targetId then
        if isBlindfolded(targetId) then
            return ServerNotify(source, 'Admin', 'player_already_blindfolded', 'info')
        end
        setBlindfolded(targetId, true)
        ServerNotify(source, 'Admin', 'player_blindfold_success', 'success')
    else
        ServerNotify(source, 'Admin', 'player_not_found', 'info')
    end
end)

lib.addCommand('forceunblindfold', {
    help = locale('admin_remove_blindfold'),
    params = {
        { name = 'target', help = locale('admin_remove_blindfold_help'), type = 'playerId' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local targetId = args.target
    if targetId then
        if not isBlindfolded(targetId) then
            ServerNotify(source, 'Admin', 'player_not_blindfolded', 'info')
            return
        end
        setBlindfolded(targetId, false)
        ServerNotify(source, 'Admin', 'player_blindfold_removed_success', 'success')
    else
        ServerNotify(source, 'Admin', 'player_not_found', 'info')
    end
end)

lib.addCommand('blindfoldstate', {
    help = locale('admin_check_blindfold_state'),
    params = {
        { name = 'target', help = locale('admin_check_blindfold_state_help'), type = 'playerId' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local targetId = args.target
    if targetId then
        local stateKey = isBlindfolded(targetId) and "state_blindfolded" or "state_not_blindfolded"
        ServerNotify(source, 'Admin', stateKey, 'info')
    else
        ServerNotify(source, 'Admin', 'player_not_found', 'info')
    end
end)

lib.addCommand('removeblindfold', {
    help = locale('remove_blindfold_command'),
}, function(source)
    if isBlindfolded(source) then
        TriggerClientEvent('wz-blindfold:removeOwnBlindfold', source)
    else
        ServerNotify(source, 'Blindfold', 'self_is_not_blindfolded', 'info')
    end
end)

AddEventHandler('onResourceStop', function(resourceName) -- Clean up blindfold states when the resource stops
    if GetCurrentResourceName() ~= resourceName then return end
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if isBlindfolded(id) then
            setBlindfolded(id, false) -- state bag change fires the client's AddStateBagChangeHandler, which removes the visuals
        end
    end
end)


