fx_version 'adamant'
game 'gta5'

author 'ESX-Framework'
description 'Allows resources to store account data, such as society funds'
lua54 'yes'
version '1.1' 

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/classes/addonaccount.lua',
	'server/main.lua'
}

dependency 'es_extended'
