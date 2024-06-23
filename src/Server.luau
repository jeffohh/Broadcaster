--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

    AddViewer: (self: Server, viewer: Player, subject: Player) -> (),
    RemoveViewer: (self: Server, viewer: Player) -> ()
}

type Proto = {
    streamers: {[Player]: {Player}}, -- streamer -> {viewers}
    viewers: {[Player]: Player} -- viewer -> streamer
}

local module = {}

local Server: Impl = {} :: Impl
Server.__index = Server

export type Server = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--


--[[ Services ]]--
local Players = game:GetService("Players")

--[[ Private Variables ]]--
local ByteNetLibrary = script.Parent:WaitForChild("ByteNetLibrary")
local broadcastPacket = require(ByteNetLibrary:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Server)

    self.streamers = {}
    self.viewers = {}

    broadcastPacket.View.listen(function(data, player: Player)
        local viewer = player
        local subject = data

        self:AddViewer(viewer, subject)
    end)

    broadcastPacket.Leave.listen(function(data, player: Player)
        local viewer = player

        self:RemoveViewer(viewer)
    end)

    return self
end


function Server:AddViewer(viewer: Player, subject: Player)
    self.viewers[viewer] = subject
    
    if (not self.streamers[subject]) then
        self.streamers[subject] = {}
    end

    table.insert(self.streamers[subject], viewer)
    -- send to streamer, turn stream on
    -- if viewer was streaming, remove all viewers
end

function Server:RemoveViewer(viewer: Player)
    local subject = self.viewers[viewer]

    if (subject) and (self.streamers[subject]) then
        local index = table.find(self.streamers[subject], viewer)
        if (index) then
            table.remove(self.streamers[subject], index)
            -- send to streamer, turn stream off if no viewers
        end
    end

    self.viewers[viewer] = nil
end


return module.new()