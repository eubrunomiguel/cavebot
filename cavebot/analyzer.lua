
if not storage.refill then
  storage.refill = {
    lastRefill = os.time(),
    refills = 0,
    refills = 0,
    refillTime = {},
  }
end

-- returns dressed-up item id based on not dressed id
-- returns number
function getActiveItemId(id)
    if not id then return false end

    if id == 3049 then
        return 3086
    elseif id == 3050 then
        return 3087
    elseif id == 3051 then
        return 3088
    elseif id == 3052 then
        return 3089
    elseif id == 3053 then
        return 3090
    elseif id == 3091 then
        return 3094
    elseif id == 3092 then
        return 3095
    elseif id == 3093 then
        return 3096
    elseif id == 3097 then
        return 3099
    elseif id == 3098 then
        return 3100
    elseif id == 16114 then
        return 16264
    elseif id == 23531 then
        return 23532
    elseif id == 23533 then
        return 23534
    elseif id == 23544 then
        return 23528
    elseif id == 23529 then
        return 23530
    elseif id == 30343 then -- Sleep Shawl
        return 30342
    elseif id == 30344 then -- Enchanted Pendulet
        return 30345
    elseif id == 30403 then -- Enchanted Theurgic Amulet
        return 30402
    elseif id == 31621 then -- Blister Ring
        return 31616
    elseif id == 32621 then -- Ring of Souls
        return 32635
    else
        return id
    end
end

-- returns first number in string, already formatted as number
-- returns number or nil
function getFirstNumberInText(text)
    local n = nil
    if string.match(text, "%d+") then n = tonumber(string.match(text, "%d+")) end
    return n
end

function getInactiveItemId(id)
    if not id then return false end

    if id == 3086 then
        return 3049
    elseif id == 3087 then
        return 3050
    elseif id == 3088 then
        return 3051
    elseif id == 3089 then
        return 3052
    elseif id == 3090 then
        return 3053
    elseif id == 3094 then
        return 3091
    elseif id == 3095 then
        return 3092
    elseif id == 3096 then
        return 3093
    elseif id == 3099 then
        return 3097
    elseif id == 3100 then
        return 3098
    elseif id == 16264 then
        return 16114
    elseif id == 23532 then
        return 23531
    elseif id == 23534 then
        return 23533
    elseif id == 23530 then
        return 23529
    elseif id == 30342 then -- Sleep Shawl
        return 30343
    elseif id == 30345 then -- Enchanted Pendulet
        return 30344
    elseif id == 30402 then -- Enchanted Theurgic Amulet
        return 30403
    elseif id == 31616 then -- Blister Ring
        return 31621
    elseif id == 32635 then -- Ring of Souls
        return 32621
    else
        return id
    end
end

local function isEquipped(id)
    local t = {getNeck(), getHead(), getBody(), getRight(), getLeft(), getLeg(), getFeet(), getFinger(), getAmmo()}
    local ids = {id, getInactiveItemId(id), getActiveItemId(id)}

    for i, slot in pairs(t) do
        if slot and table.find(ids, slot:getId()) then
            return true
        end
    end
    return false
end

local lootWorth = 0
local wasteWorth = 0
local balance = 0
local balanceDesc = ""
local hourDesc = ""
local launchTime = now
local first = {l="-", r="0"}
local second = {l="-", r="0"}
local third = {l="-", r="0"}
local fourth = {l="-", r="0"}
local five = {l="-", r="0"}
storage.bestHit = storage.bestHit or 0
storage.bestHeal = storage.bestHeal or 0
local usedItems ={}
local analyzerButton
local killList = {}
HuntingSessionStart = os.date('%Y-%m-%d, %H:%M:%S')

if not storage.analyzers then
  storage.analyzers = {
    lootChannel = true,
    rarityFrames = true,
  }
end

--destroy old windows
local windowsTable = {"MainAnalyzerWindow", 
                      "HuntingAnalyzerWindow",
                     }

                      for i, window in ipairs(windowsTable) do
  local element = g_ui.getRootWidget():recursiveGetChildById(window)

  if element then
    element:destroy()
  end
end

local mainWindow = UI.createMiniWindow("MainAnalyzerWindow")
mainWindow:hide()

--f
local toggle = function()
    if mainWindow:isVisible() then
        analyzerButton:setOn(false)
        mainWindow:close()
    else
        analyzerButton:setOn(true)
        mainWindow:open()
    end
end

local toggleAnalyzer = function(window)
    if window:isVisible() then
        window:hide()
    else
        window:show()
    end
end

-- create analyzers button
analyzerButton = modules.game_buttons.buttonsWindow.contentsPanel and modules.game_buttons.buttonsWindow.contentsPanel.buttons.botAnalyzersButton
analyzerButton = analyzerButton or modules.client_topmenu.getButton("botAnalyzersButton")
if analyzerButton then
    analyzerButton:destroy()
end

--button
analyzerButton = modules.client_topmenu.addRightGameToggleButton('botAnalyzersButton', 'vBot Analyzers', '/images/topbuttons/analyzers', toggle, false, 999999)
analyzerButton:setOn(false)

mainWindow.onClose = function()
  analyzerButton:setOn(false)
end

--hunting
local sessionTimeLabel = UI.DualLabel("Session:", "00:00h", {}, mainWindow.contentsPanel).right
local lootLabel = UI.DualLabel("Loot:", "0", {}, mainWindow.contentsPanel).right
local suppliesLabel = UI.DualLabel("Supplies:", "0", {}, mainWindow.contentsPanel).right
local balanceLabel = UI.DualLabel("Balance:", "0", {}, mainWindow.contentsPanel).right

UI.Separator(mainWindow.contentsPanel)
local totalRefills = UI.DualLabel("Total Refills:", "0", {}, mainWindow.contentsPanel).right
local avRefillTime = UI.DualLabel("Time by Refill:", "00:00h", {}, mainWindow.contentsPanel).right
local lastRefill = UI.DualLabel("Time since Refill:", "00:00h", {maxWidth = 200}, mainWindow.contentsPanel).right
UI.Separator(mainWindow.contentsPanel)

UI.DualLabel("Killed Monsters:", "", {maxWidth = 200}, mainWindow.contentsPanel)
local killedList = UI.createWidget("AnalyzerListPanel", mainWindow.contentsPanel)

UI.Separator(mainWindow.contentsPanel)

UI.DualLabel("Looted items:", "", {maxWidth = 200}, mainWindow.contentsPanel)
local lootList = UI.createWidget("AnalyzerListPanel", mainWindow.contentsPanel)
UI.Separator(mainWindow.contentsPanel)
local lootItems = UI.createWidget("AnalyzerItemsPanel", mainWindow.contentsPanel)

--#############################################
--#############################################   UI DONE
--#############################################
--#############################################
--#############################################
--#############################################

setDefaultTab("Main")
-- first, the variables

local console = modules.game_console
local regex = [[ ([^,|^.]+)]]
local noData = {}
local data = {}

local function getColor(v)
    if v >= 10000000 then -- 10kk, red
        return "#FF0000" 
    elseif v >= 5000000 then -- 5kk, orange
        return "#FFA500"
    elseif v >= 1000000 then -- 1kk, yellow
        return "#FFFF00"
    elseif v >= 100000 then -- 100k, purple
        return "#F25AED"
    elseif v >= 10000 then -- 10k, blue
        return "#5F8DF7"
    elseif v >= 1000 then -- 1k, green
        return "#00FF00"
    elseif v >= 50 then
        return "#FFFFFF" -- 50gp, white
    else
      return "#aaaaaa" -- less than 100gp, grey
    end
end

local function formatStr(str)
    if string.starts(str, "a ") then
        str = str:sub(2, #str)
    elseif string.starts(str, "an ") then
      str = str:sub(3, #str)
    end

    local n = getFirstNumberInText(str)
    if n then
        str = string.split(str, tostring(n))[1]
        str = str:sub(1,#str-1)
    end

    return str:trim()
end

local function getPrice(name)
    name = formatStr(name)
    name = name:lower()

    -- if already checked and no data skip looping items.lua
    if noData[name] then
        return 0
    end

    -- maybe was already checked, if so, skip looping items.lua
    if data[name] then
        return data[name]
    end

    -- searching in items.lua - big table, if possible skip
    for k,v in pairs(LootItems) do
        if name == k then
            data[name] = v
            return v
        end
    end

    -- if no data, save it and return 0
    noData[name] = true
    return 0
end

function format_thousand(v, comma)
  comma = comma and "," or "."
  if not v then return 0 end
  local s = string.format("%d", math.floor(v))
  local pos = string.len(s) % 3
  if pos == 0 then pos = 3 end
  return string.sub(s, 1, pos)
  .. string.gsub(string.sub(s, pos+1), "(...)", comma.."%1")
end

niceTimeFormat = function(v, seconds) -- v in seconds
  local hours = string.format("%02.f", math.floor(v/3600))
  local mins = string.format("%02.f", math.floor(v/60 - (hours*60)))
  local secs = string.format("%02.f", math.floor(math.fmod(v, 60)))

  local final = string.format('%s:%s%s',hours,mins,seconds and ":"..secs or "")
 return final
end
local uptime
sessionTime = function()
  uptime = math.floor((now - launchTime)/1000)
  return niceTimeFormat(uptime)
end
sessionTime()

local function add(t, text, color, last)
    table.insert(t, text)
    table.insert(t, color)
    if not last then
        table.insert(t, ", ")
        table.insert(t, "#FFFFFF")
    end
end

local nameRegex = [[Loot of (?:an |a |the |)([^:]+)]]
onTextMessage(function(mode, text)
    if not storage.analyzers.lootChannel then return end
    if not text:find("Loot of") and not text:find("The following items are available in your reward chest") then return end
    local name

    -- adding monster to killed list
    if text:find("Loot of") then
      name = regexMatch(text, nameRegex)[1][2]
      if not killList[name] then
        killList[name] = 1
      else
        killList[name] = killList[name] + 1
      end
      refreshKills()
    end
    -- variables
    local split = string.split(text, ":")
    local re = regexMatch(split[2], regex)
    local combinedWorth = 0
    local formatted
    local div
    local t = {}
    local messageT = {}

    -- add timestamp, creature part and color it as white
    add(t, os.date('%H:%M') .. ' ' .. split[1]..": ", "#FFFFFF", true)
    add(messageT, split[1]..": ", "#FFFFFF", true)    

    -- main part
    if re ~= 0 then
        for i=1,#re do
            local data = re[i][2] -- each looted item
            local formattedLoot = regexMatch(data, [[(^[^(]+)]])[1][1]
            formattedLoot = formattedLoot:trim()
            local amount = getFirstNumberInText(formattedLoot) -- amount found in data
            local price = amount and getPrice(formattedLoot) * amount or getPrice(formattedLoot) -- if amount then multity price, else just take price
            local color = getColor(price) -- generate hex string based off price

            combinedWorth = combinedWorth + price -- add all prices to calculate total worth

            add(t, data, color, i==#re)
            add(messageT, data, color, i==#re)
        end
    end

    -- format total worth so it wont look obnoxious
    if combinedWorth >= 1000000 then
        div = combinedWorth/1000000
        formatted = math.floor(div) .. "." .. math.floor(div * 10) % 10 .. "kk"
    elseif combinedWorth >= 1000 then
        div = combinedWorth/1000
        formatted = math.floor(div) .. "." .. math.floor(div * 10) % 10 .. "k"
    else
        formatted = combinedWorth .. "gp"
    end

    if modules.game_textmessage.messagesPanel.centerTextMessagePanel.highCenterLabel:getText() == text then
      modules.game_textmessage.messagesPanel.centerTextMessagePanel.highCenterLabel:setColoredText(messageT)
      schedule(math.max(#text * 50, 2000), function() 
        modules.game_textmessage.messagesPanel.centerTextMessagePanel.highCenterLabel:setVisible(false)
      end)
    end

    -- add total worth to string
    add(t, " - (", "#FFFFFF", true)
    add(t, formatted, getColor(combinedWorth), true)
    add(t, ")", "#FFFFFF", true)

    -- get/create tab and write raw message
    local tabName = "Loot Tracker"
    local tab = console.getTab(tabName) or console.addTab(tabName, true)
    console.addText(text, console.SpeakTypesSettings, tabName, "")

    -- find last message in given tab and rewrite it with formatted string
    local panel = console.consoleTabBar:getTabPanel(tab)
    local consoleBuffer = panel:getChildById('consoleBuffer')
    local message = consoleBuffer:getLastChild()
    message:setColoredText(t)
end)

local function niceFormat(v)
  local div
  local formatted
    if v >= 10000000 then
      div = v/10000000
      formatted = math.ceil(div) .. "M"
    elseif v >= 1000000 then
      div = v/1000000
      formatted = math.floor(div) .. "." .. math.floor(div * 10) % 10 .. "M"
    elseif v >= 10000 then
      div = v/1000
      formatted = math.floor(div) .. "k"
    elseif v >= 1000 then
        div = v/1000
        formatted = math.floor(div) .. "." .. math.floor(div * 10) % 10 .. "k"
    else
        formatted = v
    end
    return formatted
end

local function getFrame(v)
  if v >= 1000000 then
      return '/images/ui/rarity_gold'
  elseif v >= 100000 then
      return '/images/ui/rarity_purple'
  elseif v >= 10000 then
      return '/images/ui/rarity_blue'
  elseif v >= 1000 then
      return '/images/ui/rarity_green'
  else
      return '/images/ui/item'
  end
end


displayCondition = function(menuPosition, lookThing, useThing, creatureThing)
  if lookThing and not lookThing:isCreature() and not lookThing:isNotMoveable() and lookThing:isPickupable() then
    return true
  end
end
local interface = modules.game_interface

local function setFrames()
  if not storage.analyzers.rarityFrames then return end
  for _, container in pairs(getContainers()) do
      local window = container.itemsPanel
      for i, child in pairs(window:getChildren()) do
          local id = child:getItemId()
          local price = 0

          if id ~= 0 then -- there's item
              local item = Item.create(id)
              local name = item:getMarketData().name:lower()
              price = getPrice(name)

              -- set rarity frame
              child:setImageSource(getFrame(price))
          else -- empty widget
              -- revert any possible changes
              child:setImageSource("/images/ui/item")
          end
          child.onHoverChange = function(widget, hovered)
            if id == 0 or not hovered then
              return interface.removeMenuHook('analyzer')
            end
            interface.addMenuHook('analyzer', 'Price:', function() end, displayCondition, price)          
        end
      end
  end 
end 
setFrames()

onContainerOpen(function(container, previousContainer)
  setFrames()
end)

onAddItem(function(container, slot, item, oldItem)
  setFrames()
end)

onRemoveItem(function(container, slot, item)
  setFrames()
end)

onContainerUpdateItem(function(container, slot, item, oldItem)
  setFrames()
end)

function refreshLoot()

    lootItems:destroyChildren()
    lootList:destroyChildren()

    for k,v in pairs(TargetBot.Looting.getLootItemIds()) do
      if isEquipped(k) then
        v.count = v.count - 1
      end
      if v.count > 0 then
        local label1 = UI.createWidget("AnalyzerLootItem", lootItems)
        local price = v.count and getPrice(v.name) * v.count or getPrice(v.name)

        label1:setItemId(k)
        label1:setItemCount(50)
        label1:setShowCount(false)
        label1.count:setText(niceFormat(v.count))
        label1.count:setColor(getColor(price))
        local tooltipName = v.count > 1 and v.name.."s" or v.name
        label1:setTooltip(v.count .. "x " .. tooltipName .. " (Value: "..format_thousand(getPrice(v.name)).."gp, Sum: "..format_thousand(price).."gp)")
        --hunting window loot list
        local label2 = UI.createWidget("ListLabel", lootList)
        label2:setText(v.count .. "x " .. v.name)
      end
    end

    if lootItems:getChildCount() == 0 then
      local label = UI.createWidget("ListLabel", lootList)
      label:setText("None")
    end
end
refreshLoot()

function refreshKills()
    killedList:destroyChildren()
    local kills = 0
    for k,v in pairs(killList) do
      kills = kills + 1
      local label = UI.createWidget("ListLabel", killedList)
      label:setText(v .. "x " .. k)
    end

    if kills == 0 then
      local label = UI.createWidget("ListLabel", killedList)
      label:setText("None")
    end
end
refreshKills()

function refreshWaste()
    usedItems = {}

    if Supplies and Supplies.getItemsData then
      local ok, supplies = pcall(Supplies.getItemsData)
      if ok and supplies then
        for id, data in pairs(supplies) do
          local count = math.max(data.used or 0, 0)
          local numericId = tonumber(id)
          if count > 0 and numericId and ItemIds and ItemIds.getNameById then
            local name = ItemIds.getNameById(numericId)
            if name then
              usedItems[numericId] = { count = count, name = name:lower() }
            end
          end
        end
      end
    end
end

function hourVal(v)
  v = v or 0
  -- avoid division by zero / absurd early-session spikes.
  -- Below the same threshold used for the per-hour labels, return the raw total.
  if not uptime or uptime < 5*60 then
    return v
  end
  return (v/uptime)*3600
end

-- formats a gold value to kk / k / gp, handling negatives correctly
local function formatCoins(v)
  v = v or 0
  local sign = v < 0 and "-" or ""
  local n = math.abs(v)
  if n >= 1000000 then
    local d = n / 1000000
    return sign .. math.floor(d) .. "." .. math.floor(d * 10) % 10 .. "kk"
  elseif n >= 1000 then
    local d = n / 1000
    return sign .. math.floor(d) .. "." .. math.floor(d * 10) % 10 .. "k"
  else
    return sign .. math.floor(n) .. "gp"
  end
end

function bottingStats()
  lootWorth = 0
  wasteWorth = 0

  -- loot: value every looted item with the same price source used by the UI
  -- (getPrice === LootItems with custom-price override), so numbers match tooltips.
  for k, v in pairs(TargetBot.Looting.getLootItemIds()) do
    if isEquipped(k) then
      v.count = v.count - 1
    end
    if v.name and v.count then
      lootWorth = lootWorth + (getPrice(v.name) * v.count)
    end
  end

  -- supplies: usedItems is filled in refreshWaste() from Supplies.getItemsData()
  for _, v in pairs(usedItems) do
    wasteWorth = wasteWorth + (getPrice(v.name) * v.count)
  end

  balance = lootWorth - wasteWorth

  return lootWorth, wasteWorth, balance
end

function bottingLabels(lootWorth, wasteWorth, balance)
  -- keep balance/h consistent with the loot & supply windows:
  -- balance/h = loot/h - supplies/h, using the same guarded hourVal().
  local balancePerHour = hourVal(lootWorth) - hourVal(wasteWorth)

  balanceDesc = formatCoins(balance)
  hourDesc = formatCoins(balancePerHour) .. "/h"

  return balanceDesc, hourDesc
end

function reportStats()
  local lootWorth, wasteWorth, balance = bottingStats()
  local balanceDesc, hourDesc = bottingLabels(lootWorth, wasteWorth, balance)

  local a, b, c

  a = "Session Time: " .. sessionTime()
  b = " | Balance: " .. balanceDesc .. " (" .. hourDesc .. ")"
  c = a..b

  return c
end

function wasteHour()
  local _, wasteWorth = bottingStats()
  return hourVal(wasteWorth)
end

function lootHour()
  local lootWorth = bottingStats()
  return hourVal(lootWorth)
end

function avgTable(t)
  if type(t) ~= 'table' then return 0 end
  local val = 0

  for i,v in pairs(t) do
    val = val + v
  end

  if #t == 0 then
    return 0
  else
    return val/#t
  end
end

--bestdps/hps
local bestDPS = 0
local bestHPS = 0
--main loop
macro(500, function()
    refreshLoot()
    refreshWaste()

    local lootWorth, wasteWorth, balance = bottingStats()
    local balanceDesc, hourDesc = bottingLabels(lootWorth, wasteWorth, balance)

    --hunt window
    sessionTimeLabel:setText(sessionTime())
    lootLabel:setText(format_thousand(lootWorth))
    lootLabel:setColor("#15e815")
    suppliesLabel:setText(format_thousand(wasteWorth))
    suppliesLabel:setColor("#ff0404")
    balanceLabel:setColor(balance >= 0 and "#15e815" or "#ff0404")
    balanceLabel:setText(balanceDesc .. " (" .. hourDesc .. ")")

    -- stats
    totalRefills:setText(storage.refill.refills)
    avRefillTime:setText(niceTimeFormat(avgTable(storage.refill.refillTime),true))
    lastRefill:setText(niceTimeFormat(os.difftime(os.time()-storage.refill.lastRefill),true))
end)

-- public functions
-- global namespace
Analyzer = {}
Analyzer.saveRound = function()
    -- update refill stats
    table.insert(storage.refill.refillTime, os.difftime(os.time() - storage.refill.lastRefill))
    storage.refill.lastRefill = os.time()
    storage.refill.refills = storage.refill.refills + 1
end

