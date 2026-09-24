setDefaultTab("Cave")

local SuppliesConfig = {}

if not SuppliesConfig then
  SuppliesConfig = {
    items = {}
  }
end

local config = SuppliesConfig


-- Convert old item1/item2/etc. config to the new format
local function convertOldConfig(config)
  if type(config) ~= "table" then
    return { items = {} }
  end

  if config.items then
    return config
  end

  local newConfig = {
    items = {}
  }

  local items = {
    config.item1,
    config.item2,
    config.item3,
    config.item4,
    config.item5,
    config.item6
  }

  local mins = {
    config.item1Min,
    config.item2Min,
    config.item3Min,
    config.item4Min,
    config.item5Min,
    config.item6Min
  }

  local maxes = {
    config.item1Max,
    config.item2Max,
    config.item3Max,
    config.item4Max,
    config.item5Max,
    config.item6Max
  }

  local emergs = {
    config.item1Emerg,
    config.item2Emerg,
    config.item3Emerg,
    config.item4Emerg,
    config.item5Emerg,
    config.item6Emerg
  }

  for i, item in ipairs(items) do
    if item and item > 100 then
      newConfig.items[tostring(item)] = {
        min = mins[i] or 0,
        max = maxes[i] or 0,
        emerg = emergs[i] or 0
      }
    end
  end

  return newConfig
end


-- Convert existing config
SuppliesConfig = convertOldConfig(SuppliesConfig)
config = SuppliesConfig


function getEmptyItemPanels()
  local panel = CaveBot.SuppliesWindow.items
  local count = 0

  for i, child in ipairs(panel:getChildren()) do
    count = child:getId() == "blank" and count + 1 or count
  end

  return count
end


function deleteFirstEmptyPanel()
  local panel = CaveBot.SuppliesWindow.items

  for i, child in ipairs(panel:getChildren()) do
    if child:getId() == "blank" then
      child:destroy()
      break
    end
  end
end


function clearEmptyPanels()
  local panel = CaveBot.SuppliesWindow.items

  if panel:getChildCount() > 1 then
    if getEmptyItemPanels() > 1 then
      deleteFirstEmptyPanel()
    end
  end
end


function addItemPanel()
  local parent = CaveBot.SuppliesWindow.items
  local panel = UI.createWidget("ItemPanel", parent)

  local item = panel.id

  panel:setId("blank")
  item:setShowCount(false)

  panel.onItemChange = function(widget)
    local id = widget:getItemId()
    local panelId = panel:getId()

    -- Empty item
    if id < 100 then
      config.items[panelId] = nil
      panel:setId("blank")
      clearEmptyPanels()
      return
    end

    -- Item ID was not changed
    if tonumber(panelId) == id then
      return
    end

    -- Check if item is already added
    if config.items[tostring(id)] then
      warn("vBot[Drop Tracker]: Item already added!")
      widget:setItemId(0)
      return
    end

    -- Add new item
    config.items[tostring(id)] = {
      min = 0,
      max = 0,
      emerg = 0
    }

    panel:setId(id)

    -- Always keep an empty panel at the end
    addItemPanel()
  end

  return panel
end

-- Load settings
local function loadSettings()
  CaveBot.SuppliesWindow.items:destroyChildren()

  local itemList = {}

  -- Load saved items
  for id, data in pairs(config.items) do
    table.insert(itemList, {
      id = id,
      min = data.min or 0,
      max = data.max or 0,
      emerg = data.emerg or 0
    })
  end

  -- Always create exactly 6 rows
  for i = 1, 6 do
    local widget = addItemPanel()
    local data = itemList[i]

    if data then
      widget:setId(data.id)
      widget.id:setItemId(tonumber(data.id))
      widget.min:setText(data.min)
      widget.max:setText(data.max)
      widget.emerg:setText(data.emerg)
    end
  end
end

loadSettings()


-- Save settings
CaveBot.SuppliesWindow.onVisibilityChange = function(widget, visible)
  if not visible then
    config.items = {}

    local parent = CaveBot.SuppliesWindow.items

    for i, panel in ipairs(parent:getChildren()) do
      if panel.id:getItemId() > 100 then
        local id = tostring(panel.id:getItemId())
        local min = panel.min:getValue()
        local max = panel.max:getValue()
        local emerg = panel.emerg:getValue()

        config.items[id] = {
          min = min,
          max = max,
          emerg = emerg
        }
      end
    end

    CaveBot.save()
  end
end


Supplies = {}


Supplies.show = function()
  CaveBot.SuppliesWindow:show()
  CaveBot.SuppliesWindow:raise()
  CaveBot.SuppliesWindow:focus()
end


Supplies.getItemsData = function()
  local t = {}

  for i, panel in ipairs(CaveBot.SuppliesWindow.items:getChildren()) do
    if panel.id:getItemId() > 100 then
      local id = tostring(panel.id:getItemId())

      t[id] = {
        min = panel.min:getValue(),
        max = panel.max:getValue(),
        emerg = panel.emerg:getValue()
      }
    end
  end

  return t
end


Supplies.isSupplyItem = function(id)
  local data = Supplies.getItemsData()
  id = tostring(id)

  if data[id] then
    return data[id]
  end

  return false
end

Supplies.hasEnough = function()
  local data = Supplies.getItemsData()

  for id, values in pairs(data) do
    id = tonumber(id)

    local current = player:getItemsCount(id) or 0

    if current < values.min then
      return false
    end
  end

  return true
end

Supplies.hasEmergency = function()
  local data = Supplies.getItemsData()

  for id, values in pairs(data) do
    id = tonumber(id)

    local current = player:getItemsCount(id) or 0

    if current < values.emerg then
      return true
    end
  end

  return false
end

Supplies.addSupplyItem = function(id, min, max, emerg)
  if not id then
    return
  end

  -- Don't add duplicates
  if config.items[tostring(id)] then
    return
  end

  local widget = addItemPanel()

  widget:setId(id)
  widget.id:setItemId(tonumber(id))
  widget.min:setText(min or 0)
  widget.max:setText(max or 0)
  widget.emerg:setText(emerg or 0)
end


Supplies.getFullData = function()
  return {
    items = Supplies.getItemsData()
  }
end


Supplies.getConfig = function()
  return SuppliesConfig
end


Supplies.setConfig = function(data)
  if not data then
    return
  end

  SuppliesConfig = data

  SuppliesConfig = convertOldConfig(SuppliesConfig)

  config = SuppliesConfig

  loadSettings()
end
