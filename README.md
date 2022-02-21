
# MatchmakingService

# Preface
Current Version: V2.0.0
[Github](https://github.com/steven4547466/MatchmakingService). [Asset](https://www.roblox.com/library/7567983240/MatchmakingService). [Uncopylocked hub/receiver game](https://www.roblox.com/games/7563843268/MatchmakingService).

[Check out these games that use the service](https://github.com/steven4547466/MatchmakingService/blob/master/GamesThatUseMatchmakingService.md)

Want to get your game added to that list? Send me a message and I'll check your game out!

# Introduction
MatchmakingService is a way to easily make games that involve matchmaking. It utilizes the new MemoryStoreService for high through-put potential. MatchmakingService is as easy to use as:

(On your hub server where players queue from)
```lua
-- Obtain the service
local  MatchmakingService = require(7567983240).GetSingleton()

-- Set the game place
MatchmakingService:AddGamePlace("Map 1", 7584483307)
MatchmakingService:SetPlayerRange("Map 1", NumberRange.new(2, 2))

-- Queue players (you can call QueuePlayer from anywhere)
game.Players.PlayerAdded:Connect(function(p)
  MatchmakingService:QueuePlayer(p, "queue", "Map 1")
end)

for i, p in ipairs(game.Players:GetPlayers()) do
  MatchmakingService:QueuePlayer(p, "queue", "Map 1")
end
```

On the game where players are teleported to:
```lua
local MatchmakingService = require(7567983240).GetSingleton()

-- It's important game servers know how large they can get. You don't really need every map here,
-- but you do need whichever map this is.
MatchmakingService:SetPlayerRange("Map 1", NumberRange.new(2, 2))

-- Tell the service this is a game server
MatchmakingService:SetIsGameServer(true)

local gameData = nil
local t1 = {}
local t2 = {}
-- Basic start function
function Start()
  print("Started")
  MatchmakingService:StartGame(gameData.gameCode)
  -- Simple teams for a 1v1.
  local p = game.Players:GetPlayers()
  table.insert(t1, p[1])
  table.insert(t2, p[2])
end

-- YOU MUST CALL UpdateRatings BEFORE THE GAME IS CLOSED. YOU CANNOT PUT THIS IN BindToClose!
function EndGame(winner)
  MatchmakingService:UpdateRatings(gameData.ratingType, {if winner == 1 then 1 else 2, if winner == 2 then 1, else 2}, {t1, t2})
  for i, v in ipairs(game.Players:GetPlayers()) do
    -- You can teleport them back to the hub here, I just kick them
    v:Kick()
  end
end

game.Players.PlayerAdded:Connect(function(player)
  if not gameData then
    gameData = MatchmakingService:GetGameData()
  end
  if #game.Players:GetPlayers() >= 2 then
    Start()
  end
end)

game.Players.PlayerRemoving:Connect(function(player)
  MatchmakingService:RemovePlayerFromGame(player, gameData.gameCode)
end)
```

#### Small note before we start
Due to the lack of tools that MemoryQueue allows, current this version of MatchmakingService solely uses different SortedMaps which are slightly less tuned for this process. If/when MemoryQueue gets more tools that allow us to reliably manage it, then I will write this all utilizing MemoryQueues where possible.

## How does it work?
MatchmakingService utilizes the new MemoryStoreService for cross-game ephemeral memory storage. This storage is kind of like the RAM in your computer or phone, except it's not exactly the same. There's a great article on it [here](https://developer.roblox.com/en-us/articles/memory-store) which describes more of the technical details if you're interested in it. MemoryStores have a much higher throughput potential than other services which makes them great for queuing items that will be quickly removed or changed. It has overwrite protections as well! Basically MemoryStores are the best way to make a system like this (it will be even better when they give us more tools to manage a MemoryQueue which will speed this up even more).

Basically, however, one server will manage making matches across the entire queue. Think of this server as the centralized handler (I was thinking of ways to have this be completely random access, but it gets a little messy, though has potential to happen in the future). When a player queues for a specific skill level they will only be matched up against a certain number of people in the same skill level. The number that are put into the game depends on what you set it to (read the docs below!).

Users are in a first-in-first-out queue. This means that the first players to queue are the first players to get into a game. When a game is created it can either be joinable or not. By default it is still joinable if the game hasn't started and the server isn't full, the MatchmakingService will prioritize these existing games before trying to make new ones. When a game starts, by default, the server will be locked and no new joiners are permitted.

# Documentation
You can find up-to-date documentation [here](https://steven4547466.github.io/MatchmakingService/). 

# Future Plans
- Switch to MemoryQueues if/when we get more ways to manage it
- Fully random access management that doesn't use a central server
- Party parity

# Updates
I will be available to add new features and bug fixes. There will be a beta branch on the [github](https://github.com/steven4547466/MatchmakingService) for testing these new features.