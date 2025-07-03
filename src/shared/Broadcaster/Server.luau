--!strict
--[[ Imports ]]--
local NetworkServer = require(script.Parent:WaitForChild("NetworkServer"))
local NetworkTypes = require(script.Parent:WaitForChild("NetworkTypes"))

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

    channels: {[Player]: {Player}},         -- streamer -> {viewers}
    viewers: {[Player]: Player},            -- viewer -> streamer
    logs: {NetworkTypes.Viewer_LogEntry}
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
    self.logs = {}

    NetworkServer.Viewer.Request.On(function(player, request)
        if request.Action == "View" then
            self:View(player, request.Player)
        elseif request.Action == "Leave" then
            self:Leave(player)
        elseif request.Action == "Logs" then
            NetworkServer.Viewer.Log.Fire(player, self.logs)
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
    NetworkServer.Streamer.Request.Fire(streamer, "Start")
    NetworkServer.Viewer.Watch.Fire(viewer, "Start")

    -- send snapshot of cached screen
    local cached = self.cache[streamer]
    NetworkServer.Viewer.Screen.Fire(viewer, cached.ScreenStamp, cached.Camera, cached.MousePosition)
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
                NetworkServer.Streamer.Request.Fire(streamer, "Stop")
            end
        end
    end
    self.viewers[viewer] = nil
    NetworkServer.Viewer.Watch.Fire(viewer, "Stop")
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
        task.defer(PlayerAdded, player)
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
    local function sizesAreClose(size1: Vector3, size2: Vector3, epsilon: number): boolean
        epsilon = epsilon or 1e-3
        return (size1 - size2).Magnitude < epsilon
    end

    local function createLog(title: string, message: string, details: string): NetworkTypes.Viewer_LogEntry
        local s1 = string.format([[<font size="20"><b>%s</b></font>]], title)
        local s2 = string.format([[<font size="16"><b>%s</b></font>]], message)
        local s3 = string.format([[<font size="12"><b>%s</b></font>]], details)

        local output = s1 .. "\n" .. s2 .. "\n" .. s3
        local log: NetworkTypes.Viewer_LogEntry = { DateFormat = DateTime.now():FormatLocalTime("YYYY-MM-DD\nHH:mm:ss", "en-us"), Message = output }
        table.insert(self.logs, log)
        return log
    end

    local function createNameTag(player: Player): string
        return "@" .. player.Name .. (if player.Name == player.DisplayName then "" else string.format(" (%s)", player.DisplayName))
    end

    NetworkServer.Streamer.MouseTarget.On(function(player, mouseTargetInfo)
        if mouseTargetInfo.Info == "None" then return end

        local basePart = mouseTargetInfo.Target
        local parent = mouseTargetInfo.Parent

        local humanoid = parent and (parent:FindFirstChildOfClass("Humanoid") or if parent.Parent then parent.Parent:FindFirstChildOfClass("Humanoid") else nil)
        if not humanoid then return end

        local clientSize = mouseTargetInfo.Size
        local fullName = mouseTargetInfo.FullName

        -- check if hitbox expanding
        if basePart then
            local serverSize = basePart.Size
            if not sizesAreClose(serverSize, clientSize, 1e-3) then
                -- hbe
                local diff = clientSize - serverSize

                local csOutput = string.format("[%.3f, %.3f, %.3f]", clientSize.X, clientSize.Y, clientSize.Z)
                local ssOutput = string.format("[%.3f, %.3f, %.3f]", serverSize.X, serverSize.Y, serverSize.Z)
                local dfOutput = string.format("[%.3f, %.3f, %.3f]", diff.X, diff.Y, diff.Z)

                local loclTag = [[<mark color="rgb(255, 255, 100)" transparency="0.75">locl:</mark>]]
                local servTag = [[<mark color="rgb(100, 255, 100)" transparency="0.75">serv:</mark>]]
                local diffTag = [[<mark color="rgb(255, 100, 100)" transparency="0.75">diff:</mark>]]
                local pathTag = [[<mark color="rgb(0, 0, 0)" transparency="0">path:</mark>]]

                local title = "Hit Expanded Part"
                local message = createNameTag(player) .. " has mismatched part sizes."
                local details = string.format("%s %s - %s %s = %s %s\t|\t%s %s",
                                                loclTag, csOutput,
                                                servTag, ssOutput,
                                                diffTag, dfOutput,
                                                pathTag, fullName
                                            )

                local log = createLog(title, message, details)
                NetworkServer.Viewer.Log.FireAll({log})
            end
        else
            local csOutput = string.format("[%.3f, %.3f, %.3f]", clientSize.X, clientSize.Y, clientSize.Z)

            local loclTag = [[<mark color="rgb(255, 255, 100)" transparency="0.75">locl:</mark>]]
            local pathTag = [[<mark color="rgb(0, 0, 0)" transparency="0">path:</mark>]]

            local title = "Hit Nonexisting Part"
            local message = createNameTag(player) .. " has hit nonexisting part."
            local details = string.format("%s %s\t|\t%s %s",
                                            loclTag, csOutput,
                                            pathTag, fullName
                                        )

            local log = createLog(title, message, details)
            NetworkServer.Viewer.Log.FireAll({log})
        end
    end)
end

return module.new()