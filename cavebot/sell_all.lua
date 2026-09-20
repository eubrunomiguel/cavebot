CaveBot.Extensions.SellAll = {}

local sellAllCap = 0
CaveBot.Extensions.SellAll.setup = function()
  CaveBot.registerAction("SellAll", "#de8ef6", function(value, retries)
    local val = string.split(value, ",")
    local wait = CaveBot.Config.get("npcSellDelay")
    local talkDelay = CaveBot.Config.get("talkDelay") or 1000
    local exceptions = {}
    local npcName = val[1]:trim()
    local npc = getCreatureByName(npcName)

    storage.cavebotSell = storage.cavebotSell or {}

    if not npc then 
      modules.game_textmessage.displayGameMessage("[SellAll]: NPC not found! skipping")
      return false 
    end

    if retries > 10 then
      modules.game_textmessage.displayGameMessage("[SellAll]: can't sell, skipping")
      return false
    end

    if freecap() == sellAllCap then
      sellAllCap = 0 
      modules.game_textmessage.displayGameMessage("[SellAll]: Sold everything, proceeding")
      return true
    end

    delay(800)
    if not CaveBot.ReachNPC(npcName) then
      return "retry"
    end

    if not NPC.isTrading() then
      CaveBot.OpenNpcTrade()
      delay(talkDelay)
      return "retry"
    else
      sellAllCap = freecap()
    end

    for _, item in ipairs(storage.cavebotSell) do
      local data = type(item) == 'number' and item or item.id

      if data and not table.find(exceptions, data) then
        table.insert(exceptions, data)
      end
    end

    table.dump(exceptions)

    modules.game_npctrade.sellAll(wait, exceptions)

    if wait then
      modules.game_textmessage.displayGameMessage("[SellAll]: Sold All with delay")
    else
      modules.game_textmessage.displayGameMessage("[SellAll]: Sold All without delay")
    end

    return "retry"
  end)

 CaveBot.Editor.registerAction("sellall", "sell all", {
  value="NPC",
  title="Sell All",
  description="NPC Name",
 })
end