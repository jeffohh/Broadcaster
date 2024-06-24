local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("ByteNet"))

return ByteNet.defineNamespace("streamPacket", function()
    return {
        Screen = ByteNet.definePacket({
            reliabilityType = "unreliable",
            value = ByteNet.struct({
                CFrame = ByteNet.cframe,
                MouseHitPosition = ByteNet.vect3
            })
        }),

        Input = ByteNet.definePacket({
            value = ByteNet.struct({
                Name = ByteNet.string,
                State = ByteNet.string
            })
        }),

        MouseIcon = ByteNet.definePacket({
            value = ByteNet.string
        })
    }
end)