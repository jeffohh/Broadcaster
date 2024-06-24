--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

    View: (self: Client, player: Player) -> (),
    Leave: (self: Client) -> (),

    SendSnapshot: (self: Client) -> (),
    SendInput: (self: Client, name: string, state: string) -> ()
}

type Proto = {
    active: boolean,
    watching: boolean
}

local module = {}

local Client: Impl = {} :: Impl
Client.__index = Client

export type Client = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local STREAM_MAX_FPS = 60

local LINEAR_TWEEN = TweenInfo.new(1/STREAM_MAX_FPS, Enum.EasingStyle.Linear)

--[[ Services ]]--
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--[[ Private Variables ]]--
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local Controls = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local ByteNetLibrary = script.Parent:WaitForChild("ByteNetLibrary")

local streamPacket = require(ByteNetLibrary:WaitForChild("streamPacket"))
local broadcastPacket = require(ByteNetLibrary:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Client)

    self.active = false
    self.watching = false

    broadcastPacket.SetActivate.listen(function(active: boolean)
        self.active = active
    end)

    broadcastPacket.Watching.listen(function(enabled: boolean)
        self.watching = enabled
        if (self.watching) then
            Controls:Disable()
            Camera.CameraType = Enum.CameraType.Scriptable
        else
            Controls:Enable()
            Camera.CameraType = Enum.CameraType.Custom
        end
    end)

    streamPacket.Screen.listen(function(data)
        if (not self.watching) then return end

        local cameraCFrame = data.CFrame
        local mouseHitPosition = data.MouseHitPosition

        TweenService:Create(Camera, LINEAR_TWEEN, {CFrame = cameraCFrame}):Play()
    end)

    streamPacket.Input.listen(function(data)
        if (not self.watching) then return end

        local name = data.Name
        local state = data.State
    end)


    local lastFrame = tick()
    RunService.RenderStepped:Connect(function()
        local currentFrame = tick()
        if (currentFrame - lastFrame < 1 / STREAM_MAX_FPS) then return end

        lastFrame = currentFrame
        self:SendSnapshot()
    end)
    
    UserInputService.InputBegan:Connect(function(input: InputObject)
        local name
        if (input.UserInputType == Enum.UserInputType.Keyboard) then
            name = input.KeyCode.Name
        else
            name = input.UserInputType.Name
        end

        self:SendInput(name, "Begin")
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        local name
        if (input.UserInputType == Enum.UserInputType.Keyboard) then
            name = input.KeyCode.Name
        else
            name = input.UserInputType.Name
        end

        self:SendInput(name, "End")
    end)

    return self
end

function Client:View(subject: Player)
    broadcastPacket.View.send(subject)
end

function Client:Leave()
    broadcastPacket.Leave.send(LocalPlayer)
end

function Client:SendSnapshot()
    if (not self.active) then return end

    streamPacket.Screen.send({
        CFrame = Camera.CFrame,
        MouseHitPosition = Mouse.Hit.Position
    })
end

function Client:SendInput(name: string, state: string)
    if (not self.active) then return end

    streamPacket.Input.send({
        Name = name,
        State = state
    })
end

return module.new()