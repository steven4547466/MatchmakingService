local CLOSED = false

local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.ProfileService)
local Glicko2 = require(script.Glicko2)

local ProfileStore = ProfileService.GetProfileStore("PlayerRatings", {})
local Profiles = {}

local MatchmakingService = {
	Singleton = nil;
}

MatchmakingService.__index = MatchmakingService

-- Useful table utilities
function first(haystack, num, skip)
	if haystack == nil then return nil end
	if skip == nil then skip = 1 end
	local toReturn = {}
	for i = skip, num + (skip - 1) do
		if i > #haystack then break end
		table.insert(toReturn, haystack[i])
	end
	return toReturn
end

function find(haystack, needle)
	if haystack == nil then return nil end
	for i, v in ipairs(haystack) do
		if needle(v) then
			return i
		end
	end
	return nil
end

function tableSelect(haystack, prop)
	if haystack == nil then return nil end
	local toReturn = {}
	for i, v in ipairs(haystack) do
		table.insert(toReturn, v[prop])
	end
	return toReturn
end

function append(tbl, tbl2)
	if tbl == nil or tbl2 == nil then
		return nil
	end
	for _, v in ipairs(tbl2) do
		table.insert(tbl, v)
	end
end

-- End table utilities

-- Useful utilities

-- Rounds a value to the nearest 10
function roundSkill(skill)
	return math.round(skill/10) * 10
end

-- End useful utilities


-- Private connections

function PlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- In case we add anything to defaults in the future
		profile:ListenToRelease(function()
			Profiles[player.UserId] = nil
			player:Kick() -- Any time a profile is ever released, the user cannot be in the game.
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player.UserId] = profile
		else
			profile:Release()
		end
	else
		player:Kick()
		error("Unable to obtain player profile: " .. player.Name .. " (" .. player.UserId .. ")")
	end
end

-- End private connections


--- Gets or creates the top level singleton of the matchmaking service.
-- @return MatchmakingService - The matchmaking service singleton.
function MatchmakingService.GetSingleton()
	if MatchmakingService.Singleton == nil then
		MatchmakingService.Singleton = MatchmakingService.new()
		local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
		local mainJobId = memory:GetAsync("MainJobId")
		local isMain = mainJobId == nil or mainJobId == -1
		if isMain and not CLOSED then
			memory:UpdateAsync("MainJobId", function(old)
				if old == mainJobId then
					return game.JobId
				end
				return nil
			end, 86400)
		end
		Players.PlayerAdded:Connect(PlayerAdded)
		for _, player in ipairs(Players:GetPlayers()) do
			coroutine.wrap(PlayerAdded)(player)
		end
		
		Players.PlayerRemoving:Connect(function(player)
			local profile = Profiles[player.UserId]
			if profile ~= nil then
				profile:Release()
			end
		end)
		
	end
	return MatchmakingService.Singleton
end

--- Sets the matchmaking interval.
-- @param newInterval The new matchmaking interval.
function MatchmakingService:SetMatchmakingInterval(newInterval)
	self.MatchmakingInterval = newInterval
end

--- Sets the min/max players.
-- @param newPlayerRange The NumberRange with the min and max players.
function MatchmakingService:SetPlayerRange(newPlayerRange)
	if newPlayerRange.Max > 100 then
		error("Maximum players has a cap of 100.")
	end
	self.PlayerRange = newPlayerRange
end

--- Sets the place to teleport to.
-- @param newPlace The place id to teleport to.
function MatchmakingService:SetGamePlace(newPlace)
	self.GamePlaceId = newPlace
end

--- Sets whether or not this is a game server.
-- Disables match finding coroutine if it is.
-- @param newValue A boolean that indicates whether or not this server is a game server.
function MatchmakingService:SetIsGameServer(newValue)
	self.IsGameServer = newValue
end

--- Sets the starting rating of glicko objects.
-- @param newStartingRating The new starting rating.
function MatchmakingService:SetStartingRating(newStartingRating)
	self.StartingRating = newStartingRating
end

--- Sets the starting deviation of glicko objects.
-- Do not modify this unless you know what you're doing.
-- @param newStartingDeviation The new starting deviation.
function MatchmakingService:SetStartingDeviation(newStartingDeviation)
	self.StartingDeviation = newStartingDeviation
end

--- Sets the starting volatility of glicko objects.
-- Do not modify this unless you know what you're doing.
-- @param newStartingVolatility The new starting volatility.
function MatchmakingService:SetStartingVolatility(newStartingVolatility)
	self.StartingVolatility = newStartingVolatility
end

--- Clears all memory aside from player data.
function MatchmakingService:Clear()
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	memory:RemoveAsync("RunningGames")
	memory:RemoveAsync("QueuedSkillLevels")
	memory:RemoveAsync("MainJobId")
	for i = 0, 5000, 10 do -- This is inefficient and unnecessary, but unfortunately we don't have the ability to clear entire maps.
		coroutine.wrap(function()
			pcall(function()
				memoryQueue:RemoveAsync(tostring(i))
			end)
		end)()
	end
end

function MatchmakingService.new()
	local Service = {}
	setmetatable(Service, MatchmakingService)
	Service.MatchmakingInterval = 0.5
	Service.PlayerRange = NumberRange.new(6, 10)
	Service.GamePlaceId = -1
	Service.IsGameServer = false
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")

	-- Clears the store in studio 
	if RunService:IsStudio() then 
		Service:Clear()
		print("Cleared")
	end

	coroutine.wrap(function()
		while not Service.IsGameServer and not CLOSED do
			task.wait(Service.MatchmakingInterval)
			local now = DateTime.now().UnixTimestampMillis
			local mainJobId = memory:GetAsync("MainJobId")
			if mainJobId == -1 or mainJobId == nil then
				memory:UpdateAsync("MainJobId", function(old)
					if old == mainJobId and not CLOSED then
						return game.JobId
					end
					return nil
				end, 86400)
			elseif mainJobId == game.JobId then

				-- Check all games for open slots
				--local runningGames = memory:GetAsync("RunningGames")
				--if runningGames ~= nil then
				--	for code, mem in pairs(runningGames) do
				--		if not mem.full and mem.joinable then
				--			local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
				--			local queue = memoryQueue:GetAsync(tostring(mem.skillLevel))
				--			local values = first(queue, Service.PlayerRange.Max - #mem.players)
				--			if values ~= nil and #values > 0 then
				--				local plrs = {}

				--				for _, v in ipairs(values) do
				--					table.insert(plrs, v[1])
				--					Service:SetPlayerInfoId(v[1], code)
				--				end

				--				Service:AddPlayersToGameId(plrs, code)

				--				Service:RemovePlayersFromQueueId(tableSelect(values, 1), mem.skillLevel)
				--			end
				--		end
				--	end
				--end	

				-- Main matchmaking
				local queuedSkillLevels = memory:GetAsync("QueuedSkillLevels")
				if queuedSkillLevels == nil then continue end
				local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
				
				for ratingType, skillLevelQueue in pairs(queuedSkillLevels) do
					local queue = memoryQueue:GetAsync(ratingType)
					for i, skillLevelTable in ipairs(skillLevelQueue)  do
						local skillLevel = skillLevelTable[1]
						local queueTime = skillLevelTable[2]
						local expansions = skillLevelTable[3]
						if queue == nil then continue end
						queue = queue[tostring(skillLevel)]
						local values = first(queue, Service.PlayerRange.Max)
						if now >= queueTime + 10000 then
							Service:ExpandSearch(ratingType, skillLevel)
						end
						
						-- Handle expansions
						if expansions ~= nil and (values == nil or #values < Service.PlayerRange.Min) then
							for j = 1, expansions do
								for a = 1, 2 do
									local n = j
									if a == 2 then n *= -1 end
									local t = skillLevelQueue[n + i]
									if t == nil then continue end
									local l = t[1]
									if l == nil or queue[tostring(l)] == nil then continue end
									append(values, first(queue[tostring(l)], Service.PlayerRange.Max))
								end
							end							
						end
						
						-- Remove all newly queued
						if values ~= nil then 
							for j = #values, 1, -1 do
								if values[j][2] >= now - Service.MatchmakingInterval*1000 then
									table.remove(values, j)
								end
							end
						end

						-- If there aren't enough players than skip this skill level
						if values == nil or #values < Service.PlayerRange.Min then
							continue
						else
							-- Otherwise reserve a server and tell all servers the player is ready to join
							local reservedCode = not RunService:IsStudio() and TeleportService:ReserveServer(Service.GamePlaceId) or "TEST"
							memory:UpdateAsync("RunningGames", function(old)
								if old ~= nil then
									old[reservedCode] = 
										{
											["full"] = #values == Service.PlayerRange.Max;
											["skillLevel"] = skillLevel;
											["players"] = values;
											["started"] = false;
											["joinable"] = #values ~= Service.PlayerRange.Max;
											["ratingType"] = ratingType;
										}
									return old
								else
									return 
										{
											[reservedCode] = 
											{
												["full"] = #values == Service.PlayerRange.Max;
												["skillLevel"] = skillLevel;
												["players"] = values;
												["started"] = false;
												["joinable"] = #values ~= Service.PlayerRange.Max;
												["ratingType"] = ratingType;
											}
										}
								end
							end, 86400)
							for _, v in ipairs(values) do
								Service:SetPlayerInfoId(v[1], reservedCode)
							end
							Service:RemoveExpansions(ratingType, skillLevel)
							Service:RemovePlayersFromQueueId(tableSelect(values, 1), skillLevel)
						end
					end
				end
			end

			-- Teleport any players to their respective games
			local playersToTeleport = {}
			for _, v  in ipairs(Players:GetPlayers()) do
				local playerData = memory:GetAsync(v.UserId)
				if playerData ~= nil then
					if not playerData.teleported then
						if playersToTeleport[playerData.curGame] == nil then playersToTeleport[playerData.curGame] = {} end
						table.insert(playersToTeleport[playerData.curGame], v)
						local new = memory:UpdateAsync(v.UserId, function(old)
							if old then
								old.teleported = true
							end
							return old
						end, 7200)
					end
				end
			end

			for code, players in pairs(playersToTeleport) do
				if code ~= "TEST" then 
					TeleportService:TeleportToPrivateServer(Service.GamePlaceId, code, players, nil, {gameCode=code})
				end
			end
		end
	end)()
	return Service
end

--- Gets or initializes a players deserialized glicko object.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player id to get the glicko object of
-- @param ratingType The rating type to get.
-- @return The deserialzed glicko object.
function MatchmakingService:GetPlayerGlickoId(player, ratingType)
	local i = 0
	while Profiles[player] == nil do
		task.wait(0.1)
		i += 0.1
		if i > 3 then 
			error("Unable to get player profile: Wait time exceeded")
			return 
		end
	end
	local playerRatingSerialized = Profiles[player].Data[ratingType]

	if playerRatingSerialized == nil then
		Profiles[player].Data[ratingType] = Glicko2.g2(self.StartingRating, self.StartingDeviation, self.StartingVolatility):serialize()
	end
	
	for i, v in pairs(Profiles[player].Data[ratingType]) do
		print(tostring(i) .. ") " .. tostring(v))
	end
	
	return Glicko2.deserialize(Profiles[player].Data[ratingType], 2)
end

--- Gets or initializes a players deserialized glicko object.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player to get the glicko object of
-- @param ratingType The rating type to get.
-- @return The deserialzed glicko object.
function MatchmakingService:GetPlayerGlicko(player, ratingType)
	return self:GetPlayerGlickoId(player.UserId, ratingType)
end

--- Sets a players rating.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player id to get the glicko object of
-- @param ratingType The rating type to get.
-- @param glicko The new glicko object
function MatchmakingService:SetPlayerGlickoId(player, ratingType, glicko)
	Profiles[player].Data[ratingType] = glicko:serialize()
end

--- Sets a players rating.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player to get the glicko object of
-- @param ratingType The rating type to get.
-- @param glicko The new glicko object
function MatchmakingService:SetPlayerGlicko(player, ratingType, glicko)
	self:SetPlayerGlickoId(player.UserId, ratingType, glicko)
end

--- Clears the player info.
-- @param playerId The player id to clear.
function MatchmakingService:ClearPlayerInfoId(playerId)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:RemoveAsync(playerId)
end

--- Clears the player info.
-- @param player The player id to clear.
function MatchmakingService:ClearPlayerInfo(player)
	self:ClearPlayerInfoId(player.UserId)
end

--- Sets the player info.
-- @param playerId The player id to update.
-- @param code The game id that the player will teleport to.
function MatchmakingService:SetPlayerInfoId(playerId, code)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:SetAsync(playerId, {curGame=code,teleported=false}, 7200)
end

--- Sets the player info.
-- @param player The player to update.
-- @param code The game id that the player will teleport to.
function MatchmakingService:SetPlayerInfo(player, code)
	self:SetPlayerInfoId(player.UserId, code)
end

--- Queues a player with a specific skill level.
-- @param player The player id to queue.
-- @param ratingType The rating type to use.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayerId(player, ratingType)
	local deserializedRating = self:GetPlayerGlickoId(player, ratingType)
	local roundedRating = roundSkill(deserializedRating.Rating)
	local success, errorMessage
	
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	local now = DateTime.now().UnixTimestampMillis
	local new = nil
	success, errorMessage = pcall(function()
		new = memoryQueue:UpdateAsync(ratingType, function(old)
			if old == nil then return {[tostring(roundedRating)]={{player, now}}} end
			if old[tostring(roundedRating)] == nil then old[tostring(roundedRating)] = {} end
			if find(old[tostring(roundedRating)], function(entry)
					return entry[1] == player
				end) ~= nil then return old end
			table.insert(old[tostring(roundedRating)], {player, now})
			return old
		end, 86400)
	end)
	
	if not success then
		print("Unable to queue player:")
		error(errorMessage)
	end
	
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	
	success, errorMessage = pcall(function()
		memory:UpdateAsync("QueuedSkillLevels", function(old)
			if old == nil then return {[ratingType]={{roundedRating, DateTime.now().UnixTimestampMillis}}} end
			if old[ratingType] == nil then old[ratingType] = {} end
			local index = find(old[ratingType], function(entry)
				return entry[1] == roundedRating
			end)
			if index ~= nil then return nil end
			table.insert(old[ratingType], {roundedRating, DateTime.now().UnixTimestampMillis})
			table.sort(old[ratingType], function(a, b)
				return b[1] > a[1]
			end)
			return old
		end, 86400)
	end)
	
	if not success then
		print("Unable to update Queued Skill Levels:")
		error(errorMessage)
	end
	
	return find(new[tostring(roundedRating)], function(entry)
		return entry[1] == player
	end) ~= nil
end

--- Queues a player with a specific skill level.
-- @param player The player to queue.
-- @param ratingType The rating type to use.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayer(player, ratingType)
	return self:QueuePlayerId(player.UserId, ratingType)
end

--- Removes a table of player ids from the queue.
-- @param players The player ids to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromQueueId(players)
	local empty = {}
	local hasErrors = false
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	local success, errorMessage

	local queuedSkillLevels = memory:GetAsync("QueuedSkillLevels")
	if queuedSkillLevels == nil then return end
	for ratingType, skillLevelQueue in pairs(queuedSkillLevels) do
		for i, skillLevelTable in ipairs(skillLevelQueue) do
			local skillLevel = skillLevelTable[1]
			success, errorMessage = pcall(function()
				memoryQueue:UpdateAsync(ratingType, function(old)
					if old == nil then return nil end
					for _, v in ipairs(players) do
						if old[tostring(skillLevel)] == nil then old[tostring(skillLevel)] = {} end
						local index = find(old[tostring(skillLevel)], function(entry)
							return entry[1] == v
						end)
						if index == nil then continue end
						table.remove(old[tostring(skillLevel)], index)
					end
					if empty[ratingType] == nil then empty[ratingType] = {} end
					empty[ratingType][skillLevel] = #old[tostring(skillLevel)] == 0		
					return old
				end, 86400)
			end)
			if not success then
				hasErrors = true
				print("Unable to remove players from queue:")
				print(errorMessage)
			end
		end
	end
	
	for ratingType, tbl in pairs(empty) do
		for skillLevel, isEmpty in pairs(tbl) do
			if not isEmpty then continue end
			success, errorMessage = pcall(function()
				memory:UpdateAsync("QueuedSkillLevels", function(old)
					if old == nil then return nil end
					if old[ratingType] == nil then old[ratingType] = {} end
					local index = find(old[ratingType], function(entry)
						return entry[1] == skillLevel
					end)
					if index == nil then return nil end
					table.remove(old[ratingType], index)
					if #old[ratingType] == 0 then
						old[ratingType] = nil
					else
						table.sort(old[ratingType], function(a, b)
							return b[1] > a[1]
						end)
					end
					return old
				end, 86400)			
			end)

			if not success then
				hasErrors = true
				print("Unable to update Queued Skill Levels:")
				print(errorMessage)
			end
		end
	end
	
	return hasErrors
end

--- Removes a table of players from the queue.
-- @param players The players to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromQueue(players)
	return self:RemovePlayersFromQueueId(tableSelect(players, "UserId"))
end

--- Removes a specific player id from the queue.
-- @param player The player id to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromQueueId(player)
	local empty = {}
	local hasErrors = false
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	local success, errorMessage
	
	local queuedSkillLevels = memory:GetAsync("QueuedSkillLevels")
	if queuedSkillLevels == nil then return end
	for ratingType, skillLevelQueue in pairs(queuedSkillLevels) do
		for i, skillLevelTable in ipairs(skillLevelQueue) do
			local skillLevel = skillLevelTable[1]
			success, errorMessage = pcall(function()
				memoryQueue:UpdateAsync(ratingType, function(old)
					if old == nil then return nil end
					if old[tostring(skillLevel)] == nil then old[tostring(skillLevel)] = {} end
					local index = find(old[tostring(skillLevel)], function(entry)
						return entry[1] == player
					end)
					if index == nil then return nil end
					table.remove(old[tostring(skillLevel)], index)
					if empty[ratingType] == nil then empty[ratingType] = {} end
					empty[ratingType][skillLevel] = #old[tostring(skillLevel)] == 0	
					return old
				end, 86400)
			end)

			if not success then
				hasErrors = true
				print("Unable to remove player from queue:")
				print(errorMessage)
			end
		end
	end
	
	
	for ratingType, tbl in pairs(empty) do
		for skillLevel, isEmpty in pairs(tbl) do
			if not isEmpty then continue end
			success, errorMessage = pcall(function()
				memory:UpdateAsync("QueuedSkillLevels", function(old)
					if old == nil then return nil end
					if old[ratingType] == nil then old[ratingType] = {} end
					local index = find(old[ratingType], function(entry)
						return entry[1] == skillLevel
					end)
					if index ~= nil then return nil end
					table.remove(old[ratingType], index)
					table.sort(old[ratingType], function(a, b)
						return b[1] > a[1]
					end)
					return old
				end, 86400)			
			end)

			if not success then
				hasErrors = true
				print("Unable to update Queued Skill Levels:")
				print(errorMessage)
			end
		end
	end
	
	return hasErrors
end

--- Removes a specific player from the queue.
-- @param player The player to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromQueue(player)
	return self:RemovePlayerFromQueueId(player.UserId)
end

--- Adds a player id to a specific existing game.
-- @param player The player id to add to the game.
-- @param gameId The id of the game to add the player to.
-- @return true if there was no error.
function MatchmakingService:AddPlayerToGameId(player, gameId, updateJoinable)
	if updateJoinable == nil then updateJoinable = true end
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				table.insert(old[gameId].players, player)
				old[gameId].full = #old[gameId].players == self.PlayerRange.Max
				old[gameId].joinable = updateJoinable and #old[gameId].players ~= self.PlayerRange.Max or old[gameId].joinable
				return old
			end
		end, 86400)
	end)
	if not success then
		print("Unable to update Running Games (Add player to game:")
		error(errorMessage)
	end
	return true
end

--- Adds a player to a specific existing game.
-- @param player The player to add to the game.
-- @param gameId The id of the game to add the player to.
-- @return true if there was no error.
function MatchmakingService:AddPlayerToGame(player, gameId, updateJoinable)
	return self:AddPlayerToGameId(player.UserId, gameId, updateJoinable)
end

--- Adds a table of player ids to a specific existing game.
-- @param players The player ids to add to the game.
-- @param gameId The id of the game to add the players to.
-- @return true if there was no error.
function MatchmakingService:AddPlayersToGameId(players, gameId, updateJoinable)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				for _, v in ipairs(players) do
					table.insert(old[gameId].players, v)
				end
				old[gameId].full = #old[gameId].players == self.PlayerRange.Max
				old[gameId].joinable = updateJoinable and #old[gameId].players ~= self.PlayerRange.Max or old[gameId].joinable
				return old
			end
		end, 86400)
	end) 
	if not success then
		print("Unable to update Running Games (Add players to game):")
		error(errorMessage)
	end
	return true
end

--- Adds a table of players to a specific existing game.
-- @param players The players to add to the game.
-- @param gameId The id of the game to add the players to.
-- @return true if there was no error.
function MatchmakingService:AddPlayersToGame(players, gameId, updateJoinable)
	return self:AddPlayersToGameId(tableSelect(players, "UserId"), gameId, updateJoinable)
end

--- Removes a specific player id from an existing game.
-- @param player The player id to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromGameId(player, gameId, updateJoinable)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				local index = table.find(old[gameId].players, player)
				if index ~= nil then 
					table.remove(old[gameId].players, index)
				else
					return nil
				end
				old[gameId].full = #old[gameId].players == self.PlayerRange.Max
				old[gameId].joinable = updateJoinable and #old[gameId].players ~= self.PlayerRange.Max or old[gameId].joinable
				return old
			end
		end, 86400)
	end)
	if not success then
		print("Unable to update Running Games (Remove player from game):")
		error(errorMessage)
	end
	return true
end

--- Removes a specific player from an existing game.
-- @param player The player to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromGame(player, gameId, updateJoinable)
	return self:RemovePlayerFromGameId(player.UserId, gameId, updateJoinable)
end

--- Removes multiple players from an existing game.
-- @param players The player ids to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromGameId(players, gameId, updateJoinable)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				for _, v in ipairs(players) do
					local index = table.find(old[gameId].players, v)
					if index == nil then continue end
					table.remove(old[gameId].players, index)
				end
				old[gameId].full = #old[gameId].players == self.PlayerRange.Max
				old[gameId].joinable = updateJoinable and #old[gameId].players ~= self.PlayerRange.Max or old[gameId].joinable
				return old
			end
		end, 86400)
	end)
		
	if not success then
		print("Unable to update Running Games (Remove players from game):")
		error(errorMessage)
	end
	return true
end

--- Removes multiple players from an existing game.
-- @param players The players to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromGame(players, gameId, updateJoinable)
	self:RemovePlayersFromGameId(tableSelect(players, "UserId"), gameId, updateJoinable)
end

--- Update player ratings after a game is over.
-- @param team1 Team 1's player id's.
-- @param team1 Team 2's player id's.
-- @param winner The winner of the game (0 - Draw, 1 - Team 1 win, 2 - Team 2 win).
-- @return true if there was no error.
function MatchmakingService:UpdateRatingsId(team1, team2, winner)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		local team1Scored = {}
		local team2Scored = {}
		
		-- if draw then 0.5 else if won then 1 else 0
		local t1Score = (winner == 0 and 0.5) or winner == 1 and 1 or 0 
		local t2Score = (winner == 0 and 0.5) or winner == 2 and 1 or 0
		
		for _, id in ipairs(team1) do
			-- Update with the opposite score because they're opponents
			-- basically if they win score them with 0 as that means team 2 lost against them when we update
			local glicko = self:GetPlayerGlickoId(id):score(t2Score)
			table.insert(team1Scored, glicko)
		end
		
		for _, id in ipairs(team2) do
			local glicko = self:GetPlayerGlickoId(id):score(t1Score)
			table.insert(team2Scored, glicko)
		end
		
		for _, id in ipairs(team1) do
			local glicko = self:GetPlayerGlickoId(id):update(team2Scored) -- Update them against the scored glickos of team 2
			self:SetPlayerGlickoId(id, glicko)
		end

		for _, id in ipairs(team2) do
			local glicko = self:GetPlayerGlickoId(id):update(team1Scored) -- Update them against the scored glickos of team 1
			self:SetPlayerGlickoId(id, glicko)
		end
	end)
	if not success then
		print("Unable to update Ratings:")
		error(errorMessage)
	end
	return true
end

--- Update player ratings after a game is over.
-- @param team1 Team 1's players.
-- @param team1 Team 2's player.
-- @param winner The winner of the game (0 - Draw, 1 - Team 1 win, 2 - Team 2 win).
-- @return true if there was no error.
function MatchmakingService:UpdateRatings(team1, team2, winner)
	return self:UpdateRatingsId(tableSelect(team1, "UserId"), tableSelect(team1, "UserId"), winner)
end

--- Removes a game from memory.
-- @param gameId The game to remove.
-- @return true if there was no error.
function MatchmakingService:RemoveGame(gameId)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				old[gameId] = nil
				return old
			elseif old[gameId] == nil then
				return nil
			end
		end, 86400)
	end)
	if not success then
		print("Unable to update Running Games (Remove game):")
		error(errorMessage)
	end
	return true
end

--- Starts a game.
-- @param gameId The game to start.
-- @param joinable Whether or not the game is still joinable
-- @return true if there was no error.
function MatchmakingService:StartGame(gameId, joinable)
	if joinable == nil then joinable = false end
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("RunningGames", function(old)
			if old ~= nil and old[gameId] ~= nil then
				old[gameId].started = true
				old[gameId].joinable = joinable
				return old
			elseif old[gameId] == nil then
				return nil
			end
		end, 86400)
	end)
		
	if not success then
		print("Unable to update Running Games (Start game):")
		error(errorMessage)
	end
	return true
end

--- Expands the search of a specific rating queue.
-- @param skillLevel The ratingType to expand.
-- @param skillLevel The rating to expand.
function MatchmakingService:ExpandSearch(ratingType, skillLevel)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("QueuedSkillLevels", function(old)
			if old == nil or old[ratingType] == nil then return nil end
			local index = find(old[ratingType], function(entry)
				return entry[1] == skillLevel
			end)
			if index == nil then return nil end
			local pre = old[ratingType][index][3]
			if pre == nil then pre = 0 end
			old[ratingType][index] = {skillLevel, DateTime.now().UnixTimestampMillis, pre+1}
			table.sort(old[ratingType], function(a, b)
				return b[1] > a[1]
			end)
			return old
		end, 86400)
	end)
end

--- Removes expansions of the search of a specific rating queue.
-- @param skillLevel The ratingType to remove expansions from.
-- @param skillLevel The rating to to remove expansions from.
function MatchmakingService:RemoveExpansions(ratingType, skillLevel)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		memory:UpdateAsync("QueuedSkillLevels", function(old)
			if old == nil or old[ratingType] == nil then return nil end
			local index = find(old[ratingType], function(entry)
				return entry[1] == skillLevel
			end)
			if index == nil then return nil end
			old[ratingType][index] = {skillLevel, DateTime.now().UnixTimestampMillis}
			table.sort(old[ratingType], function(a, b)
				return b[1] > a[1]
			end)
			return old
		end, 86400)
	end)
end

game:BindToClose(function()
	CLOSED = true
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	local success, errorMessage = pcall(function()
		local mainId = memory:GetAsync("MainJobId")
		if mainId == game.JobId then
			memory:RemoveAsync("MainJobId")
		end
	end)
	
	for _, plr in ipairs(Players:GetPlayers()) do
		MatchmakingService:RemovePlayerFromQueueId(plr.UserId)
	end
end)

return MatchmakingService
