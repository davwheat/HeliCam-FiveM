-- FiveM Heli Cam by davwheat and mraes
-- Version 2.0 05-11-2018 (DD-MM-YYYY)
-- config
local fov_max = 110
local fov_min = 7.5 -- max zoom level (smaller fov is more zoom)
local zoomspeed = 3.0 -- camera zoom speed
local speed_lr = 8.0 -- speed by which the camera pans left-right
local speed_ud = 8.0 -- speed by which the camera pans up-down
local toggle_helicam = 51 -- control id of the button by which to toggle the helicam mode. Default: INPUT_CONTEXT (E)
local toggle_vision = 25 -- control id to toggle vision mode. Default: INPUT_AIM (Right mouse btn)
local toggle_rappel = 154 -- control id to rappel out of the heli. Default: INPUT_DUCK (X)
local toggle_spotlight = 183 -- control id to toggle the front spotlight Default: INPUT_PhoneCameraGrid (G)
local toggle_lock_on = 22 -- control id to lock onto a vehicle with the camera. Default is INPUT_SPRINT (spacebar)
local minHeightAboveGround = 1.5 -- default: 1.5. Minimum height above ground to activate Heli Cam (in metres). Should be between 1 and 20.
local useMilesPerHour = 1 -- 0 is kmh; 1 is mph

-- Script starts here
local helicam = false -- is in helicam
local fov = (fov_max + fov_min) * 0.5
local vision_state = 0 -- 0 is normal, 1 is night vision, 2 is thermal vision
local spotlight_state = false

local function DebugPrint(msg)
    if not Config.Debug then return end
    print(string.format("^2[HeliCam System] ^7%s", msg))
end

local RunHeliThread = false

local locked_on_vehicle = nil
local function LODCheck()
    while locked_on_vehicle do
        if not cache.vehicle then
            return
        end
        local dist = #(GetEntityCoords(cache.vehicle) - GetEntityCoords(locked_on_vehicle))
        if not HasEntityClearLosToEntity(cache.vehicle, locked_on_vehicle, 17) then
            SetControlNormal(0, toggle_lock_on, 1.0)
        elseif dist > 300.0 then
            SetControlNormal(0, toggle_lock_on, 1.0)
        end
        Wait(500)
    end
end

local function HeliThread()
    CreateThread(
        function()
            while RunHeliThread do
                Wait(0)

                local lPed = cache.ped
                local heli = cache.vehicle

                if IsHeliHighEnough(heli) then
                    if IsControlJustPressed(0, toggle_helicam) and not helicam then -- Toggle Helicam
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                        helicam = true
                        SendNUIMessage({type = "show"})
                    end

                    if IsControlJustPressed(0, toggle_rappel) then -- Initiate rappel
                        Citizen.Trace("Attempting rapel from helicopter...\n")
                        if cache.seat == 1 or cache.seat == 2 then
                            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                            TaskRappelFromHeli(lPed, 1)
                        else
                            lib.notify(
                                {
                                    id = "rappel_error",
                                    title = "Wrong Seat",
                                    description = "You can not rappel from this seat!",
                                    position = "center-right",
                                    style = {
                                        backgroundColor = "#141517",
                                        color = "#C1C2C5",
                                        [".description"] = {color = "#909296"}
                                    },
                                    icon = "ban",
                                    iconColor = "#C53030"
                                }
                            )
                            PlaySoundFrontend(-1, "5_Second_Timer", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", false)
                        end
                    end
                end

                if helicam then
                    local scaleform = RequestScaleformMovie("DRONE_CAM")
                    while not HasScaleformMovieLoaded(scaleform) do
                        Citizen.Wait(0)
                    end

                    local lPed = cache.ped
                    local heli = cache.vehicle
                    local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
                    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
                    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(heli))
                    SetCamFov(cam, fov)
                    RenderScriptCams(true, false, 0, 1, 0)

                    -- BeginScaleformMovieMethod(scaleform, "SET_LOCATION")
                    -- ScaleformMovieMethodAddParamInt(0)
                    -- EndScaleformMovieMethod()

                    locked_on_vehicle = nil
                    while helicam and not IsEntityDead(cache.ped) and cache.vehicle and IsHeliHighEnough(heli) do
                        if IsControlJustPressed(0, toggle_helicam) then -- Toggle Helicam
                            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                            helicam = false
                            SendNUIMessage({type = "hide"})
                        end

                        if IsControlJustPressed(0, toggle_vision) then
                            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                            ChangeVision()
                        end

                        DisableControlAction(0, 75, true) -- disable exit vehicle
                        DisableControlAction(27, 75, true) -- disable exit vehicle

                        local vehicle = nil

                        if locked_on_vehicle then
                            if DoesEntityExist(locked_on_vehicle) then
                                vehicle = locked_on_vehicle

                                PointCamAtEntity(cam, locked_on_vehicle, 0.0, 0.0, 0.0, true)
                                if IsControlJustPressed(0, toggle_lock_on) then
                                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                                    locked_on_vehicle = nil
                                    local rot = GetCamRot(cam, 2) -- All this because I can't seem to get the camera unlocked from the entity
                                    local fov = GetCamFov(cam)
                                    local old
                                    cam = cam
                                    DestroyCam(old_cam, false)
                                    cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
                                    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
                                    SetCamRot(cam, rot, 2)
                                    SetCamFov(cam, fov)
                                    RenderScriptCams(true, false, 0, 1, 0)
                                end
                            else
                                locked_on_vehicle = nil -- Cam will auto unlock when entity doesn't exist anyway
                            end
                        else
                            local zoomvalue = (1.0 / (fov_max - fov_min)) * (fov - fov_min)
                            CheckInputRotation(cam, zoomvalue)
                            local vehicle_detected = GetVehicleInView(cam)
                            if DoesEntityExist(vehicle_detected) then
                                vehicle = vehicle_detected

                                if IsControlJustPressed(0, toggle_lock_on) then
                                    local dist = #(GetEntityCoords(cache.vehicle) - GetEntityCoords(vehicle_detected))
                                    if dist < 300.0 then
                                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                                        locked_on_vehicle = vehicle_detected
                                        CanSeeTarget = true
                                        CreateThread(LODCheck)
                                    end
                                end
                            end
                        end

                        HandleZoom(cam)
                        HideHUDThisFrame()

                        HandleSpotlight(cam)

                        BeginScaleformMovieMethod(scaleform, "SET_DISPLAY_CONFIG")
                        ScaleformMovieMethodAddParamInt(0)
                        ScaleformMovieMethodAddParamInt(0)
                        ScaleformMovieMethodAddParamFloat(0.0)
                        ScaleformMovieMethodAddParamFloat(0.0)
                        ScaleformMovieMethodAddParamFloat(0.0)
                        ScaleformMovieMethodAddParamFloat(0.0)
                        ScaleformMovieMethodAddParamBool(true)
                        ScaleformMovieMethodAddParamBool(true)
                        ScaleformMovieMethodAddParamBool(false)
                        EndScaleformMovieMethod()

                        BeginScaleformMovieMethod(scaleform, "SET_ALT_FOV_HEADING")
                        ScaleformMovieMethodAddParamFloat(GetEntityCoords(heli).z)
                        ScaleformMovieMethodAddParamFloat(zoomvalue)
                        ScaleformMovieMethodAddParamFloat(GetCamRot(cam, 2).z)
                        EndScaleformMovieMethod()

                        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)

                        local playerCoords = GetEntityCoords(lPed)

                        local streetname =
                            GetStreetNameFromHashKey(
                            GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
                        )

                        local roadHashNearHeli

                        if vehicle == nil then
                            SendNUIMessage(
                                {
                                    type = "update",
                                    info = {
                                        fov = fov,
                                        numPlate = "",
                                        vehRoadName = "",
                                        acftRoadName = streetname,
                                        acftHeading = GetEntityHeading(heli),
                                        heading = GetCamRot(cam, 2).z,
                                        vehHeading = -1,
                                        altitude = GetEntityHeight(
                                            lPed,
                                            playerCoords.x,
                                            playerCoords.y,
                                            playerCoords.z,
                                            true,
                                            true
                                        ),
                                        altitudeAGL = GetEntityHeightAboveGround(lPed),
                                        locked = not (not locked_on_vehicle),
                                        camtype = vision_state,
                                        speed = "",
                                        spotlight = spotlight_state
                                    }
                                }
                            )
                        else
                            local vehicleCoords = GetEntityCoords(vehicle)
                            local vehstreetname =
                                GetStreetNameFromHashKey(
                                GetStreetNameAtCoord(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z)
                            )

                            local vehspd = ""

                            if useMilesPerHour then
                                vehspd =
                                    string.format(
                                    "%." .. (numDecimalPlaces or 0) .. "f",
                                    GetEntitySpeed(vehicle) * 2.236936
                                ) .. " mph"
                            else
                                vehspd =
                                    string.format("%." .. (numDecimalPlaces or 0) .. "f", GetEntitySpeed(vehicle) * 3.6) ..
                                    " kmh"
                            end

                            SendNUIMessage(
                                {
                                    type = "update",
                                    info = {
                                        fov = fov,
                                        numPlate = GetVehicleNumberPlateText(vehicle),
                                        vehRoadName = vehstreetname,
                                        acftRoadName = streetname,
                                        acftHeading = GetEntityHeading(heli),
                                        heading = RotAnglesToVec(GetCamRot(cam, 2)).z,
                                        vehHeading = GetEntityHeading(vehicle),
                                        altitude = GetEntityHeight(
                                            heli,
                                            playerCoords.x,
                                            playerCoords.y,
                                            playerCoords.z,
                                            true,
                                            false
                                        ),
                                        altitudeAGL = GetEntityHeightAboveGround(lPed),
                                        locked = not (not locked_on_vehicle),
                                        camtype = vision_state,
                                        speed = vehspd,
                                        spotlight = spotlight_state
                                    }
                                }
                            )
                        end

                        Citizen.Wait(0)
                    end
                    helicam = false
                    -- ClearTimecycleModifier()
                    fov = (fov_max + fov_min) * 0.5 -- reset to starting zoom level
                    RenderScriptCams(false, false, 0, 1, 0) -- Return to gameplay camera
                    SetScaleformMovieAsNoLongerNeeded(scaleform) -- Cleanly release the scaleform
                    DestroyCam(cam, false)
                    SetNightvision(false)
                    SetSeethrough(false)
                    SendNUIMessage({type = "hide"})
                    vision_state = 0
                    spotlight_state = false
                end
            end
        end
    )
end

CreateThread(
    function()
        local HasPerms = lib.callback.await("Helicam:CheckPerms", false)
        if HasPerms then
            lib.onCache(
                "vehicle",
                function(value)
                    if value and GetVehicleClass(value) == 15 then
                        DebugPrint("Heli Thread Started")
                        if RunHeliThread then
                            return
                        end
                        RunHeliThread = true
                        HeliThread()
                    else
                        RunHeliThread = false
                        LocalPlayer.state:set(
                            "spotlight_data",
                            {
                                enabled = false,
                                camcoords = 0,
                                forward_vector = 0
                            },
                            true
                        )
                    end
                end
            )
        end
    end
)

function IsHeliHighEnough(heli)
    return GetEntityHeightAboveGround(heli) > minHeightAboveGround
end

function ChangeVision()
    if vision_state == 0 then
        SetNightvision(true)
        vision_state = 1
    elseif vision_state == 1 then
        SetNightvision(false)
        SetSeethrough(true)
        vision_state = 2
    else
        SetSeethrough(false)
        vision_state = 0
    end
end

function HideHUDThisFrame()
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()
    HideHudComponentThisFrame(1) -- Wanted Stars
    HideHudComponentThisFrame(2) -- Weapon icon
    HideHudComponentThisFrame(3) -- Cash
    HideHudComponentThisFrame(4) -- MP CASH
    HideHudComponentThisFrame(7) -- Area Name
    HideHudComponentThisFrame(8) -- Vehicle Class
    HideHudComponentThisFrame(9) -- Street Name
    HideHudComponentThisFrame(11) -- Floating Help Text
    HideHudComponentThisFrame(12) -- more floating help text
    HideHudComponentThisFrame(13) -- Cash Change
    HideHudComponentThisFrame(15) -- Subtitle Text
    HideHudComponentThisFrame(18) -- Game Stream
    HideHudComponentThisFrame(19) -- weapon wheel
    HideHudComponentThisFrame(21) -- weapon wheel
end

function CheckInputRotation(cam, zoomvalue)
    local rightAxisX = GetDisabledControlNormal(0, 220)
    local rightAxisY = GetDisabledControlNormal(0, 221)
    local rotation = GetCamRot(cam, 2)
    if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
        new_z = rotation.z + rightAxisX * -1.0 * (speed_ud) * (zoomvalue + 0.1)
        new_x = math.max(math.min(20.0, rotation.x + rightAxisY * -1.0 * (speed_lr) * (zoomvalue + 0.1)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
        SetCamRot(cam, new_x, 0.0, new_z, 2)
    end
end

function HandleZoom(cam)
    if IsControlJustPressed(0, 241) then -- Scrollup
        fov = math.max(fov - zoomspeed, fov_min)
    end
    if IsControlJustPressed(0, 242) then
        fov = math.min(fov + zoomspeed, fov_max) -- ScrollDown
    end
    local current_fov = GetCamFov(cam)
    if math.abs(fov - current_fov) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
        fov = current_fov
    end
    SetCamFov(cam, current_fov + (fov - current_fov) * 0.05) -- Smoothing of camera zoom
end

function GetVehicleInView(cam)
    local coords = GetCamCoord(cam)
    local forward_vector = RotAnglesToVec(GetCamRot(cam, 2))
    -- DrawLine(coords, coords+(forward_vector*100.0), 255,0,0,255) -- debug line to show LOS of cam
    local rayhandle =
        StartShapeTestRay(coords, coords + (forward_vector * 350.0), 10, GetVehiclePedIsIn(GetPlayerPed(-1)), 0)
    local _, _, _, _, entityHit = GetShapeTestResult(rayhandle)
    if entityHit > 0 and IsEntityAVehicle(entityHit) then
        return entityHit
    else
        return nil
    end
end

RegisterNetEvent("heli:spotlight_on")
RegisterNetEvent("heli:spotlight_off")
RegisterNetEvent("heli:spotlight_update")

local currentPlayerId = cache.serverId

local spotlights = {}

local spotlight_thread = false
local function RunSpotlights()
    CreateThread(
        function()
            while spotlight_thread do
                for key, value in pairs(spotlights) do
                    if
                        value.enabled and key ~= currentPlayerId and value.camcoords ~= nil and
                            value.forward_vector ~= nil
                     then
                        DrawSpotLight(
                            value.camcoords,
                            value.forward_vector,
                            255,
                            255,
                            255,
                            300.0,
                            1.0,
                            0.75,
                            7.50,
                            75.0
                        )
                    end
                end
                Wait(0)
            end
        end
    )
end

LocalPlayer.state:set(
    "spotlight_data",
    {
        enabled = false,
        camcoords = 0,
        forward_vector = 0
    },
    true
)

AddStateBagChangeHandler(
    "spotlight_data",
    nil,
    function(bagName, key, value)
        local player = GetPlayerFromStateBagName(bagName)
        if player == 0 then
            return
        end

        local player_id = GetPlayerServerId(player)
        if player_id == cache.serverId then
            return
        end

        if value.enabled then
            --print("Updating spotlight for player: " .. GetPlayerName(player))

            if not spotlights[player_id] then
                DebugPrint(string.format("Adding spotlight for player: %s [%s]", GetPlayerName(player), player_id))
            end

            spotlights[player_id] = value

            if not spotlight_thread then
                DebugPrint("Starting Spotlight Main Thread")
                spotlight_thread = true
                RunSpotlights()
            end
        else
            if spotlights[player_id] then
                DebugPrint(string.format("Removing spotlight for player: %s [%s]", GetPlayerName(player), player_id))
                spotlights[player_id] = nil
                if #spotlights == 0 then
                    DebugPrint("Stopping Spotlight Thread - No More Left In Cache.")
                    spotlight_thread = false
                end
            end
        end
    end
)

function HandleSpotlight(cam)
    if IsControlJustPressed(0, toggle_spotlight) then
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
        spotlight_state = not spotlight_state
    end

    if spotlight_state then
        local rotation = GetCamRot(cam, 2)
        local forward_vector = RotAnglesToVec(rotation)
        local camcoords = GetCamCoord(cam)

        DrawSpotLight(camcoords, forward_vector, 255, 255, 255, 300.0, 1.0, 0.75, 7.50, 75.0)

        SyncInfoToNetwork(
            {
                enabled = true,
                camcoords = camcoords,
                forward_vector = forward_vector
            }
        )
    else
        SyncInfoToNetwork(
            {
                enabled = false,
                camcoords = 0,
                forward_vector = 0
            }
        )
    end
end

function RotAnglesToVec(rot) -- input vector3
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local sync_cooldown = false
function SyncInfoToNetwork(data)
    if not sync_cooldown then
        LocalPlayer.state:set(
            "spotlight_data",
            {
                enabled = data.enabled,
                camcoords = data.camcoords,
                forward_vector = data.forward_vector
            },
            true
        )

        sync_cooldown = true
        SetTimeout(
            100,
            function()
                sync_cooldown = false
            end
        )
    end
end
