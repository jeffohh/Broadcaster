--!strict
--[[ Imports ]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local NetworkTypes = require(script.Parent:WaitForChild("NetworkTypes"))

--[[ Header ]]--
type Impl = {
    __index: Impl,

    BindCamera: (self: Client) -> (),
    BindViewport: (self: Client) -> (),
    BindMouse: (self: Client) -> (),
    BindMouseIcon: (self: Client) -> (),
}

type Proto = {
    streaming: boolean,
    watching: boolean
}

local module = {}

local Client: Impl = {} :: Impl
Client.__index = Client

export type Client = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local FPS_LIMIT = 1/60

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

    self.streaming = false
    self.watching = false

    self:BindCamera()
    self:BindViewport()
    self:BindMouse()
    self:BindMouseIcon()

    return self
end

function Client:BindCamera()
    local target: BasePart? = nil
    local fpsLimit: number = 0
    RunService:BindToRenderStep("StreamCamera", Enum.RenderPriority.Camera + 1, function(delta)
        -- update mouse target and size
        if target ~= Mouse.Target then
            target = Mouse.Target
            NetworkClient.Streamer.MouseTarget:Fire(target, target.Size)
        end

        -- update camera
        fpsLimit += delta
        if fpsLimit < 1/60 then return end
        NetworkClient.Streamer.Camera.Fire(tick(), Camera.CFrame)
        fpsLimit = 0
    end)
end

function Client:BindViewport()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local viewport = Camera.ViewportSize
        NetworkClient.Streamer.ViewportSize.Fire(viewport.X, viewport.Y)
    end)
end

function Client:BindMouse()
    local latestX = 0
    local latestY = 0

    local lastTick = tick()
    local scheduled = false
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local mousePos = input.Position
        if mousePos.X == latestX and mousePos.Y == latestY then return end

        latestX = mousePos.X
        latestY = mousePos.Y

        if scheduled then return end

        local now = tick()
        local delta = now - lastTick
        if delta >= FPS_LIMIT then
            lastTick = now
            NetworkClient.Streamer.MousePosition.Fire(now, latestX, latestY)
        else
            scheduled = true
            task.delay(FPS_LIMIT - delta, function()
                lastTick = tick()
                NetworkClient.Streamer.MousePosition.Fire(lastTick, latestX, latestY)
                scheduled = false
            end)
        end
    end)
end

function Client:BindMouseIcon()
    UserInputService:GetPropertyChangedSignal("MouseIcon"):Connect(function()
        NetworkClient.Streamer.MouseIcon.Fire(UserInputService.MouseIcon)
    end)
end



return module.new()