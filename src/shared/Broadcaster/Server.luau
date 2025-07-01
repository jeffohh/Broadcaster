--!strict
--[[ Imports ]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkServer = require(script.Parent:WaitForChild("NetworkServer"))
local NetworkTypes = require(script.Parent:WaitForChild("NetworkTypes"))

--[[ Header ]]--
type Cached = {
    Camera: CFrame,
    CameraStamp: number,

    MouseX: number,
    MouseY: number,
    MouseStamp: number,

    ViewportX: number,
    ViewportY: number,

    MouseIcon: string
}

type Impl = {
    __index: Impl,

    View: (self: Server, viewer: Player, streamer: Player) -> (),
    Leave: (self: Server, viewer: Player) -> (),

    BindPlayers: (self: Server) -> (),

    BindCamera: (self: Server) -> (),
    BindViewport: (self: Server) -> (),
    BindMouse: (self: Server) -> (),
    BindMouseTarget: (self: Server) -> (),
}

type Proto = {
    cache: {[Player]: Cached},

    channels: {[Player]: {Player}},  -- streamer -> {viewers}
    viewers: {[Player]: Player}       -- viewer -> streamer
}

local module = {}

local Server: Impl = {} :: Impl
Server.__index = Server

export type Server = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local FPS_LIMIT = 1/60

--[[ Services ]]--
local Players = game:GetService("Players")

--[[ Private Variables ]]--

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Server)

    self.cache = {}
    self.channels = {}
    self.viewers = {}

    NetworkServer.Viewer.Request.On(function(player, request)
        if request.Action == "View" then
            self:View(player, request.Player)
        elseif request.Action == "Leave" then
            self:Leave(player)
        end
    end)

    self:BindPlayers()

    self:BindCamera()
    self:BindViewport()
    self:BindMouse()
    self:BindMouseTarget()

    return self
end

function Server:View(viewer, streamer)
    -- cannot watch yourself
    if viewer == streamer then return end

    -- if previously watching someone, leave
    if self.viewers[viewer] then
        self:Leave(viewer)
    end

    -- if viewer has streamers, make them leave
    for _, streamViewer in self.channels[viewer] do
        self:Leave(streamViewer)
    end

    -- watch new person
    table.insert(self.channels[streamer], viewer)
    self.viewers[viewer] = streamer
    NetworkServer.Streamer.Request.Fire(streamer, "Online")

    -- send snapshot of cached screen
    
end

function Server:Leave(viewer)
    -- retrieve what streamer they are watching
    local streamer = self.viewers[viewer]
    if streamer then
        local streamViewers = self.channels[streamer]
        local index = table.find(streamViewers, viewer)
        if index then
            -- remove from viewer list
            table.remove(self.channels[streamer], index)

            -- check viewer count, go offline if no viewers
            local viewerCount = #self.channels[streamer]
            if viewerCount == 0 then
                NetworkServer.Streamer.Request.Fire(streamer, "Offline")
            end
        end
    end
    self.viewers[viewer] = nil
end

function Server:BindPlayers()
    local function PlayerAdded(player: Player)
        self.cache[player] = {}
        self.channels[player] = {}
    end
    local function PlayerRemoving(player: Player)
        self.cache[player] = nil

        -- if previously watching someone, leave
        if self.viewers[player] then
            self:Leave(player)
        end

        -- make all viewers exit when streamer leaves
        for _, viewer in self.channels[player] do
            self:Leave(viewer)
        end

        -- remove from channels
        self.channels[player] = nil
    end

    for _, player in Players:GetPlayers() do
        task.defer(PlayerAdded)(player)
    end
    Players.PlayerAdded:Connect(PlayerAdded)
    Players.PlayerRemoving:Connect(PlayerRemoving)
end

function Server:BindCamera()
    NetworkServer.Streamer.Camera.On(function(player, stamp, cframe)
        self.cache[player].Camera = cframe
    end)
end

function Server:BindViewport()
    NetworkServer.Streamer.ViewportSize.On(function(player, viewportX, viewportY)
        self.cache[player].ViewportX = viewportX
        self.cache[player].ViewportY = viewportY
    end)
end

function Server:BindMouse()
    NetworkServer.Streamer.MousePosition.On(function(player, stamp, mouseX, mouseY)
        self.cache[player].MouseX = mouseX
        self.cache[player].MouseY = mouseY
    end)
end


function Server:BindMouseTarget()
    NetworkServer.Streamer.MouseTarget.On(function(player, basePart, size)
        -- check if hitbox expanding
    end)
end

return module.new()