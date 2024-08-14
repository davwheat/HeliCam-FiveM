fx_version "bodacious"
games {"gta5"}

author "David Wheatley & Grav"
description "FiveM Helicopter Camera by davwheat and mraes - updated by Grav"
version "3.1"

server_script "heli_server.lua"
client_script "heli_client.lua"
shared_scripts {
    "@ox_lib/init.lua",
    "shared_config.lua"
}

files {"custom_ui.html", "ui.css", "noise.png"}

ui_page "custom_ui.html"
lua54 "yes"
