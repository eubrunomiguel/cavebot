CaveBot.Extensions.SupplyCheck = {}

CaveBot.Extensions.SupplyCheck.setup = function()
  CaveBot.registerAction("SupplyCheck", "#28f825", function(value)
    local data = string.split(value, ",")
    local label = data[1]:trim()

    if Supplies.hasEnough() then
      modules.game_textmessage.displayGameMessage(
        "[SupplyCheck]: Supplies OK, going to label: " .. label
      )

      return CaveBot.gotoLabel(label)
    end

    modules.game_textmessage.displayGameMessage(
      "[SupplyCheck]: Not enough supplies, proceeding."
    )

    return true
  end)

  CaveBot.Editor.registerAction(
    "supplycheck",
    "supply then",
    {
      value = function()
        return "startHunt"
      end,
      title = "Supply check label",
      description = "Label to go to when supplies are sufficient",
      validation = "^[^,]+$"
    }
  )
end