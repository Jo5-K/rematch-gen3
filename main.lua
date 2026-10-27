-- Standalone mod. No engine files or other mods are written.
return function(mod)
  local version = require('src.core.GameVersion').get()
  if not ({firered=true,leafgreen=true,ruby=true,sapphire=true,emerald=true})[version] then return end
  local Space = require('src.core.game3.scripting.space')
  local Flags = require('src.core.game3.scripting.flags')
  local Trainers = require('src.core.game3.scripting.trainers')
  local Bridge = require('src.core.game3.battle_bridge')
  local Battle = require('src.core.game3.battle')
  local Prize = require('src.core.game3.battle.prize')
  local defaults = {enabled=true, xp=50, money=50, doubles=true, cooldown=0, limit=0}
  local pending

  local function bounded(value, fallback, maximum)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(0, math.min(maximum, math.floor(value)))
  end
  local function data(game)
    local value = mod.storage:read(game, 'config')
    if type(value) ~= 'table' then value = {} end
    for key, fallback in pairs(defaults) do
      if type(fallback) == 'boolean' then
        if type(value[key]) ~= 'boolean' then value[key] = fallback end
      else value[key] = bounded(value[key], fallback, key == 'cooldown' and 1000 or key == 'limit' and 20 or 80) end
    end
    return value
  end
  local function history(game)
    local value = mod.storage:read(game, 'history')
    if type(value) ~= 'table' then value = {} end
    value.steps = bounded(value.steps, 0, 2147483647)
    if type(value.trainers) ~= 'table' then value.trainers = {} end
    return value
  end

  -- The engine has no money reward hook. Wrap only the in-memory calculation,
  -- once across mod reloads, and only for battle states tagged by this mod.
  -- Native payouts, caps and Amulet Coin remain in the normal reward pipeline.
  if not Prize._rematchGen3Wrapped then
    Prize._rematchGen3Wrapped = true
    for _, key in ipairs({'calc', 'calcRse'}) do
      local original = Prize[key]
      Prize[key] = function(...)
        local amount = original(...)
        local state = Battle.getState()
        local tag = state and state._rematchGen3
        if tag then return math.floor(amount * tag.money / 100) end
        return amount
      end
    end
  end

  mod.hooks:wrap('exp.gain', function(next, ctx)
    local amount = next(ctx)
    local tag = ctx.battle and ctx.battle._rematchGen3
    if not tag or not ctx.isTrainer then return amount end
    return math.floor(amount * tag.xp / 100)
  end)

  mod.events:on('battle.started', function(ctx)
    if pending and ctx.kind == 'trainer' and ctx.trainerId == pending.id then
      ctx.battle._rematchGen3 = {xp=pending.config.xp, money=pending.config.money}
    end
  end)
  mod.events:on('world.stepped', function()
    local game = require('src.core.game3.field')._game
    if not game then return end
    local h = history(game)
    h.steps = h.steps + 1
    mod.storage:write(game, 'history', h)
  end)

  -- Observe the trainer command actually executed by the VM. NPC scripts
  -- may call another script, so scanning only the NPC's first list misses them.
  mod.hooks:wrap('script.command', function(next, ctx, op, row)
    if op ~= 'trainerbattle' or pending then return next(ctx, op, row) end
    local Field = require('src.core.game3.field')
    local Runtime = require('src.core.game3.runtime')
    local Message = require('src.ui.game3.message')
    local Choice = require('src.ui.game3.choice')
    local game = Field._game
    if not game then return next(ctx, op, row) end
    local config = data(game)
    local function trace(stage, detail)
      mod.storage:write(game, 'diagnostic', {
        version='0.1.2', stage=stage, detail=detail,
        trainer=tonumber(row.trainer or row[1]), type=tonumber(row.type) or 0,
      })
    end
    trace('trainer_command')
    local kind = tonumber(row.type) or 0
    local id = tonumber(row.trainer or row[1])
    -- Types 2/6 are ordinary RSE trainers with a PokéNav registration
    -- continuation. We let the normal script finish and never replay it.
    local eligible = kind == 0 or kind == 4
      or ((version == 'emerald' or version == 'ruby' or version == 'sapphire')
        and (kind == 2 or kind == 6))
    if not config.enabled or not id or not eligible
        or ((kind == 0 or kind == 4) and row.eventScript) or not Flags.isTrainerDefeated(Space.store, nil, id) then
      return next(ctx, op, row)
    end
    local foe = Trainers.foeFromId(id)
    if not foe then return next(ctx, op, row) end
    local double = kind == 4 or kind == 6 or foe.doubleBattle
    if double and not config.doubles then return next(ctx, op, row) end
    local h = history(game)
    local previous = h.trainers[tostring(id)] or {count=0}
    if config.limit > 0 and (tonumber(previous.count) or 0) >= config.limit then return next(ctx, op, row) end
    if previous.step and h.steps - previous.step < config.cooldown then return next(ctx, op, row) end
    local session = Runtime.getSession()
    local map = session and session.map
    local request = {id=id, config=config}
    pending = request
    local function clear()
      Field.unlock(request)
      if pending == request then pending = nil end
    end
    local function current()
      return Field._game == game and Runtime.getSession() == session
        and session and session.map == map
    end
    -- Let the original beaten-trainer dialogue finish, including all calls
    -- and message closing. Never clear flags or replay the story script.
    local result = next(ctx, op, row)
    trace('waiting_for_dialogue')
    local function afterDialogue()
      if pending ~= request or not current() then clear(); return true end
      local vm = ctx.runner or ctx.vm or Space.vm
      if (vm and vm:isRunning()) or Message.isOpen() or Choice.isOpen()
          or Battle.isActive() then return false end
      Field.lock(request)
      trace('question_shown')
      Message.show('Rematch?', function()
        if not current() then Message.close(); clear(); return end
        Choice.yesNo(function(yes)
          Message.close()
          if not yes or not current() then trace('declined_or_cancelled'); clear(); return end
          trace('accepted')
          -- Release only our menu lock; the battle bridge owns its own locks.
          Field.unlock(request)
          local started = Bridge.start(mod, game, foe, {
            trainerId=id, double=double,
            cancel=clear, failed=clear,
            done=function(outcome)
              clear()
              if outcome == 'win' then
                local currentHistory = history(game)
                local old = currentHistory.trainers[tostring(id)] or {count=0}
                currentHistory.trainers[tostring(id)] = {
                  count=(tonumber(old.count) or 0)+1, step=currentHistory.steps,
                }
                mod.storage:write(game, 'history', currentHistory)
              end
            end,
          })
          if not started then trace('battle_not_started'); clear() end
        end)
        Choice.options = {'SIM', 'NAO'}
        Choice.cursor = 2 -- no battle starts without an explicit confirmation
      end)
      return true
    end
    Field.addFrameTask(function()
      local ok, done = pcall(afterDialogue)
      if not ok then trace('error', tostring(done)); clear(); return true end
      return done
    end)
    return result
  end)

  mod.hooks:wrap('ui.options.rows', function(next, game, rows)
    rows = next(game, rows)
    rows[#rows+1] = {id='rematch_heading', label='REMATCH GEN3', group=true}
    local function option(key, label, step, maximum)
      rows[#rows+1] = {
        id='rematch_'..key, label=label,
        value=function(g)
          local value = data(g)[key]
          if type(value) == 'boolean' then return value and 'SIM' or 'NAO' end
          if key == 'xp' or key == 'money' then return tostring(value)..'%' end
          if value == 0 then return key == 'limit' and 'SEM LIMITE' or 'SEM ESPERA' end
          return tostring(value)
        end,
        step=function(g, direction)
          local config = data(g)
          if type(config[key]) == 'boolean' then config[key] = not config[key]
          else config[key] = bounded(config[key] + direction * step, defaults[key], maximum) end
          mod.storage:write(g, 'config', config)
        end,
      }
    end
    option('enabled', 'Ativar revanche')
    option('xp', 'XP recebido', 1, 80)
    option('money', 'Dinheiro recebido', 1, 80)
    option('doubles', 'Permitir duplas')
    option('cooldown', 'Espera em passos', 50, 1000)
    option('limit', 'Vitorias por treinador', 1, 20)
    return rows
  end)
end
