canStart = true
robberyCreated = false
ongoing = false
checkingStealth = true
location = {
    vector3(-176.18, 502.71, 137.42), -- wild oats drive
    --vector3(-48.29, -587.09, 37.95) -- integrity way
}

--[[-------------------------------------------
Create NPC and targetingzone
---------------------------------------------]]

Citizen.CreateThread(function()
    RequestModel(GetHashKey("a_m_y_business_03"))
	
    while not HasModelLoaded(GetHashKey("a_m_y_business_03")) do
        Wait(1)
    end
	
    local npc = CreatePed(4, 0xA1435105, 446.77, -1551.83, 28.28, 177.75, false, true)
    
    SetEntityHeading(npc, 177.75)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
	
end)

Citizen.CreateThread(function()
    exports['dark_target']:AddBoxZone("houseRobStart", vector3(446.83, -1551.95, 29.28), 0.6, 0.6, {
        name="houseRobStart",
        heading=0,
        --debugPoly=true
      }, {
          options = {
              {
                  event = "startRobbery",
                  icon = "far fa-clipboard",
                  label = "Signup for a houserobbery",
              },
          },
          job = {"all"},
          distance = 1.0
      })
end)

--[[-------------------------------------------
Get target and create route
---------------------------------------------]]

RegisterNetEvent("startRobbery")
AddEventHandler("startRobbery", function()
    if canStart then
        canStart = false
        ongoing = true
        exports['mythic_notify']:DoHudText('inform', 'Alright. I will send you a location shortly.')
        local missionWait = math.random( 1000,  10000)
        Citizen.Wait(missionWait)
        local missionTarget = Config.Locations[math.random(#Config.Locations)]
        TriggerEvent("createBlipAndRoute", missionTarget)
        TriggerEvent("createEntry", missionTarget)
    else
        exports['mythic_notify']:DoHudText('inform', 'You cant start another robbery right now.')
    end
end)

RegisterNetEvent("createBlipAndRoute")
AddEventHandler("createBlipAndRoute", function(missionTarget)
    exports['mythic_notify']:DoHudText('inform', 'You recived an robbery location.')
    targetBlip = AddBlipForCoord(missionTarget.location.x, missionTarget.location.y, missionTarget.location.z)
    SetBlipSprite(targetBlip, 374)
    SetBlipColour(targetBlip, 1)
    SetBlipAlpha(targetBlip, 90)
    SetBlipScale(targetBlip, 0.5)
    SetBlipRoute(targetBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Robbery location")
    EndTextCommandSetBlipName(targetBlip)
end)


--[[-------------------------------------------
Create entry, exit and loot locations
---------------------------------------------]]
RegisterNetEvent("createEntry")
AddEventHandler("createEntry", function(missionTarget)
    local streetNameHash = GetStreetNameAtCoord(missionTarget.location.x, missionTarget.location.y, missionTarget.location.z)
    local streetName = GetStreetNameFromHashKey(streetNameHash)
    entryZone = BoxZone:Create(missionTarget.location, 2.0, 2.0, {
        name="robbery_entry_zone",
        debugPoly= true
    })
    entryZone:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
        insideEntry = isPointInside
        inside = insideEntry
        local ped = PlayerPedId()
        if insideEntry then
            local string = 'Press [E] to start the robbery'
            exports['visual_prompt']:DisplayPrompt(string)
            Citizen.CreateThread(function()
                while ongoing do
                    if IsControlJustPressed(1, 38) and insideEntry then
                        inside = true
                        local finished = exports["dark_skillCheck"]:taskBar(10000,10)
                        if (finished == 100) then
                            exports['mythic_notify']:DoHudText('success', 'Alarm bypassed, police will be alerted in 3min')
                            SetEntityCoords(PlayerPedId(), missionTarget.inside.x, missionTarget.inside.y, missionTarget.inside.z)
                            if not robberyCreated then
                                TriggerEvent("createExit", missionTarget)
                                TriggerEvent("createLoot", missionTarget)
                                robberyCreated = true
                            end
                            RemoveBlip(targetBlip)
                            stealthCheck(missionTarget, streetName)
                            startAlarmCountDown(missionTarget, streetName)
                        else
                            exports['mythic_notify']:DoHudText('error', 'Alarm bypass failed, police was alerted')
                            PlaySoundFrontend(-1, "ScreenFlash", "MissionFailedSounds") -- Needs a better option. Has to be a alarm in radius for every player
                            exports['dark_dispatch']:addCall("10-56", "House Alarm", {
                                {icon = 'fa-road', info = streetName}
                            }, {missionTarget.location.x, missionTarget.location.y, missionTarget.location.z}, 'police', 3000, 374, 49)
                            SetEntityCoords(PlayerPedId(), missionTarget.inside.x, missionTarget.inside.y, missionTarget.inside.z)
                            if not robberyCreated then
                                TriggerEvent("createExit", missionTarget)
                                TriggerEvent("createLoot", missionTarget)
                                robberyCreated = true
                            end
                            RemoveBlip(targetBlip)
                        end
                    end
                    Citizen.Wait(0)
                end
            end)
        else
            exports['visual_prompt']:HidePrompt()
        end
    end)
end)

RegisterNetEvent("createExit")
AddEventHandler("createExit", function(missionTarget)
    local exitZone = BoxZone:Create(missionTarget.exit, 2.0, 2.0, {
        name="robbery_exit_zone",
        debugPoly= true,
        minZ = missionTarget.exitMinZ
    })
    exitZone:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
        insideExit = isPointInside
        inside = insideExit
        if isPointInside then
            local string = 'Press [E] to end robbery'
            exports['visual_prompt']:DisplayPrompt(string)
            Citizen.CreateThread(function()
                while ongoing do
                    if IsControlJustPressed(1, 38) and insideExit then
                        inside = true
                        SetEntityCoords(PlayerPedId(), missionTarget.outside.x, missionTarget.outside.y, missionTarget.outside.z)
                        Citizen.Wait(2000)
                        ongoing = false
                        entryZone:destroy()
                        exitZone:destroy()
                        cooldownNextRobbery()
                    end
                    Citizen.Wait(0)
                end
            end)
        else
            exports['visual_prompt']:HidePrompt()
        end
    end)
end)
RegisterNetEvent("createLoot")
AddEventHandler("createLoot", function(missionTarget)
    for i,v in ipairs(missionTarget.loot) do
        print(i, " ", v)
        local looted = false
        Citizen.CreateThread(function()
            while ongoing do
                local wait = 5000
                local ped = PlayerPedId()
                local pedCoords = GetEntityCoords(ped)
                if #(v - pedCoords) < 20 then
                    wait = 1
                    DrawMarker(27, v.x, v.y, v.z - 0.5, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0001, 0, 50, 255, 150, 0, 1, 2,0)
                    if #(v - pedCoords) < 2 then
                        drawTxt3D(v.x, v.y, v.z, "Press [E] to look for stuff here")
                        if IsControlJustPressed(0, 46) then
                            if not looted then
                                print(looted)
                                beginLoot()
                                looted = true
                            else
                                print(looted)
                            end
                        end
                    end
                end
                Wait(wait)
            end
        end)
    end
end)

function drawTxt3D(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
end

function beginLoot()
    exports['visual_progressbar']:Progress({
        name = "houseRobberyLoot",
        duration = 15000,
        label = "Searching...",
        useWhileDead = false,
        canCancel = false,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = "anim@amb@business@bgen@bgen_inspecting@",
            anim = "inspecting_low_lookingaround_inspector",
            flags = 1,
        },
    }, function(status)
        if not status then
            exports['mythic_notify']:DoCustomHudText('inform', 'Fertig', 4000)
            TriggerServerEvent("robbery:loot")
        else
            exports['mythic_notify']:DoCustomHudText('inform', 'Abgebrochen', 4000)
        end
    end)
end

function startAlarmCountDown(missionTarget, streetName)
    Citizen.Wait(180000)
    exports['dark_dispatch']:addCall("10-56", "House Alarm", {
        {icon = 'fa-road', info = streetName}
    }, {missionTarget.location.x, missionTarget.location.y, missionTarget.location.z}, 'police', 3000, 374, 49)
end

RegisterCommand("bug_prompt", function()
    exports['visual_prompt']:HidePrompt()
end)

function stealthCheck(missionTarget, streetName)
    local ped = PlayerPedId()
    ForcePedMotionState(ped, 0x422d7a25, 0,0,0)
    Citizen.Wait(3000)
    Citizen.CreateThread(function()
        while checkingStealth do
            local status = GetPedStealthMovement(ped)
            print(status)
            if status == false then
                checkingStealth = false
                PlaySoundFrontend(-1, "ScreenFlash", "MissionFailedSounds") -- Needs a better option. Has to be a alarm in radius for every player
                exports['mythic_notify']:DoHudText('error', 'You where to loud, alarm triggered!')
                exports['dark_dispatch']:addCall("10-56", "House Alarm", {
                    {icon = 'fa-road', info = streetName}
                }, {missionTarget.location.x, missionTarget.location.y, missionTarget.location.z}, 'police', 3000, 374, 49)
            end
            Citizen.Wait(3000)
        end
    end)
end

function cooldownNextRobbery()
    Citizen.Wait(600000) -- Needs a better option. So that client cant just reconnect and reset timer that way.
    canStart = true
    robberyCreated = false
    ongoing = false
    checkingStealth = true
end