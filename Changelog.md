Changelog
Version 3.0.0-beta.2
Changes (breaking):
* [Addition] Added a new role system to allow developers to assign players roles while in queue. This would allow them to queue on different teams. For example, in dead by daylight, you can queue as killer or survivor. This new system allows you to mimic that.
* [Addition] `SetMapRoles()`. Allows you to set the map roles to a table with this format (example):
```lua
{
  ["Killer"] = { -- Key is the role name
    Min=1;
    Max=1;
  };
  ["Survivor"] = {
    Min=1;
    Max=4;
  };
}
```
* * `SetPlayerRange` is unchanged, but is now only applicable if the `role` parameter is not used when queuing
* [Change] `QueuePlayerId`, `QueuePlayer`, `QueuePartyId`, `QueueParty`, `AddPlayerToGame`, `AddPlayerToGameId`, `AddPlayersToGame`, and `AddPlayersToGameId` now accept a `role` parameter. If not provided, then it will use the old system without roles, but the backend adds a role called `MMS_NO_ROLE` for the sake of convenience in the queue.

Changes (non-breaking):
* [Addition] Added signal `GameCreated(gameData, serverId, reservedCode)` which is fired when a server for a game is reserved. This only works in the game which is currently handling the matchmaking loop (otherwise known as the main job).
* [Addition] Added the `RunningGamesJoinable` property with the corresponding method `SetRunningGamesJoinable()`. Defaults to `true`, if `false`, the matchmaking loop will skip running games and not use any memory queue rate limit units on them. This means that when a game is created by the serivce, it will never be joinable to the service, even if you manually set it to joinable. If you use this, it is recommended to set the minimum and maximum players to the same value so that only full games will be made since they are no longer able to be joined afterwards.

Fixes:
* None

Version 3.0.0-beta.1
Changes (breaking):
* [Removal] Removed `GetRunningGames()`.
* [Change] `SetJoinable()` will now move a running game from the joinable memory to the non-joinable memory to preserve rate limit while matchmaking.
* [Change] `StartGame()` will move games from joinable to non-joinable memory if `joinable` is false.
* [Optimization] The matchmaking loop will now only get joinable games, ignoring all non-joinable games to free up rate limit units.

Changes (non-breaking):
* [Addition] Added `GetJoinableGames()`.
* [Addition] Added `GetNonJoinableGames()`.
* [Addition] Added `GetJoinableGamesFiltered()`
* [Addition] Added `GetNonJoinableGamesFiltered()`
* [Change] `GetAllRunningGames()` will return both joinable and non-joinable games.
* [Change] `StartGame()`'s `gameId` parameter is now optional. If `nil`, it will default to the current game id.
* [Optimization] Players queued will be given the `MMS_QUEUED` attribute. If `true`, MatchmakingService will check their data to see if they've joined a game.
* [Optimization] Rather than getting the data from memory in every loop, teleport game data is cached outside the loop.
* [Optimization] `GetCurrentGameCode()` now caches its value so it only gets it from memory once rather than every call.

Fixes:
* [Fix] Fixed both `ApplyCustomTeleportData`'s and `ApplyGeneralTeleportData`'s game data argument.
* [Fix] Fixed the return value on many methods that would always return `true` regardless of errors.
* [Fix] `require`ing the script with a `MajorVersion` option will now set the singleton to the one returned from that version's `GetSingleton` properly.

Version 2.1.0
Changes (breaking):
* None

Changes (non-breaking):
* [Change] `GetRunningGame`'s argument `code` is now optional. If not provided, the code will be the current code of the server, if it's a game server.

Fixes:
* [Fix] Updated `MessagingService` implementation to reflect Roblox's updates to how data is sent and fixes from user [misternicekai](https://devforum.roblox.com/u/misternicekai). I did make this change on my end many months ago, but I unfortunately seemed to have forgotten to commit it.
* [Fix] Fixed [issue #22](https://github.com/steven4547466/MatchmakingService/issues/22).

Version 2.0.4
Changes (breaking):
* None

Changes (non-breaking):
* [Change] `RemovePlayerFromGame` no longer needs to be called manually. If the game is a game server, this will be handled automatically.
* [Change] `SetIsGameServer` now accepts a second parameter `updateJoinableOnLeave` that denotes whether to update the joinable value when a player leaves. This is false by default.
* [Addition] Reintroduced `GetQueueCounts`.
* [Addition] Added typing to methods to allow for auto-complete ([#19](https://github.com/steven4547466/MatchmakingService/pull/19)). Thank you @Dannyftm for this.

Fixes:
* None

Version 2.0.3
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Attempted a fix for an issue that would cause an error when teleporting players to existing games with no custom teleport data.

Version 2.0.2
Changes (breaking):
* None

Changes (non-breaking):
*  None

Fixes:
* [Fix] Fixed `SetPlayerRating` from calling a function that no longer exists.

Version 2.0.1
Changes (breaking):
* None

Changes (non-breaking):
* [Update] Updated [OpenSkill](https://devforum.roblox.com/t/openskill-a-skill-based-rating-system-for-matchmaking/1571168) to version 1.2.0.

Fixes:
* [Fix] Fixed `GetPlayerParty` for users that have found a game.

Version 2.0.0
Changes (breaking):
* [Removal] Removed all teleport data.
* [Addition] Added `MatchmakingService:GetCurrentGameCode()`. This will get the code of the current game, if it is a game server, nil otherwise.
* [Addition] Added `MatchmakingService:GetGameData(code)`. This replaces the teleport data for game data. This will include the game's code, rating type and any custom data you apply with `ApplyGeneralTeleportData`. You can call this without `code`, if so MMS will use the use `GetCurrentGameCode()`.
* [Addition] Added `MatchmakingService:GetUserDataId(player)` (and `MatchmakingService:GetUserData(player)`, accepts player rather than player id). This replaces teleport data for players. Use this to get any data you apply with `ApplyCustomTeleportData`.
* [Change] `RemoveGame(gameId)` is now called automatically on game close and will no longer accept a `gameId` parameter. This shouldn't be called anymore, as MMS will handle it for you.

Changes (non-breaking):
* None

Fixes:
* [Fix] Custom user data is now applied when teleporting to existing games.

Version 1.3.2
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Delimiter for memory is now two underscores. This allows maps to have names with a single underscore.
* [Fix] Added a quick fix for an issue where queue would not be removed if no one was in it, which caused an error.

Version 1.3.1
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed a bug that would prevent global events from working if you passed nothing into `GetSingleton`.
* [Fix] Fixed a bug that would happen if the main job was set to an empty table.
* [Fix] Fixed a bug that would happen if the last players in queue were removed from queue while MMS is finding a game. 
* [Fix] Fixed `GetRunningGames` with max > 200.

Version 1.3.0
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added `DisableGlobalEvents` to the options table when using `GetSingleton`. Setting this to true will disable `PlayerAddedToQueue` and `PlayerRemovedFromQueue` from firing for users not in the server and will save you messaging service quota.

Fixes:
* None

Version 1.2.1
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] `FoundGame` should now fire properly on all servers, not just the main handler.


Version 1.2.0
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added `MatchmakingService.FoundGame` signal which is fired when a player finds a game and is going to be teleported. It is fired with the arguments `userId, gameCode, gameData`. [More info](https://steven4547466.github.io/MatchmakingService/maindocs/#listening-for-finding-games).
* [Addition]  Added `MatchmakingService:SetFoundGameDelay(newValue)` which will delay players teleporting to their game for the number of seconds provided so that you can show a UI, etc.
* [Change] `SetPlayerInfo` now accepts a `teleportAfeter` parameter which is the unix timestamp milliseconds after which the player will teleport.
* [Change] Changed all `error` calls to `warn` calls to prevent code execution from stopping.

Fixes:
* [Fix] `GetRunningGames` will properly return up to `max` games.

Version 1.1.0
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added `MajorVersion` to the options table when using `GetSingleton()`. [More info](https://steven4547466.github.io/MatchmakingService/#getting-a-specific-major-version).
* [Addition] Added `MatchmakingService:GetAllRunningGames()`.
* [Addition] Added `MatchmakingService:GetRunningGames(max, filter)`.
* [Change] Changed how matchmaking works internally. It's no longer as complex and should save a lot of memory calls.

Fixes:
* [Fix] Fixed `PlayerRemovedFromQueue` firing with a table as the second value, rather than the values inside the table.

Version 1.0.0
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added `DisableExpansions` to the options table when using `GetSingleton()`.
* [Addition] Added more comments to the code.

Fixes:
* None

Version 4.4.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed queue expansions for already running games... again! (small oversight).

Version 4.4.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed queue expansions for already running games.

Version 4.4.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Readdition] Readded queue expansions.
* [Addition] Added `SetSecondsBetweenExpansion` which allows you to set the time between queue expansions. A queue's are rounded off at every 10 skill level. A single expansion allows players from the next and previous 10 to be matched together. If a player is queued at 10 skill level, a single expansion will look in 0 and 20 as well.

Fixes:
* None

Version 4.3.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added `ApplyCustomTeleportData` which is a function you can bind to give users custom teleport data.
* [Addition] Added `ApplyGeneralTeleportData` which is a function you can bind to give the game custom teleport data.

Fixes:
* [Fix] `PlayerRemovedFromQueue` will now be passed a number as the fourth parameter, instead of its string representation.

Version 4.2.3-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue that caused the PlayerAddedToQueue event to not fire when queueing a party.
* [Fix] Fixed an issue that caused `QueueParty` to always return false.

Version 4.2.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue that caused party queueing to break.

Version 4.2.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue that causes players to not be removed from queue when finding a game.

Version 4.2.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] `SetJoinable(gameId, joinable)` allows you to explicitly set the joinable state of the game.

Fixes:
* [Fix] A fix for [#10](https://github.com/steven4547466/MatchmakingService/issues/10) has been merged.

Version 4.1.3-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] `GetSingleton` should no longer yield.

Version 4.1.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Prevented runningGamesCount from going to 0 which caused issues.

Version 4.1.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue with breaking up the running games resulting in an error.


Version 4.1.0-beta
Changes (breaking):
* [Addition] `SetPlayerRange` now takes a `map` name as its first argument. Player range is now per map.

Changes (non-breaking):
* None

Fixes:
* None


Version 4.0.0-beta
Changes (breaking):
* [Addition] [OpenSkill](https://devforum.roblox.com/t/openskill-a-skill-based-rating-system-for-matchmaking/1571168) has been added in place of Glicko2 for the rating system.
* [Addition] `AddGamePlace(name, id)` has replaced `SetGamePlace`. `name` is the name of the map, `id` is the game's place id. Supports any number of maps.
* [Addition] `SetStartingMean(newStartingMean)` has been added.
* [Addition] `ToRatingNumber(openSkillObject)` has been added.
* [Removal] ProfileService has been removed.
* [Removal] Glicko2 has been removed.
* [Removal] `SetGamePlace` has been removed.
* [Removal] `SetStartingRating` has been removed (due to how open skill works, this will not be readdedd).
* [Removal] `SetStartingVolatility` has been removed.
* [Removal] `GetQueueCounts` has been temporarily removed. Will be readded in the future.
* [Change] Significant changes have been made to the internal queue system.
* [Change] `PlayerAddedToQueue` will now fire with the arguments `Player`, `Map`, `RatingType`, `RoundedRating`.
* [Change] `PlayerRemovedFromQueue` will now fire with the arguments `Player`, `Map`, `RatingType`, `RoundedRating`.
* [Change] `SetStartingDeviation` has been renamed to `SetStartingStandardDeviation`
* [Change] `GetPlayerGlickoId` has been renamed to `GetPlayerRatingId`. It now returns an OpenSkill object. To get a rating number from this, use `MatchmakingService:ToRatingNumber(openSkillObject)`.
* [Change] `GetPlayerGlicko` has been renamed to `GetPlayerRating`. It now returns an OpenSkill object. To get a rating number from this, use `MatchmakingService:ToRatingNumber(openSkillObject)`.
* [Change] `SetPlayerGlickoId` has been renamed to `SetPlayerRatingId`. Its third parameter is now an OpenSkill object, rather than a glicko object.
* [Change] `SetPlayerGlicko` has been renamed to `SetPlayerRating`. Its third parameter is now an OpenSkill object, rather than a glicko object.
* [Change] `GetQueue` now takes `map` as an argument instead of `ratingType`. It will now return in the format `{ratingType: {skillLevel: queue}}` where `queue` is a table of tables `{userId, partyMembersAfter}`
* [Change] `QueuePlayerId` now requires a third argument `map` which is a map name that is the same as one added with `AddGamePlace`.
* [Change] `QueuePlayer` now requires a third argument `map` which is a map name that is the same as one added with `AddGamePlace`.
* [Change] `QueuePartyId` now requires a third argument `map` which is a map name that is the same as one added with `AddGamePlace`.
* [Change] `QueueParty` now requires a third argument `map` which is a map name that is the same as one added with `AddGamePlace`.
* [Change] `UpdateRatingsId`'s arguments have been completely changed. It now takes the arguments `ratingType`, `ranks`, `teams`. Where `ratingType` is the name of the rating type. `ranks` is a table of numbers that relate to placements of each team. `teams` is a table of tables that contain user ids.
* [Change] `UpdateRatings`'s arguments have been completely changed. It now takes the arguments `ratingType`, `ranks`, `teams`. Where `ratingType` is the name of the rating type. `ranks` is a table of numbers that relate to placements of each team. `teams` is a table of tables that contain players.

Changes (non-breaking):
* [Change] Queue expansions has been removed for the time being. Will be readded in the future.
* [Change] `SetPlayerInfoId` now has a fifth parameter `map` which is the name of the map they queued for.
* [Change] `SetPlayerInfo` now has a fifth parameter `map` which is the name of the map they queued for.

Fixes:
* [Fix] Options will now default to `{}`.

Version 3.4.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue where you would get an error while queueing a player or party with the rating system disabled.

Version 3.4.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] Added an `options` table to `GetSingleton`. Right now the only accepted option is `DisableRatingSystem` which will disable the rating system, disable profile service, and everyone will be in the same queue pool.

Fixes:
* None

Version 3.3.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Change] Players are now removed from queue automatically upon leaving, if they are in the queue.

Fixes:
* [Fix] Broke up the memory stores to bypass the arbitrary 1kb limit on a single key in the memory store map. This fix is being monitored.

Version 3.2.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue that prevented players from being matched after their ratings were updated.
* [Adjustment] Rating can no longer go below 0.

Version 3.2.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] A possible fix to [#3](https://github.com/steven4547466/MatchmakingService/issues/3) has been added. This fix is being monitored.

Version 3.2.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Change] Switched to `task.spawn` over `coroutine.wrap` [#2](https://github.com/steven4547466/MatchmakingService/pull/2)

Fixes:
* [Fix] Added retries to getting things from memory. This should better prevent "Request failed" errors. Cache module still in the works
* [Fix] Profiles will now be force loaded meaning "Unable to get player profile: Wait time exceeded" errors should be less frequent.

Version 3.1.3-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Fixed an issue where MatchmakingService would attempt to index nil with a number.

Version 3.1.1-beta
Changes (breaking):
* None

Version 3.1.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix/Change] Increased the wait time for player profiles to up to 8 seconds which should better prevent "Unable to get player profile: Wait time exceeded" errors when the player is actually in the game

Version 3.1.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Added a fallback to updating main job. If 25 seconds has passed without the main job being updated, a running game will automatically reassign itself as the main job. By default, however, the main job removes itself on close, but this will prevent server hangs from causing lasting issues

Version 3.1.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] `MatchmakingService:GetQueue(ratingType)` Gets the queue of the specified rating type. Returns the values in a dictionary of `{skillLevel: queue}` where skill level is the skill level pool (a rounded rating) and queue is a table of user ids.

Fixes:
* None

Version 3.0.2-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] MatchmakingService should properly queue players now, this should resolve an issue with players not being teleported

Version 3.0.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] `GetPlayerInfo` should now correctly return the player info (https://github.com/steven4547466/MatchmakingService/pull/1)

Version 3.0.0-beta
Changes (breaking):
* [Change] `MatchmakingService.PlayerAddedToQueue` will now fire with a user id instead of a player. This is to support cross-server signaling.
* [Change] `MatchmakingService.PlayerRemovedFromQueue` will now fire with a user id instead of a player. This is to support cross-server signaling.

Changes (non-breaking):
* [Change] `MatchmakingService.PlayerAddedToQueue` will now fire with players from other server instances. This will fire in waves every 5 seconds from every server. It will still fire instantly for users in the same server they queue from.
* [Change] `MatchmakingService.PlayerRemovedFromQueue` will now fire with players from other server instances. This will fire in waves every 5 seconds from every server. It will still fire instantly for users in the same server they queue from.

Fixes:
* None

Version 2.2.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] `MatchmakingService:SetMaxPartySkillGap(newMaxGap)`
* [Addition] `MatchmakingService:GetPlayerInfo(player)`
* [Addition] `MatchmakingService:QueueParty(players, ratingType)`
* [Addition] `MatchmakingService:GetPlayerParty(player)`
* [Addition] `MatchmakingService.PlayerAddedToQueue` signal.
* [Addition] `MatchmakingService.PlayerRemovedFromQueue` signal.
* [Change] `MatchmakingService:SetPlayerInfo` now accepts a new argument, party, which is a table of player ids in their party including the player's own id.

Fixes:
* None

Version 2.1.0-beta
Changes (breaking):
* None

Changes (non-breaking):
* [Addition] `MatchmakingService:GetQueueCounts()`

Fixes:
* None

Version 2.0.0-beta:
Changes (breaking):
* [Change] `QueuePlayer` now takes a ratingType instead of a skill level.
* [Change] `RemovePlayerFromQueue` and `RemovePlayersFromQueue` no longer take a second argument.

Changes (non-breaking):
* [Addition] `SetStartingRating(rating)`
* [Addition] `SetStartingDeviation(deviation)`
* [Addition] `SetStartingVolatility(volatility)`
* [Addition] `<Glicko-2 Object> GetPlayerGlicko(player, ratingType)`
* [Addition] `SetPlayerGlicko(player, ratingType, glickoObject)`
* [Addition] `UpdateRatings(teamOne, teamTwo, ratingType, winner)`


Fixes:
* None

Version 1.0.1-beta
Changes (breaking):
* None

Changes (non-breaking):
* None

Fixes:
* [Fix] Attempt to get length of nil value when no one is queued.