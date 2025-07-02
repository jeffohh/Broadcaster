--!strict
--[[ Imports ]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))

local Packages = ReplicatedStorage:WaitForChild("Packages")

local LemonSignal = require(Packages:WaitForChild("lemonsignal"))

--[[ Header ]]--
type Impl = {
    __index: Impl,

    View: (self: Client, streamer: Player) -> (),
    Leave: (self: Client) -> (),

    _BindUpdate: (self: Client) -> (),

    _BindStream: (self: Client) -> (),
    _BindScreen: (self: Client) -> (),
    _BindMouseIcon: (self: Client) -> (),
}

type Proto = {
    streaming: boolean,
    watching: boolean,

    OnScreenUpdate: LemonSignal.Signal<number, CFrame, Vector3>,
    OnMouseIconUpdate: LemonSignal.Signal<string>,

    OnWatchingChanged: LemonSignal.Signal<boolean>
}

local module = {}

local Client: Impl = {} :: Impl
Client.__index = Client

export type Client = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local FPS_LIMIT = 1/144

--[[ Services ]]--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--[[ Private Variables ]]--
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Client)

    self.streaming = false -- camera + mouse
    self.watching = false

    self.OnScreenUpdate = LemonSignal.new()
    self.OnMouseIconUpdate = LemonSignal.new()

    self.OnWatchingChanged = LemonSignal.new()

    -- viewing
    self:_BindUpdate()

    -- streaming
    self:_BindStream()

    self:_BindScreen()
    self:_BindMouseIcon()

    return self
end

function Client:Stream(value)
    self.streaming = value
end

function Client:View(streamer)
    NetworkClient.Viewer.Request.Fire({Action = "View", Player = streamer})
end

function Client:Leave()
    NetworkClient.Viewer.Request.Fire({Action = "Leave"})
end

function Client:_BindUpdate()
    NetworkClient.Viewer.Screen.On(function(stamp, cframe, vector3)
        self.OnCameraUpdate:Fire(stamp, cframe, vector3)
    end)

    NetworkClient.Viewer.MouseIcon.On(function(mouseIcon)
        self.OnMouseIconUpdate:Fire(mouseIcon)
    end)
end

function Client:_BindStream()
    NetworkClient.Streamer.Request.On(function(request)
        if request == "StartStream" then
            self.streaming = true
        elseif request == "EndStream" then
            self.streaming = false
        end
    end)

    NetworkClient.Viewer.Watch.On(function(request)
        if request == "StartWatch" then
            self.watching = true
            self.OnWatchingChanged:Fire(self.watching)
        elseif request == "EndWatch" then
            self.watching = false
            self.OnWatchingChanged:Fire(self.watching)
        end
    end)
end

function Client:_BindScreen()
    local target: BasePart? = nil
    local fpsLimit: number = 0
    RunService:BindToRenderStep("BindScreen", Enum.RenderPriority.Camera.Value + 1, function(delta)
        -- update mouse target and size
        if target ~= Mouse.Target then
            target = Mouse.Target
            NetworkClient.Streamer.MouseTarget.Fire(target, if target then target.Size else nil)
        end

        if not self.streaming then return end
        if not Camera then return end

        -- update camera
        fpsLimit += delta
        if fpsLimit < FPS_LIMIT then return end
        NetworkClient.Streamer.Screen.Fire(time(), Camera.CFrame, Mouse.Hit.Position)
        fpsLimit = 0
    end)
end

function Client:_BindMouseIcon()
    NetworkClient.Streamer.MouseIcon.Fire(UserInputService.MouseIcon)
    UserInputService:GetPropertyChangedSignal("MouseIcon"):Connect(function()
        NetworkClient.Streamer.MouseIcon.Fire(UserInputService.MouseIcon)
    end)
end



return module.new()