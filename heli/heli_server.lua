-- FiveM Heli Cam by davwheat and mraes
-- Version 2.0 05-11-2018 (DD-MM-YYYY)

RegisterServerEvent("heli:spotlight")
AddEventHandler(
	"heli:spotlight",
	function(state)
		local serverID = source
		TriggerClientEvent("heli:spotlight", -1, serverID, state)
	end
)
