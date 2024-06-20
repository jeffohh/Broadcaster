--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

}

type Proto = {
    
}

local module = {}

local Server: Impl = {} :: Impl
Server.__index = Server

export type Server = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--


--[[ Services ]]--
local Players = game:GetService("Players")

--[[ Private Variables ]]--
local Packets = script.Parent:WaitForChild("Packets")
local broadcastPacket = require(Packets:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Server)

    broadcastPacket.View.listen(function(data, player: Player)
        local viewer = player
        local subject = data
    end)

    broadcastPacket.Leave.listen(function(data, player: Player)
        local viewer = player
    end)

    return self
end


return module.new()