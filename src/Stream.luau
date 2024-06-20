--!strict
--[[ Imports ]]--

--[[ Header ]]--
type Impl = {
    __index: Impl,

    GetActive: (self: Stream) -> (boolean),
    SetActive: (self: Stream, active: boolean) -> (),

    Destroy: (self: Stream) -> (),

    _Record: (self: Stream) -> ()

}

type Proto = {
    active: boolean,

    connections: {RBXScriptConnection}
}

local module = {}

local Stream: Impl = {} :: Impl
Stream.__index = Stream

export type Stream = typeof(setmetatable({} :: Proto, {} :: Impl))

--[[ Globals ]]--
local STREAM_MAX_FPS = 60

--[[ Services ]]--
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--[[ Private Variables ]]--
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local Broadcaster = ReplicatedStorage:WaitForChild("Broadcaster")

local broadcastPacket = require(Broadcaster:WaitForChild("broadcastPacket"))
local streamPacket = require(Broadcaster:WaitForChild("streamPacket"))

--[[ Object ]]--
function module.new()
    local self = setmetatable({} :: Proto, Stream)

    self.active = false
    self.connections = {}

    broadcastPacket.SetActivate.listen(function(active: boolean)
        self:SetActive(active)
    end)

    self:_Record()

    return self
end

function Stream:GetActive()
    return self.active
end

function Stream:SetActive(active: boolean)
    self.active = active
end

function Stream:Destroy()
    for _, connection in next, self.connections do
        connection:Disconnect()
    end
end

function Stream:_Record()
    -- camera tracker
    do
        local tickStamp = tick()
        table.insert(
            self.connections,
            RunService.RenderStepped:Connect(function(deltaTime: number)
                if (not self.active) then return end
                
                local currentStamp = tick()
                if (currentStamp - tickStamp >= STREAM_MAX_FPS) then
                    tickStamp = currentStamp
                    
                    streamPacket.Screen:send({
                        CFrame = Camera.CFrame,
                        MouseHitPosition = Mouse.Hit.Position
                    })
                end
            end)
        )
    end
    
    -- input tracker
    do
        table.insert(
            self.connections,
            UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
                if (not self.active) then return end
                if (gpe) then return end
    
                if (input.UserInputType == Enum.UserInputType.Keyboard) then
                    streamPacket.Input:send({
                        Name = input.KeyCode.Name,
                        State = "Begin"
                    })
                else
                    streamPacket.Input:send({
                        Name = input.Name,
                        State = "Begin"
                    })
                end
            end)
        )
    
        table.insert(
            self.connections,
            UserInputService.InputEnded:Connect(function(input: InputObject, gpe: boolean)
                if (not self.active) then return end
                if (gpe) then return end
    
                if (input.UserInputType == Enum.UserInputType.Keyboard) then
                    streamPacket.Input:send({
                        Name = input.KeyCode.Name,
                        State = "End"
                    })
                else
                    streamPacket.Input:send({
                        Name = input.Name,
                        State = "End"
                    })
                end
            end)
        )
    end
end

return module