--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,
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

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Broadcaster)

    return self
end

function Broadcaster:RequestStream()
    
end


return module