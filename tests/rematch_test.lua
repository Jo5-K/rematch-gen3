local root = assert(arg[1])
local hooks, events, saved = {}, {}, {}
local state, calls, talked, flags = nil, 0, 0, true
local game = {}
local session = {map='ROUTE'}
local task, printed, choose, locked
local running = false
local vm = {isRunning=function() return running end}
local row = {op='trainerbattle',type=0,trainer=12}
local modules = {
 ['src.core.GameVersion']={get=function() return 'emerald' end},
 ['src.core.game3.runtime']={getSession=function() return session end},
 ['src.core.game3.field']={_game=game,
  addFrameTask=function(fn) task=fn end,
  lock=function() locked=true end, unlock=function() locked=false end},
 ['src.ui.game3.message']={isOpen=function() return printed ~= nil end,
  show=function(text,cb) assert(text=='Rematch?'); printed=cb end,
  close=function() printed=nil end},
 ['src.ui.game3.choice']={isOpen=function() return choose ~= nil end,
  yesNo=function(cb) choose=cb end},
 ['src.core.game3.scripting.space']={store={},bundle={scripts={npc={row}}}},
 ['src.core.game3.scripting.flags']={isTrainerDefeated=function() return flags end},
 ['src.core.game3.scripting.trainers']={foeFromId=function() return {party={{level=5}}} end},
 ['src.core.game3.battle']={isActive=function() return false end,getState=function() return state end},
 ['src.core.game3.battle.prize']={calc=function() return 101 end,calcRse=function() return 201 end},
}
local opts
modules['src.core.game3.battle_bridge']={start=function(_,_,_,o)
 calls=calls+1; opts=o; state={}
 events['battle.started']({kind='trainer',trainerId=o.trainerId,battle=state})
 return true
end}
for key, value in pairs(modules) do package.loaded[key]=value end
local mod = {
 hooks={wrap=function(_,key,fn) hooks[key]=fn end},
 events={on=function(_,key,fn) events[key]=fn end},
 storage={read=function(_,g,key) return saved[key] end, write=function(_,g,key,v) saved[key]=v end},
}
local install=assert(loadfile(root..'/main.lua'))()
install(mod)
local function command()
 return hooks['script.command'](function() talked=talked+1 end,{runner=vm},'trainerbattle',row)
end
local function answer(yes)
 local cb=choose; choose=nil; cb(yes)
end
local function talk()
 task=nil; command()
 if task then
  assert(task()==true and printed and locked)
  printed(); assert(choose and calls>=0)
  answer(true)
  return true
 end
end
local function xp() return hooks['exp.gain'](function() return 101 end,{battle=state,isTrainer=true}) end
local prize=modules['src.core.game3.battle.prize']
assert(prize.calc()==101)
flags=false; talk(); assert(calls==0 and talked==1)
flags=true
command(); running=true
assert(task()==false and printed==nil and calls==0)
running=false; assert(task()==true and printed and locked)
printed(); assert(calls==0 and choose)
answer(false); assert(calls==0 and not locked and printed==nil)
assert(talk()==true and calls==1)
assert(xp()==50 and prize.calc()==50 and prize.calcRse()==100)
opts.done('win'); state={}; assert(prize.calc()==101 and xp()==101)
local rows=hooks['ui.options.rows'](function(_,r) return r end,game,{})
local byid={}; for _,r in ipairs(rows) do byid[r.id]=r end
assert(#rows==7)
for _=1,100 do byid.rematch_xp.step(game,1); byid.rematch_money.step(game,1) end
assert(saved.config.xp==80 and saved.config.money==80)
talk(); assert(xp()==80 and prize.calc()==80); opts.done('win')
for _=1,100 do byid.rematch_xp.step(game,-1); byid.rematch_money.step(game,-1) end
talk(); assert(xp()==0 and prize.calc()==0); opts.done('win')
state={}; saved.config.enabled=false; local before=calls; talk(); assert(calls==before)
saved.config.enabled=true; row.eventScript='story'; talk(); assert(calls==before)
row.eventScript=nil; row.type=1; talk(); assert(calls==before)
row.type=4; saved.config.doubles=false; talk(); assert(calls==before)
row.type=0; saved.config.limit=1; talk(); assert(calls==before)
saved.config.limit=0; saved.config.cooldown=50; talk(); assert(calls==before)
for _=1,50 do events['world.stepped']() end
talk(); assert(calls==before+1); opts.done('lose')
state={}; saved.config.cooldown=0; install(mod); talk()
saved.config.money=80 -- running battles use the configuration snapshot from start
assert(prize.calc()==0) -- no double wrapping after reload
opts.done('win'); talk(); assert(prize.calc()==80)
-- Reproduce BOTH actual Petalburg Woods trainer commands from the imported game.
local realScripts=assert(loadfile(root..'/tests/fixtures/petalburg_woods.lua'))()
opts.done('win'); state={}; saved.config.limit=0; saved.config.cooldown=0
for _, key in ipairs({'g3:0822e26d','g3:0822e284'}) do
 row=realScripts[key][1]
 assert(row.trainer==616 or row.trainer==621)
 local oldCalls=calls
 command(); assert(task and calls==oldCalls)
 assert(task()==true and printed)
 printed(); assert(calls==oldCalls and choose)
 answer(false); assert(calls==oldCalls and not locked)
 command(); assert(task()==true); printed(); answer(true)
 assert(calls==oldCalls+1)
 opts.done('win'); state={}
end
print('PASS: imported Petalburg Woods NPCs 616 and 621, PokéNav continuation, dialogue completion, yes/no confirmation and cancellation, first battles, 0/50/80%, bounds, story exclusions, doubles, limits, cooldown, reload')
