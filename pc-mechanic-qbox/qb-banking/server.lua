local cfg = BridgeConfig
local lation = cfg.LationResource

local function debug(...)
  if cfg.Debug then print("^3[qb-banking bridge]^7", ...) end
end

local function accountName(name)
  if not name or name == "" then return nil end
  name = tostring(name)
  if cfg.AccountPrefix ~= "" and name:sub(1, #cfg.AccountPrefix) ~= cfg.AccountPrefix then
    name = cfg.AccountPrefix .. name
  end
  return name
end

local function callLation(key, ...)
  if GetResourceState(lation) ~= "started" then
    print(("^1[qb-banking bridge] %s is not started - start it before qb-banking and pc-mechanic^7"):format(lation))
    return false, nil
  end
  local exportName = cfg.Exports[key]
  local res = exports[lation]
  local ok, result = pcall(function(...) return res[exportName](res, ...) end, ...)
  if not ok then
    print(("^1[qb-banking bridge] exports['%s']:%s failed: %s^7"):format(lation, exportName, tostring(result)))
    print("^1[qb-banking bridge] Check BridgeConfig.Exports in qb-banking/config.lua against lation's docs^7")
    return false, nil
  end
  return true, result
end

local function getBalance(name)
  local acc = accountName(name)
  if not acc then return 0 end
  local ok, balance = callLation("balance", acc)
  -- Some banking scripts return the whole account table instead of a number
  if type(balance) == "table" then
    balance = balance.balance or balance.account_balance or balance.money or balance.amount
  end
  balance = ok and tonumber(balance) or 0
  debug("balance", acc, balance)
  return balance
end

local function addMoney(name, amount, reason)
  local acc, amt = accountName(name), tonumber(amount)
  if not acc or not amt or amt <= 0 then return false end
  local ok, result = callLation("add", acc, amt, reason or "pc-mechanic")
  debug("add", acc, amt, reason, ok, result)
  return ok and result ~= false
end

local function removeMoney(name, amount, reason)
  local acc, amt = accountName(name), tonumber(amount)
  if not acc or not amt or amt <= 0 then return false end
  if getBalance(name) < amt then
    debug("remove refused (insufficient funds)", acc, amt)
    return false
  end
  local ok, result = callLation("remove", acc, amt, reason or "pc-mechanic")
  debug("remove", acc, amt, reason, ok, result)
  return ok and result ~= false
end

-- qb-banking (v2) API
exports("GetAccountBalance", getBalance)
exports("AddMoney", addMoney)
exports("RemoveMoney", removeMoney)
exports("GetAccount", function(name)
  local acc = accountName(name)
  if not acc then return nil end
  return { account_name = acc, account_balance = getBalance(name), account_type = "job" }
end)
exports("CreateJobAccount", function(name, startingBalance)
  -- Accounts are created and owned by lation_banking; nothing to do here.
  debug("CreateJobAccount ignored", name, startingBalance)
end)

-- Older qb-management / Renewed-Banking style names, in case pc-mechanic calls them
exports("GetMoney", getBalance)
exports("getAccountMoney", getBalance)
exports("addAccountMoney", addMoney)
exports("removeAccountMoney", removeMoney)

-- /bridgetest <account> - console-only check that balances come through
RegisterCommand("bridgetest", function(source, args)
  if source ~= 0 then return end
  local name = args[1] or "mechanic"
  print(("[qb-banking bridge] %s -> lation account '%s' balance: %s"):format(name, accountName(name), getBalance(name)))
end, true)
