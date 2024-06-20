local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("ByteNet"))

return ByteNet.defineNamespace("streamPacket", function()
    return {
        Screen = ByteNet.definePacket({
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
        })
    }
end)