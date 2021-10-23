Changelog

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