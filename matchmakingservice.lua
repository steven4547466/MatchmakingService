local CLOSED = false

local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.ProfileService)
local Glicko2 = require(script.Glicko2)
local Signal = require(script.Signal)

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

--- Sets the max gap in rating between party members.
-- @param newMaxGap The new starting volatility.
function MatchmakingService:SetMaxPartySkillGap(newMaxGap)
  self.MaxPartySkillGap = newMaxGap
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
  Service.MaxPartySkillGap = 50
  Service.PlayerAddedToQueue = Signal:Create()
  Service.PlayerRemovedFromQueue = Signal:Create()
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
        local runningGames = memory:GetAsync("RunningGames")
        if runningGames ~= nil then
          for code, mem in pairs(runningGames) do
            if mem.joinable then
              local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
              local queue = memoryQueue:GetAsync(mem.ratingType)
              if queue == nil then continue end
              queue = queue[tostring(mem.skillLevel)]
              if queue == nil then continue end
              
              local values = first(queue, Service.PlayerRange.Max - #mem.players)


              if values ~= nil then
                local acc = #values
                while not checkForParties(values) do
                  local f = first(queue, Service.PlayerRange.Max - #mem.players, acc + 1)
                  if f == nil or #f == 0 then
                    break
                  end
                  acc += #f
                  append(values, f)
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
              if values ~= nil and #values > 0 then
                local plrs = {}

                for _, v in ipairs(values) do
                  table.insert(plrs, v[1])
                  Service:SetPlayerInfoId(v[1], code)
                end

                Service:AddPlayersToGameId(plrs, code)

                Service:RemovePlayersFromQueueId(tableSelect(values, 1), mem.skillLevel)
              end
            end
          end
        end	

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
            if queue == nil then continue end
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
            
            if values ~= nil then
              local acc = #values
              while not checkForParties(values) do
                local f = first(queue, Service.PlayerRange.Max, acc + 1)
                if f == nil or #f == 0 then
                  break
                end
                acc += #f
                append(values, f)
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
              
              local parties = memory:GetAsync("QueuedParties")
              
              for _, v in ipairs(values) do
                Service:SetPlayerInfoId(v[1], reservedCode, ratingType, parties ~= nil and parties[v[1]] or {})
              end
              Service:RemoveExpansions(ratingType, skillLevel)
              Service:RemovePlayersFromQueueId(tableSelect(values, 1), skillLevel)
            end
          end
        end
      end

      -- Teleport any players to their respective games
      local playersToTeleport = {}
      local playersToRatings = {}
      for _, v  in ipairs(Players:GetPlayers()) do
        local playerData = Service:GetPlayerInfoId(v.UserId)
        if playerData ~= nil then
          if not playerData.teleported and playerData.curGame ~= nil then
            if playersToTeleport[playerData.curGame] == nil then playersToTeleport[playerData.curGame] = {} end
            table.insert(playersToTeleport[playerData.curGame], v)
            playersToRatings[v.UserId] = playerData.ratingType
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
          TeleportService:TeleportToPrivateServer(Service.GamePlaceId, code, players, nil, {gameCode=code, ratingType=playersToRatings[players[1].UserId]})
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
  local profile = nil
  while Profiles[player] == nil do
    task.wait(0.1)
    i += 0.1
    if i > 3 then 
      error("Unable to get player profile: Wait time exceeded")
      return 
    end
  end

  profile = Profiles[player]

  local playerRatingSerialized = profile.Data[ratingType]

  if playerRatingSerialized == nil then
    profile.Data[ratingType] = Glicko2.g2(self.StartingRating, self.StartingDeviation, self.StartingVolatility):serialize()
  end

  return Glicko2.deserialize(profile.Data[ratingType], 2)
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
  local i = 0
  local profile = nil
  while Profiles[player] == nil do
    task.wait(0.1)
    i += 0.1
    if i > 3 then 
      error("Unable to get player profile: Wait time exceeded")
      return 
    end
  end
  profile = Profiles[player]

  profile.Data[ratingType] = glicko:serialize()
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
-- @param player The player id to update.
-- @param code The game id that the player will teleport to, if any.
-- @param ratingType The rating type of their current game, if any.
-- @param party The player's party (table of user ids including the player).
function MatchmakingService:SetPlayerInfoId(player, code, ratingType, party)
  local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
  memory:SetAsync(player, {curGame=code,teleported=false,ratingType=ratingType,party=party}, 7200)
end

--- Sets the player info.
-- @param player The player to update.
-- @param code The game id that the player will teleport to, if any.
-- @param ratingType The rating type of their current game, if any.
-- @param party The player's party (table of user ids including the player).
function MatchmakingService:SetPlayerInfo(player, code, ratingType, party)
  self:SetPlayerInfoId(player.UserId, code, ratingType, party)
end

--- Gets the player info.
-- @param player The player to get.
function MatchmakingService:GetPlayerInfoId(player)
  local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
  return memory:GetAsync(player)
end

--- Gets the player info.
-- @param player The player to get.
function MatchmakingService:GetPlayerInfo(player)
  self:GetPlayerInfoId(player.UserId)
end

--- Counts how many players are in the queues.
-- @return A dictionary of {ratingType: count} and the full count.
function MatchmakingService:GetQueueCounts()
  local counts = {}
  local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
  local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
  local queuedSkillLevels = memory:GetAsync("QueuedSkillLevels")
  if queuedSkillLevels == nil then return {} end
  for ratingType, skillLevelQueue in pairs(queuedSkillLevels) do
    counts[ratingType] = 0
    local queue = memoryQueue:GetAsync(ratingType)
    for i, skillLevelTable in ipairs(skillLevelQueue)  do
      if queue == nil then continue end
      queue = queue[tostring(skillLevelTable[1])]
      counts[ratingType] += #queue
    end
  end
  return counts, reduce(counts, function(acc, cur)
    return acc + cur
  end)
end

--- Queues a player.
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

  local s = find(new[tostring(roundedRating)], function(entry)
    return entry[1] == player
  end) ~= nil
  
  if s then
    local plr = Players:GetPlayerByUserId(player)
    if plr then
      self.PlayerAddedToQueue:Fire(plr, deserializedRating, ratingType, roundedRating)
    end
  end
  
  return s
end

--- Queues a player.
-- @param player The player to queue.
-- @param ratingType The rating type to use.
-- @return A boolean that is true if the player was queued.
function MatchmakingService:QueuePlayer(player, ratingType)
  return self:QueuePlayerId(player.UserId, ratingType)
end

--- Queues a party.
-- @param players The player ids to queue.
-- @param ratingType The rating type to use.
-- @return A boolean that is true if the party was queued.
function MatchmakingService:QueuePartyId(players, ratingType)
  local ratingValues = {}
  local avg = 0
  local success, errorMessage
  
  for _, v in ipairs(players) do
    ratingValues[v] = self:GetPlayerGlickoId(v, ratingType)
    if any(ratingValues, function(r)
        return math.abs(ratingValues[v].Rating - r.Rating) > self.MaxPartySkillGap
      end) then
      return false, v, "Rating disparity too high"
    end
    avg += ratingValues[v].Rating
  end
  
  avg = avg/dictlen(ratingValues)
  
  local roundedRating = roundSkill(avg)
  
  local memoryQueue = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE_QUEUE")
  local now = DateTime.now().UnixTimestampMillis
  local new = nil
  
  local tbl = {}
  
  for i, v in ipairs(players) do
    table.insert(tbl, {v, now, #players - i})
  end
  
  success, errorMessage = pcall(function()
    new = memoryQueue:UpdateAsync(ratingType, function(old)
      if old == nil then return {[tostring(roundedRating)]=tbl} end
      if old[tostring(roundedRating)] == nil then old[tostring(roundedRating)] = {} end
      if find(old[tostring(roundedRating)], function(entry)
          return any(players, function(x) return entry[1] == x end)
        end) ~= nil then return old end
      append(old[tostring(roundedRating)], tbl)
      return old
    end, 86400)
  end)
  
  if not success then
    print("Unable to queue party:")
    error(errorMessage)
  end
  
  local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
  
  local t = {}
  
  for _, v in ipairs(players) do
    t[v] = players
  end
  
  success, errorMessage = pcall(function()
    memory:UpdateAsync("QueuedParties", function(old)
      if old == nil then return t end
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
  
  for _, v in ipairs(players) do
    if find(new[tostring(roundedRating)], function(entry)
      return entry[1] == v
    end) == nil then
      return false
    end
  end
  
  for _, v in ipairs(players) do
    local plr = Players:GetPlayerByUserId(v)
    if plr then
      self.PlayerAddedToQueue:Fire(plr, ratingValues[v], ratingType, roundedRating, players)
    end
  end

  return true
end

--- Queues a party.
-- @param player The players to queue.
-- @param ratingType The rating type to use.
-- @return A boolean that is true if the party was queued.
function MatchmakingService:QueueParty(players, ratingType)
  return self:QueuePartyId(tableSelect(players, "UserId"), ratingType)
end

--- Gets a player's party.
-- @param player The player id to get the party of.
-- @return A table of player id's of players in the party including this player.
function MatchmakingService:GetPlayerPartyId(player)
  local memory = MemoryStoreService:GetSortedMap("MATCHMAKINGSERVICE")
  local parties = memory:GetAsync("QueuedParties")
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
          
          local plr = Players:GetPlayerByUserId(player)
          if plr then
            self.PlayerRemovedFromQueue:Fire(plr, ratingType, skillLevel)
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
            local plr = Players:GetPlayerByUserId(v)
            if plr then
              self.PlayerRemovedFromQueue:Fire(plr, ratingType, skillLevel)
            end
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
  
  success, errorMessage = pcall(function()
    memory:UpdateAsync("QueuedParties", function(old)
      if old == nil then return nil end
      for _, v in ipairs(players) do
        old[v] = nil
      end
      return old
    end, 86400)
  end)

  if not success then
    print("Unable to update Queued Parties:")
    error(errorMessage)
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
-- @param ratingType The rating type of the game.
-- @param winner The winner of the game (0 - Draw, 1 - Team 1 win, 2 - Team 2 win).
-- @return true if there was no error.
function MatchmakingService:UpdateRatingsId(team1, team2, ratingType, winner)
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
      local glicko = self:GetPlayerGlickoId(id, ratingType):score(t2Score)
      table.insert(team1Scored, glicko)
    end

    for _, id in ipairs(team2) do
      local glicko = self:GetPlayerGlickoId(id, ratingType):score(t1Score)
      table.insert(team2Scored, glicko)
    end

    for _, id in ipairs(team1) do
      local glicko = self:GetPlayerGlickoId(id, ratingType):update(team2Scored) -- Update them against the scored glickos of team 2
      self:SetPlayerGlickoId(id, ratingType, glicko)
      self:GetPlayerGlickoId(id, ratingType)
    end

    for _, id in ipairs(team2) do
      local glicko = self:GetPlayerGlickoId(id, ratingType):update(team1Scored) -- Update them against the scored glickos of team 1
      self:SetPlayerGlickoId(id, ratingType, glicko)
      self:GetPlayerGlickoId(id, ratingType)
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
-- @param ratingType The rating type of the game.
-- @param winner The winner of the game (0 - Draw, 1 - Team 1 win, 2 - Team 2 win).
-- @return true if there was no error.
function MatchmakingService:UpdateRatings(team1, team2, ratingType, winner)
  return self:UpdateRatingsId(tableSelect(team1, "UserId"), tableSelect(team2, "UserId"), ratingType, winner)
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
    local profile = Profiles[plr.UserId]
    if profile ~= nil then
      profile:Release()
    end
  end
end)

return MatchmakingService
