-- Globals
MAX_SCORES = 10
players = {}
map = Cvar.get('mapname')
layout = Cvar.get('layout')
highscore_cvar = 'oc_' .. map .. layout .. '_highscores'
if Cvar.get(highscore_cvar) == '' then
    Cvar.set(highscore_cvar, '')
    Cvar.archive(highscore_cvar)
end

function ClientName(ent)
    if ent == nil or ent.client == nil then
        return "<not client>"
    end
    return ent.client.name
end

function Say(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'print ' .. '"^2OC^*: ' .. txt .. '"')
end

function CP(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function SayCP(ent, txt)
    CP(ent, txt)
    Say(ent, txt)
end

function Putteam(ent, team)
    if ent == nil or ent.client == nil then
        return
    end
    Cmd.exec('delay 1f putteam ' .. ent.number .. ' ' .. team)
end

function LockAliens()
    Cmd.exec('lock a')
end

function SameEnt(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.number == b.number
end

function WelcomeClient(ent, connect)
    if not connect then
        return
    end
    txt = 'Welcome to the Unvanquished Obstacle course server!'
    CP(ent, txt)
end

function HandleTeamChange(ent, team)
    if team == "alien" then
        Putteam(ent, "human")
    end
    if team == "spectator" then
        players[ent.client.guid] = nil
        return
    end
    players[ent.client.guid] = { ["checkpoint"] = nil, ["start"] = sgame.level.time }
end

function HandlePlayerSpawn(ent)
    if ent.team ~= "human" then
        return
    end
    p = players[ent.client.guid]
    if p == nil then
        return
    end
    checkpoint = p["checkpoint"]
    if checkpoint == nil then
        return
    end
    pt = checkpoint.origin
    pt[3] = pt[3] + 100
    ent.client:teleport(pt)
end

function ParseArgs(m)
    local args = {}
    local idx
    local oldIdx = 1
    while true do
        idx = m:find(' ', oldIdx)
        if idx == nil then
            table.insert(args, m:sub(oldIdx))
            return args
        end
        table.insert(args, m:sub(oldIdx, idx))
        oldIdx = idx
    end
end

function ExecChatCommand(ent, team, message)
    if message:sub(1, 1) == '!' then
        local idx = message:find(' ')
        local c = message:sub(2)
        if idx ~= nil then
            c = message:sub(2, idx)
        end
        local cmd = COMMANDS[c]
        if cmd ~= nil then
            Timer.add(1, function() cmd(ent) end)
        end
    end
end

function PrintHelp(ent)
    Say(ent, [=[Welcome to the Obstacle Course mod!
Touch the RC to win!
List of commands: !help !time !highscores']=])
end

function HumanTime(time)
    s = math.floor(time / 1000.0)
    ms = time % 1000
    m = math.floor(s / 60)
    sr = s % 60
    h = math.floor(m / 60)
    mr = m % 60
    t = ''
    if h > 0 then
        t = t .. h .. ' hours '
    end
    if mr > 0 then
        t = t .. mr .. ' minutes '
    end
    if sr > 0 then
        t = t .. sr .. ' seconds'
    end
    return t
end

function PrintTime(ent)
    if ent == nil or ent.client == nil then
        return
    end
    p = players[ent.client.guid]
    if p == nil then
        Say(ent, 'Clock not started')
        return nil
    end
    diff = sgame.level.time - p["start"]
    Say(ent, 'Time Elapsed: ' .. HumanTime(diff))
end

function PrintHighScores(ent)
    if ent == nil or ent.client == nil then
        return
    end
    local s = ''
    local highscores = Cvar.get(highscore_cvar)
    local t = ParseHighScores(highscores)
    if #t == 0 then
        Say(ent, 'No high scores!')
        return
    end
    for i, score in ipairs(t) do
        s = s .. '#' .. i .. ': ' .. score.name .. ' — ' .. HumanTime(score.time) .. '\n'
    end
    Say(ent, s)
end

COMMANDS = {
    ["help"]=PrintHelp,
    ["time"]=PrintTime,
    ["highscores"]=PrintHighScores,
}



function SaveCheckpoint(self, caller, activator)
    if caller == nil or caller.client == nil then
        return
    end
    p = players[caller.client.guid]
    if p == nil then
        return
    end
    p["checkpoint"] = self
end

function mb(v)
    if v == nil then
        return ''
    end
    return v
end

function ParseHighScores(m)
    local args = {}
    local idx
    local oldIdx = 1
    while true do
        idx = m:find('\\\\', oldIdx)
        if idx == nil or oldIdx == idx then
            s = m:sub(oldIdx)
            if #s == 0 then
                break
            end
            table.insert(args, s)
            break
        end
        table.insert(args, m:sub(oldIdx, idx-1))
        oldIdx = idx + 2
    end
    local t = {}
    for i = 1, #args, 2 do

        table.insert(t, {name=args[i], time=tonumber(args[i+1])})
    end
    return t
end

function SerializeHighScores(t)
    local s = ''
    for _, p in ipairs(t) do
        s = s .. p.name .. '\\\\' .. p.time .. '\\\\'
    end
    return s
end

function Victory(self, caller, activator)
    if caller == nil or caller.client == nil then
        return
    end
    p = players[caller.client.guid]
    if p == nil then
        return
    end
    diff = sgame.level.time - p["start"]
    SayCP(nil, ClientName(caller) .. ' finished the level in: ' .. HumanTime(diff))
    local highscores = Cvar.get(highscore_cvar)
    local t = ParseHighScores(highscores)
    if #t == 0 then
        table.insert(t, {name=ClientName(caller), time=diff})
    else
        if t[#t].time > diff or #t < MAX_SCORES then
            local insert = false
            for i, v in ipairs(t) do
                if v.time > diff then
                    table.insert(t, i, {name=ClientName(caller), time=diff})
                    insert = true
                    break
                end
            end
            if not insert and #t < MAX_SCORES then
                table.insert(t, {name=ClientName(caller), time=diff})
            end
            if #t > MAX_SCORES then
                t[#t] = nil
            end
        end

    end
    Cvar.set(highscore_cvar, s)
    Cvar.archive(highscore_cvar)
    p["checkpoint"] = nil
    p["start"] = sgame.level.time
    caller.client:kill()
end

function init()
    sgame.hooks.RegisterClientConnectHook(WelcomeClient)
    sgame.hooks.RegisterTeamChangeHook(HandleTeamChange)
    sgame.hooks.RegisterChatHook(ExecChatCommand)
    sgame.hooks.RegisterPlayerSpawnHook(HandlePlayerSpawn)
    local cps = { Entity.iterate_classname('team_human_medistat') }
    for _, e in ipairs(cps) do
        e.touch = SaveCheckpoint
    end
    local rc = Entity.iterate_classname('team_human_reactor')
    rc.touch = Victory

    LockAliens()
    print('Loaded lua...')
end

init()
