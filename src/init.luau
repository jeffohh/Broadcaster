local RunService = game:GetService("RunService")

if (RunService:IsServer()) then
    return require(script:WaitForChild("Server"))
elseif (RunService:IsClient()) then
    return require(script:WaitForChild("Client"))
end