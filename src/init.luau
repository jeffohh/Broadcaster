--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

    View: (self: Broadcaster, player: Player) -> ()
}

type Proto = {
    
}

local module = {}

local Broadcaster: Impl = {} :: Impl
Broadcaster.__index = Broadcaster

export type Broadcaster = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--


--[[ Services ]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[ Private Variables ]]--
local streamPacket = require(script:WaitForChild("streamPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Broadcaster)

    return self
end

function Broadcaster:View(player: Player)
    
end


return module.new()