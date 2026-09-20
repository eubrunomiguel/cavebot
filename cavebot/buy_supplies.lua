CaveBot.Extensions.BuySupplies = {}

CaveBot.Extensions.BuySupplies.onSave = function()
  if Supplies and Supplies.getConfig then
    return Supplies.getConfig()
  end

  return nil
end

CaveBot.Extensions.BuySupplies.onConfigChange = function(name, enabled, data)
  if not data then
    return
  end

  if Supplies and Supplies.setConfig then
    Supplies.setConfig(data)
  end
end

CaveBot.Extensions.BuySupplies.setup = function()
  CaveBot.registerAction("BuySupplies", "#C300FF", function(value, retries)
    local possibleItems = {}

    local val = string.split(value, ",")
    local waitVal

    if #val == 0 or #val > 2 then
      warn("BuySupplies: incorrect BuySupplies value")
      return false
    elseif #val == 2 then
      waitVal = tonumber(val[2]:trim())
    end

    local npcName = val[1]:trim()

    if not waitVal and #val == 2 then
      warn("BuySupplies: incorrect delay values!")
    elseif waitVal and #val == 2 then
      delay(waitVal)
    end

    if retries > 50 then
      modules.game_textmessage.displayGameMessage("BuySupplies: Too many tries, can't buy")
      return false
    end

    -- Check supplies BEFORE going to the NPC.
    -- If everything is already at max, skip the action.
    local needsSupplies = false

    for id, values in pairs(Supplies.getItemsData()) do
      id = tonumber(id)

      local max = tonumber(values.max) or 0
      local current = player:getItemsCount(id) or 0

      if current < max then
        needsSupplies = true
        break
      end
    end

    if not needsSupplies then
      modules.game_textmessage.displayGameMessage(
        "BuySupplies: supplies already met, skipping"
      )
      NPC.closeTrade()
      NPC.say("bye")
      return true
    end

    local npc = getCreatureByName(npcName)
    if not npc then
      modules.game_textmessage.displayGameMessage("BuySupplies: NPC not found")
      return false
    end

    if not CaveBot.ReachNPC(npcName) then
      return "retry"
    end

    if not NPC.isTrading() then
      CaveBot.OpenNpcTrade()
      CaveBot.delay(1000)
      return "retry"
    end

    -- Get items from NPC
    local npcItems = NPC.getBuyItems()

    for i, v in pairs(npcItems) do
      table.insert(possibleItems, v.id)
    end

    for id, values in pairs(Supplies.getItemsData()) do
      id = tonumber(id)

      if table.find(possibleItems, id) then
        local max = values.max or 0
        local current = player:getItemsCount(id) or 0
        local toBuy = max - current

        if toBuy > 0 then
          toBuy = math.min(100, toBuy)

          NPC.buy(id, toBuy)

          modules.game_textmessage.displayGameMessage("BuySupplies: bought " .. toBuy .. "x " .. id)
          return "retry"
        end
      end
    end

    
    NPC.closeTrade()
    NPC.say("bye")
    modules.game_textmessage.displayGameMessage("BuySupplies: bought everything, proceeding")
    return true
  end)

  CaveBot.Editor.registerAction("buysupplies", "buy supplies", {
    value = "NPC name",
    title = "Buy Supplies",
    description = "NPC Name, delay(in ms, optional)",
  })
end