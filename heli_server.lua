lib.callback.register(
    "Helicam:CheckPerms",
    function(source)
        local src = source
        if Config.Permissions.Enabled then
            return IsPlayerAceAllowed(src, Config.Permissions.AcePerm)
        else
            return true
        end
    end
)
