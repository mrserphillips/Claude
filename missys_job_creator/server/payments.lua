MJC = MJC or {}
MJC.Payments = MJC.Payments or {}

local P = MJC.Payments

local function normalize(paymentType)
    paymentType = MJC.Validation.trim(paymentType or Config.DefaultPaymentType)
    if not MJC.Constants.PaymentTypes[paymentType] then
        return Config.DefaultPaymentType
    end
    return paymentType
end

function P.label(paymentType)
    paymentType = normalize(paymentType)
    if paymentType == 'black_money' then return 'black money' end
    return paymentType
end

function P.balance(source, paymentType)
    paymentType = normalize(paymentType)
    if paymentType == 'black_money' then
        return tonumber(exports.ox_inventory:GetItemCount(source, 'black_money', nil, false)) or 0
    end
    return tonumber(exports.qbx_core:GetMoney(source, paymentType)) or 0
end

function P.take(source, paymentType, amount, reason)
    paymentType = normalize(paymentType)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return true end
    if P.balance(source, paymentType) < amount then return false end

    if paymentType == 'black_money' then
        return exports.ox_inventory:RemoveItem(source, 'black_money', amount) == true
    end

    return exports.qbx_core:RemoveMoney(source, paymentType, amount, reason) == true
end

function P.refund(source, paymentType, amount, reason)
    paymentType = normalize(paymentType)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return true end

    if paymentType == 'black_money' then
        return exports.ox_inventory:AddItem(source, 'black_money', amount) ~= false
    end

    return exports.qbx_core:AddMoney(source, paymentType, amount, reason) ~= false
end

function P.give(source, paymentType, amount, reason)
    return P.refund(source, paymentType, amount, reason)
end
