fx_version 'cerulean'
game 'gta5'

author 'Landing Competition'
description 'Multiplayer airplane landing competition with GeoGuessr-style results'
version '1.0.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/nui_bridge.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/picker.js',
    'html/js/hud.js',
    'html/js/results.js',
}

lua54 'yes'
