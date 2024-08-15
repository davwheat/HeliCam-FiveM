Config = {
    Permissions = {
        Enabled = true, -- if set to false, it will not check ace perm
        AcePerm = "leo-perms", -- ace perm to use helicam
    },
    AllowInAnyHeli = true, -- if set to false, it will only allow in the helis listed below
    Vehicles = {
        [GetHashKey("polmav")] = true
    },
    Debug = false, -- debug prints
}
