# MatchmakingService
Current Version: V3.4.0-beta
[Github](https://github.com/steven4547466/MatchmakingService). [Asset](https://www.roblox.com/library/7567983240/MatchmakingService). [Uncopylocked hub/receiver game](https://www.roblox.com/games/7563843268/MatchmakingService).

In case it wasn't clear to everyone, which it obviously isn't. **This module is in beta and has no guarantee of working under all conditions. It is being actively developed there are DEFINITELY game breaking bugs and issues that have not been found.**

Basically,
# Use this module at your own risk until it's out of beta
When it's out of beta, the releases will be more stable.

[Check out these games that use the service](https://github.com/steven4547466/MatchmakingService/blob/master/GamesThatUseMatchmakingService.md)

MatchmakingService is a way to easily make games that involve matchmaking. It utilizes the new MemoryStoreService for blazing fast execution speed. MatchmakingService is as easy to use as:

(On your hub server where players queue from)
```lua
-- Obtain the service
local MatchmakingService = require(7567983240).GetSingleton()

-- Set the game place
MatchmakingService:SetGamePlace(7584483307)

-- Queue players (you can call QueuePlayer from anywhere)
game.Players.PlayerAdded:Connect(function(p)
  MatchmakingService:QueuePlayer(p, "ranked")
end)

for i, p in ipairs(game.Players:GetPlayers()) do
  MatchmakingService:QueuePlayer(p, "ranked")
end
```

On the game where players are teleported to:
```lua
local MatchmakingService = require(7567983240).GetSingleton()

-- Tell the service this is a game server
MatchmakingService:SetIsGameServer(true)

local t1 = {}
local t2 = {}
-- Basic start function
function Start()
  print("Started")
  MatchmakingService:StartGame(_G.gameId)
  -- Simple teams.
  local p = game.Players:GetPlayers()
  table.insert(t1, p[1])
  table.insert(t2, p[2])
end

-- YOU MUST CALL UpdateRatings BEFORE THE GAME IS CLOSED. YOU CANNOT PUT THIS IN BindToClose!
function EndGame(winner)
  MatchmakingService:UpdateRatings(t1, t2, _G.ratingType, winner)
  for i, v in ipairs(game.Players:GetPlayers()) do
    -- You can teleport them back to the hub here, I just kick them
    v:Kick()
  end
end

game.Players.PlayerAdded:Connect(function(player)
  local joinData = player:GetJoinData()
  if _G.gameId == nil and joinData then
    -- Global so its accessible from other scripts if it needs to be.
    _G.gameId = joinData.TeleportData.gameCode
    _G.ratingType = joinData.TeleportData.ratingType
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

Users are in a first-in-first-out queue. This means that the first players to queue are the first players to get into a game. When a game is created it can either be joinable or not. By default it is still joinable if the game hasn't started and the server isn't full, the MatchmakingService will prioritize these existing games before trying to make new ones. When a game starts, by default, the server will be locked and no new joiners are permitted.

# Documentation
Using the MatchmakingService is easy, the source itself has documentation on everything you'd need, however it will be written here as well.

### Correctly obtaining the MatchmakingService
MatchmakingService provides a top-level singleton to avoid accidentally creating multiple MatchmakingServices in one game server. I recommend requiring it from the asset id like so:

```lua
local MatchmakingService = require(7567983240).GetSingleton()
```

This makes it easy to stay up to date, but it isn't necessary.

##### The options table
You may want to provide additional options when obtaining the service. You can do this by passing a table of options when calling `GetSingleton`. Right now the only recoginzed option is `DisableRatingSystem`.

### Changing settings
You can choose to change the properties themselves, or you can use the setters. It doesn't matter which you use, but the setters are documented as follows:

### Setting the update interval
By default, MatchmakingService will try to find matches or teleport players to their matches every 3 seconds. You can change this for any number of reasons like performance, but I recommend the 1-3 second range. Changing it is simple:
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
MatchmakingService:SetIsGameServer(true) -- Denotes this server as a game server.
```

### Setting the starting rating
As of `v2.0.0-beta`, MatchmakingService uses [an implementation](https://devforum.roblox.com/t/a-lua-implementation-of-the-glicko-2-rating-algorithm-for-skill-based-matchmaking/1442673) of glicko-2 for rating purposes. You can set the starting rating like so (default is 0, negative rating does exist):
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetStartingRating(1000) -- Sets the starting rating to 1000.
```

### Two additional glicko-2 initalizers
I won't go into detail what these two initializers do as you shouldn't modify them unless you know how glicko-2 works and want to set up very specific starting conditions.

The first one is starting rating deviation:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetStartingDeviation(0.08314) -- Sets the starting deviation to 0.08314.
```

The next is volatility:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetStartingVolatility(0.6) -- Sets the starting volatility to 0.6.
```

I do not recommend changing them from their default values.

### Setting the max skill disparity in parties
By default all party members must be within 50 rating points of all other party members. You may want to change this if you want parties to be of more or less similar skill.
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:SetMaxPartySkillGap(100) -- Sets the max skill disparity of parties to 100 rating points.
```

# Getting/Setting ratings
While I do not recommend ever setting ratings directly, you may want to get ratings for any number of reasons. MatchmakingService exposes both operations.

### How glicko-2 objects work
A glicko-2 object is guaranteed to have these three properies: `Rating`, `RD` (Rating deviation), and `Vol` (Volatility). The main thing you would ever access is the `Rating` property. This object may also contain a `Score` property, but that has to do with how ratings are updated and it's unlikely you will ever see it.

### Getting a glicko-2 object
One of a player's glicko-2 object(s) can be retrieved like so (if it does not exist it will be created and defaulted): 
```lua
local MatchmakingService = require(7567983240).GetSingleton()
local g = MatchmakingService:GetPlayerGlicko(player, "ranked") -- Gets the player's ranked glicko-2 object.
print(g.Rating)
```
You can access the properties described above when you retrieve the object. Changing these values will have no effect.

### Setting a player's glicko-2 object
As I stated above I do not recommend using this, but if you want to set specific ratings the option is available for you. This must be a glicko-2 object.
```lua
local MatchmakingService = require(7567983240).GetSingleton()
 MatchmakingService:SetPlayerGlicko(player, "ranked", glicko2Object) -- Sets the player's ranked glicko-2 object.
```

# Updating a player's rating after a game
Currently MatchmakingService supports games that have 2 teams with any number of players on each team. As described in the example handler script, you must update the players' ratings before the game is closed. It must execute before `BindToClose`, this means that it cannot be put in `BindToClose`. A simple way to handle this is make a basic game ender:
```lua
-- YOU MUST CALL UpdateRatings BEFORE THE GAME IS CLOSED. YOU CANNOT PUT THIS IN BindToClose!
function EndGame()
  MatchmakingService:UpdateRatings(t1, t2, _G.ratingType, winner)
  for i, v in ipairs(game.Players:GetPlayers()) do
    -- You can teleport them back to the hub here, I just kick them
    v:Kick()
  end
end
``` 

To break this down I will go over the parameters of this method:
`MatchmakingService:UpdateRatings(t1, t2, ratingType, winner)` takes the two teams (t1 and t2), these are tables of players. Following the second team is the rating type, this is passed in the teleport data of players, in the example script it's set to `_G.ratingType`. Finally we have the winner. This is either 0, 1, or 2. If the game is a draw, the value should be 0, if team one won then you should pass 1. And obviously if team 2 won you pass 2. 

This method updates, and then saves player ratings for that specific rating type.

# Getting player info
Getting a player's info can be useful mainly to check if they're in a party.
```lua
local MatchmakingService = require(7567983240).GetSingleton()
local info = MatchmakingService:GetPlayerInfo(player)
```
The info returned is a dictionary (**it may be nil**). The main thing you'll use this for is parties. If the player is in a party, then `info.party` will be a table of all of the player ids of the players in their party including the players own id.

# Getting a player's party
If a player is partied, you can get all the players in their party like so:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
local party = MatchmakingService:GetPlayerParty(player)
```
If they aren't in a party, this will return `nil`. If they are in a party, this will return a table of all of the player ids of the players in their party including their own id.

# Managing the queue
Most of the functions of MatchmakingService are for internal use, but are exposed if you want to directly manage the queue yourself. All of the methods shown here have an equivalent id variant that accepts player ids instead of player objects. These exist for convenience. For example `QueuePlayer` is the same as `QueuePlayerId`, except `QueuePlayer` takes a player and `QueuePlayerId` takes a user id.

Enough with that though here's all the methods that MatchmakingService provides to manage your queue.

### Getting a specific queue
Queue might be important to you for any number of reasons. MatchmakingService exposes a helpful method to get the queue of a specific rating type:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
local queues = MatchmakingService:GetQueue(ratingType)
```

`queues` is a dictionary that would look like this:
```lua
{
  [poolOne] = {userId, userId2, userId3, ...};
  [poolTwo] = {userId, userId2, userId3, ...};
  ...;
}
```

The pool is a rounded rating. It's internally stored as a string, so if you want to perform mathematical expressions on it make sure you convert it to a number. So if you want to get the queue of a specific rating in a specific pool, say 500 rating: `MatchmakingService:GetQueue(ratingType)["500"]` would get you that queue.


### Getting queue counts
You may want to get a count of players in the queue. This can be accomplished like so:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
local perRating, totalCount = MatchmakingService:GetQueueCounts()
```

`perRating` is a table of `{ratingType=count}` and `totalCount` is the sum of those.

### Listening to when a player is added to or removed from the queue
You may want to listen to exactly when a player is added to or removed from a queue. This is more performant than running `GetQueueCounts` because it does not make any api calls. MatchmakingService uses a custom signal class to achive this with very little overhead:
```lua
local MatchmakingService = require(7567983240).GetSingleton()

MatchmakingService.PlayerAddedToQueue:Connect(function(plr, glicko, ratingType, skillPool)
  print(plr, glicko, ratingType, skillPool)
end)

MatchmakingService.PlayerRemovedFromQueue:Connect(function(plr, ratingType, skillPool)
  print(plr, ratingType, skillPool)
end)
```

In `PlayerAddedToQueue`, the player's user id is passed along with their glicko object, the rating type their queued for and the skill pool they were put in (which is their rating rounded to the nearest 10).

`PlayerRemovedFromQueue` is similar but it does not pass their glicko object. If you need it you can still use `GetPlayerGlicko`.

### Adding a player to the queue
Queuing a player is simple:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:QueuePlayer(player, "ranked") -- Queues the player in the ranked queue pool. Ranked can be any string you want. Think of them as different game modes or queue types. For example in League of Legends you have blind, draft, and ranked. All 3 of these game types use a separate rating behind the scenes.
```
For now, a rating type must be provided, but in future versions the default will be "none" which will have no rating nor will it have skill-based match making.

### Adding a party to the queue
Parties can be added to the queue and are ensured that they all get into the same game when a game is found. This can also be useful for forcing teams. As of v2.2.0-beta, there is no party parity which means there may be parties matched against all solo players. I may add this in the future if it doesn't prove to be too complex.

You can add a party to the queue like so:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:QueueParty(players, ratingType)
```

You can use `RemovePlayersFromQueueId(GetPlayerParty(player))` to dequeue a party.

### Removing a player from queue
Removing a player is also incredibly simple:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayerFromQueue(player) -- Removes the player from the queue.
```

### Removing multiple players from the queue
If you handle your own matchmaking you may want to remove multiple users from the queue at the same time which is more efficient than running 10 update operations. This method does that for you and takes a table of players:
```lua
local MatchmakingService = require(7567983240).GetSingleton()
MatchmakingService:RemovePlayersFromQueue(players) -- Removes the players from the queue.
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

local t1 = {}
local t2 = {}
-- Basic start function
function Start()
  print("Started")
  MatchmakingService:StartGame(_G.gameId)
  -- Simple teams.
  local p = game.Players:GetPlayers()
  table.insert(t1, p[1])
  table.insert(t2, p[2])
end

-- YOU MUST CALL UpdateRatings BEFORE THE GAME IS CLOSED. YOU CANNOT PUT THIS IN BindToClose!
function EndGame(winner)
  MatchmakingService:UpdateRatings(t1, t2, _G.ratingType, winner)
  for i, v in ipairs(game.Players:GetPlayers()) do
    -- You can teleport them back to the hub here, I just kick them
    v:Kick()
  end
end

game.Players.PlayerAdded:Connect(function(player)
  local joinData = player:GetJoinData()
  if _G.gameId == nil and joinData then
    -- Global so its accessible from other scripts if it needs to be.
    _G.gameId = joinData.TeleportData.gameCode
    _G.ratingType = joinData.TeleportData.ratingType
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
If you put this script in your game server in ServerScriptService, it will handle setting game id and removing players from the game on disconnect and removing the game itself on close.

# Future Plans
- A "none" rating type
- Switch to MemoryQueues if/when we get more ways to manage it
- Fully random access management that doesn't use a central server
- Party parity
- Map support

# Updates
I do plan to update this to fix bugs and add features when I have free time. I don't get a lot of free time these days because of college and the game that I'm currently working on, but updates/fixes will release periodically.