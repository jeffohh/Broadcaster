local RunService = game:GetService("RunService")

if (RunService:IsClient()) then
    return require(script:WaitForChild("Client"))
elseif (RunService:IsServer()) then
    return require(script:WaitForChild("Server"))
end