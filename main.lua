-- main tab
VERSION = "1.3"

UI.Label("Config version: " .. VERSION)
UI.Separator()

-- F12 toggles CaveBot and TargetBot on/off together. This is fixed and has no
-- configuration option; the binding itself is owned by cavebot_main.lua.
UI.Label("F12 toggles CaveBot & TargetBot")
