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

--[[ Private Variables ]]--
local ByteNetLibrary = script.Parent:WaitForChild("ByteNetLibrary")

local streamPacket = require(ByteNetLibrary:WaitForChild("streamPacket"))
local broadcastPacket = require(ByteNetLibrary:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Server)

    self.streamers = {}
    self.viewers = {}

    -- packet handling
    streamPacket.Screen.listen(function(data, player: Player)
        local listeners = self.streamers[player]
        
        for i=1, #listeners do
            streamPacket.Screen.sendTo(data, listeners[i])
        end
    end)

    streamPacket.Input.listen(function(data, player: Player)
        local listeners = self.streamers[player]
        
        for i=1, #listeners do
            streamPacket.Input.sendTo(data, listeners[i])
        end
    end)

    streamPacket.MouseIcon.listen(function(data, player: Player)
        local listeners = self.streamers[player]
        
        for i=1, #listeners do
            streamPacket.MouseIcon.sendTo(data, listeners[i])
        end
    end)

    -- viewer handling
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
    if (viewer == subject) then return end

    -- make them stop spectating whoever
    self:RemoveViewer(viewer)

    -- if viewer was streaming, remove all viewers
    if (self.streamers[viewer]) then
        for _, player in next, self.streamers[viewer] do
            self:RemoveViewer(player)
        end
    end

    -- add viewer to viewer list, add viewer to streamer list
    self.viewers[viewer] = subject

    if (not self.streamers[subject]) then
        self.streamers[subject] = {}
    end

    table.insert(self.streamers[subject], viewer)

    -- send to streamer, turn stream on
    broadcastPacket.SetActivate.sendTo(true, subject)
    broadcastPacket.SetWatching.sendTo(true, viewer)
end

function Server:RemoveViewer(viewer: Player)
    local subject = self.viewers[viewer]

    if (subject and self.streamers[subject]) then
        local index = table.find(self.streamers[subject], viewer)
        if (index) then
            table.remove(self.streamers[subject], index)

            -- send to streamer, turn stream off if no viewers
            if (#self.streamers[subject] == 0) then
                broadcastPacket.SetActivate.sendTo(false, subject)
            end
        end
    end

    self.viewers[viewer] = nil
    broadcastPacket.SetWatching.sendTo(false, viewer)
end


return module.new()