local Broadcaster = require(game.ReplicatedStorage.Broadcaster)

Broadcaster.OnScreenChanged:Connect(function(cframe: CFrame, mouseHitPosition: Vector3)
    print("1")
end)

Broadcaster.OnInputChanged:Connect(function(name: string, state: string)
    print(name, state)
end)

Broadcaster:View(game.Players:WaitForChild("Player2"))