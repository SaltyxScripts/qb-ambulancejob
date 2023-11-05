local QBCore = exports['qb-core']:GetCoreObject()
local hospitalLocations = {
    vector3(291.55, -606.26, 43.21),
    vector3(-466.62, -342.31, 34.37),
    vector3(1842.33, 3668.43, 33.68),
    vector3(-236.79, 6331.55, 32.4),
}
local carry = {
	InProgress = false,
	targetSrc = -1,
	type = "",
	personCarrying = {
		animDict = "missfinale_c2mcs_1",
		anim = "fin_c2_mcs_1_camman",
		flag = 49,
	},
	personCarried = {
		animDict = "nm",
		anim = "firemans_carry",
		attachX = 0.27,
		attachY = 0.15,
		attachZ = 0.63,
		flag = 33,
	}
}
local offlineMedic = nil
local offlineAmbulance = nil
local timerOn = false
local timerExpired = false

local function ensureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end        
    end
    return animDict
end

function loadAnimDict( dict )
    RequestAnimDict( dict )
    while ( not HasAnimDictLoaded( dict ) ) do
        Citizen.Wait( 3 )
    end
end

function findNearestHospital()
    local pCoords = GetEntityCoords(PlayerPedId())
    local nearest = hospitalLocations[1]
    local distance = #(pCoords - nearest)
    for i = 2, #hospitalLocations do
        if #(pCoords - hospitalLocations[i]) < distance then
            distance = #(pCoords - hospitalLocations[i])
            nearest = hospitalLocations[i]
        end
    end
    return nearest
end

function CalculateDirection(fromPos, toPos)
    local direction = math.atan2(toPos.y - fromPos.y, toPos.x - fromPos.x) * (180 / math.pi)
    return direction - 90
end

RegisterNetEvent('qb-ambulancejob:client:checkOfflineMedic')
AddEventHandler('qb-ambulancejob:client:checkOfflineMedic', function()
    beginMonkeyMedical()
end)

RegisterNetEvent('qb-ambulancejob:client:cleanOfflineMedic', function()
    -- clean up
    cleanUp()
end)

Citizen.CreateThread(function()
    local i = 0
    while true do
        if not timerOn then
            Wait(5000)
        else
            Wait(1)
            while timerOn do
                Wait(500)
                i = i + 1
                if i >= 120 then
                    timerExpired = true
                    timeOn = false
                end
            end
        end
    end

end)

function beginMonkeyMedical()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    math.randomseed(GetGameTimer())
    local randX, randY = math.random(-50, 50), math.random(-50, 50)
    local randX, randY = 0,0
    local coordsBehindPlayer = GetOffsetFromEntityInWorldCoords(ped, 100.0, -50.0, 0.0)
    local found, outPos, outHeading = GetClosestVehicleNodeWithHeading(coordsBehindPlayer['x'], coordsBehindPlayer['y'], coordsBehindPlayer['z'], 1, 3.0, 0)
    local playerHeading = GetEntityHeading(playerPed)
   
    -- spawn ambulance
    RequestModel(`thruster`)
    while not HasModelLoaded(`thruster`) do 
        Wait(5)
    end
    offlineAmbulance = CreateVehicle(`thruster`, outPos.x, outPos.y, outPos.z, true, true)
    SetEntityHeading(offlineAmbulance, CalculateDirection(GetEntityCoords(offlineAmbulance), coords))
    SetVehicleNumberPlateText(offlineAmbulance, "MNKY MD")
    exports['LegacyFuel']:SetFuel(offlineAmbulance, 100.0)
    -- spawn monkey
    RequestModel(`a_c_chimp`)
    while not HasModelLoaded(`a_c_chimp`) do
        Wait(5)
    end
    offlineMedic = CreatePedInsideVehicle(offlineAmbulance, 30, `a_c_chimp`, -1, true, true)
    -- set monkey attributes
    SetPedFleeAttributes(offlineMedic, 0, 0)
    Wait(100)
    SetPedIntoVehicle(offlineMedic, offlineAmbulance, -1)
    SetVehicleSiren(offlineAmbulance, true)
    SetEntityInvincible(offlineMedic, true)
    SetEntityInvincible(offlineAmbulance, true)
    SetPedCanRagdoll(offlineMedic, false)

    local ret, destinationCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 0, 100.0, 2.5)
    -- TaskVehicleDriveToCoordLongrange(offlineMedic, offlineAmbulance, destinationCoords.x, destinationCoords.y, destinationCoords.z, 60.0, 828, 5.0)
    -- print("drive")
    -- TaskHeliChase(offlineMedic, PlayerPedId(), 0.0, 0.0, 40.0)
    TaskHeliMission(offlineMedic, offlineAmbulance, 0, 0, destinationCoords.x, destinationCoords.y, destinationCoords.z + 40.0, 4, 80.0, 5.0, 0.0, 0, 0, 0.0, 0)
    local dest = vector3(coords.x, coords.y, coords.z + 40.0)
    Citizen.CreateThread(function()
        while true do
            local c = GetEntityCoords(offlineAmbulance)
            if (#(dest - c) < 10.0) then
                -- print("reached dest")
                SetEntityVelocity(offlineAmbulance, 0.0, 0.0, 0.0)
                -- beginWalk()\
                beginLanding()
                return
            end
            Wait(5)
        end
    end)
end

function beginLanding()
    -- print("arrived above")

    local coords = GetEntityCoords(PlayerPedId())
    -- print(coords)
    local ret, destinationCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 0, 100.0, 2.5)
    TaskHeliMission(offlineMedic, offlineAmbulance, 0, 0, destinationCoords.x, destinationCoords.y, destinationCoords.z, 20, 10.0, 5.0, 0.0, 0, 0, 0.0, 0)
    Citizen.CreateThread(function()
        while true do
            local ambCoords = GetEntityCoords(offlineAmbulance)
            local vel = GetEntityVelocity(offlineAmbulance)
            local altitude = ambCoords.z

            local dist = #(ambCoords - destinationCoords)
            local isCloseToLanding = (dist < 5.0)
            local isStationary = (#(vel - vector3(0.0, 0.0, 0.0)) < 0.5)
            local isCloseToGround = (GetEntityHeightAboveGround(offlineAmbulance) < 0.85)
            -- print(isCloseToLanding)
            -- print(isStationary)
            -- print(isCloseToGround)
            -- print(GetEntityHeightAboveGround(offlineAmbulance))
            -- print("====")
            -- if (#(ambCoords - coords) < 1.0) then
            if isCloseToLanding and isStationary and isCloseToGround then
                -- print("landed")
                SetEntityVelocity(offlineAmbulance, 0.0)
                FreezeEntityPosition(offlineAmbulance, true)
                beginWalk()
                return
            end
            Wait(5)
        end
    end)
end

function beginWalk()
    -- ClearPedTasksImmediately(offlineMedic)
    -- SetVehicleSiren(offlineAmbulance, false)
    TaskLeaveVehicle(offlineMedic, offlineAmbulance, 0)
    Wait(500)
    local ped = PlayerPedId()
    TaskGoToEntity(offlineMedic, ped, -1, 1.0, 1073741824, 0)
    timerOn = true
    Citizen.CreateThread(function()
        while true do
            if timerExpired then
                -- could not reach in tikme
                cleanUp()
                return
            else
                local c = GetEntityCoords(offlineMedic)
                if (#(c - GetEntityCoords(ped)) < 1.0) then
                    timerOn = false
                    -- beginPickup()
                    beginHeal()
                    return
                end
            end
            Wait(5)

        end
    end)
end

function CarryPerson()
    ensureAnimDict(carry.personCarried.animDict)
    TaskPlayAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 8.0, -8.0, 100000, carry.personCarried.flag, 0, false, false, false)
    TaskPlayAnim(offlineMedic, carry.personCarrying.animDict, carry.personCarrying.anim, 8.0, -8.0, 100000, carry.personCarrying.flag, 0, false, false, false)
	AttachEntityToEntity(PlayerPedId(), offlineMedic, 0, carry.personCarried.attachX, carry.personCarried.attachY, carry.personCarried.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
end

function PlaceInVehicle(vehicle)
	local playerPed = PlayerPedId()
	local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)
	for i=maxSeats - 1, 0, -1 do
		if IsVehicleSeatFree(vehicle, i) then
			freeSeat = i
			break
		end
	end
	if freeSeat then
		TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
	end
end

function beginPickup()
    ClearPedTasksImmediately(offlineMedic)
    CarryPerson()
    Wait(200)
    TaskGoToEntity(offlineMedic, offlineAmbulance, -1, 1.0, 1073741824, 0)
    timerOn = true
    Citizen.CreateThread(function()
        while true do
            if timerExpired then
                -- could not reach
                cleanUp()
                return
            else
                local c = GetEntityCoords(offlineMedic)
                if (#(c - GetEntityCoords(offlineAmbulance)) < 2.0) then
                    PlaceInVehicle(offlineAmbulance)
                    SetVehicleSiren(offlineAmbulance, true)
                    TaskEnterVehicle(offlineMedic, offlineAmbulance, 999, -1, 2.0, 16, 0)
                    Citizen.CreateThread(function()
                        while true do
                            if (IsPedInAnyVehicle(offlineMedic, false)) then
                                timerOn = false
                                beginReturn()
                                return
                            end
                            Wait(5)
                        end
                    end)
                end
            end
            Wait(5)
        end
    end)
end

function beginReturn()
    local closestHospital = findNearestHospital()
    print(closestHospital)
    TaskVehicleDriveToCoordLongrange(offlineMedic, offlineAmbulance, closestHospital.x, closestHospital.y, closestHospital.z, 80.0, 525100, 5.0)
    timerOn = true
    Citizen.CreateThread(function()
        while true do
            if timerExpired then
                -- could not reach
                cleanUp()
                return
            else
                local c = GetEntityCoords(offlineAmbulance)
                if (#(c - closestHospital) < 5.0) then
                    timerOn = false
                    beginHeal()
                    return
                end
            end
            
            Wait(5)
        end
    end)
end

function beginHeal()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(offlineMedic)
    TaskTurnPedToFaceEntity(offlineMedic, ped, -1)
    loadAnimDict(healAnimDict)
    TaskPlayAnim(offlineMedic, healAnimDict, healAnim, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
    Wait(3000)
    local bedId = GetAvailableBed()
    if bedId then
        TriggerServerEvent("hospital:server:SendToBed", bedId, true)
    end
    cleanUp()
    return
end

function cleanUp()
    timerOn = false
    timerExpired = false
    if offlineMedic then
        DeleteEntity(offlineMedic)
        offlineMedic = nil
    end
    if offlineAmbulance then
        DeleteEntity(offlineAmbulance)
        offlineAmbulance = nil
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    ClearPedSecondaryTask(PlayerPedId())
    cleanUp()
end)


