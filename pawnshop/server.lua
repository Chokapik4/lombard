local QBCore = exports['qb-core']:GetCoreObject()
local ox_inventory = exports.ox_inventory

-- Inicjalizacja inwentarzy i bazy danych
MySQL.ready(function()
    exports.ox_inventory:RegisterStash(Config.CommonStash.id, Config.CommonStash.label, Config.CommonStash.slots, Config.CommonStash.weight, false)
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_company (
            id INT AUTO_INCREMENT PRIMARY KEY,
            level INT DEFAULT 1,
            exp INT DEFAULT 0,
            earnings_today BIGINT DEFAULT 0,
            last_reset DATE DEFAULT CURRENT_DATE
        )
    ]], {})
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_missions (
            citizenid VARCHAR(50),
            mission_id INT,
            status VARCHAR(20) DEFAULT 'W toku',
            location LONGTEXT,
            reward INT,
            PRIMARY KEY (citizenid, mission_id)
        )
    ]], {})
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_daily (
            citizenid VARCHAR(50) PRIMARY KEY,
            accepted_missions INT DEFAULT 0,
            completed_missions INT DEFAULT 0,
            last_date DATE DEFAULT CURRENT_DATE
        )
    ]], {})
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50),
            mission_id INT,
            reward INT,
            completed_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]], {})
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_upgrades (
            id INT AUTO_INCREMENT PRIMARY KEY,
            upgrade_name VARCHAR(50),
            purchased_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]], {})
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pawnshop_shop_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50),
            item_name VARCHAR(50),
            price INT,
            description TEXT,
            amount INT DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]], {})
end)

-- Reset dziennych misji
Citizen.CreateThread(function()
    while true do
        local now = os.date('*t')
        if now.hour == Config.MissionRefreshHour then
            MySQL.update('UPDATE pawnshop_daily SET accepted_missions = 0, completed_missions = 0, last_date = CURRENT_DATE', {})
            MySQL.update('UPDATE pawnshop_company SET earnings_today = 0, last_reset = CURRENT_DATE', {})
            Wait(3600000) -- 1 godzina
        end
        Wait(60000) -- Co minutę
    end
end)

-- Pobieranie danych firmy
QBCore.Functions.CreateCallback('pawnshop:getCompanyData', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    local company = MySQL.query.await('SELECT * FROM pawnshop_company WHERE id = 1', {})
    local daily = MySQL.query.await('SELECT accepted_missions, completed_missions FROM pawnshop_daily WHERE citizenid = ?', { citizenid })
    local balance = exports['lb_phone']:getCompanyBalance() or 0
    local employees = exports['lb_phone']:getEmployeeCount() or 0
    
    if #company == 0 then
        MySQL.insert('INSERT INTO pawnshop_company (id, level, exp, earnings_today) VALUES (1, 1, 0, 0)', {})
        company = {{ level = 1, exp = 0, earnings_today = 0 }}
    end
    if #daily == 0 then
        MySQL.insert('INSERT INTO pawnshop_daily (citizenid, accepted_missions, completed_missions) VALUES (?, 0, 0)', { citizenid })
        daily = {{ accepted_missions = 0, completed_missions = 0 }}
    end
    
    cb({
        level = company[1].level,
        exp = company[1].exp,
        earnings = company[1].earnings_today,
        balance = balance,
        employeeCount = employees,
        acceptedMissions = daily[1].accepted_missions,
        completedMissions = daily[1].completed_missions
    })
end)

-- Pobieranie dostępnych misji
QBCore.Functions.CreateCallback('pawnshop:getAvailableMissions', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    local daily = MySQL.query.await('SELECT accepted_missions FROM pawnshop_daily WHERE citizenid = ?', { citizenid })
    
    if daily[1] and daily[1].accepted_missions >= Config.MaxDailyMissions then
        cb({ error = 'Osiągnąłeś dzienny limit zleceń!' })
        return
    end
    
    local missions = {}
    for i, mission in ipairs(Config.Missions) do
        local active = MySQL.query.await('SELECT 1 FROM pawnshop_missions WHERE citizenid = ? AND mission_id = ? AND status = "W toku"', { citizenid, i })
        if #active == 0 then
            table.insert(missions, {
                id = i,
                name = mission.name,
                description = mission.description,
                requiredItems = mission.requiredItems,
                reward = mission.reward
            })
        end
    end
    cb(missions)
end)

-- Przyjmowanie misji
RegisterNetEvent('pawnshop:acceptMission')
AddEventHandler('pawnshop:acceptMission', function(missionId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local daily = MySQL.query.await('SELECT accepted_missions FROM pawnshop_daily WHERE citizenid = ?', { citizenid })
    
    if daily[1] and daily[1].accepted_missions >= Config.MaxDailyMissions then
        QBCore.Functions.Notify(src, 'Osiągnąłeś dzienny limit zleceń!', 'error')
        return
    end
    
    local mission = Config.Missions[missionId]
    local location = Config.DeliveryLocations[math.random(1, #Config.DeliveryLocations)]
    
    MySQL.insert('INSERT INTO pawnshop_missions (citizenid, mission_id, location, reward) VALUES (?, ?, ?, ?)', {
        citizenid, missionId, json.encode(location), mission.reward
    })
    MySQL.update('UPDATE pawnshop_daily SET accepted_missions = accepted_missions + 1 WHERE citizenid = ?', { citizenid })
    
    TriggerClientEvent('pawnshop:startMission', src, {
        id = missionId,
        name = mission.name,
        requiredItems = mission.requiredItems,
        reward = mission.reward,
        location = location
    })
end)

-- Negocjacja dostawy
RegisterNetEvent('pawnshop:negotiateDelivery')
AddEventHandler('pawnshop:negotiateDelivery', function(missionId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local mission = MySQL.query.await('SELECT mission_id, reward FROM pawnshop_missions WHERE citizenid = ? AND mission_id = ? AND status = "W toku"', { citizenid, missionId })
    
    if #mission == 0 then
        QBCore.Functions.Notify(src, 'Misja nie istnieje lub została już ukończona!', 'error')
        return
    end
    
    local requiredItems = Config.Missions[mission[1].mission_id].requiredItems
    for _, item in ipairs(requiredItems) do
        if ox_inventory:GetItem(src, item.name, nil, true).count < item.amount then
            QBCore.Functions.Notify(src, 'Nie masz wystarczającej ilości przedmiotów!', 'error')
            return
        end
    end
    
    lib.registerContext({
        id = 'negotiate_delivery',
        title = 'Negocjuj dostawę',
        options = {
            {
                title = 'Dostarcz bez negocjacji',
                description = string.format('Otrzymasz $%d', mission[1].reward),
                onSelect = function()
                    TriggerServerEvent('pawnshop:deliverItems', missionId, false)
                end
            },
            {
                title = 'Negocjuj nagrodę',
                description = '50% szans na zwiększenie nagrody o 10%',
                onSelect = function()
                    TriggerServerEvent('pawnshop:deliverItems', missionId, true)
                end
            }
        }
    })
    lib.showContext('negotiate_delivery')
end)

-- Dostarczenie przedmiotów
RegisterNetEvent('pawnshop:deliverItems')
AddEventHandler('pawnshop:deliverItems', function(missionId, negotiate)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local mission = MySQL.query.await('SELECT mission_id, reward FROM pawnshop_missions WHERE citizenid = ? AND mission_id = ? AND status = "W toku"', { citizenid, missionId })
    
    if #mission == 0 then
        QBCore.Functions.Notify(src, 'Misja nie istnieje lub została już ukończona!', 'error')
        return
    end
    
    local requiredItems = Config.Missions[mission[1].mission_id].requiredItems
    for _, item in ipairs(requiredItems) do
        if ox_inventory:GetItem(src, item.name, nil, true).count < item.amount then
            QBCore.Functions.Notify(src, 'Nie masz wystarczającej ilości przedmiotów!', 'error')
            return
        end
    end
    
    local finalReward = mission[1].reward
    if negotiate and math.random(1, 2) == 1 then
        finalReward = math.floor(finalReward * 1.1)
        QBCore.Functions.Notify(src, 'Negocjacje zakończone sukcesem! Nagroda zwiększona do $' .. finalReward, 'success')
    elseif negotiate then
        QBCore.Functions.Notify(src, 'Negocjacje nie powiodły się. Nagroda pozostaje $' .. finalReward, 'error')
    end
    
    for _, item in ipairs(requiredItems) do
        ox_inventory:RemoveItem(src, item.name, item.amount)
    end
    
    local company = MySQL.query.await('SELECT level FROM pawnshop_company WHERE id = 1', {})
    local multiplier = Config.RewardMultiplier ^ (company[1].level - 1)
    local totalReward = math.floor(finalReward * multiplier)
    
    MySQL.update('UPDATE pawnshop_company SET exp = exp + 100, earnings_today = earnings_today + ? WHERE id = 1', { totalReward })
    MySQL.update('UPDATE pawnshop_daily SET completed_missions = completed_missions + 1 WHERE citizenid = ?', { citizenid })
    MySQL.insert('INSERT INTO pawnshop_history (citizenid, mission_id, reward) VALUES (?, ?, ?)', { citizenid, mission[1].mission_id, totalReward })
    MySQL.update('UPDATE pawnshop_missions SET status = "Ukończona", reward = ? WHERE citizenid = ? AND mission_id = ?', { totalReward, citizenid, mission[1].mission_id })
    
    exports['lb_phone']:addCompanyMoney(totalReward)
    
    local companyData = MySQL.query.await('SELECT level, exp FROM pawnshop_company WHERE id = 1', {})
    if companyData[1].exp >= (Config.LevelExp[companyData[1].level] or 5000) then
        MySQL.update('UPDATE pawnshop_company SET level = level + 1, exp = 0 WHERE id = 1', {})
    end
    
    TriggerClientEvent('pawnshop:endMission', src, mission[1].mission_id)
    QBCore.Functions.Notify(src, string.format('Zlecenie ukończone! Firma zarobiła $%d', totalReward), 'success')
end)

-- Pobieranie aktywnych misji
QBCore.Functions.CreateCallback('pawnshop:getActiveMissions', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    local missions = MySQL.query.await('SELECT * FROM pawnshop_missions WHERE citizenid = ? AND status = "W toku"', { citizenid })
    local activeMissions = {}
    
    for _, mission in ipairs(missions) do
        table.insert(activeMissions, {
            id = mission.mission_id,
            name = Config.Missions[mission.mission_id].name,
            requiredItems = Config.Missions[mission.mission_id].requiredItems,
            reward = mission.reward,
            location = json.decode(mission.location),
            status = mission.status
        })
    end
    cb(activeMissions)
end)

-- Pobieranie historii misji
QBCore.Functions.CreateCallback('pawnshop:getHistory', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    local history = MySQL.query.await('SELECT mission_id, reward, completed_at FROM pawnshop_history WHERE citizenid = ? ORDER BY completed_at DESC', { citizenid })
    cb(history)
end)

-- Pobieranie przedmiotów w sklepie
QBCore.Functions.CreateCallback('pawnshop:getShopItems', function(source, cb)
    local items = MySQL.query.await('SELECT * FROM pawnshop_shop_items ORDER BY created_at DESC', {})
    local shopItems = {}
    
    for _, item in ipairs(items) do
        table.insert(shopItems, {
            id = item.id,
            citizenid = item.citizenid,
            item_name = item.item_name,
            price = item.price,
            description = item.description or 'Brak opisu',
            amount = item.amount
        })
    end
    cb(shopItems)
end)

-- Wystawianie przedmiotu
RegisterNetEvent('pawnshop:listItem')
AddEventHandler('pawnshop:listItem', function(itemName, price, description)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    
    if player.PlayerData.job.name ~= Config.PawnShopNPC.job then
        QBCore.Functions.Notify(src, 'Tylko pracownicy lombardu mogą wystawiać przedmioty!', 'error')
        return
    end
    
    local item = ox_inventory:GetItem(src, itemName, nil, true)
    if not item or item.count < 1 then
        QBCore.Functions.Notify(src, 'Nie posiadasz tego przedmiotu w inwentarzu!', 'error')
        return
    end
    
    if price <= 0 then
        QBCore.Functions.Notify(src, 'Cena musi być większa od 0!', 'error')
        return
    end
    
    ox_inventory:RemoveItem(src, itemName, 1)
    MySQL.insert('INSERT INTO pawnshop_shop_items (citizenid, item_name, price, description) VALUES (?, ?, ?, ?)', {
        citizenid, itemName, price, description
    })
    QBCore.Functions.Notify(src, 'Przedmiot wystawiony w sklepie!', 'success')
end)

-- Kupowanie przedmiotu
RegisterNetEvent('pawnshop:buyItem')
AddEventHandler('pawnshop:buyItem', function(itemId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local item = MySQL.query.await('SELECT * FROM pawnshop_shop_items WHERE id = ?', { itemId })
    
    if #item == 0 then
        QBCore.Functions.Notify(src, 'Przedmiot nie istnieje!', 'error')
        return
    end
    
    if player.PlayerData.money.cash < item[1].price then
        QBCore.Functions.Notify(src, 'Nie masz wystarczająco gotówki!', 'error')
        return
    end
    
    player.Functions.RemoveMoney('cash', item[1].price)
    ox_inventory:AddItem(src, item[1].item_name, 1)
    exports['lb_phone']:addCompanyMoney(item[1].price)
    MySQL.query('DELETE FROM pawnshop_shop_items WHERE id = ?', { itemId })
    QBCore.Functions.Notify(src, string.format('Kupiono %s za $%d!', QBCore.Shared.Items[item[1].item_name].label, item[1].price), 'success')
end)

-- Usuwanie przedmiotu
RegisterNetEvent('pawnshop:removeItem')
AddEventHandler('pawnshop:removeItem', function(itemId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local item = MySQL.query.await('SELECT * FROM pawnshop_shop_items WHERE id = ? AND citizenid = ?', { itemId, citizenid })
    
    if #item == 0 or player.PlayerData.job.name ~= Config.PawnShopNPC.job then
        QBCore.Functions.Notify(src, 'Nie możesz usunąć tego przedmiotu!', 'error')
        return
    end
    
    ox_inventory:AddItem(src, item[1].item_name, 1)
    MySQL.query('DELETE FROM pawnshop_shop_items WHERE id = ?', { itemId })
    QBCore.Functions.Notify(src, 'Przedmiot usunięty ze sklepu!', 'success')
end)

-- Zakup ulepszeń
RegisterNetEvent('pawnshop:purchaseUpgrade')
AddEventHandler('pawnshop:purchaseUpgrade', function(upgradeName)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local balance = exports['lb_phone']:getCompanyBalance() or 0
    local upgrade = nil
    
    for _, u in ipairs(Config.Upgrades) do
        if u.name == upgradeName then
            upgrade = u
            break
        end
    end
    
    if not upgrade or balance < upgrade.cost then
        QBCore.Functions.Notify(src, 'Niewystarczające środki lub ulepszenie niedostępne!', 'error')
        return
    end
    
    MySQL.insert('INSERT INTO pawnshop_upgrades (upgrade_name) VALUES (?)', { upgradeName })
    upgrade.effect()
    exports['lb_phone']:addCompanyMoney(-upgrade.cost)
    QBCore.Functions.Notify(src, string.format('Zakupiono ulepszenie: %s za $%d', upgradeName, upgrade.cost), 'success')
end)