local cavebotMacro = nil
local config = nil

-- ui
local configWidget = UI.Config()
local ui = UI.createWidget("CaveBotPanel")

ui.list = ui.listPanel.list -- shortcut
CaveBot.actionList = ui.list

-- Persistent action position (storage backed) ---------------------------------
-- The focused action is remembered per config file, so that toggling CaveBot
-- on/off (or reloading/restarting the client) resumes at the same action
-- instead of jumping back to the first one.
--
-- Switching to a *different* config, however, resets the position back to the
-- first action (index 0) -- see lastSelectedConfig below.
local actionPositions = storage.cavebotActionPositions
if type(actionPositions) ~= "table" then
  actionPositions = {}
  storage.cavebotActionPositions = actionPositions
end

local lastConfig = ""
local currentActionIndex = nil
local lastPersistedIndex = nil

-- The config that was selected the last time a config was loaded. Used to
-- detect when the user switches to a different config (e.g. a different entry
-- in _configs), in which case we reset the remembered position to 0.
local lastSelectedConfig = storage.cavebotActionLastConfig
if type(lastSelectedConfig) ~= "string" or lastSelectedConfig == "" then
  lastSelectedConfig = nil
end

-- read the index of the currently focused action (nil if there is none)
local function getFocusedActionIndex()
  local focused = ui.list:getFocusedChild()
  if not focused then return nil end
  local index = ui.list:getChildIndex(focused)
  if type(index) ~= "number" or index < 0 then return nil end
  return index
end

-- focus an action by index, returns false if the index is invalid
local function focusActionIndex(index)
  if type(index) ~= "number" then return false end
  local ok, child = pcall(function() return ui.list:getChildByIndex(index) end)
  if not ok or not child then return false end
  ui.list:focusChild(child)
  return true
end

-- remember the position in storage, but only when it actually changed
local function persistActionIndex(index)
  if index == nil or lastConfig == "" then return end
  if index == lastPersistedIndex then return end
  lastPersistedIndex = index
  actionPositions[lastConfig] = index
  storage.cavebotActionPositions = actionPositions
end

if CaveBot.Editor then
  CaveBot.Editor.setup()
end
if CaveBot.Config then
  CaveBot.Config.setup()
end
for extension, callbacks in pairs(CaveBot.Extensions) do
  if callbacks.setup then
    callbacks.setup()
  end
end

-- main loop, controlled by config
local actionRetries = 0
local prevActionResult = true
cavebotMacro = macro(20, function()
  if TargetBot and TargetBot.isActive() and not TargetBot.isCaveBotActionAllowed() then
    CaveBot.resetWalking()
    return -- target bot or looting is working, wait
  end
  
  if CaveBot.doWalking() then
    return -- executing walking
  end
  
  local actions = ui.list:getChildCount()
  if actions == 0 then return end
  local currentAction = ui.list:getFocusedChild()
  if not currentAction then
    currentAction = ui.list:getFirstChild()
  end
  local action = CaveBot.Actions[currentAction.action]  
  local value = currentAction.value
  local retry = false
  if action then
    local status, result = pcall(function()
      CaveBot.resetWalking()
      return action.callback(value, actionRetries, prevActionResult)
    end)
    if status then
      if result == "retry" then
        actionRetries = actionRetries + 1
        retry = true
      elseif type(result) == 'boolean' then
        actionRetries = 0
        prevActionResult = result
      else
        error("Invalid return from cavebot action (" .. currentAction.action .. "), should be \"retry\", false or true, is: " .. tostring(result))
      end
    else
      error("Error while executing cavebot action (" .. currentAction.action .. "):\n" .. result)
    end    
  else
    error("Invalid cavebot action: " .. currentAction.action)
  end
  
  if retry then
    return
  end
  
  if currentAction ~= ui.list:getFocusedChild() then
    -- focused child can change durring action, get it again and reset state
    currentAction = ui.list:getFocusedChild() or ui.list:getFirstChild()
    actionRetries = 0
    prevActionResult = true
  end
  local nextAction = ui.list:getChildIndex(currentAction) + 1
  if nextAction > actions then
    nextAction = 1
  end
  local nextChild = ui.list:getChildByIndex(nextAction)
  if nextChild then
    ui.list:focusChild(nextChild)
    currentActionIndex = nextAction
    persistActionIndex(nextAction)
  end
end)

-- config, its callback is called immediately, data can be nil
config = Config.setup("cavebot_configs", configWidget, "cfg", function(name, enabled, data)
  if enabled and CaveBot.Recorder.isOn() then
    CaveBot.Recorder.disable()
    CaveBot.setOff()
    return    
  end

  -- Switching to a different config should restart from the first action, so
  -- forget the position remembered for the config we are switching to. This is
  -- what makes the selected config in _configs drive a reset to 0, while
  -- on/off toggling and restarting the *same* config still resume.
  if name and name ~= "" and name ~= lastSelectedConfig then
    actionPositions[name] = nil
    lastSelectedConfig = name
    storage.cavebotActionLastConfig = name
  end

  -- remember where the config we are leaving was (before the list is rebuilt),
  -- and figure out where the config we are loading should resume from.
  -- both are kept in storage, so it also survives a reload/restart.
  local prevIndex = getFocusedActionIndex()
  if prevIndex ~= nil and lastConfig ~= "" then
    actionPositions[lastConfig] = prevIndex
    storage.cavebotActionPositions = actionPositions
  end
  local restoreIndex = actionPositions[name]
  if restoreIndex == nil and lastConfig == name then
    restoreIndex = prevIndex
  end

  ui.list:destroyChildren()
  if not data then
    cavebotMacro.setOff()
    currentActionIndex = nil
    lastPersistedIndex = nil
    return
  end
  
  local cavebotConfig = nil
  for k,v in ipairs(data) do
    if type(v) == "table" and #v == 2 then
      if v[1] == "config" then
        local status, result = pcall(function()
          return json.decode(v[2])
        end)
        if not status then
          error("Error while parsing CaveBot extensions from config:\n" .. result)
        else
          cavebotConfig = result
        end
      elseif v[1] == "extensions" then
        local status, result = pcall(function()
          return json.decode(v[2])
        end)
        if not status then
          error("Error while parsing CaveBot extensions from config:\n" .. result)
        else
          for extension, callbacks in pairs(CaveBot.Extensions) do
            if callbacks.onConfigChange then
              callbacks.onConfigChange(name, enabled, result[extension])
            end
          end
        end
      else
        CaveBot.addAction(v[1], v[2])
      end
    end
  end

  CaveBot.Config.onConfigChange(name, enabled, cavebotConfig)
  
  actionRetries = 0
  CaveBot.resetWalking()
  prevActionResult = true
  cavebotMacro.setOn(enabled)
  cavebotMacro.delay = nil

  -- restore the action we were on; if the stored index is gone (e.g. the config
  -- shrank) fall back to the first action
  if restoreIndex == nil or not focusActionIndex(restoreIndex) then
    local first = ui.list:getFirstChild()
    if first then
      ui.list:focusChild(first)
    end
  end
  currentActionIndex = getFocusedActionIndex()
  lastPersistedIndex = currentActionIndex
  lastConfig = name  
end)

-- ui callbacks
ui.showEditor.onClick = function()
  if not CaveBot.Editor then return end
  if ui.showEditor:isOn() then
    CaveBot.Editor.hide()
    ui.showEditor:setOn(false)
  else
    CaveBot.Editor.show()
    ui.showEditor:setOn(true)
  end
end

ui.showConfig.onClick = function()
  if not CaveBot.Config then return end
  if ui.showConfig:isOn() then
    CaveBot.Config.hide()
    ui.showConfig:setOn(false)
  else
    CaveBot.Config.show()
    ui.showConfig:setOn(true)
  end
end

ui.showSupply.onClick = function()
  if not CaveBot.SuppliesWindow then return end
  if ui.showSupply:isOn() then
    CaveBot.SuppliesWindow:setVisible(false)
    ui.showSupply:setOn(false)
  else
    CaveBot.SuppliesWindow:setVisible(true)
    ui.showSupply:setOn(true)
  end
end

-- public function, you can use them in your scripts
CaveBot.isOn = function()
  return config.isOn()
end

CaveBot.isOff = function()
  return config.isOff()
end

CaveBot.setOn = function(val)
  if val == false then  
    return CaveBot.setOff(true)
  end
  config.setOn()
end

CaveBot.setOff = function(val)
  if val == false then  
    return CaveBot.setOn(true)
  end
  config.setOff()
end

CaveBot.delay = function(value)
  cavebotMacro.delay = math.max(cavebotMacro.delay or 0, now + value)
end

CaveBot.gotoLabel = function(label)
  label = label:lower()
  for index, child in ipairs(ui.list:getChildren()) do
    if child.action == "label" and child.value:lower() == label then    
      ui.list:focusChild(child)
      return true
    end
  end
  return false
end

CaveBot.save = function()
  local data = {}
  for index, child in ipairs(ui.list:getChildren()) do
    table.insert(data, {child.action, child.value})
  end
  
  if CaveBot.Config then
    table.insert(data, {"config", json.encode(CaveBot.Config.save())})
  end
  
  local extension_data = {}
  for extension, callbacks in pairs(CaveBot.Extensions) do
    if callbacks.onSave then
      local ext_data = callbacks.onSave()
      if type(ext_data) == "table" then
        extension_data[extension] = ext_data
      end
    end
  end
  table.insert(data, {"extensions", json.encode(extension_data, 2)})
  config.save(data)
end

-- F12 hotkey: toggle BOTH CaveBot and TargetBot on/off together. ------------
-- Always active, no configuration option and no storage dependency: F12 is
-- bound unconditionally. Turning on happens only when both are off; otherwise
-- the press turns both off. Every toggle is reported through BotInfo.message.
local function toggleCaveBotAndTargetBotHotkey()
  local targetOn = TargetBot and TargetBot.isOn and TargetBot.isOn() or false
  local turningOn = not (CaveBot.isOn() or targetOn)

  if turningOn then
    CaveBot.setOn()
    if TargetBot and TargetBot.setOn then
      TargetBot.setOn()
    end
    BotInfo.message("[CaveBot & TargetBot]: ON")
  else
    CaveBot.setOff()
    if TargetBot and TargetBot.setOff then
      TargetBot.setOff()
    end
    BotInfo.message("[CaveBot & TargetBot]: OFF")
  end
end

-- bind unconditionally (idempotent: rebinding after a reload is fine)
g_keyboard.bindKeyDown('F12', toggleCaveBotAndTargetBotHotkey)

-- Kept for backwards compatibility with any existing callers, but the hotkey
-- can no longer be disabled: it always toggles both bots.
CaveBot.setHotkeyEnabled = function(enabled)
  -- no-op on purpose; F12 is always bound above
  storage.cavebotHotkey = true
end

CaveBot.isHotkeyEnabled = function()
  return true
end

local sellContainer = UI.Container(function(widget, items)
  storage.cavebotSell = items
end, true, nil, ui.sellExceptions)
sellContainer:setHeight(70)
sellContainer:setItems(storage.cavebotSell)

macro(500, "Emergency Escape", function() 
  if Supplies.hasEmergency() and TargetBot.isOn() then
    BotInfo.message("[Supplies]: Too little supply, turning off target bot")
    TargetBot.setOff()
  end
end)
