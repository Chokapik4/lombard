Config = {}

-- Ustawienia NPC
Config.PawnShopNPC = {
    model = `a_m_m_business_01`,
    coords = vector4(150.0, -1040.0, 29.0, 160.0),
    job = "pawnshop"
}

Config.ShopNPC = {
    model = `a_m_m_business_02`,
    coords = vector4(160.0, -1050.0, 29.0, 180.0)
}

Config.StorageLocation = {
    coords = vector4(170.0, -1060.0, 29.0, 90.0)
}

Config.MaxDailyMissions = 8
Config.MissionRefreshHour = 0

-- Poziomy firmy
Config.LevelExp = {
    [1] = 500,
    [2] = 1000,
    [3] = 2000,
    [4] = 3500,
    [5] = 5000
}
Config.RewardMultiplier = 1.1

-- 30 losowych lokalizacji dla dostaw
Config.DeliveryLocations = {
    { coords = vector3(200.0, -900.0, 30.0), heading = 180.0 },
    { coords = vector3(300.0, -1000.0, 29.0), heading = 90.0 },
    { coords = vector3(100.0, -1100.0, 29.0), heading = 270.0 },
    { coords = vector3(250.0, -950.0, 30.0), heading = 0.0 },
    { coords = vector3(350.0, -1050.0, 29.0), heading = 45.0 },
    { coords = vector3(150.0, -1150.0, 29.0), heading = 90.0 },
    { coords = vector3(200.0, -800.0, 30.0), heading = 135.0 },
    { coords = vector3(400.0, -900.0, 29.0), heading = 180.0 },
    { coords = vector3(100.0, -1200.0, 29.0), heading = 225.0 },
    { coords = vector3(300.0, -850.0, 30.0), heading = 270.0 },
    { coords = vector3(250.0, -1100.0, 29.0), heading = 315.0 },
    { coords = vector3(350.0, -950.0, 30.0), heading = 0.0 },
    { coords = vector3(150.0, -1000.0, 29.0), heading = 45.0 },
    { coords = vector3(200.0, -1050.0, 30.0), heading = 90.0 },
    { coords = vector3(300.0, -1100.0, 29.0), heading = 135.0 },
    { coords = vector3(100.0, -950.0, 30.0), heading = 180.0 },
    { coords = vector3(250.0, -1200.0, 29.0), heading = 225.0 },
    { coords = vector3(350.0, -800.0, 30.0), heading = 270.0 },
    { coords = vector3(150.0, -850.0, 29.0), heading = 315.0 },
    { coords = vector3(200.0, -1150.0, 30.0), heading = 0.0 },
    { coords = vector3(300.0, -900.0, 29.0), heading = 45.0 },
    { coords = vector3(100.0, -1050.0, 30.0), heading = 90.0 },
    { coords = vector3(250.0, -1000.0, 29.0), heading = 135.0 },
    { coords = vector3(350.0, -1100.0, 30.0), heading = 180.0 },
    { coords = vector3(150.0, -950.0, 29.0), heading = 225.0 },
    { coords = vector3(200.0, -1200.0, 30.0), heading = 270.0 },
    { coords = vector3(300.0, -850.0, 29.0), heading = 315.0 },
    { coords = vector3(100.0, -1100.0, 30.0), heading = 0.0 },
    { coords = vector3(250.0, -1050.0, 29.0), heading = 45.0 },
    { coords = vector3(350.0, -1150.0, 30.0), heading = 90.0 }
}

-- Modele NPC odbiorców
Config.DeliveryNPCTypes = {
    `a_m_y_hipster_01`,
    `a_f_y_business_01`,
    `a_m_m_prolhost_01`
}

-- Definicje misji (bez limitu czasu)
Config.Missions = {
    {
        name = "Dostawa złota",
        description = "Dostarcz złote przedmioty do klienta.",
        requiredItems = {
            { name = "goldbar", amount = 2 },
            { name = "goldwatch", amount = 1 }
        },
        reward = 500
    },
    {
        name = "Dostawa elektroniki",
        description = "Dostarcz elektronikę do klienta.",
        requiredItems = {
            { name = "phone", amount = 1 },
            { name = "laptop", amount = 1 }
        },
        reward = 700
    }
}

-- Inwentarz
Config.PersonalStash = {
    slots = 20,
    weight = 50000
}

Config.CommonStash = {
    id = 'pawnshop_common_stash',
    label = 'Ogólny inwentarz lombardu',
    slots = 50,
    weight = 100000
}

-- Ulepszenia
Config.Upgrades = {
    { name = "Increase Mission Limit", cost = 10000, effect = function() Config.MaxDailyMissions = 10 end },
    { name = "Increase Reward Bonus", cost = 20000, effect = function() Config.RewardMultiplier = Config.RewardMultiplier * 1.1 end }
}