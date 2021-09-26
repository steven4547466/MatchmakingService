local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MatchmakingService = {
	Singleton = nil;
}

MatchmakingService.__index = MatchmakingService

-- Useful table utilities
function first(haystack, num)
	if haystack == nil then return nil end
	local toReturn = {}
	for i, v in ipairs(haystack) do
		if i <= num then
			table.insert(toReturn, v)
		end
	end
	return toReturn
end

function find(haystack, needle)
	for i, v in ipairs(haystack) do
		if needle(v) then
			return i
		end
	end
	return nil
end

function tableSelect(haystack, prop)
	local toReturn = {}
	for i, v in ipairs(haystack) do
		table.insert(toReturn, v[prop])
	end
	return toReturn
end

-- End table utilities

--- Gets or creates the top level singleton of the matchmaking service.
-- @return MatchmakingService - The matchmaking service singleton.
function MatchmakingService.GetSingleton()
	if MatchmakingService.Singleton == nil then
		MatchmakingService.Singleton = MatchmakingService.new()
		local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
		local mainJobId = memory:GetAsync("MainJobId")
		local isMain = mainJobId == nil or mainJobId == -1
		if isMain then
			memory:UpdateAsync("MainJobId", function(old)
				if old == mainJobId then
					return game.JobId
				end
				return nil
			end, 86400)
		end
	end
	return MatchmakingService.Singleton
end

--- Sets the max queue time in seconds.
-- @param newMax The new maximum queue time in seconds.
function MatchmakingService:SetMaxQueueTime(newMax)
	self.MaxQueueTime = newMax
end

--- Sets the skill levels.
-- @param newSkillLevels The new skill levels.
function MatchmakingService:SetSkillLevels(newSkillLevels)
	self.SkillLevels = newSkillLevels
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

function MatchmakingService.new()
	local Service = {}
	setmetatable(Service, MatchmakingService)
	Service.MaxQueueTime = 600
	Service.SkillLevels = {}
	Service.MatchmakingInterval = 0.5
	Service.PlayerRange = NumberRange.new(6, 10)
	Service.GamePlaceId = -1
	Service.IsGameServer = false
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	
	-- Clears the store in studio 
	if RunService:IsStudio() then 
		memory:SetAsync("RunningGames", {}, 1)
	end
	
	coroutine.wrap(function()
		while not Service.IsGameServer do
			task.wait(Service.MatchmakingInterval)
			local now = DateTime.now().UnixTimestampMillis
			local mainJobId = memory:GetAsync("MainJobId")
			if mainJobId == -1 or mainJobId == nil then
				memory:UpdateAsync("MainJobId", function(old)
					if old == mainJobId then
						return game.JobId
					end
					return nil
				end, 86400)
			elseif mainJobId == game.JobId then
				
				-- Check all games for open slots
				local runningGames = memory:GetAsync("RunningGames")
				if runningGames ~= nil then
					for code, mem in pairs(runningGames) do
						if not mem.full and mem.joinable then
							local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
							local queue = memoryQueue:GetAsync(tostring(mem.skillLevel))
							local values = first(queue, Service.PlayerRange.Max - #mem.players)
							if values ~= nil and #values > 0 then
								local plrs = {}
								
								for _, v in ipairs(values) do
									table.insert(plrs, v[1])
									Service:SetPlayerInfo(v[1], code)
								end
								
								Service:AddPlayersToGameId(plrs, code)
								
								Service:RemovePlayersFromQueueId(tableSelect(values, 1), mem.skillLevel)
							end
						end
					end
				end	
				
				-- Main matchmaking
				for _, skillLevel in ipairs(Service.SkillLevels)  do
					
					local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
					local queue = memoryQueue:GetAsync(tostring(skillLevel))
					local values = first(queue, Service.PlayerRange.Max)
					
					for i = #values, 1, -1 do
						if values[i][2] >= now - Service.MatchmakingInterval*1000 then
							table.remove(values, i)
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
										}
									}
							end
						end, 86400)
						for i, v in ipairs(values) do
							Service:SetPlayerInfo(v[1], reservedCode)
						end
						Service:RemovePlayersFromQueueId(tableSelect(values, 1), skillLevel)
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

--- Sets the player info.
-- @param player The player id to update.
-- @param code The game id that the player will teleport to.
function MatchmakingService:SetPlayerInfo(playerId, code)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:SetAsync(playerId, {curGame=code,teleported=false}, 7200)
end

--- Queues a player with a specific skill level.
-- @param player The player id to queue.
-- @param skillLevel The skill level of the player.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayerId(player, skillLevel)
	if table.find(self.SkillLevels, skillLevel) == nil then
		error("Skill level " .. tostring(skillLevel) .. " was not registered, but a user tried to queue as such.")
	end
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	local now = DateTime.now().UnixTimestampMillis
	local new = memoryQueue:UpdateAsync(tostring(skillLevel), function(old)
		if old == nil then return {{player.UserId}, now} end
		if find(old, function(entry)
				return entry[1] == player.UserId
			end) ~= nil then return old end
		table.insert(old, {player.UserId, now})
		return old
	end, 86400)
	return find(new, function(entry)
		return entry[1] == player.UserId
	end) ~= nil
end

--- Queues a player with a specific skill level.
-- @param player The player to queue.
-- @param skillLevel The skill level of the player.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayer(player, skillLevel)
	return self:QueuePlayerId(player, skillLevel)
end

--function MatchmakingService:QueuePartyId(party, skillLevel)
--	if table.find(self.SkillLevels, skillLevel) == nil then
--		error("Skill level " .. tostring(skillLevel) .. " was not registered, but a user tried to queue as such.")
--	end
--	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
--	local new = memoryQueue:UpdateAsync(tostring(skillLevel), function(old)
--		if old == nil then return {party} end
--		for _, p in ipairs(party) do
--			if table.find(old, p) ~= nil then continue end
--			table.insert(old, p)
--		end
--		return old
--	end, 86400)
--	local partyMemory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_PARTIES")
--	partyMemory:SetAsync(party[1], party)
--	return table.find(new, party[1]) ~= nil
--end

--function MatchmakingService:QueueParty(party, skillLevel)
--	local partyIds = {}
--	for _, p in ipairs(party) do
--		table.insert(partyIds, p.UserId)
--	end
--	return self:QueuePartyId(partyIds, skillLevel)
--end

--- Removes a table of player ids from the queue.
-- @param players The player ids to remove from queue.
-- @param skillLevel The skill level of the players.
function MatchmakingService:RemovePlayersFromQueueId(players, skillLevel)
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	local new = memoryQueue:UpdateAsync(tostring(skillLevel), function(old)
		if old == nil then return nil end
		for _, v in ipairs(players) do
			local index = find(old, function(entry)
				return entry[1] == v
			end)
			if index == nil then continue end
			table.remove(old, index)
		end
		return old
	end, 86400)
end

--- Removes a table of players from the queue.
-- @param players The players to remove from queue.
-- @param skillLevel The skill level of the players.
function MatchmakingService:RemovePlayersFromQueue(players, skillLevel)
	self:RemovePlayersFromQueueId(tableSelect(players, "UserId"), skillLevel)
end

--- Removes a specific player id from the queue.
-- @param player The player id to remove from queue.
-- @param skillLevel The skill level of the player.
function MatchmakingService:RemovePlayerFromQueueId(player, skillLevel)
	local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
	memoryQueue:UpdateAsync(tostring(skillLevel), function(old)
		if old == nil then return nil end
		local index = find(old, function(entry)
			return entry[1] == player
		end)
		if index == nil then return nil end
		table.remove(old, index)
		return old
	end, 86400)
end

--- Removes a specific player from the queue.
-- @param player The player to remove from queue.
-- @param skillLevel The skill level of the player.
function MatchmakingService:RemovePlayerFromQueue(player, skillLevel)
	self:RemovePlayerFromQueueId(player.UserId)
end

--- Adds a player id to a specific existing game.
-- @param player The player id to add to the game.
-- @param gameId The id of the game to add the player to.
function MatchmakingService:AddPlayerToGameId(player, gameId, updateJoinable)
	if updateJoinable == nil then updateJoinable = true end
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:UpdateAsync("RunningGames", function(old)
		if old ~= nil and old[gameId] ~= nil then
			table.insert(old[gameId].players, player)
			old[gameId].full = #old[gameId].players == self.PlayerRange.Max
			old[gameId].joinable = updateJoinable and #old[gameId].players ~= self.PlayerRange.Max or old[gameId].joinable
			return old
		end
	end, 86400)
end

--- Adds a player to a specific existing game.
-- @param player The player to add to the game.
-- @param gameId The id of the game to add the player to.
function MatchmakingService:AddPlayerToGame(player, gameId, updateJoinable)
	self:AddPlayerFromQueueId(player.UserId, gameId, updateJoinable)
end

--- Adds a table of player ids to a specific existing game.
-- @param players The player ids to add to the game.
-- @param gameId The id of the game to add the players to.
function MatchmakingService:AddPlayersToGameId(players, gameId, updateJoinable)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
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
end

--- Adds a table of players to a specific existing game.
-- @param players The players to add to the game.
-- @param gameId The id of the game to add the players to.
function MatchmakingService:AddPlayersToGame(players, gameId, updateJoinable)
	self:AddPlayerFromQueueId(tableSelect(players, "UserId"), gameId, updateJoinable)
end

--- Removes a specific player id from an existing game.
-- @param player The player id to remove from the game.
-- @param gameId The id of the game to remove the player from.
function MatchmakingService:RemovePlayerFromGameId(player, gameId, updateJoinable)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:UpdateAsync("RunningGames", function(old)
		if old ~= nil and old[gameId] ~= nil then
			local plrs = old[gameId].players
			local index = table.find(plrs, player)
			if index ~= nil then 
				table.remove(plrs, index)
			else
				return nil
			end
			old[gameId].full = #plrs == self.PlayerRange.Max
			old[gameId].players = plrs
			old[gameId].joinable = updateJoinable and #plrs ~= self.PlayerRange.Max or old[gameId].joinable
			return old
		end
	end, 86400)
end

--- Removes a specific player from an existing game.
-- @param player The player to remove from the game.
-- @param gameId The id of the game to remove the player from.
function MatchmakingService:RemovePlayerFromGame(player, gameId, updateJoinable)
	self:RemovePlayerFromQueueId(player.UserId, gameId, updateJoinable)
end

--function MatchmakingService:GetPlayerPartyId(player)
--	local partyMemory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_PARTIES")
--	return partyMemory:GetAsync(player)
--end

--function MatchmakingService:GetPlayerParty(player)
--	return self:GetPlayerPartyId(player.UserId)
--end

--- Removes a game from memory.
-- @param gameId The game to remove.
function MatchmakingService:RemoveGame(gameId)
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:UpdateAsync("RunningGames", function(old)
		if old ~= nil and old[gameId] ~= nil then
			old[gameId] = nil
			return old
		elseif old[gameId] == nil then
			return nil
		end
	end, 86400)
end

--- Starts a game.
-- @param gameId The game to start.
-- @param joinable Whether or not the game is still joinable
function MatchmakingService:StartGame(gameId, joinable)
	if joinable == nil then joinable = false end
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:UpdateAsync("RunningGames", function(old)
		if old ~= nil and old[gameId] ~= nil then
			old[gameId].started = true
			old[gameId].joinable = joinable
			return old
		elseif old[gameId] == nil then
			return nil
		end
	end, 86400)
end

game:BindToClose(function()
	local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
	memory:UpdateAsync("MainJobId", function(old)
		if old == game.JobId then
			return -1
		end
		return nil
	end, 86400)
end)

return MatchmakingService
