--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

    View: (self: Client, player: Player) -> ()
}

type Proto = {
    
}

local module = {}

local Client: Impl = {} :: Impl
Client.__index = Client

export type Client = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--


--[[ Services ]]--
local Players = game:GetService("Players")

--[[ Private Variables ]]--
local LocalPlayer = Players.LocalPlayer

local Packets = script.Parent:WaitForChild("Packets")
local broadcastPacket = require(Packets:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Client)

    return self
end

function Client:View(subject: Player)
    broadcastPacket.View.send(subject)
end

function Client:Leave()
    broadcastPacket.Leave.send(LocalPlayer)
end


return module.new()