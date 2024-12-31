if arg == nil or arg[1] == nil then
    print("please specify a hitbox singe file.")
    os.exit(1)
end

dofile(arg[1])  -- this is a hitbox-*.singe file.

hitmapFrame = 1		-- Frame the boxes belong to
hitmapIndex = 2		-- Where in the hitbox array to start looking
hitmapCount = 3		-- How many boxes
hitmapBonus = 4		-- Index for a skull/spitoon bound box (in the powerup array)
hitmapCivStart = 5	-- Index in the civillian array to start looking
hitmapCivCount = 6	-- How many boxes

print("            actions = {");

local identical_frames = 0
local first_frame = -1
local prev = nil
local frameoffset = 0
if (arg ~= nil) and (arg[2] ~= nil) then frameoffset = tonumber(arg[2]) end

for i,v in ipairs(hitmap) do
    local frame = v[hitmapFrame]
    local idx = v[hitmapIndex]
    local count = v[hitmapCount]
    --local bonus = v[hitmapBonus]
    --local civstart = v[hitmapCivStart]
    --local civcount = v[hitmapCivCount]

    if first_frame == -1 then
        first_frame = frame
        identical_frames = 1
        prev = hitmap[i]
    else
        prev = hitmap[i-1]
        local matches = true  -- until proven otherwise!
        if (prev[hitmapFrame] ~= (frame - 1)) or (prev[hitmapCount] ~= count) then
            matches = false
        else
            for j = 1, count do
                --print("idx=" .. tostring(idx) .. "  j=" .. tostring(j))
                local box = hitbox[idx+(j-1)]
                local prevbox = hitbox[prev[hitmapIndex]+(j-1)]
                if (prevbox[1] ~= box[1]) or (prevbox[2] ~= box[2]) or (prevbox[3] ~= box[3]) or (prevbox[4] ~= box[4]) then
                    matches = false
                    break
                end
            end
        end

        if matches then
            identical_frames = identical_frames + 1
        else
            local prevcount = prev[hitmapCount]
            local beststr = ", best=true"
            for j = 1, prevcount do
                local box = hitbox[prev[hitmapIndex]+(j-1)]
                print("                { input=\"action\", from=laserdisc_frame_to_ms(" .. (first_frame-frameoffset) .. "), to=laserdisc_frame_to_ms(" .. ((first_frame+identical_frames)-frameoffset) .. "), area={" .. tostring(box[1]) .. ", " .. tostring(box[2]) .. ", " .. tostring(box[3]) .. ", " .. tostring(box[4]) .. "}, points=badguy_points, nextsequence=nil" .. beststr .." },")
                beststr = ''
            end
            identical_frames = 0
            first_frame = -1
        end
    end
end

if identical_frames > 0 then
    local prevcount = prev[hitmapCount]
    local beststr = ", best=true"
    for j = 1, prevcount do
        local box = hitbox[prev[hitmapIndex]+(j-1)]
        print("                { input=\"action\", from=laserdisc_frame_to_ms(" .. (first_frame-frameoffset) .. "), to=laserdisc_frame_to_ms(" .. ((first_frame+identical_frames)-frameoffset) .. "), area={" .. tostring(box[1]) .. ", " .. tostring(box[2]) .. ", " .. tostring(box[3]) .. ", " .. tostring(box[4]) .. "}, points=badguy_points, nextsequence=nil" .. beststr .." },")
        beststr = '';
    end
end

print("            },");

