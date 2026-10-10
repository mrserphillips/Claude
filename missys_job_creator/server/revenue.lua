MJC = MJC or {}
MJC.Revenue = {}

local R = MJC.Revenue

local function internalDeposit(account, amount)
    MySQL.query.await([[
        INSERT INTO missys_job_creator_business_ledger (account, balance)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)
    ]], { account, amount })
    return true
end

local function deposit(account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if Config.CustomBusinessDeposit then
        local ok, accepted = pcall(Config.CustomBusinessDeposit, account, amount, reason)
        if ok and accepted then return true end
    end

    local provider = Config.Revenue.provider
    local targetAccount = (Config.Revenue.accountPrefix or '') .. account

    -- Lation Banking addresses society accounts by job/gang name. Keep the
    -- creator's business job key unchanged so `whitewidow` credits the
    -- `whitewidow` society account.
    if (provider == 'auto' or provider == 'lation') and GetResourceState('lation_banking') == 'started' then
        local depositReason = reason or 'missys-job-creator-sale'
        local ok, result = pcall(function()
            return exports['lation_banking']:AddAccountMoney(targetAccount, amount, depositReason)
        end)

        -- The export may return nil on success depending on the banking build;
        -- only an explicit false or a thrown export error is treated as failure.
        if ok and result ~= false then
            if Config.Debug then
                print(('[missys_job_creator] Deposited $%s into Lation society account %s (%s).'):format(
                    amount, targetAccount, depositReason
                ))
            end
            return true
        end

        print(('[missys_job_creator] Lation society deposit FAILED: account=%s amount=%s reason=%s result=%s error=%s'):format(
            tostring(targetAccount), tostring(amount), tostring(depositReason), tostring(result), ok and 'none' or tostring(result)
        ))

        if provider == 'lation' then return false end
    elseif provider == 'lation' then
        print('[missys_job_creator] Revenue provider is set to lation but lation_banking is not started.')
        return false
    end

    return internalDeposit(account, amount)
end

function R.route(shop, amount, reason)
    local mode = shop.revenue_mode or 'system'
    if mode == 'system' then return true end

    local revenue = shop.revenue or MJC.Validation.decode(shop.revenue_json, {})
    local account = revenue.account or shop.business_job
    if not account or account == '' then return false end

    if mode == 'business' then
        return deposit(account, amount, reason or 'missys-job-creator-sale')
    end

    if mode == 'split' then
        local businessPercent = math.max(0, math.min(100, tonumber(revenue.businessPercent) or 90))
        local businessAmount = math.floor(amount * (businessPercent / 100))
        local taxAmount = amount - businessAmount
        local businessOk = deposit(account, businessAmount, reason or 'missys-job-creator-sale')
        local taxOk = true
        if taxAmount > 0 then
            taxOk = deposit(revenue.taxAccount or Config.Revenue.taxAccount, taxAmount, 'missys-job-creator-tax')
        end
        return businessOk and taxOk
    end

    return false
end

function R.getInternalBalance(account)
    return tonumber(MySQL.scalar.await('SELECT balance FROM missys_job_creator_business_ledger WHERE account = ?', { account })) or 0
end
