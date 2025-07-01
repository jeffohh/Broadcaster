local RunService = game:GetService("RunService")

local Server = script:WaitForChild("Server")
local Client = script:WaitForChild("Client")

if RunService:IsServer() then
    return require(Server)
elseif RunService:IsClient() then
    return require(Client)
end