Changelog

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