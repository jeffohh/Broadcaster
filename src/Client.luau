--!strict
--[[ Imports ]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("GoodSignal"))

--[[ Header ]]--
type Impl = {
    __index: Impl,

    View: (self: Client, player: Player) -> (),
    Leave: (self: Client) -> (),

    _SendSnapshot: (self: Client) -> (),
    _SendInput: (self: Client, name: string, state: string) -> (),

    Settings: {
        STREAM_MAX_FPS: number
    }
}

type Proto = {
    active: boolean,
    watching: boolean,

    OnWatchingChanged: Signal.Signal<boolean>,
    OnScreenChanged: Signal.Signal<CFrame, Vector3>,
    OnInputChanged: Signal.Signal<string, string>,
    OnMouseIconChanged: Signal.Signal<string>
}

local module = {}

local Client: Impl = {} :: Impl
Client.__index = Client

export type Client = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local Settings = {}
Settings.STREAM_MAX_FPS = 60

Client.Settings = Settings

--[[ Services ]]--
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--[[ Private Variables ]]--
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local Packets = script.Parent:WaitForChild("Packets")

local streamPacket = require(Packets:WaitForChild("streamPacket"))
local broadcastPacket = require(Packets:WaitForChild("broadcastPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Client)

    self.active = false
    self.watching = false

    local OnWatchingChanged = Signal.new()
    local OnScreenChanged = Signal.new()
    local OnInputChanged = Signal.new()
    local OnMouseIconChanged = Signal.new()

	self.OnWatchingChanged = OnWatchingChanged
	self.OnScreenChanged = OnScreenChanged
	self.OnInputChanged = OnInputChanged
	self.OnMouseIconChanged = OnMouseIconChanged

    broadcastPacket.SetActivate.listen(function(active: boolean)
        self.active = active
    end)

    broadcastPacket.SetWatching.listen(function(enabled: boolean)
        self.watching = enabled
        streamPacket.MouseIcon.send(UserInputService.MouseIcon)

        OnWatchingChanged:Fire(enabled)
    end)

    streamPacket.Screen.listen(function(data)
        if (not self.watching) then return end

        local cameraCFrame = data.CFrame
        local mouseHitPosition = data.MouseHitPosition

        OnScreenChanged:Fire(cameraCFrame, mouseHitPosition)
    end)

    streamPacket.Input.listen(function(data)
        if (not self.watching) then return end

        local name = data.Name
        local state = data.State

        print(self.OnInputChanged)
        OnInputChanged:Fire(name, state)
    end)

    streamPacket.MouseIcon.listen(function(data)
        local icon = data

        OnMouseIconChanged:Fire(icon)
    end)

    local currentIcon = UserInputService.MouseIcon
    local lastFrame = tick()
    RunService.RenderStepped:Connect(function()
        if (currentIcon ~= UserInputService.MouseIcon) then
            currentIcon = UserInputService.MouseIcon
            streamPacket.MouseIcon.send(currentIcon)
        end

        -- frame limit
        local currentFrame = tick()
        if (currentFrame - lastFrame < 1 / self.Settings.STREAM_MAX_FPS) then return end

        lastFrame = currentFrame
        self:_SendSnapshot()
    end)
    
    UserInputService.InputBegan:Connect(function(input: InputObject)
        local name
        if (input.UserInputType == Enum.UserInputType.Keyboard) then
            name = input.KeyCode.Name
        else
            name = input.UserInputType.Name
        end

        self:_SendInput(name, "Begin")
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        local name
        if (input.UserInputType == Enum.UserInputType.Keyboard) then
            name = input.KeyCode.Name
        else
            name = input.UserInputType.Name
        end

        self:_SendInput(name, "End")
    end)

    return self
end

function Client:View(subject: Player)
    broadcastPacket.View.send(subject)
end

function Client:Leave()
    broadcastPacket.Leave.send(LocalPlayer)
end

function Client:_SendSnapshot()
    if (not self.active) then return end

    streamPacket.Screen.send({
        CFrame = Camera.CFrame,
        MouseHitPosition = Mouse.Hit.Position
    })
end

function Client:_SendInput(name: string, state: string)
    if (not self.active) then return end

    streamPacket.Input.send({
        Name = name,
        State = state
    })
end

return module.new()