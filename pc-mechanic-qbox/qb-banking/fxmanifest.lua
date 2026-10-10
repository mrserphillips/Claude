fx_version "cerulean"
game "gta5"
lua54 "yes"

name "qb-banking"
description "Bridge: exposes the qb-banking society API and forwards it to lation_banking (for pc-mechanic on Qbox)"
version "1.0.0"

-- This folder MUST stay named "qb-banking" so pc-mechanic (Config.SocietyBanking = "qb-banking")
-- finds it. Do not run the real qb-banking at the same time.

server_scripts {
  "config.lua",
  "server.lua",
}
