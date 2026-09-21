# AGENTS.md

Repository-specific knowledge for an AI developer working on **CaveBot 1.3**
(running inside OTClientV8 / vBot). Read this before touching anything.

---

## 1. Project Overview

- Language: Lua, executed as a bot module inside OTClientV8/vBot.
- Purpose: a CaveBot with waypoint/action programming plus a companion
  TargetBot (auto-attack + looting).
- This is **not** a generic OTCv8/vBot codebase. Many helpers (macro, Config,
  UI, g_game, g_map, storage) come from the host client, but the architecture
  and conventions below are specific to this repository.

## 2. Main Entry Points

- `cavebot.lua` (repo root) — the actual loader:
  - sets default tabs `Cave` / `Target`
  - creates namespaces `CaveBot = {}`, `CaveBot.Extensions = {}`, `TargetBot = {}`
  - `importStyle(...)` + `dofile(...)` in a fixed order
  - This load order matters (see "Conventions").
- `cavebot/cavebot.lua` — CaveBot runtime:
  - builds `CaveBotPanel`, wires Editor/Config/Extensions
  - contains the 20 ms `cavebotMacro` that walks the action list
  - defines public API: `isOn/isOff/setOn/setOff`, `delay`, `gotoLabel`,
    `save`, `resetWalking`, `doWalking`
- `targetbot/target.lua` — TargetBot runtime:
  - builds `TargetBotPanel`, wires Looting/editor
  - contains the 100 ms `targetbotMacro`
  - defines public API: `isActive`, `isCaveBotActionAllowed`, `allowCaveBot`,
    `setOn/setOff`, `saySpell/sayAttackSpell`, `useItem/useAttackItem`,
    `canLure`, `setStatus`
- `main.lua` — only sets `VERSION = "1.3"` and shows a label. **It is not a
  loader.** The real loader is the root `cavebot.lua`.
- `tools.lua`, `hp.lua`, `mwall_timer.lua` — additional tabs/features that
  share the same global environment (`macro`, `storage`, `UI.*`, `say`, ...).

## 3. CaveBot Architecture

Three layers:

1. **Control / model** — `cavebot/cavebot.lua`.
   The action list widget `CaveBot.actionList` is the serialized program.
   Each child carries `.action` (string) and `.value` (string).
   The macro evaluates exactly one focused child per tick.
2. **Registries** — `cavebot/actions.lua` and `cavebot/editor.lua`.
   - `CaveBot.registerAction(name, color, callback)` → runtime handlers.
   - `CaveBot.Editor.registerAction(name, title, params)` → editor dialog.
3. **Extensions** — `CaveBot.Extensions.<Name>` packages under
   `cavebot/*.lua` (depositer, buy_supplies, sell_all, supply_then,
   no_supply_then, target_set). See the lifecycle below.

Extension lifecycle:
- `setup()`                — build UI, `registerAction`, `Editor.registerAction`
- `onConfigChange(name, enabled, data)` — rehydrate UI from saved data
- `onSave()`               — return a table to persist (or nil)
- optional `run(retries, prev)` — helper callable from `function` waypoints

## 4. Actions, Movement, Waypoints, Callbacks, Macros, Timers, Events

**Actions**
- Built-in actions registered in `cavebot/actions.lua`:
  `label`, `gotolabel`, `delay`, `function`, `goto`, `use`, `usewith`, `say`.
- Action callbacks receive `(value, retries, prev)` and must return one of:
  - `true`  → advance to next action (retries reset)
  - `false` → treat as failure / abandon
  - `"retry"` → re-run the same action in ~20 ms (retries increments)
- Invalid return values raise a hard error from the macro.

**Movement / Waypoints**
- Central movement helper: `CaveBot.walkTo(dest, maxDist, params)` in
  `cavebot/walking.lua`. Two modes controlled by `CaveBot.Config.get("mapClick")`:
  - step-by-step via `g_game.walk` with `expectedDirs` verification
  - `autoWalk` via map click
- Waypoint `goto` handling lives in `cavebot/actions.lua`
  (stairs detection via minimap color, precision fallback, `skipBlocked`).
- The Recorder (`cavebot/recorder.lua`) emits `goto` actions from position
  changes (>5 tiles or floor change) and `use`/`usewith` from game events.
- Minimap right-click menu (`cavebot/minimap.lua`) can insert a `goto` via
  `CaveBot.addAction("goto", ...)` then `CaveBot.save()`.

**Macros / Timers**
- System macro API is `macro(intervalMs, name, callback)` (name optional).
  Each macro exposes `:setOn(bool)`, `:isOn()`, `:setOff()`, and a mutable
  `.delay` field (absolute timestamp).
- A macro "delay" = `macro.delay = now + value`. `CaveBot.delay` and
  `TargetBot.delay` follow this pattern; do not invent your own sleep.
- `schedule(ms, fn)` is used for short asynchronous UI work, most notably
  the `schedule(20, ...)` trick to focus widgets before opening dialogs.

**Events** (OTClientV8)
- Observed across the repo: `onPlayerPositionChange`, `onUse`, `onUseWith`,
  `onTextMessage`, `onContainerOpen`, `onCreatureDisappear`,
  `onAddThing`, `onRemoveThing`.
- Prefer existing event hooks and existing polling patterns over new loops.

## 5. Configuration and Storage

There are **three distinct persistence layers**. Do not conflate them.

1. **Program** — `cavebot_configs/*.cfg`
   - Line-oriented action list, one action per line:
     - `function:[[ ...lua... ]]`
     - `label:NAME`
     - `goto:x,y,z`
     - `config:{...json...}`    (keys must match `cavebot/config.lua`)
     - `extensions:[[ ...json... ]]`
   - Loaded by `cavebot/cavebot.lua` via the `Config.setup(...)` callback.
   - The `function:` blocks frequently act as a **boot script**: they assign
     values into `storage.*` (e.g. `storage.manaId`, `storage.hpId`).
2. **Policy** — `targetbot_configs/*.json`
   - `targeting[]` matches the fields produced by `creature_editor.lua`.
   - `looting` matches `TargetBot.Looting.save/update`.
3. **State** — `storage` (persisted as `storage.json` / `storage/profile_1.json`).
   - Runtime state: macro on/off (`_macros`), selected configs (`_configs`),
     healing/haste/anti-paralyze settings, food, dropItems, autoEquip,
     `cavebotSell`, `SuppliesConfig`, ingame editor buffers, etc.

Configuring CaveBot options:
- `cavebot/config.lua` exposes `CaveBot.Config.add/get/save/onConfigChange`.
- Default keys: `ping`, `walkDelay`, `mapClick`, `mapClickDelay`,
  `ignoreFields`, `skipBlocked`, `useDelay`, `talkDelay`, `npcSellDelay`.
- `CaveBot.Config.save()` is embedded inside `CaveBot.save()`.

Supplies:
- `cavebot/supplies.lua` is a facade: `Supplies.getItemsData`,
  `hasEnough`, `hasEmergency`, `getConfig`, `setConfig`, `addSupplyItem`.
- It performs backward-compat migration (`convertOldConfig`) from the legacy
  `item1..item6` shape into `items = { [id] = {min, max, emerg} }`.
- `CaveBot.Extensions.BuySupplies` delegates to `Supplies.getConfig/setConfig`.

## 6. TargetBot Interaction

- CaveBot pauses movement while TargetBot is doing work:
  `if TargetBot.isActive() and not TargetBot.isCaveBotActionAllowed() then ... end`
  at the top of the CaveBot macro.
- TargetBot grants the CaveBot temporary time windows via
  `TargetBot.allowCaveBot(ms)` (used by luring).
- CaveBot toggles TargetBot through `cavebot/target_set.lua` actions
  `TargetOn` / `TargetOff` (which call `TargetBot.setOn()/setOff()`).
- The "Emergency Escape" macro in `cavebot/cavebot.lua` calls
  `TargetBot.setOff()` when `Supplies.hasEmergency()` is true.
- **Critical shared-spell rule**: healing/haste/anti-paralyze code in
  `hp.lua` must use `TargetBot.saySpell(...)` / `TargetBot.useItem(...)`
  instead of `say(...)` / `g_game.useInventoryItemWith(...)`, so that the
  TargetBot's global spell/rune cooldowns (`lastSpell`, `lastAttackSpell`,
  `lastItemUse`, `lastRuneAttack`) are respected.
- The creature target list (`TargetBot.targetList`) is the same widget as
  `ui.list` in `targetbot/target.otui` — it is both UI and data model.

## 7. Important Reusable Helpers / APIs

Prefer these over re-implementing.

CaveBot core:
- `CaveBot.registerAction`, `CaveBot.Editor.registerAction`
- `CaveBot.addAction` / `CaveBot.editAction`
- `CaveBot.gotoLabel`, `CaveBot.delay`, `CaveBot.save`
- `CaveBot.Config.get`

Movement / NPC / Depot (from `cavebot/cavebot_lib.lua`):
- `CaveBot.MatchPosition`, `CaveBot.GoTo`, `CaveBot.walkTo`
- `CaveBot.ReachNPC`, `CaveBot.Conversation`, `CaveBot.OpenNpcTrade`,
  `CaveBot.Travel`
- `CaveBot.ReachDepot`, `CaveBot.OpenLocker`, `CaveBot.OpenDepotChest`,
  `CaveBot.OpenInbox`, `CaveBot.ReachAndOpenDepot`, `CaveBot.OpenDepotBox`,
  `CaveBot.WithdrawItem`, `CaveBot.StashItem`
- `CaveBot.GetLootItems`, `CaveBot.GetLootContainers`

Supplies:
- `Supplies.hasEnough`, `Supplies.hasEmergency`, `Supplies.getItemsData`,
  `Supplies.addSupplyItem`, `Supplies.getConfig/setConfig`

TargetBot:
- `TargetBot.isOn/isOff/setOn/setOff`, `TargetBot.isActive`,
  `TargetBot.isCaveBotActionAllowed`, `TargetBot.allowCaveBot`
- `TargetBot.canLure`, `TargetBot.disableLuring`, `TargetBot.enableLuring`
- `TargetBot.saySpell`, `TargetBot.sayAttackSpell`,
  `TargetBot.useItem`, `TargetBot.useAttackItem`
- `TargetBot.setStatus`, `TargetBot.save`

UI idioms:
- `UI.createWidget`, `UI.Container`, `UI.DualScrollPanel`,
  `UI.DualScrollItemPanel`, `UI.Config`, `UI.EditorWindow`
- `schedule(20, fn)` to obtain correct focus before opening an editor.

## 8. Project-Specific Conventions

- **UI is the model.** Action lists, creature lists, supply rows and loot
  item lists are edited in-place and then serialized by reading the widget
  tree (`getChildren()`, `:getText()`, `:getItemId()`, ...). Do not create a
  parallel data model.
- **Pair actions with editor entries.** Every new runtime action should have
  a matching `CaveBot.Editor.registerAction` (see `extension_template.lua`).
- **Persist via `onSave` / `onConfigChange`.** Do not write directly to
  `storage` for extension-config-sized data; use the lifecycle.
- **Return contract.** Action callbacks return `true` / `false` / `"retry"`.
  Anything else throws.
- **Timing.** Use `CaveBot.delay` / `TargetBot.delay`; `schedule` is for UI.
- **NPC dialog.** Use `CaveBot.Conversation` / `CaveBot.OpenNpcTrade` and
  the `schedule + delay + return "retry"` pattern seen in the configs.
- **`function:` waypoints** are the normal escape hatch for logic that does
  not fit the action vocabulary. Inside them, extensions are available as
  bare names (e.g. `Depositer.run(...)`), plus `retries`, `prev`, `delay`,
  `gotoLabel`. `macro` is deliberately disabled inside them.

## 9. Things to Avoid / Do Not Assume

- **Do not change the `dofile` order in the root `cavebot.lua`.**
  Modules rely on `CaveBot`, `CaveBot.Actions`, `CaveBot.Editor`,
  `TargetBot.targetList`, `storage`, and `CaveBot.SuppliesWindow` already
  existing at load time.
- **Do not modify the `.otui` widget IDs** used from Lua. Examples that are
  referenced by name and would break if renamed:
  - `cavebot/cavebot.otui`: `list`, `showEditor`, `showConfig`, `showSupply`,
    `sellExceptions`
  - `cavebot/editor.otui`: `pos`, `buttons`, `autoRecording`
  - `cavebot/supplies.otui`: `items`, `min`, `max`, `emerg`, `id`, `closeButton`
  - `targetbot/target.otui`: `status.left/right`, `target.left/right`,
    `config.left/right`, `danger.left/right`, `listPanel.list`,
    `listScrollbar`, `configButton`, `editor`, `editor.buttons.add/edit/remove`,
    `editor.debug`
- **Do not bypass the TargetBot spell/item cooldowns.** In healing/haste/
  anti-paralyze code, always go through `TargetBot.saySpell` / `useItem`.
- **Do not invent new config keys silently.** `cavebot/config.lua` defaults
  must stay in sync with the `config:{...}` blobs found in existing
  `cavebot_configs/*.cfg` files.
- **Do not edit `.cfg`, `.json`, or `.otui` files as part of routine Lua
  changes** unless the request explicitly targets them. Most behavior is
  driven by Lua + UI, and the serialized files are produced by the bot
  itself.
- **Do not add per-file documentation to `AGENTS.md` that duplicates large
  source snippets.** Keep it as orientation, not as a copy of the code.
- **Do not assume this is upstream OTCv8/vBot.** Many idioms here (three-way
  storage, `function:` waypoints, extension lifecycle, the TargetBot ↔ CaveBot
  handshake, `schedule(20, ...)` focus trick) are repository-specific.
- **Do not assume `main.lua` loads anything.** The loader is the root
  `cavebot.lua`.

## 10. Quick Mental Model

The bot is an event-augmented, list-driven state machine on three axes:

1. **Macro axis** — `macro(ms, name, fn)` drives all polling loops.
   CaveBot (20 ms) and TargetBot (100 ms) are just two of them; Tools/HP/
   mwall features run alongside.
2. **CaveBot axis** — `CaveBot.actionList` is the program.
   Each entry maps to a registered callback; progress = moving focus;
   `gotoLabel` = moving focus to a label widget.
3. **TargetBot axis** — its own 100 ms macro selects the highest-priority
   creature config per tick, fights (attack/group/rune + chase/keepDistance/
   lure) and loots (containers + smart-loot keywords, danger/capacity limits).
   It temporarily pauses the CaveBot (`isActive` / `isCaveBotActionAllowed`)
   or grants it windows (`allowCaveBot`).

Persistence is split into **Program** (`.cfg`), **Policy** (`.json`) and
**State** (`storage`). The UI is the single source of truth for what gets
saved, which is why most logic revolves around `UI.createWidget`,
`getChildren()` and `onDoubleClick`.
