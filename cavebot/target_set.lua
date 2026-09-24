CaveBot.Extensions.TargetOn = {}

CaveBot.Extensions.TargetOn.setup = function()
  CaveBot.registerAction("TargetOn", "#28f825", function()
    if not TargetBot.isOn() then
      BotInfo.message("[Target]: Enabling targeting.")
      TargetBot.setOn()
    end
    return true
  end)

  CaveBot.Editor.registerAction(
    "targeton",
    "target on",
    {
      value = function()
        return "empty"
      end,
      title = "Target on",
      description = "Enable targeting",
    }
  )
end

CaveBot.Extensions.TargetOff = {}

CaveBot.Extensions.TargetOff.setup = function()
  CaveBot.registerAction("TargetOff", "#ff5500", function()
    if TargetBot.isOn() then
      BotInfo.message("[Target]: Disabling targeting.")
      TargetBot.setOff()
    end
    return true
  end)

  CaveBot.Editor.registerAction(
    "targetoff",
    "target off",
    {
      value = function()
        return "empty"
      end,
      title = "Target off",
      description = "Disable targeting",
    }
  )
end
