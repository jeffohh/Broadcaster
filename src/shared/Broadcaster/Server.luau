--!strict
--[[ Imports ]]--
local NetworkServer = require(script.Parent:WaitForChild("NetworkServer"))

--[[ Header ]]--
type Cached = {
    ScreenStamp: number,
    Camera: CFrame,
    MousePosition: Vector3,
    MouseIcon: string
}

type Impl = {
    __index: Impl,

    View: (self: Server, viewer: Player, streamer: Player) -> (),
    Leave: (self: Server, viewer: Player) -> (),

    _BindPlayers: (self: Server) -> (),

    _BindScreen: (self: Server) -> (),
    _BindMouseIcon: (self: Server) -> (),
    _BindMouseTarget: (self: Server) -> (),
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
        print(player, request)
        if request.Action == "View" then
            self:View(player, request.Player)
        elseif request.Action == "Leave" then
            self:Leave(player)
        end
    end)

    self:_BindPlayers()

    self:_BindScreen()
    self:_BindMouseIcon()
    self:_BindMouseTarget()

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
    NetworkServer.Streamer.Request.Fire(streamer, "StartStream")
    NetworkServer.Viewer.Watch.Fire(viewer, "StartWatch")

    -- send snapshot of cached screen
    local cached = self.cache[streamer]
    NetworkServer.Viewer.Screen.Fire(viewer, cached.CameraStamp, cached.Camera, cached.MousePosition)
    NetworkServer.Viewer.MouseIcon.Fire(viewer, cached.MouseIcon)
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
                NetworkServer.Streamer.Request.Fire(streamer, "EndStream")
            end
        end
    end
    self.viewers[viewer] = nil
    NetworkServer.Viewer.Watch.Fire(viewer, "EndWatch")
end

function Server:_BindPlayers()
    local function PlayerAdded(player: Player)
        self.cache[player] = {
            ScreenStamp = 0,
            Camera = CFrame.new(),
            MousePosition = Vector3.zero,
            MouseIcon = ""
        }
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

function Server:_BindScreen()
    NetworkServer.Streamer.Screen.On(function(player, stamp, cframe, mousePos)
        self.cache[player].Camera = cframe
        self.cache[player].MousePosition = mousePos

        local viewers = self.channels[player]
        NetworkServer.Viewer.Screen.FireList(viewers, stamp, cframe, mousePos)
    end)
end

function Server:_BindMouseIcon()
    NetworkServer.Streamer.MouseIcon.On(function(player, mouseIcon)
        self.cache[player].MouseIcon = mouseIcon

        local viewers = self.channels[player]
        NetworkServer.Viewer.MouseIcon.FireList(viewers, mouseIcon)
    end)
end

function Server:_BindMouseTarget()
    NetworkServer.Streamer.MouseTarget.On(function(player, basePart, size)
        -- check if hitbox expanding
    end)
end

return module.new()