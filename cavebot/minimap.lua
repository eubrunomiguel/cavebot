local minimap = modules.game_minimap.minimapWidget

local function parseGotoPos(value)
  if type(value) ~= "string" then return nil end
  local x, y, z = value:match("^%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*$")
  if not x then return nil end
  return {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
end

local function getLastGotoPos()
  local last = nil
  if CaveBot and CaveBot.actionList then
    for _, child in ipairs(CaveBot.actionList:getChildren()) do
      if child.action == "goto" then
        local pos = parseGotoPos(child.value)
        if pos then last = pos end
      end
    end
  end
  return last
end

minimap.onMouseRelease = function(widget,pos,button)
  if not minimap.allowNextRelease then return true end
  minimap.allowNextRelease = false

  local mapPos = minimap:getTilePosition(pos)
  if not mapPos then return end

  if button == 1 then
    local player = g_game.getLocalPlayer()
    if minimap.autowalk then
      player:autoWalk(mapPos)
    end
    return true
  elseif button == 2 then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setId("minimapMenu")
    menu:setGameMenu(true)
    menu:addOption(tr('Create mark'), function() minimap:createFlagWindow(mapPos) end)
    menu:addOption(tr('Add CaveBot GoTo'), function()
      local prevPos = getLastGotoPos()

      CaveBot.addAction("goto", mapPos.x .. "," .. mapPos.y .. "," .. mapPos.z, true)
      CaveBot.save()

      if not prevPos then
        BotInfo.message("Waypoint added.")
        return
      end

      if prevPos.z ~= mapPos.z then
        BotInfo.message("Waypoint added (different floor, distance not measured).")
        return
      end

      local steps = math.max(math.abs(prevPos.x - mapPos.x), math.abs(prevPos.y - mapPos.y))
      local maxDistance = CaveBot.Config.get("maxDistance")

      BotInfo.message("Waypoint added, " .. steps .. " steps from the last waypoint.")

      if steps > maxDistance then
        BotInfo.message("WARNING: Waypoint is " .. steps .. " steps from the last waypoint, exceeding maxDistance (" .. maxDistance .. ").")
      end
    end)
    menu:display(pos)
    return true
  end
  return false
end
