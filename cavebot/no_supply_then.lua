CaveBot.Extensions.NoSupplyCheck = {}

CaveBot.Extensions.NoSupplyCheck.setup = function()
  CaveBot.registerAction("NoSupplyCheck", "#db5a5a", function(value)
    local data = string.split(value, ",")
    local label = data[1]:trim()

    -- Check configured supplies
    if not Supplies.hasEnough() then
      modules.game_textmessage.displayGameMessage(
        "[NoSupplyCheck]: Not enough supplies, going to label: "
        .. label
      )

      return CaveBot.gotoLabel(label)
    end

    -- Supplies are OK -> continue with next action
    modules.game_textmessage.displayGameMessage(
      "[NoSupplyCheck]: Supplies OK, proceeding."
    )

    return true
  end)

  CaveBot.Editor.registerAction(
    "nosupplycheck",
    "no supply then",
    {
      value = function()
        return "exitHunt"
      end,
      title = "Supply check label",
      description = "Label to go to when supplies are insufficient",
      validation = [[^[^,]+$]]
    }
  )
end
