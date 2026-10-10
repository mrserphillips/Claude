BridgeConfig = {}

-- Name of the lation banking resource folder on your server.
BridgeConfig.LationResource = "lation_banking"

-- How society accounts are named in lation_banking.
-- pc-mechanic asks for the job name (e.g. "mechanic"). If lation stores it as
-- "society_mechanic", set the prefix to "society_".
BridgeConfig.AccountPrefix = ""

-- Export names on the lation banking resource. Check these against lation's
-- docs (Exports > Server) and change any that differ.
--   balance(account)                -> number
--   add(account, amount, reason)    -> boolean
--   remove(account, amount, reason) -> boolean
BridgeConfig.Exports = {
  balance = "GetAccountBalance",
  add     = "AddMoney",
  remove  = "RemoveMoney",
}

-- Print every call to the server console (turn on while testing).
BridgeConfig.Debug = false
