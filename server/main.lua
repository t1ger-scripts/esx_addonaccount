local AccountsIndex, Accounts, SharedAccounts = {}, {}, {}

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		local accounts = MySQL.query.await(
			'SELECT * FROM addon_account LEFT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name UNION SELECT * FROM addon_account RIGHT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name')

		local newAccounts = {}
		for i = 1, #accounts do
			local account = accounts[i]
			if account.shared == 0 then
				if not Accounts[account.name] then
					AccountsIndex[#AccountsIndex + 1] = account.name
					Accounts[account.name] = {}
				end
				Accounts[account.name][#Accounts[account.name] + 1] = CreateAddonAccount(account.name, account.owner,
					account.money)
			else
				if account.money then
					SharedAccounts[account.name] = CreateAddonAccount(account.name, nil, account.money)
				else
					newAccounts[#newAccounts + 1] = { account.name, 0 }
				end
			end
		end
		GlobalState.SharedAccounts = SharedAccounts

		if next(newAccounts) then
			MySQL.prepare('INSERT INTO addon_account_data (account_name, money) VALUES (?, ?)', newAccounts)
			for i = 1, #newAccounts do
				local newAccount = newAccounts[i]
				SharedAccounts[newAccount[1]] = CreateAddonAccount(newAccount[1], nil, 0)
			end
			GlobalState.SharedAccounts = SharedAccounts
		end
	end
end)

function GetAccount(name, owner)
	for i = 1, #Accounts[name], 1 do
		if Accounts[name][i].owner == owner then
			return Accounts[name][i]
		end
	end
end
exports("GetAccount", GetAccount)

function GetSharedAccount(name)
	return SharedAccounts[name]
end
exports("GetSharedAccount", GetSharedAccount)

--- Adds a shared account for a society/job.
-- @param society (table) A table containing:
--        society.name (string) - Unique job/society identifier (e.g., "mechanic", "police").
--        society.label (string) - Display label for the job/society (e.g., "Mechanic", "Police Department").
-- @param amount (number, optional) The starting balance for the shared account. Default is 0.
-- @return (boolean, string|table) Returns `true, account` on success, or `false, "error message"` on failure.
function AddSharedAccount(society, amount)
    -- Validate input parameters
    if not society or type(society) ~= 'table' then
        return false, "Expected society as a table"
    end

    if not society.name or type(society.name) ~= "string" or society.name == "" then
        return false, "Invalid society.name provided"
    end

    if not society.label or type(society.label) ~= "string" or society.label == "" then
        return false, "Invalid society.label provided"
    end

    -- Check if account already exists
    if SharedAccounts[society.name] ~= nil then
        return false, "Account already exists"
    end

    -- Insert into `addon_account` table
    local accountInsert = MySQL.insert.await('INSERT INTO `addon_account` (name, label, shared) VALUES (?, ?, ?)', {
        society.name, society.label, 1
    })

    if not accountInsert then
        return false, "Database error: Failed to insert into addon_account"
    end

    -- Insert into `addon_account_data` table
    local accountDataInsert = MySQL.insert.await('INSERT INTO `addon_account_data` (account_name, money) VALUES (?, ?)', {
        society.name, amount or 0
    })

    if not accountDataInsert then
        return false, "Database error: Failed to insert into addon_account_data"
    end

    -- Successfully created account
    SharedAccounts[society.name] = CreateAddonAccount(society.name, nil, amount or 0)

    return true, "Success"
end
exports("AddSharedAccount", AddSharedAccount)

AddEventHandler('esx_addonaccount:getAccount', function(name, owner, cb)
	cb(GetAccount(name, owner))
end)

AddEventHandler('esx_addonaccount:getSharedAccount', function(name, cb)
	cb(GetSharedAccount(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
	local addonAccounts = {}

	for i = 1, #AccountsIndex, 1 do
		local name    = AccountsIndex[i]
		local account = GetAccount(name, xPlayer.identifier)

		if account == nil then
			MySQL.insert('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
				{ name, 0, xPlayer.identifier })

			account = CreateAddonAccount(name, xPlayer.identifier, 0)
			Accounts[name][#Accounts[name] + 1] = account
		end

		addonAccounts[#addonAccounts + 1] = account
	end

	xPlayer.set('addonAccounts', addonAccounts)
end)

RegisterNetEvent('esx_addonaccount:refreshAccounts')
AddEventHandler('esx_addonaccount:refreshAccounts', function()
	local addonAccounts = MySQL.query.await('SELECT * FROM addon_account')

	for i = 1, #addonAccounts, 1 do
		local name             = addonAccounts[i].name
		local shared           = addonAccounts[i].shared

		local addonAccountData = MySQL.query.await('SELECT * FROM addon_account_data WHERE account_name = ?', { name })

		if shared == 0 then
			table.insert(AccountsIndex, name)
			Accounts[name] = {}

			for j = 1, #addonAccountData, 1 do
				local addonAccount = CreateAddonAccount(name, addonAccountData[j].owner, addonAccountData[j].money)
				table.insert(Accounts[name], addonAccount)
			end
		else
			local money = nil

			if #addonAccountData == 0 then
				MySQL.insert('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
					{ name, 0, nil })
				money = 0
			else
				money = addonAccountData[1].money
			end

			local addonAccount   = CreateAddonAccount(name, nil, money)
			SharedAccounts[name] = addonAccount
		end
	end
end)
