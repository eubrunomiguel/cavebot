-- Skull values reported by creature:getSkull()
local SkullWhite = 3
local SkullRed = 4
local SkullBlack = 5

TargetBot.Creature.attack = function(params, targets, isLooting) -- params {config, creature, danger, priority}
  if player:isWalking() then
    lastWalk = now
  end

  local config = params.config
  local creature = params.creature
  
  if g_game.getAttackingCreature() ~= creature then
    g_game.attack(creature)
  end

  if not isLooting then -- walk only when not looting
    TargetBot.Creature.walk(creature, config, targets)
  end

  -- attacks
  local mana = player:getMana()

  -- 1. Group attack spell has the highest priority.
  local groupAttackConfigured = config.useGroupAttack and config.groupAttackSpell:len() > 1
  local canAffordGroupAttack = mana > config.minManaGroup

  if groupAttackConfigured then
    local pos = player:getPosition()

    -- Count monsters within the configured attack radius
    local creatures = g_map.getSpectatorsInRange(
      pos,
      false,
      config.groupAttackRadius,
      config.groupAttackRadius
    )

    local monsters = 0

    for _, creature in ipairs(creatures) do
      if creature:isMonster() then
        monsters = monsters + 1
      end
    end

    -- Do not use group attack if ANY other player is nearby
    local playerAround = false

    local nearbyCreatures = g_map.getSpectatorsInRange(
      pos,
      false,
      4,
      4
    )

    for _, creature in ipairs(nearbyCreatures) do
      if not creature:isLocalPlayer() and creature:isPlayer() then
        -- Ignore players we are allowed to hit: white, red or black skull.
        local skull = creature:getSkull()
        local isAttackableSkull = skull == SkullWhite or skull == SkullRed or skull == SkullBlack
        if not isAttackableSkull then
        playerAround = true
        break
        end
      end
    end

    -- The group attack is the right spell here only when there are enough
    -- monsters and no other player is nearby.
    if monsters >= config.groupAttackTargets and not playerAround then
      -- We cannot afford the group attack: conserve mana instead of spending it
      -- on the single-target spell. This is the ONLY case where we hold back --
      -- mana being the specific blocker for the group attack.
      if not canAffordGroupAttack then
        return
      end

      if TargetBot.sayAttackSpell(
          config.groupAttackSpell,
          config.groupAttackDelay
        ) then
        return
      end
    end
  end

  -- 2. Single-target attack spell.
  --    If the group attack was skipped for a reason other than mana (not enough
  --    targets, a player nearby, or it is simply not configured), we fall through
  --    and the single-target spell is still allowed.
  if config.useSpellAttack
      and config.attackSpell:len() > 1
      and mana > config.minMana
      and g_game.getAttackingCreature()
      and g_game.getAttackingCreature():isMonster() then

    if TargetBot.sayAttackSpell(
        config.attackSpell,
        config.attackSpellDelay
      ) then
      return
    end
  end
end

TargetBot.Creature.walk = function(creature, config, targets)
  local cpos = creature:getPosition()
  local pos = player:getPosition()
  
  local isTrapped = true
  local pos = player:getPosition()
  local dirs = {{-1,1}, {0,1}, {1,1}, {-1, 0}, {1, 0}, {-1, -1}, {0, -1}, {1, -1}}
  for i=1,#dirs do
    local tile = g_map.getTile({x=pos.x-dirs[i][1],y=pos.y-dirs[i][2],z=pos.z})
    if tile and tile:isWalkable(false) then
      isTrapped = false
    end
  end
  
  -- luring
  if TargetBot.canLure() and (config.lure or config.lureCavebot) and not (config.chase and creature:getHealthPercent() < 30) and not isTrapped then
    local monsters = 0
    if targets < config.lureCount then
      if config.lureCavebot then
        return TargetBot.allowCaveBot(200)
      else
        local path = findPath(pos, cpos, 5, {ignoreNonPathable=true, precision=2})
        if path then
          return TargetBot.walkTo(cpos, 10, {marginMin=5, marginMax=6, ignoreNonPathable=true})
        end
      end
    end
  end

  storage.isChasing = false
  local currentDistance = findPath(pos, cpos, 10, {ignoreCreatures=true, ignoreNonPathable=true, ignoreCost=true})
  if config.chase and (creature:getHealthPercent() < 30 or not config.keepDistance) then
    if #currentDistance > 1 then
      storage.isChasing = true
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, precision=1})
    end
  elseif config.keepDistance then
    if #currentDistance ~= config.keepDistanceRange and #currentDistance ~= config.keepDistanceRange + 1 then
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, marginMin=config.keepDistanceRange, marginMax=config.keepDistanceRange + 1})
    end
  end

  if config.avoidAttacks then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if math.abs(diffx) == 1 and diffy == 0 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x, y=pos.y+1, z=pos.z}}
    elseif diffx == 0 and math.abs(diffy) == 1 then
      candidates = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}}
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tile and tile:isWalkable() then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable=true})
      end
    end
  end
end
