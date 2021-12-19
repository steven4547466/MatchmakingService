## Preface
This documentation will provide the insight on to **every** method available from Matchmaking Service. This will include methods intended for internal use, these are still documented, just in case you ever need them. 

### Note
Every method here that involves a player object most likely also has an "Id" variant. Internally, everything is done with user ids, but the helper methods exist to streamline the process. This means if you see a method called `RemovePlayersFromGame`, there is another method called `RemovePlayersFromGameId` where instead of player objects, user ids are passed. If you're in doubt whether or not an id variant exists for the method you are using, I recommend [looking through the source](https://github.com/steven4547466/MatchmakingService/blob/master/matchmakingservice.lua), if it exists, it will have the same name suffixed with `Id`. "Id" variants will not be listed here unless there is no regular variant.



## Obtaining Singleton
Gets or creates the top level singleton of the matchmaking service.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| options | table | The options to provide matchmaking service | {} |
| options.DisableRatingSystem | boolean | Wheter or not to disable the rating system | false |

```lua
MatchmakingService.GetSingleton(options)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | MatchmakingService | The matchmaking service singleton |

## Clearing the Memory
Clears all memory aside from player data.
```lua
MatchmakingService:Clear()
```

## Setting Matchmaking Interval
Sets the matchmaking interval.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| newInterval | number | The new matchmaking interval |  |

```lua
MatchmakingService:SetMatchmakingInterval(newInterval)
```

## Setting the Player Range
Sets the min/max players.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| map | string | The map the player range applies to |  |
| newPlayerRange | number | The NumberRange with the min and max players |  |

```lua
MatchmakingService:SetPlayerRange(map, newPlayerRange)
```

## Adding A New Map
Add a new game place.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| name | string | The name of the map |  |
| id | number | The place id to teleport to |  |

```lua
MatchmakingService:AddGamePlace(name, id)
```

## Seting Is Game Server
Sets whether or not this is a game server.

!!! note "Note"
    Disables match finding coroutine if `newValue` is true.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| newValue | boolean | A boolean that indicates whether or not this server is a game server |  |

```lua
MatchmakingService:SetIsGameServer(newValue)
```

## Setting the Starting Ranking Mean
Sets the starting mean of OpenSkill objects.

!!! warning "Warning"
    Do not modify this unless you know what you're doing.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| newStartingMean | number | The new starting mean |  |

```lua
MatchmakingService:SetStartingMean(newStartingMean)
```

## Setting the Starting Ranking Standard Deviation
Sets the starting standard deviation of OpenSkill objects.

!!! warning "Warning"
    Do not modify this unless you know what you're doing.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| newStartingStandardDeviation | number | The new starting standing deviation |  |

```lua
MatchmakingService:SetStartingStandardDeviation(newStartingStandardDeviation)
```

## Setting the Max Skill Gap Between Party Members
Sets the max gap in rating between party members.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| newMaxGap | number | The new max gap between party members |  |

```lua
MatchmakingService:SetMaxPartySkillGap(newMaxGap)
```

## Obtaining a Rating Value from an OpenSkill Object
Turns an OpenSkill object into a single rating number.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| openSkillObject | OpenSkill object | The OpenSkill object |  |

```lua
MatchmakingService:ToRatingNumber(openSkillObject)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | number | The single number representation of the object |

## Obtaining an OpenSkill Object
Gets or initializes a players OpenSkill object.

!!! note "Note"
    You should not edit this directly unless you know what you're doing.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to get the OpenSkill object of |  |
| ratingType | string | The rating type to get |  |

```lua
MatchmakingService:GetPlayerRating(player, ratingType)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | OpenSkill object | The OpenSkill object (which is just 2 numbers) |
    
## Setting an OpenSkill Object
Sets a player's skill.

!!! note "Note"
    You should not edit this directly unless you know what you're doing.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to get the OpenSkill object of |  |
| ratingType | string | The rating type to get |  |
| rating | OpenSkill object | The new OpenSkill object |  |

```lua
MatchmakingService:SetPlayerRating(player, ratingType, rating)
```

## Clearing a Player's Info
Clears the player info.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to clear |  |

```lua
MatchmakingService:ClearPlayerInfo(player)
```

## Setting a Player's info
Sets the player info.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to update |  |
| code | string | The game id that the player will teleport to, if any |  |
| ratingType | string | The rating type of their current game, if any |  |
| party | table | The player's party (table of user ids including the player) |  |
| map | string | The player's queued map, if any | |

```lua
MatchmakingService:SetPlayerInfo(player, code, ratingType, party, map)
```

## Getting a Player's Info
Gets the player info.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to get |  |

```lua
MatchmakingService:GetPlayerInfo(player)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | table or nil | The player info |

## Getting the Queue
Gets a table of user ids, ratingTypes, and skillLevels in a specific queue.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| map | string | The map to get the queue of |  |

```lua
MatchmakingService:GetQueue(map)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | table | A dictionary of `{ratingType: {skillLevel: queue}}` where `ratingType` is the rating type, `skillLevel` is the skill level pool (a rounded rating), and `queue` is a table of user ids |

## Queueing a Single Player
Queues a player.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to queue |  |
| ratingType | string | The rating type to use |  |
| map | string | The map to queue them on |  |

```lua
MatchmakingService:QueuePlayer(player, ratingType, map)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean that is true if the player was queued |

## Queueing a Party
Queues a party.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| players | table<​Player> | The players to queue |  |
| ratingType | string | The rating type to use |  |
| map | string | The map to queue them on |  |

```lua
MatchmakingService:QueueParty(players, ratingType, map)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean that is true if the party was queued |
    | Player | The player that caused the queue to not start |
    | string | The reason the queue did not start |

## Getting a Player's Party
Gets a player's party.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to get the party of |  |

```lua
MatchmakingService:GetPlayerParty(player)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | table<​string> | A table of player id's of players in the party including this player |

## Remove a Single Player from the Queue
Removes a specific player from the queue.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to remove from queue |  |

```lua
MatchmakingService:RemovePlayerFromQueue(player)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Remove Multiple Players from the Queue
Removes a table of players from the queue.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| players | table<​Player> | The players to remove from queue |  |

```lua
MatchmakingService:RemovePlayersFromQueue(players)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Adding A Player to an Existing Game
Adds a player to a specific existing game.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to add to the game |  |
| gameId | string | The id of the game to add the player to |  |
| updateJoinable | boolean | Whether or not to update the joinable status of the game | |

```lua
MatchmakingService:AddPlayerToGame(player, gameId, updateJoinable)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Adding Multiple Players to an Existing Game
Adds a table of players to a specific existing game.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | table<​Player> | The players to add to the game |  |
| gameId | string | The id of the game to add the player to |  |
| updateJoinable | boolean | Whether or not to update the joinable status of the game | |

```lua
MatchmakingService:AddPlayersToGame(players, gameId, updateJoinable)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Removing a Player from a Game
Removes a specific player from an existing game.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| player | Player | The player to remove from the game |  |
| gameId | string | The id of the game to remove the player from |  |
| updateJoinable | boolean | Whether or not to update the joinable status of the game | |

```lua
MatchmakingService:RemovePlayersFromGame(players, gameId, updateJoinable)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Updating Ratings
Update player ratings after a game is over.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| ratingType | string | The rating type this is applicable for |  |
| ranks | table<​number> | The ranks of the teams. #scores should be the same as the #teams |  |
| teams | table<​Player> | The teams. A table of tables which contain players | |

```lua
MatchmakingService:UpdateRatings(ratingType, ranks, teams)
```

!!! note "Explaination"
    Basically, lets have this scenario in the ratingType ranked:
    ```lua
      local team1 = {player1, player2}
      local team2 = {player3, player4}
      local team3 = {player5, player6}
    ```
    Let’s say team2 came first, team1 came second and team3 came third. To update the ratings correctly, you would do this:

    `MatchmakingService:UpdateRatings("ranked", {2, 1, 3}, {team1, team2, team3})`

    `{2,1,3}` is important, and so is order. Order is extremely important here. Because I passed the teams in order, I can give the position of each team in order. As previously stated team1 placed second, therefore because team1 is the first team in the teams table, it also has the first value in the rankings table.


!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Set the Game's Joinable Status
Sets the joinable status of a game.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| gameId | string | The id of the game to update |  |
| joinable | boolean | Whether or not the game will be joinable |  |

```lua
MatchmakingService:SetJoinable(gameId, joinable)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Remove a Game from Memory
Removes a game from memory.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| gameId | string | The game to remove |  |

```lua
MatchmakingService:RemoveGame(gameId)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |

## Start a Game
Starts a game.

| Parameter Name | Type | Description | Default Value |
| -------------- | ---- | ----------- | ------------- |
| gameId | string | The game to start |  |
| joinable | boolean | Whether or not the game is still joinable |  |

```lua
MatchmakingService:StartGame(gameId, joinable)
```

!!! info "Returns"
    | Type | Description |
    | ---- | ----------- |
    | boolean | A boolean indicating if there was no error (true if there was no error) |