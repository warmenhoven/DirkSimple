#!/usr/bin/lua

if arg == nil or arg[1] == nil then
    print("please specify a hitbox singe file.")
    os.exit(1)
end

dofile(arg[1])  -- this is a hitbox-*.singe file.

local hitmapFrame = 1		-- Frame the boxes belong to
local hitmapIndex = 2		-- Where in the hitbox array to start looking
local hitmapCount = 3		-- How many boxes
local hitmapBonus = 4		-- Index for a skull/spitoon bound box (in the powerup array)
local hitmapCivStart = 5	-- Index in the civillian array to start looking
local hitmapCivCount = 6	-- How many boxes

local actions = {}

local frameoffset = 0
if (arg ~= nil) and (arg[2] ~= nil) then frameoffset = tonumber(arg[2]) end

for i,v in ipairs(hitmap) do
    local frame = v[hitmapFrame]
    local idx = v[hitmapIndex]
    local count = v[hitmapCount]
    local bonus = v[hitmapBonus]
    local civstart = v[hitmapCivStart]
    local civcount = v[hitmapCivCount]
    local pointsstr = nil
    local hitbox_table = nil
    local isbadguy = false

--[[
    if civstart ~= 0 then  -- civilian and good guys
        hitbox_table = powerup
        pointsstr = "goodguy_points"
        idx = civstart
        count = civcount
    elseif bonus ~= 0 then  -- skull/spittoon hitbox
        hitbox_table = hitbox
        pointsstr = "spittoon_points"
        idx = bonus
    else  -- bad guys
]]--
        isbadguy = true
        hitbox_table = hitbox
        pointsstr = "badguy_points"
--    end

    --print(frame .. "  " .. count .. "  " .. pointsstr)

    local best = isbadguy
    for j = 1, count do
        local box = hitbox_table[idx+(j-1)]
        if (box ~= nil) then
            actions[#actions+1] = { from=(frame-frameoffset), to=((frame+1)-frameoffset), area={box[1],box[2],box[3],box[4]}, points=pointsstr, best=best }
            best = false
        end
    end
end

local function cmpactions2(a, b)
    if (a.from < b.from) then return false end
    if (a.from > b.from) then return true end
    return false
end

local function cmpactions1(a, b)
    local aarea = a.area
    local barea = b.area
    if (aarea[1] < barea[1]) then return false end
    if (aarea[1] > barea[1]) then return true end
    if (aarea[2] < barea[2]) then return false end
    if (aarea[2] > barea[2]) then return true end
    if (aarea[3] < barea[3]) then return false end
    if (aarea[3] > barea[3]) then return true end
    if (aarea[4] < barea[4]) then return false end
    if (aarea[4] > barea[4]) then return true end
    return cmpactions2(a, b)
end

local function bubble_sort(a, cmp)
    local n = #a
    repeat
        local newn = 0
        for i = 2,n,1 do
            if cmp(a[i - 1], a[i]) then
                local tmp = a[i]
                a[i] = a[i-1]
                a[i-1] = tmp
                newn = i
            end
        end
        n = newn
    until n <= 2
end

bubble_sort(actions, cmpactions1)

local newactions = { actions[1] }
for i=2,#actions,1 do
    local prev = actions[i-1]
    local cur = actions[i]
    local dumpit = false
    if (prev.area[1] == cur.area[1]) and (prev.area[2] == cur.area[2]) and (prev.area[3] == cur.area[3]) and (prev.area[4] == cur.area[4]) then
        if (prev.to == cur.from) or (prev.to == (cur.from-1)) then
            dumpit = true
        end
    end

    if not dumpit then
        newactions[#newactions+1] = cur
    else
        newactions[#newactions].to = cur.from
    end
end

bubble_sort(newactions, cmpactions2)

print("            actions = {");
for i,v in ipairs(newactions) do
    local beststr = ''
    if v.best then beststr = ', best=true' end
    print('                { input="action", from=laserdisc_frame_to_ms(' .. v.from .. '), to=laserdisc_frame_to_ms(' .. v.to .. '), area={' .. v.area[1] .. ', ' .. v.area[2].. ', ' .. v.area[3].. ', ' .. v.area[4] .. '}, points=' .. v.points .. ', nextsequence=nil' .. beststr .. ' },')
end
print("            },");

