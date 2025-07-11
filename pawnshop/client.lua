local QBCore = exports['qb-core']:GetCoreObject()
local ox_inventory = exports.ox_inventory
local lib = exports.ox_lib
local activeMissions = {}
local deliveryNPCs = {}
local deliveryBlips = {}

-- Inicjalizacja NPC do zarządzania lombardem
Citizen.CreateThread(function()
    local npc = CreatePed(4, GetHashKey(Config.PawnShopNPC.model), Config.PawnShopNPC.coords.x, Config.PawnShopNPC.coords.y, Config.PawnShopNPC.coords.z - 1.0, Config.PawnShopNPC.coords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    exports.ox_target:addLocalEntity(npc, {
        name = 'pawnshop_npc',
        label = 'Otwórz system lombardu',
        icon = 'fas fa-briefcase',
        distance = 2.0,
        onSelect = function()
            local playerJob = QBCore.Functions.GetPlayerData().job.name
            if playerJob == Config.PawnShopNPC.job then
                SendNUIMessage({ action = 'openMenu' })
                SetNuiFocus(true, true)
            else
                QBCore.Functions.Notify('Tylko pracownicy lombardu mają dostęp!', 'error')
            end
        end
    })
end)

-- Inicjalizacja NPC do sklepu
Citizen.CreateThread(function()
    local shopNpc = CreatePed(4, GetHashKey(Config.ShopNPC.model), Config.ShopNPC.coords.x, Config.ShopNPC.coords.y, Config.ShopNPC.coords.z - 1.0, Config.ShopNPC.coords.w, false, true)
    FreezeEntityPosition(shopNpc, true)
    SetEntityInvincible(shopNpc, true)
    exports.ox_target:addLocalEntity(shopNpc, {
        name = 'shop_npc',
        label = 'Otwórz sklep lombardu',
        icon = 'fas fa-shopping-cart',
        distance = 2.0,
        onSelect = function()
            SendNUIMessage({ action = 'openShop' })
            SetNuiFocus(true, true)
        end
    })
end)

-- Box zone dla inwentarzy (bez NPC)
Citizen.CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = Config.StorageLocation.coords,
        size = vector3(2.0, 2.0, 2.0),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'pawnshop_personal_stash',
                label = 'Otwórz swoją prywatną szafkę',
                icon = 'fas fa-lock',
                distance = 2.0,
                canInteract = function()
                    return QBCore.Functions.GetPlayerData().job.name == Config.PawnShopNPC.job
                end,
                onSelect = function()
                    local player = QBCore.Functions.GetPlayerData()
                    local stashId = 'pawnshop_stash_' .. player.citizenid
                    ox_inventory:openInventory('stash', stashId)
                end
            },
            {
                name = 'pawnshop_common_stash',
                label = 'Otwórz ogólny inwentarz',
                icon = 'fas fa-warehouse',
                distance = 2.0,
                canInteract = function()
                    return QBCore.Functions.GetPlayerData().job.name == Config.PawnShopNPC.job
                end,
                onSelect = function()
                    ox_inventory:openInventory('stash', Config.CommonStash.id)
                end
            }
        }
    })
end)

-- Rozpoczęcie misji (tworzenie NPC i blipa)
RegisterNetEvent('pawnshop:startMission')
AddEventHandler('pawnshop:startMission', function(mission)
    activeMissions[mission.id] = mission
    local loc = mission.location
    local npcModel = Config.DeliveryNPCTypes[math.random(1, #Config.DeliveryNPCTypes)]
    RequestModel(npcModel)
    while not HasModelLoaded(npcModel) do
        Wait(100)
    end
    local npc = CreatePed(4, npcModel, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.heading, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    deliveryNPCs[mission.id] = npc
    SetEntityAsMissionEntity(npc, true, true)
    exports.ox_target:addLocalEntity(npc, {
        name = 'pawnshop_delivery_' .. mission.id,
        label = 'Rozpocznij dostawę',
        icon = 'fas fa-box',
        distance = 2.0,
        onSelect = function()
            TriggerServerEvent('pawnshop:negotiateDelivery', mission.id)
        end
    })
    local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Punkt dostawy: ' .. mission.name)
    EndTextCommandSetBlipName(blip)
    deliveryBlips[mission.id] = blip
end)

-- Zakończenie misji (usunięcie NPC i blipa)
RegisterNetEvent('pawnshop:endMission')
AddEventHandler('pawnshop:endMission', function(missionId)
    if deliveryNPCs[missionId] then
        DeleteEntity(deliveryNPCs[missionId])
        deliveryNPCs[missionId] = nil
    end
    if deliveryBlips[missionId] then
        RemoveBlip(deliveryBlips[missionId])
        deliveryBlips[missionId] = nil
    end
    activeMissions[missionId] = nil
end)

-- Obsługa NUI
RegisterNUICallback('acceptMission', function(data, cb)
    TriggerServerEvent('pawnshop:acceptMission', data.missionId)
    cb({ status = 'ok' })
end)

RegisterNUICallback('listItem', function(data, cb)
    TriggerServerEvent('pawnshop:listItem', data.itemName, data.price, data.description or '')
    cb({ status = 'ok' })
end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('pawnshop:buyItem', data.itemId)
    cb({ status = 'ok' })
end)

RegisterNUICallback('removeItem', function(data, cb)
    TriggerServerEvent('pawnshop:removeItem', data.itemId)
    cb({ status = 'ok' })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetNuiFocus(false, false)
    cb({ status = 'ok' })
end)

RegisterNUICallback('closeShop', function(_, cb)
    SetNuiFocus(false, false)
    cb({ status = 'ok' })
end)