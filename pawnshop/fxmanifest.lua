fx_version 'cerulean'
game 'gta5'

author 'Chokapik'
description 'lombard bo dev ma wolne'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/shop.html',
    'ui/shop.css',
    'ui/shop.js'
}

dependencies {
    'qb-core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
    'lb_phone'
}