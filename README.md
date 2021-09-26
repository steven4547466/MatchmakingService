# MatchmakingService
[Github](https://github.com/steven4547466/MatchmakingService). [Asset](https://www.roblox.com/library/7567983240/MatchmakingService). [Uncopylocked hub/receiver game](https://www.roblox.com/games/7563843268/MatchmakingService).

MatchmakingService is a way to easily make games that involve matchmaking. It utilizes the new MemoryStoreService for blazing fast execution speed. Memory store is as easy to use as:

(On your hub server where players queue from)
```lua
local MatchmakingService = require(7567983240).GetSingleton()

-- Register the number 1 as a skill level. Skill levels can be numbers or strings reliably.
MatchmakingService:SetSkillLevels({1})

-- Set the game place that players will be teleported to.
MatchmakingService:SetGamePlace(placeToTeleportTo)

game.Players.PlayerAdded:Connect(function(p)
	MatchmakingService:QueuePlayer(p, 1)
end)

game.Players.PlayerRemoving:Connect(function(p)
	MatchmakingService:RemovePlayerFromQueue(p, 1)
end)

for i, p in ipairs(game.Players:GetPlayers()) do
	MatchmakingService:QueuePlayer(p, 1)
end
```

On the game where players are teleported to:
```lua
local MatchmakingService = require(7567983240).GetSingleton()

-- Tell the service this is a game server
MatchmakingService:SetIsGameServer(true)

-- Basic start function
function Start()
	MatchmakingService:StartGame(_G.gameId)
end

game.Players.PlayerAdded:Connect(function(player)
	local joinData = player:GetJoinData()
	if _G.gameId == nil and joinData then
    -- Global so its accessible from other scripts if it needs to be.
		_G.gameId = joinData.TeleportData.gameCode
	end
	if #game.Players:GetPlayers() >= 2 then
		Start()
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	MatchmakingService:RemovePlayerFromGame(player, _G.gameId)
end)

-- THIS IS EXTREMELY IMPORTANT
game:BindToClose(function()
	MatchmakingService:RemoveGame(_G.gameId)
end)
```

#### Small note before we start
Due to the lack of tools that MemoryQueue allows, current this version of MatchmakingService solely uses different SortedMaps which are slightly less tuned for this process. If/when MemoryQueue gets more tools that allow us to reliably manage it, then I will write this all utilizing MemoryQueues where possible.

## How does it work?
MatchmakingService utilizes the new MemoryStoreService for cross-universe ephemeral memory storage. This storage is kind of like the RAM in your computer or phone, except it's not exactly the same. There's a great article on it [here](https://developer.roblox.com/en-us/articles/memory-store) which describes more of the technical details if you're interested in it. MemoryStores have a much higher throughput potential than other services which makes them great for queuing items that will be quickly removed or changed. It has overwrite protections as well! Basically MemoryStores are the best way to make a system like this (it will be even better when they give us more tools to manage a MemoryQueue which will speed this up even more).

Basically, however, one server will manage making matches across the entire queue. Think of this server as the centralized handler (I was thinking of ways to have this be completely random access, but it gets a little messy, though has potential to happen in the future). When a player queues for a specific skill level they will only be matched up against a certain number of people in the same skill level. The number that are put into the game depends on what you set it to (read the docs below!).

Users are in a first-in-first-out queue. This mqqueue are the first players to get into a game. **At this time, parties are not supported, but that is planned**. When a game is created it can either be joinable or not. By default it is still joinable if the game hasn't started and the server isn't full, the MatchmakingService will prioritize these existing games before trying to make new ones. When a game starts, by default, the server will be locked and no new joiners are permitted.

# Documentation
Using the MatchmakingService is easy, the source itself has documentation on everything you'd need, however it will be written here as well.




# Future Plans