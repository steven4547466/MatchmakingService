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
MatchmakingService utilizes the new MemoryStoreService for cross-game ephemeral memory storage. This storage is kind of like the RAM in your computer or phone, except it's not exactly the same. There's a great article on it [here](https://developer.roblox.com/en-us/articles/memory-store) which describes more of the technical details if you're interested in it. MemoryStores have a much higher throughput potential than other services which makes them great for queuing items that will be quickly removed or changed. It has overwrite protections as well! Basically MemoryStores are the best way to make a system like this (it will be even better when they give us more tools to manage a MemoryQueue which will speed this up even more).

Basically, however, one server will manage making matches across the entire queue. Think of this server as the centralized handler (I was thinking of ways to have this be completely random access, but it gets a little messy, though has potential to happen in the future). When a player queues for a specific skill level they will only be matched up against a certain number of people in the same skill level. The number that are put into the game depends on what you set it to (read the docs below!).

Users are in a first-in-first-out queue. This mqqueue are the first players to get into a game. **At this time, parties are not supported, but that is planned**. When a game is created it can either be joinable or not. By default it is still joinable if the game hasn't started and the server isn't full, the MatchmakingService will prioritize these existing games before trying to make new ones. When a game starts, by default, the server will be locked and no new joiners are permitted.

# Documentation
Using the MatchmakingService is easy, the source itself has documentation on everything you'd need, however it will be written here as well.

### Correctly obtaining the MatchmakingService
MatchmakingService provides a top-level singleton to avoid accidentally creating multiple MatchmakingServices in one game server. I recommend requiring it from the asset id like so:

```lua
local MatchmakingService = require(7567983240).GetSingleton()
```

This makes it easy to stay up to date, but it isn't necessary.

### Changing settings
You can choose to change the properties themselves, or you can use the setters. It doesn't matter which you use, but the setters are documented as follows:

#### Setting the max queue time
Unfortunately we can't keep users in the queue forever. The max queue time exists to purge players from queue after a specific amount of time, in seconds. It's defaulted to 10 minutes and can be changed like so:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetMaxQueueTime(300) -- Sets the max queue time to 5 minutes
```

#### Registering skill levels
Currently, MatchmakingService will only match users of the same skill level. It is planned to broaden searches over time but that is not yet possible in this version. You must have at least one skill level registered and users **must** be queued with a skill level. If your game doesn't have skill levels, then register a single skill level and default queue players with it. Skill levels is a table of anything, but you should keep it either strings or numbers (this may change in the future).

You can set the registered skill levels like so:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetSkillLevels({1,2,3,4,5,6}) -- Registers the skill levels as 1, 2, 3, 4, 5, and 6.
```

##### Dynamic skill levels
Dynamic skill levels will register skill levels on queue if it doesn't exist. **THIS IS CURRENTLY NOT IMPLEMENTED.**

### Setting the update interval
By default, MatchmakingService will try to find matches or teleport players to their matches every half second. You can change this for any number of reasons like performance, but I recommend the 0.5-3 second range. Changing it is simple:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetMatchmakingInterval(1) -- Sets the update interval to 1 second
```

### Setting the player range
The player range is the number min and max players allowed in a server. It uses roblox's NumberRange to achive this easier. The default minimum players is 6 and the default maximum is 10. The max cannot be above 100 players. Changing it requires making a new NumberRange which isn't hard to do:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetPlayerRange(NumberRange.new(1, 10)) -- Sets the minimum players to 1 and the maximum players to 10.
```

### Setting the game place
Setting the game place is necessary as it tells the MatchmakingService what place it should teleport players to when a game is found. These servers are private and not joinable when created through MatchmakingService unless you use the TeleportService, which MatchmakingService does internally. **You must set this to a place that's in the same universe as the place where players are teleported from**. Here's an example:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetGamePlace(7563846691) -- Sets the game place to 7563846691.
```

### Denoting a server as a game server
You will need to require the MatchmakingService in your game servers as well. You don't want your game servers running the matchmaking loop unnecessarily so denoting them as a game server will prevent the matchmaking from running. This is a simple boolean value and defaults to false:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetIsGameServer(true) -- Denoates this server as a game server
```

# Managing the queue
Most of the functions of MatchmakingService are for internal use, but are exposed if you want to directly manage the queue yourself. All of the methods shown here have an equivalent id variant that accepts player ids instead of player objects. These exist for convenience. For example `QueuePlayer` is the same as `QueuePlayerId`, except `QueuePlayer` takes a player and `QueuePlayerId` takes a user id.

Enough with that though here's all the methods that MatchmakingService provides to manage your queue.

### Adding a player to the queue
Queuing a player is simple:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:QueuePlayer(player, 1) -- Queues the player with a skill level of 1.
```
If no skill level is provided, or the skill level is not registered and dynamic skill levels is disabled this method will error.

### Removing a player from queue
Same as adding a player just with removing. Skill level is required because the memory stores are separated by skill level.
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayerFromQueue(player, 1) -- Removes the player from the queue. Skill level is also required here.
```

### Removing multiple players from the queue
If you handle your own matchmaking you may want to remove multiple users from the queue at the same thime which is more efficient than running 10 update operations. This method does that for you and takes a table of players:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayersFromQueue(players, 1) -- Removes the players from the queue. Skill level is also required here.
```

### Adding a player to a game
You may want to add a player to a game if you're doing your own matchmaking. A game id is a reserved teleport code to teleport a user to a reserved server. This is unique at all times. The third parameter (defaults to true) will tell the MatchmakingService to update the servers joinability (meaning if it's full then close the server).
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:AddPlayerToGame(player, gameId, true) -- Adds the player to the game and updates its joinability status.
```

### Adding multiple players to a game
You can add multiple players to a game in one update operation as well. It takes a table of players, like `RemovePlayersFromQueue`.
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:AddPlayersToGame(players, gameId, true) -- Adds the players to the game and updates its joinability status.
```

### Removing a player from an existing game
If a player disconnects mid game you can remove them from it very simply:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayerFromGame(player, gameId, true) -- Removes the player from the game and updates its joinability status.
```

### Removing multiple players from an existing game
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayersFromGame(players, gameId, true) -- Removes the players from the game and updates its joinability status.
```

### Starting a game and removing a game from memory
You should denote a game as started when it actually started. Removing a game from memory after it's closed is very important and is incredibly simple to do. 

You can choose whether or not the game is joinable after starting (default false) with the second parameter in `StartGame`:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:StartGame(gameId, false) -- Starts the game and locks players from joining.
```

You can remove a game easily as well when the game server closes:
```lua
game:BindToClose(function()
  MatchmakingService:RemoveGame(gameId)
end)
```

In your server that players are teleported to I recommend using this script at a minimum, but feel free to add to it:
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
  if #game.Players:GetPlayers() >= minPlayersToStart then
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
If you put this script in your game server in ServerScriptService, it will handle setting game id and removing players from the game on disconnect and removing the game itself on close.

# Future Plans

- A party system
- Dynamic skill level creation
- Not requiring skill levels at all
- Switch to MemoryQueues if/when we get more ways to manage it
- Fully random access management that doesn't use a central server.