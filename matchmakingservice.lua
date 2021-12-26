local CLOSED = false

local PLAYERSADDED = {}
local PLAYERSREMOVED = {}
local PLAYERSADDEDTHISWAVE = {}

local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local DatastoreService = game:GetService("DataStoreService")

local SkillDatastore = DatastoreService:GetDataStore("MATCHMAKINGSERVICE_SKILLS")

local OpenSkill = require(script.OpenSkill)
local Signal = require(script.Signal)

local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")

local MatchmakingService = {
  Singleton = nil;
  Version = "4.3.0-beta";
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

function dictlen(dict)
  local counter = 0
  for _ in pairs(dict) do
    counter += 1
  end
  return counter
end

function any(haystack, cond)
  if haystack == nil or cond == nil then return false end
  for i, v in pairs(haystack) do
    if cond(v) then
      return true
    end
  end
  return false
end

function all(haystack, needles)
  if haystack == nil or needles == nil then return false end
  local hasNeedles = {}
  for i, v in ipairs(needles) do
    hasNeedles[v] = false
  end
  for i, v in ipairs(haystack) do
    if table.find(needles, v) ~= nil then
      hasNeedles[v] = true
    end
  end
  return not any(hasNeedles, function(x) return not x end)
end

function reduce(haystack, transform, default)
  local cur = default or 0
  for k, v in pairs(haystack) do
    cur = transform(cur, v, k, haystack)
  end
  return cur
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

function checkForParties(values)
  for i, v in ipairs(values) do
    if v[3] ~= nil and i + v[3] > #values then
      for j = #values, i, -1 do
        table.remove(values, j)
      end
      return false
    end
  end
  return true
end

function getFromMemory(m, k, retries)
  if retries == nil then retries = 3 end
  local success, response
  local count = 0
  while not success and count < retries do
    success, response = pcall(m.GetAsync, m, k)
    count += 1
    if not success then task.wait(3) end
  end
  if not success then error(response) end
  return response
end

function updateQueue(map, ratingType, stringRoundedRating)
  local now = DateTime.now().UnixTimestampMillis
  local success, errorMessage

  success, errorMessage = pcall(function()
    memoryQueue:UpdateAsync("QueuedMaps", function(old)
      if old == nil then 
        old = {map}
      else
        if find(old, function(v)
            return v == map
          end) then
          return old
        end
        table.insert(old, map)
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update queued maps:")
    error(errorMessage)
  end

  success, errorMessage = pcall(function()
    memoryQueue:UpdateAsync(map.."_QueuedRatingTypes", function(old)
      if old == nil then 
        old = {}
        old[ratingType] = {{stringRoundedRating, now}}
      elseif old[ratingType] == nil then
        old[ratingType] = {{stringRoundedRating, now}}
      else
        if find(old[ratingType], function(v)
            return v[1] == stringRoundedRating
          end) then
          return old
        end
        table.insert(old[ratingType], {stringRoundedRating, now})
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update queued rating types:")
    error(errorMessage)
  end
end

-- End useful utilities


-- Private connections

-- End private connections


--- Gets or creates the top level singleton of the matchmaking service.
-- @param options - The options to provide matchmaking service.
-- @param options.DisableRatingSystem - Whether or not to disable the rating system.
-- @return MatchmakingService - The matchmaking service singleton.
function MatchmakingService.GetSingleton(options)
  print("Retrieving MatchmakingService ("..MatchmakingService.Version..") Singleton.")
  if MatchmakingService.Singleton == nil then
    Players.PlayerRemoving:Connect(function(player)
      MatchmakingService.Singleton:RemovePlayerFromQueueId(player.UserId)
    end)
    MatchmakingService.Singleton = MatchmakingService.new(options)
    task.spawn(function()
      local mainJobId = getFromMemory(memory, "MainJobId", 3)
      local now = DateTime.now().UnixTimestampMillis
      local isMain = mainJobId == nil or mainJobId[2] + 25000 <= now
      if isMain and not CLOSED then
        memory:UpdateAsync("MainJobId", function(old)
          if old == nil or old[1] == mainJobId then
            return {game.JobId, now}
          end
          return nil
        end, 86400)
      end


      MessagingService:SubscribeAsync("MatchmakingServicePlayersAddedToQueue", function(players)
        for _, v in ipairs(players) do
          if Players:GetPlayerByUserId(v) ~= nil then continue end

          MatchmakingService.Singleton.PlayerAddedToQueue:Fire(v[1], v[2], v[3], v[4])
        end
      end)

      MessagingService:SubscribeAsync("MatchmakingServicePlayersRemovedFromQueue", function(players)
        for _, v in ipairs(players) do
          if Players:GetPlayerByUserId(v) ~= nil then continue end
          MatchmakingService.Singleton.PlayerRemovedFromQueue:Fire(v[1], v[2], v[3], v[4])
        end
      end)

      while not CLOSED do
        task.wait(5) -- ~12 messages a minute.
        if #PLAYERSADDED > 0 then
          MessagingService:PublishAsync("MatchmakingServicePlayersAddedToQueue", PLAYERSADDED)
          table.clear(PLAYERSADDED)
        end

        if #PLAYERSREMOVED > 0 then
          MessagingService:PublishAsync("MatchmakingServicePlayersRemovedFromQueue", PLAYERSREMOVED)
          table.clear(PLAYERSREMOVED)
        end

        table.clear(PLAYERSADDEDTHISWAVE)
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
-- @param map The map the player range applies to.
-- @param newPlayerRange The NumberRange with the min and max players.
function MatchmakingService:SetPlayerRange(map, newPlayerRange)
  if newPlayerRange.Max > 100 then
    error("Maximum players has a cap of 100.")
  end
  self.PlayerRanges[map] = newPlayerRange
end

--- Add a new game place.
-- @param name The name of the map.
-- @param id The place id to teleport to.
function MatchmakingService:AddGamePlace(name, id)
  self.GamePlaceIds[name] = id
  if not self.PlayerRanges[name] then
    self.PlayerRanges[name] = NumberRange.new(6, 10)
  end
end

--- Sets whether or not this is a game server.
-- Disables match finding coroutine if it is.
-- @param newValue A boolean that indicates whether or not this server is a game server.
function MatchmakingService:SetIsGameServer(newValue)
  self.IsGameServer = newValue
end

--- Sets the starting mean of OpenSkill objects.
-- Do not modify this unless you know what you're doing.
-- @param newStartingMean The new starting mean.
function MatchmakingService:SetStartingMean(newStartingMean)
  self.StartingMean = newStartingMean
end

--- Sets the starting standard deviation of OpenSkill objects.
-- Do not modify this unless you know what you're doing.
-- @param newStartingStandardDeviation The new starting standing deviation.
function MatchmakingService:SetStartingStandardDeviation(newStartingStandardDeviation)
  self.StartingStandardDeviation = newStartingStandardDeviation
end

--- Sets the max gap in rating between party members.
-- @param newMaxGap The new max gap between party members.
function MatchmakingService:SetMaxPartySkillGap(newMaxGap)
  self.MaxPartySkillGap = newMaxGap
end

--- Sets the number of seconds between each queue expansion.
-- An expansion is 10 rounded skill level in each direction.
-- If a player is skill level 25, they get rounded to 30
-- @param newValue The new value, in seconds, of seconds between each queue expansion.
function MatchmakingService:SetSecondsBetweenExpansion(newValue)
  self.SecondsPerExpansion = newValue
end

--- Clears all memory aside from player data.
function MatchmakingService:Clear()
  print("Clearing memory")
  local count = getFromMemory(memory, "RunningGamesCount", 3)
  if count then
    for i = 1, count do
      local runningGames = getFromMemory(memory, "RunningGames"..tostring(i), 3)
      if runningGames ~= nil then
        for _, code in ipairs(runningGames) do
          memory:RemoveAsync(code)
        end
      end
      memory:RemoveAsync("RunningGames"..tostring(i))
    end
  end
  memory:RemoveAsync("RunningGames")
  memory:RemoveAsync("RunningGamesCount")
  memory:RemoveAsync("QueuedSkillLevels")
  memory:RemoveAsync("MainJobId")
  local queuedMaps = getFromMemory(memoryQueue, "QueuedMaps", 3)
  if queuedMaps == nil then return end
  memoryQueue:RemoveAsync("QueuedMaps")

  for i, map in ipairs(queuedMaps) do
    local mapQueue = self:GetQueue(map)
    memoryQueue:RemoveAsync(map.."_QueuedRatingTypes")
    if mapQueue == nil then continue end
    for ratingType, skillLevelAndQueue in pairs(mapQueue) do
      for skillLevel, queue in pairs(skillLevelAndQueue) do
        memoryQueue:RemoveAsync(map.."_"..ratingType.."_"..skillLevel)
      end
    end
  end
end

function MatchmakingService.new(options)
  local Service = {}
  setmetatable(Service, MatchmakingService)
  Service.Options = options or {}
  Service.MatchmakingInterval = 3
  Service.PlayerRanges = {}
  Service.GamePlaceIds = {}
  Service.IsGameServer = false
  Service.MaxPartySkillGap = 50
  Service.PlayerAddedToQueue = Signal:Create()
  Service.PlayerRemovedFromQueue = Signal:Create()
  Service.ApplyCustomTeleportData = nil
  Service.ApplyGeneralTeleportData = nil
  Service.SecondsPerExpansion = 10

  -- Clears the store in studio 
  if RunService:IsStudio() then 
    task.spawn(Service.Clear, Service)
  end

  task.spawn(function()
    local lastCheckMain = 0
    local mainJobId = getFromMemory(memory, "MainJobId", 3)
    while not Service.IsGameServer and not CLOSED do
      task.wait(Service.MatchmakingInterval)
      local now = DateTime.now().UnixTimestampMillis
      if lastCheckMain + 10000 <= now then
        mainJobId = getFromMemory(memory, "MainJobId", 3)
        lastCheckMain = now
        if mainJobId ~= nil and mainJobId[1] == game.JobId then
          memory:UpdateAsync("MainJobId", function(old)
            if (old == nil or old[1] == game.JobId) and not CLOSED then
              return {game.JobId, now}
            end
            return nil
          end, 86400)
          mainJobId = {game.JobId, now}
        end
      end
      if mainJobId == nil or mainJobId[2] + 30000 <= now then
        memory:UpdateAsync("MainJobId", function(old)
          if (old == nil or mainJobId == nil or old[1] == mainJobId[1]) and not CLOSED then
            return {game.JobId, now}
          end
          return nil
        end, 86400)
        mainJobId = {game.JobId, now}
      elseif mainJobId[1] == game.JobId then
        -- Check all games for open slots
        local parties = getFromMemory(memory, "QueuedParties", 3)
        local runningGamesCount = getFromMemory(memory, "RunningGamesCount", 3)
        if runningGamesCount then
          for i = 1, runningGamesCount do
            local runningGames = getFromMemory(memory, "RunningGames"..tostring(i), 3)
            if runningGames ~= nil then
              for _, code in ipairs(runningGames) do
                local mem = getFromMemory(memory, code, 3)
                if mem == nil then continue end
                if mem.joinable then
                  local queue = Service:GetQueue(mem.map)
                  if queue ~= nil then
                    queue = queue[mem.ratingType]
                  end
                  if queue ~= nil then
                    queue = queue[tostring(mem.skillLevel)]
                  end

                  local expansions = math.floor((now-mem.createTime)/(Service.SecondsPerExpansion*1000))

                  if queue == nil and expansions == 0 then continue end

                  local values = first(queue or {}, Service.PlayerRanges[mem.map].Max - #mem.players)

                  for i = 1, expansions do
                    local skillUp = tostring(tonumber(mem.ratingType)+10*i)
                    local skillDown = tostring(tonumber(mem.ratingType)-10*i)
                    local queueUp = nil
                    local queueDown = nil
                    queueUp = queue[mem.ratingType]
                    queueDown = queue[mem.ratingType]
                    if queueUp ~= nil then
                      queueUp = queueUp[skillUp]
                      queueDown = queueDown[skillDown]
                    end
                    append(values, queueUp)
                    append(values, queueDown)
                  end
                  
                  if values ~= nil then
                    for j = #values, 1, -1 do
                      if values[j][2] >= now - Service.MatchmakingInterval*1000 then
                        table.remove(values, j)
                      end
                    end

                    local acc = #values
                    while not checkForParties(values) do
                      local f = first(queue, Service.PlayerRanges[mem.map].Max - #mem.players, acc + 1)
                      if f == nil or #f == 0 then
                        break
                      end
                      acc += #f
                      append(values, f)
                    end
                  end

                  if values ~= nil and #values > 0 then
                    local plrs = {}

                    for _, v in ipairs(values) do
                      table.insert(plrs, v[1])
                      Service:SetPlayerInfoId(v[1], code, mem.ratingType, parties ~= nil and parties[v] or {}, mem.map)
                    end

                    Service:AddPlayersToGameId(plrs, code)

                    Service:RemovePlayersFromQueueId(tableSelect(values, 1))
                  end
                end
              end
            end	
          end
        end

        -- Main matchmaking
        local queuedMaps = getFromMemory(memoryQueue, "QueuedMaps", 3)
        if queuedMaps == nil then continue end

        for i, map in ipairs(queuedMaps) do
          local mapQueue = Service:GetQueue(map)
          if mapQueue == nil then continue end

          for ratingType, skillLevelAndQueue in pairs(mapQueue) do
            for skillLevel, queue in pairs(skillLevelAndQueue) do
              local values = first(queue, Service.PlayerRanges[map].Max)
              local expansions = math.floor((now-values[1][2])/(Service.SecondsPerExpansion*1000))

              for i = 1, expansions do
                local skillUp = tostring(tonumber(skillLevel)+10*i)
                local skillDown = tostring(tonumber(skillLevel)-10*i)
                local queueUp = nil
                local queueDown = nil
                queueUp = mapQueue[ratingType]
                queueDown = mapQueue[ratingType]
                if queueUp ~= nil then
                  queueUp = queueUp[skillUp]
                  queueDown = queueDown[skillDown]
                end
                if values == nil then values = {} end
                append(values, queueUp)
                append(values, queueDown)
              end

              if values ~= nil then
                for j = #values, 1, -1 do
                  if values[j][2] >= now - Service.MatchmakingInterval*1000 then
                    table.remove(values, j)
                  end
                end

                local acc = #values
                while not checkForParties(values) do
                  local f = first(queue, Service.PlayerRanges[map].Max, acc + 1)
                  if f == nil or #f == 0 then
                    break
                  end
                  acc += #f
                  append(values, f)
                end
              end

              -- If there aren't enough players than skip this skill level
              if values == nil or #values < Service.PlayerRanges[map].Min then
                continue
              else
                local userIds = tableSelect(values, 1)
                -- Otherwise reserve a server and tell all servers the player is ready to join
                local reservedCode = not RunService:IsStudio() and TeleportService:ReserveServer(Service.GamePlaceIds[map]) or "TEST"
                local success, err
                success, err = pcall(function()
                  memory:UpdateAsync(reservedCode, function()
                    return 
                      {
                        ["full"] = #values == Service.PlayerRanges[map].Max;
                        ["skillLevel"] = tonumber(skillLevel);
                        ["players"] = userIds;
                        ["started"] = false;
                        ["joinable"] = #values ~= Service.PlayerRanges[map].Max;
                        ["ratingType"] = ratingType;
                        ["map"] = map;
                        ["createTime"] = now;
                      }
                  end, 86400)
                end)

                if not success then
                  print("Error adding new game:")
                  print(err)
                else
                  if not runningGamesCount or runningGamesCount == 0 then
                    memory:SetAsync("RunningGamesCount", 1, 86400)
                    runningGamesCount = 1
                  end
                  local incremented = false
                  for i = 1, runningGamesCount do
                    success, err = pcall(function()
                      memory:UpdateAsync("RunningGames"..tostring(i), function(old)
                        if not old then old = {} end
                        table.insert(old, reservedCode)
                        return old
                      end, 86400)
                    end)

                    if success then
                      print("Successfully added running game")
                      break
                    elseif not success and i == runningGamesCount then
                      incremented = true
                      memory:SetAsync("RunningGamesCount", runningGamesCount + 1, 86400)
                      runningGamesCount += 1
                      break
                    end
                  end

                  if incremented then
                    success, err = pcall(function()
                      memory:UpdateAsync("RunningGames"..tostring(runningGamesCount), function(old)
                        if not old then old = {} end
                        table.insert(old, reservedCode)
                        return old
                      end, 86400)
                    end)

                    if success then
                      print("Successfully added running game")
                    else
                      print("Error adding running game (1):")
                      print(err)
                    end
                  end

                  for _, v in ipairs(userIds) do
                    Service:SetPlayerInfoId(v, reservedCode, ratingType, parties ~= nil and parties[v] or {}, map)
                  end
                  --Service:RemoveExpansions(ratingType, skillLevel)
                  Service:RemovePlayersFromQueueId(userIds)
                end
              end
            end
          end
        end

      end

      -- Teleport any players to their respective games
      local playersToTeleport = {}
      local playersToRatings = {}
      local playersToMaps = {}
      for _, v  in ipairs(Players:GetPlayers()) do
        local playerData = Service:GetPlayerInfoId(v.UserId)
        if playerData ~= nil then
          if not playerData.teleported and playerData.curGame ~= nil then
            if playersToTeleport[playerData.curGame] == nil then playersToTeleport[playerData.curGame] = {} end
            table.insert(playersToTeleport[playerData.curGame], v)
            playersToRatings[v.UserId] = playerData.ratingType
            playersToMaps[v.UserId] = playerData.map
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
          local data = {gameCode=code, ratingType=playersToRatings[players[1].UserId], customData={}}

          if Service.ApplyCustomTeleportData ~= nil then
            for i, player in ipairs(players) do
              data.customData[player.UserId] = Service.ApplyCustomTeleportData(player, getFromMemory(memory, code, 3))
            end
          end
          
          if Service.ApplyGeneralTeleportData ~= nil then
            data.gameData = Service.ApplyGeneralTeleportData(getFromMemory(memory, code, 3))
          end

          TeleportService:TeleportToPrivateServer(Service.GamePlaceIds[playersToMaps[players[1].UserId]], code, players, nil, data)
        end
      end
    end
  end)
  return Service
end

--- Turns an OpenSkill object into a single rating number.
-- @param openSkillObject The open skill object.
-- @return The single number representation of the object.
function MatchmakingService:ToRatingNumber(openSkillObject)
  return OpenSkill.Ordinal(openSkillObject)
end

--- Gets or initializes a players OpenSkill object.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player id to get the OpenSkill object of.
-- @param ratingType The rating type to get.
-- @return The OpenSkill object (which is just 2 numbers).
function MatchmakingService:GetPlayerRatingId(player, ratingType)
  if self.Options.DisableRatingSystem then return nil end
  local skill = SkillDatastore:GetAsync(ratingType.."_"..tostring(player))
  if not skill then
    local rating = OpenSkill.Rating(self.StartingMean, self.StartingStandardDeviation)
    SkillDatastore:SetAsync(ratingType.."_"..tostring(player), rating, {player})
    skill = rating
  end
  return skill
end

--- Gets or initializes a players OpenSkill object.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player to get the OpenSkill object of.
-- @param ratingType The rating type to get.
-- @return The OpenSkill object (which is just 2 numbers).
function MatchmakingService:GetPlayerRating(player, ratingType)
  return self:GetPlayerRatingId(player.UserId, ratingType)
end

--- Sets a player's skill.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player to set the rating of.
-- @param ratingType The rating type to set.
-- @param rating The new OpenSkill object.
function MatchmakingService:SetPlayerRatingId(player, ratingType, rating)
  if self.Options.DisableRatingSystem then return nil end
  SkillDatastore:SetAsync(ratingType.."_"..tostring(player), rating, {player})
end

--- Sets a player's skill.
-- You should not edit this directly unless you
-- know what you're doing.
-- @param player The player to set the rating of.
-- @param ratingType The rating type to set.
-- @param rating The new OpenSkill object.
function MatchmakingService:SetPlayerRating(player, ratingType, rating)
  self:SetPlayerSkillId(player.UserId, ratingType, rating)
end

--- Clears the player info.
-- @param playerId The player id to clear.
function MatchmakingService:ClearPlayerInfoId(playerId)
  memory:RemoveAsync(playerId)
end

--- Clears the player info.
-- @param player The player to clear.
function MatchmakingService:ClearPlayerInfo(player)
  self:ClearPlayerInfoId(player.UserId)
end

--- Sets the player info.
-- @param player The player id to update.
-- @param code The game id that the player will teleport to, if any.
-- @param ratingType The rating type of their current game, if any.
-- @param party The player's party (table of user ids including the player).
-- @param map The player's queued map, if any.
function MatchmakingService:SetPlayerInfoId(player, code, ratingType, party, map)
  if self.Options.DisableRatingSystem then ratingType = "MMS_RatingDisabled" end
  memory:SetAsync(player, {curGame=code,teleported=false,ratingType=ratingType,party=party,map=map}, 7200)
end

--- Sets the player info.
-- @param player The player to update.
-- @param code The game id that the player will teleport to, if any.
-- @param ratingType The rating type of their current game, if any.
-- @param party The player's party (table of user ids including the player).
-- @param map The player's queued map, if any.
function MatchmakingService:SetPlayerInfo(player, code, ratingType, party, map)
  self:SetPlayerInfoId(player.UserId, code, ratingType, party, map)
end

--- Gets the player info.
-- @param player The player to get.
-- @return The player info.
function MatchmakingService:GetPlayerInfoId(player)
  return getFromMemory(memory, player, 3)
end

--- Gets the player info.
-- @param player The player to get.
-- @return The player info.
function MatchmakingService:GetPlayerInfo(player)
  return self:GetPlayerInfoId(player.UserId)
end

--- Counts how many players are in the queues.
-- @return A dictionary of {ratingType: count} and the full count.
--function MatchmakingService:GetQueueCounts()
--	local counts = {}
--	local queuedSkillLevels = getFromMemory(memory, "QueuedSkillLevels", 3)
--	if queuedSkillLevels == nil then return {} end
--	for ratingType, skillLevelQueue in pairs(queuedSkillLevels) do
--		counts[ratingType] = 0
--		local queue = getFromMemory(memoryQueue, ratingType, 3)
--		for i, skillLevelTable in ipairs(skillLevelQueue)  do
--			if queue == nil then continue end
--			queue = queue[tostring(skillLevelTable[1])]
--			counts[ratingType] += #queue
--		end
--	end
--	return counts, reduce(counts, function(acc, cur)
--		return acc + cur
--	end)
--end

--- Gets a table of user ids, ratingTypes, and skillLevels in a specific queue.
-- @param map The map to get the queue of.
-- @return A dictionary of {ratingType: {skillLevel: queue}} where rating type is the rating type, skill level is the skill level pool (a rounded rating) and queue is a table of user ids.
function MatchmakingService:GetQueue(map)
  local queuedRatingTypes = getFromMemory(memoryQueue, map.."_QueuedRatingTypes", 3)
  if queuedRatingTypes == nil then return nil end
  local queue = {}
  for ratingType, ratingObj in pairs(queuedRatingTypes) do
    queue[ratingType] = {}
    for i, v in ipairs(ratingObj) do
      queue[ratingType][v[1]] = getFromMemory(memoryQueue, map.."_"..ratingType.."_"..v[1], 3)
    end
  end
  return queue
end

--- Queues a player.
-- @param player The player id to queue.
-- @param ratingType The rating type to use.
-- @param map The map to queue them on.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayerId(player, ratingType, map)
  local now = DateTime.now().UnixTimestampMillis
  local deserializedRating = nil
  local roundedRating = 0
  if self.Options.DisableRatingSystem then 
    ratingType = "MMS_RatingDisabled" 
  else
    deserializedRating = self:GetPlayerRatingId(player, ratingType)
    roundedRating = roundSkill(OpenSkill.Ordinal(deserializedRating))
  end
  local stringRoundedRating = tostring(roundedRating)

  local success, errorMessage

  local new = nil

  success, errorMessage = pcall(function()
    new = memoryQueue:UpdateAsync(map.."_"..ratingType.."_"..stringRoundedRating, function(old)
      if old == nil then 
        old = {{player, now}}
      else
        table.insert(old, {player, now})
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to queue player:")
    error(errorMessage)
  end

  updateQueue(map, ratingType, stringRoundedRating)

  local s = find(new, function(v) return v[1] == player end) ~= nil

  if s then
    self.PlayerAddedToQueue:Fire(player, map, ratingType, if self.Options.DisableRatingSystem then nil else roundedRating)

    if table.find(PLAYERSADDEDTHISWAVE, player) == nil then
      local index = find(PLAYERSADDED, function(x)
        return x[1] == player
      end)
      if index == nil then
        table.insert(PLAYERSADDED, {player, map, ratingType, if self.Options.DisableRatingSystem then nil else roundedRating})
      end
      table.insert(PLAYERSADDEDTHISWAVE, player)
    end

    local index = find(PLAYERSREMOVED, function(x)
      return x[1] == player
    end)
    if index ~= nil then
      table.remove(PLAYERSREMOVED, index)
    end
  end

  return s
end

--- Queues a player.
-- @param player The player to queue.
-- @param ratingType The rating type to use.
-- @param map The map to queue them on.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayer(player, ratingType, map)
  return self:QueuePlayerId(player.UserId, ratingType, map)
end

--- Queues a party.
-- @param players The player ids to queue.
-- @param ratingType The rating type to use.
-- @param map The map to queue them on.
-- @return A boolean that is true if the party was queued.
function MatchmakingService:QueuePartyId(players, ratingType, map)
  local now = DateTime.now().UnixTimestampMillis
  local ratingValues = nil
  local avg = 0
  if self.Options.DisableRatingSystem then 
    ratingType = "MMS_RatingDisabled"
  else
    ratingValues = {}
    for _, v in ipairs(players) do
      ratingValues[v] = self:GetPlayerRatingId(v, ratingType)
      if any(ratingValues, function(r)
          return math.abs(OpenSkill.Ordinal(ratingValues[v]) - OpenSkill.Ordinal(r)) > self.MaxPartySkillGap
        end) then
        return false, v, "Rating disparity too high"
      end
      avg += OpenSkill.Ordinal(ratingValues[v])
    end

    avg = avg/dictlen(ratingValues)
  end
  local success, errorMessage

  local roundedRating = roundSkill(avg)
  local stringRoundedRating = tostring(roundedRating)
  local new = nil

  local tbl = {}

  for i, v in ipairs(players) do
    table.insert(tbl, {v, now, #players - i})
  end

  success, errorMessage = pcall(function()
    new = memoryQueue:UpdateAsync(map.."_"..ratingType.."_"..stringRoundedRating, function(old)
      if old == nil then 
        old = {}
      end
      for i, v in ipairs(tbl) do
        table.insert(old, v)
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to queue party:")
    error(errorMessage)
  end

  local t = {}

  for _, v in ipairs(players) do
    t[v] = players
  end

  success, errorMessage = pcall(function()
    memory:UpdateAsync("QueuedParties", function(old)
      if old == nil then old = {} end
      for k, v in pairs(t) do
        old[k] = v
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update Queued Parties:")
    error(errorMessage)
  end

  updateQueue(map, ratingType, stringRoundedRating)

  for _, v in ipairs(players) do
    if find(new, function(t) return t[1] == v end) == nil then
      return false, v, "Player not added to queue"
    end
  end

  for _, v in ipairs(players) do
    self.PlayerAddedToQueue:Fire(v, map, ratingType, if self.Options.DisableRatingSystem then nil else roundedRating)
    if table.find(PLAYERSADDEDTHISWAVE, v) == nil then
      local index = find(PLAYERSADDED, function(x)
        return x[1] == v
      end)
      if index == nil then
        table.insert(PLAYERSADDED, {v, map, ratingType, if self.Options.DisableRatingSystem then nil else roundedRating})
      end
      table.insert(PLAYERSADDEDTHISWAVE, v)
    end

    local index = find(PLAYERSREMOVED, function(x)
      return x[1] == v
    end)
    if index ~= nil then
      table.remove(PLAYERSREMOVED, index)
    end
  end

  return true
end

--- Queues a party.
-- @param player The players to queue.
-- @param ratingType The rating type to use.
-- @param map The map to queue them on.
-- @return A boolean that is true if the party was queued.
function MatchmakingService:QueueParty(players, ratingType, map)
  return self:QueuePartyId(tableSelect(players, "UserId"), ratingType, map)
end

--- Gets a player's party.
-- @param player The player id to get the party of.
-- @return A table of player id's of players in the party including this player.
function MatchmakingService:GetPlayerPartyId(player)
  local parties = getFromMemory(memory, "QueuedParties", 3)
  if parties == nil or parties[player] == nil then return nil end
  return parties[player]
end

--- Gets a player's party.
-- @param player The player to get the party of.
-- @return A table of player id's of players in the party including this player.
function MatchmakingService:GetPlayerParty(player)
  return self:GetPlayerPartyId(player)
end


--- Removes a specific player id from the queue.
-- @param player The player id to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromQueueId(player)
  local toRemove = {}
  local hasErrors = false
  local success, errorMessage

  local queuedMaps = getFromMemory(memoryQueue, "QueuedMaps", 3)

  if queuedMaps == nil then return end

  for i, map in ipairs(queuedMaps) do
    local queue = self:GetQueue(map)
    for ratingType, skillLevelAndQueue in pairs(queue) do
      for skillLevel, levelQueue in pairs(skillLevelAndQueue) do
        if find(levelQueue, function(v) return v[1] == player end) then
          success, errorMessage = pcall(function()
            memoryQueue:UpdateAsync(map.."_"..ratingType.."_"..skillLevel, function(old)
              if old == nil then return nil end
              local index = find(levelQueue, function(v) return v[1] == player end)
              if index == nil then return nil end
              table.remove(old, index)
              if #old == 0 then 
                table.insert(toRemove, map.."_"..ratingType.."_"..skillLevel)
              end

              self.PlayerRemovedFromQueue:Fire(player, map, ratingType, tonumber(skillLevel))

              if table.find(PLAYERSADDEDTHISWAVE, player) == nil then
                local index = find(PLAYERSREMOVED, function(x)
                  return x[1] == player
                end)
                if index == nil then
                  table.insert(PLAYERSREMOVED, {player, map, ratingType, tonumber(skillLevel)})
                end
                table.insert(PLAYERSADDEDTHISWAVE, player)
              end

              local index = find(PLAYERSADDED, function(x)
                return x[1] == player
              end)
              if index ~= nil then
                table.remove(PLAYERSADDED, index)
              end

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
    end
  end

  success, errorMessage = pcall(function()
    memory:UpdateAsync("QueuedParties", function(old)
      if old == nil then return nil end
      old[player] = nil
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update Queued Parties:")
    error(errorMessage)
  end

  for i = #toRemove, 1, -1 do
    local str = toRemove[i]
    memoryQueue:RemoveAsync(str)
    local map, ratingType, skillLevel = table.unpack(string.split(str, "_"))

    memoryQueue:UpdateAsync(map.."_QueuedRatingTypes", function(old)
      if old == nil then 
        return nil
      elseif old[ratingType] ~= nil then
        local index = find(old, function(v) return v[1] == skillLevel end)
        if index ~= nil then
          table.remove(old[ratingType], index)
        end
        if #old[ratingType] == 0 then
          old[ratingType] = nil
        end
        if dictlen(old) == 0 then
          table.insert(toRemove, map.."_QueuedRatingTypes")
        end
      end
      return old
    end, 86400)

    if not success then
      hasErrors = true
      print("Unable to update Queued Rating Types:")
      print(errorMessage)
    end
    table.remove(toRemove, i)
  end

  for i = #toRemove, 1, -1 do
    local str = toRemove[i]
    memoryQueue:RemoveAsync(str)
    local map = table.unpack(string.split(str, "_"))

    memoryQueue:UpdateAsync("QueuedMaps", function(old)
      if old == nil then 
        return nil
      else
        local index = table.find(old, map)
        if index ~= nil then
          table.remove(old, index)
        end
      end
      return old
    end, 86400)

    if not success then
      hasErrors = true
      print("Unable to update Queued Maps:")
      print(errorMessage)
    end
    table.remove(toRemove, i)
  end

  return not hasErrors
end

--- Removes a specific player from the queue.
-- @param player The player to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromQueue(player)
  return self:RemovePlayerFromQueueId(player.UserId)
end


--- Removes a table of player ids from the queue.
-- @param players The player ids to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromQueueId(players)
  local toRemove = {}
  local hasErrors = false
  local success, errorMessage

  local queuedMaps = getFromMemory(memoryQueue, "QueuedMaps", 3)

  if queuedMaps == nil then return end

  local playersToQueues = {}

  for i, map in ipairs(queuedMaps) do
    local queue = self:GetQueue(map)
    for ratingType, skillLevelAndQueue in pairs(queue) do
      for skillLevel, levelQueue in pairs(skillLevelAndQueue) do
        for i, player in ipairs(players) do
          if find(levelQueue, function(v) return v[1] == player end) then
            if not playersToQueues[map.."_"..ratingType.."_"..skillLevel] then
              playersToQueues[map.."_"..ratingType.."_"..skillLevel] = {}
            end
            table.insert(playersToQueues[map.."_"..ratingType.."_"..skillLevel], player)
          end
        end
      end
    end
  end

  for id, plrs in pairs(playersToQueues) do
    success, errorMessage = pcall(function()
      memoryQueue:UpdateAsync(id, function(old)
        if old == nil then return nil end
        local map, ratingType, skillLevel = string.split(id, "_")
        for i, player in ipairs(plrs) do
          local index = find(old, function(v) return v[1] == player end)
          if index == nil then return nil end
          table.remove(old, index)	
          self.PlayerRemovedFromQueue:Fire(player, map, ratingType, tonumber(skillLevel))
          if table.find(PLAYERSADDEDTHISWAVE, player) == nil then
            local index = find(PLAYERSREMOVED, function(x)
              return x[1] == player
            end)
            if index == nil then
              table.insert(PLAYERSREMOVED, {player, map, ratingType, tonumber(skillLevel)})
            end
            table.insert(PLAYERSADDEDTHISWAVE, player)
          end

          local index = find(PLAYERSADDED, function(x)
            return x[1] == player
          end)
          if index ~= nil then
            table.remove(PLAYERSADDED, index)
          end
        end

        if #old == 0 then 
          table.insert(toRemove, id)
        end

        return old
      end, 86400)
    end)

    if not success then
      hasErrors = true
      print("Unable to remove player from queue:")
      print(errorMessage)			
    end		
  end

  success, errorMessage = pcall(function()
    memory:UpdateAsync("QueuedParties", function(old)
      if old == nil then return nil end
      for i, player in ipairs(players) do
        old[player] = nil
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update Queued Parties:")
    error(errorMessage)
  end

  for i = #toRemove, 1, -1 do
    local str = toRemove[i]
    memoryQueue:RemoveAsync(str)
    local map, ratingType, skillLevel = table.unpack(string.split(str, "_"))

    memoryQueue:UpdateAsync(map.."_QueuedRatingTypes", function(old)
      if old == nil then 
        return nil
      elseif old[ratingType] ~= nil then
        local index = find(old, function(v) return v[1] == skillLevel end)
        if index ~= nil then
          table.remove(old[ratingType], index)
        end
        if #old[ratingType] == 0 then
          old[ratingType] = nil
        end
        if dictlen(old) == 0 then
          table.insert(toRemove, map.."_QueuedRatingTypes")
        end
      end
      return old
    end, 86400)

    if not success then
      hasErrors = true
      print("Unable to update Queued Rating Types:")
      print(errorMessage)
    end
    table.remove(toRemove, i)
  end

  for i = #toRemove, 1, -1 do
    local str = toRemove[i]
    memoryQueue:RemoveAsync(str)
    local map = table.unpack(string.split(str, "_"))

    memoryQueue:UpdateAsync("QueuedMaps", function(old)
      if old == nil then 
        return nil
      else
        local index = table.find(old, map)
        if index ~= nil then
          table.remove(old, index)
        end
      end
      return old
    end, 86400)

    if not success then
      hasErrors = true
      print("Unable to update Queued Maps:")
      print(errorMessage)
    end
    table.remove(toRemove, i)
  end

  return not hasErrors
end

--- Removes a table of players from the queue.
-- @param players The players to remove from queue.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromQueue(players)
  return self:RemovePlayersFromQueueId(tableSelect(players, "UserId"))
end

--- Adds a player id to a specific existing game.
-- @param player The player id to add to the game.
-- @param gameId The id of the game to add the player to.
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:AddPlayerToGameId(player, gameId, updateJoinable)
  if updateJoinable == nil then updateJoinable = true end
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        table.insert(old.players, player)
        old.full = #old.players == self.PlayerRanges[old.map].Max
        old.joinable = if updateJoinable then #old.players ~= self.PlayerRanges[old.map].Max else old.joinable
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
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:AddPlayerToGame(player, gameId, updateJoinable)
  return self:AddPlayerToGameId(player.UserId, gameId, updateJoinable)
end

--- Adds a table of player ids to a specific existing game.
-- @param players The player ids to add to the game.
-- @param gameId The id of the game to add the players to.
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:AddPlayersToGameId(players, gameId, updateJoinable)
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        for _, v in ipairs(players) do
          table.insert(old.players, v)
        end
        old.full = #old.players == self.PlayerRanges[old.map].Max
        old.joinable = if updateJoinable then #old.players ~= self.PlayerRanges[old.map].Max else old.joinable
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
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:AddPlayersToGame(players, gameId, updateJoinable)
  return self:AddPlayersToGameId(tableSelect(players, "UserId"), gameId, updateJoinable)
end

--- Removes a specific player id from an existing game.
-- @param player The player id to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromGameId(player, gameId, updateJoinable)
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        local index = table.find(old.players, player)
        if index ~= nil then 
          table.remove(old.players, index)
        else
          return nil
        end
        old.full = #old.players == self.PlayerRanges[old.map].Max
        old.joinable = if updateJoinable then #old.players ~= self.PlayerRanges[old.map].Max else old.joinable
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
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:RemovePlayerFromGame(player, gameId, updateJoinable)
  return self:RemovePlayerFromGameId(player.UserId, gameId, updateJoinable)
end

--- Removes multiple players from an existing game.
-- @param players The player ids to remove from the game.
-- @param gameId The id of the game to remove the player from.
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromGameId(players, gameId, updateJoinable)
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        for _, v in ipairs(players) do
          local index = table.find(old.players, v)
          if index == nil then continue end
          table.remove(old.players, index)
        end
        old.full = #old.players == self.PlayerRanges[old.map].Max
        old.joinable = if updateJoinable then #old.players ~= self.PlayerRanges[old.map].Max else old.joinable
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
-- @param updateJoinable Whether or not to update the joinable status of the game.
-- @return true if there was no error.
function MatchmakingService:RemovePlayersFromGame(players, gameId, updateJoinable)
  self:RemovePlayersFromGameId(tableSelect(players, "UserId"), gameId, updateJoinable)
end

--- Update player ratings after a game is over.
-- @param ratingType The rating type this is applicable for.
-- @param ranks The ranks of the teams. #scores should be the same as the #teams.
-- @param teams The teams. A table of tables which contain player ids.
-- @return true if there was no error.
function MatchmakingService:UpdateRatingsId(ratingType, ranks, teams)
  if self.Options.DisableRatingSystem then return nil end
  local success, errorMessage = pcall(function()
    local ratings = {}
    for i, team in ipairs(teams) do
      local teamRatings = {}
      for i, plr in ipairs(team) do
        table.insert(teamRatings, self:GetPlayerRatingId(plr, ratingType))
      end
      table.insert(ratings, teamRatings)
    end

    OpenSkill.Rate(ratings, { rank = ranks })

    for i, team in ipairs(ratings) do
      for j, rating in ipairs(team) do
        local plr = teams[i][j]
        self:SetPlayerRatingId(plr, ratingType, rating)
      end
    end

  end)
  if not success then
    print("Unable to update Ratings:")
    error(errorMessage)
  end
  return true
end

--- Update player ratings after a game is over.
-- @param ratingType The rating type this is applicable for.
-- @param ranks The ranks of the teams. #scores should be the same as the #teams.
-- @param teams The teams. A table of tables which contain players.
-- @return true if there was no error.
function MatchmakingService:UpdateRatings(ratingType, ranks, teams)
  local teamsIds = {}
  for i, team in ipairs(teams) do
    table.insert(teamsIds, tableSelect(team, "UserId"))
  end
  return self:UpdateRatingsId(ratingType, ranks, teamsIds)
end

--- Sets the joinable status of a game.
-- @param gameId The id of the game to update.
-- @param joinable Whether or not the game will be joinable.
-- @return true if there was no error.
function MatchmakingService:SetJoinable(gameId, joinable)
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        old.joinable = joinable
        return old
      end
    end, 86400)
  end)

  if not success then
    print("Unable to update Running Games (Update Joinable):")
    error(errorMessage)
  end
  return true
end

--- Removes a game from memory.
-- @param gameId The game to remove.
-- @return true if there was no error.
function MatchmakingService:RemoveGame(gameId)
  local gameData = getFromMemory(memory, gameId, 3)
  local success, errorMessage = pcall(function()
    memory:RemoveAsync(gameId)
  end)
  if not success then
    print("Unable to update Running Games (Remove game):")
    error(errorMessage)
  end

  local runningGamesCount = getFromMemory(memory, "RunningGamesCount", 3)
  if runningGamesCount then
    for i = 1, runningGamesCount do
      local runningGames = getFromMemory(memory, "RunningGames"..tostring(i), 3)
      if runningGames ~= nil then
        local index = table.find(runningGames, gameId)
        if index == nil then continue end
        if #runningGames == 1 then
          local success, errorMessage = pcall(function()
            memory:RemoveAsync("RunningGames"..tostring(i))
          end)
          if runningGamesCount == i then
            memory:UpdateAsync("RunningGamesCount", function(old)
              return old - 1
            end, 86400)
          end
          if not success then
            print("Unable to update Running Games (Remove game 2):")
            error(errorMessage)
          end
        else
          local success, errorMessage = pcall(function()
            memory:UpdateAsync("RunningGames"..tostring(i), function(old)
              table.remove(old, index)
              return old
            end, 86400)
          end)
          if not success then
            print("Unable to update Running Games (Remove game 3):")
            error(errorMessage)
          end
        end
        break
      end
    end
  end

  if gameData then
    for userId in ipairs(gameData.players) do
      self:ClearPlayerInfoId(userId)
    end
  end

  return true
end

--- Starts a game.
-- @param gameId The game to start.
-- @param joinable Whether or not the game is still joinable.
-- @return true if there was no error.
function MatchmakingService:StartGame(gameId, joinable)
  if joinable == nil then joinable = false end
  local success, errorMessage = pcall(function()
    memory:UpdateAsync(gameId, function(old)
      if old ~= nil then
        old.started = true
        old.joinable = joinable
        return old
      else
        if old ~= nil and old == nil then
          warn("Unable to update Running Games (Start game): Invalid gameId.")
        else
          warn("Unable to update Running Games (Start game): No running games found in memory")
        end

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

game:BindToClose(function()
  CLOSED = true
  local success, errorMessage = pcall(function()
    local mainId = getFromMemory(memory, "MainJobId", 3)
    if mainId[1] == game.JobId then
      memory:RemoveAsync("MainJobId")
    end
  end)
end)

return MatchmakingService
