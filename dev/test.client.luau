local Broadcaster = require(game.ReplicatedStorage.Broadcaster)

Broadcaster.OnScreenChanged = function(cframe: CFrame, mouseHitPosition: Vector3)
    
end

Broadcaster.OnInputChanged = function(name: string, state: string)
    print(name, state)
end

Broadcaster:View(game.Players:WaitForChild("Player2"))