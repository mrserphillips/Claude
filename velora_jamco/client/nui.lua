-- Velora Jam Co. - NUI focus management and bridge
Nui = { app = nil, handlers = {} }

function Nui.isOpen()
    return Nui.app ~= nil
end

function Nui.open(app, data)
    if Nui.app and Nui.app ~= app then Nui.close() end
    Nui.app = app
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', app = app, data = data })
end

function Nui.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- Closing is idempotent: Escape, the close button, interruptions and resource stop all land here
function Nui.close()
    local app = Nui.app
    Nui.app = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if app and Nui.handlers[app] then
        local ok, err = pcall(Nui.handlers[app])
        if not ok then print('^1[velora_jamco] close handler error: ' .. tostring(err) .. '^7') end
    end
end

function Nui.onClose(app, fn)
    Nui.handlers[app] = fn
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    Nui.close()
end)

-- Read-only / self-validating server calls the UI may make directly
local Proxied = {
    ['kitchen:preview'] = true,
    ['kitchen:collect'] = true,
    ['kitchen:getData'] = true,
    ['business:getData'] = true,
    ['book'] = true,
    ['stats'] = true,
}

RegisterNUICallback('server', function(data, cb)
    if type(data) ~= 'table' or not Proxied[data.name] then return cb(false) end
    local args = type(data.args) == 'table' and data.args or {}
    local result = lib.callback.await('velora_jamco:' .. data.name, false, args[1], args[2], args[3])
    cb(result or false)
end)

-- Never leave the cursor stuck if the resource restarts while the UI is open
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Nui.app then
        SetNuiFocus(false, false)
    end
end)
