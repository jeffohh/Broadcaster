local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("ByteNet"))

return ByteNet.defineNamespace("broadcastPacket", function()
    return {
        View = ByteNet.definePacket({
            value = ByteNet.inst
        }),

        Leave = ByteNet.definePacket({
            value = ByteNet.nothing
        }),

        SetActivate = ByteNet.definePacket({
            value = ByteNet.bool
        }),

        Watching = ByteNet.definePacket({
            value = ByteNet.bool
        })
    }
end)