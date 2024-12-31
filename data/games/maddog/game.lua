-- DirkSimple; a dirt-simple player for FMV games.
--
-- Please see the file LICENSE.txt in the source's root directory.
--
--  This file written by Ryan C. Gordon.
--
-- Laserdisc (rather, DVD) frame offsets taken from Singe's maddog-hd module (thank you!).
--

DirkSimple.gametitle = "Mad Dog McCree"

-- CVARS
local starting_lives = 3
local infinite_lives = false  -- set to true to not lose a life on failure.
local god_mode = false  -- if true, game plays correct moves automatically, so you never fail.
local skip_tutorial = false  -- if true, game skips tutorial scene and goes straight to the actual game at start.
local skip_undertaker = false  -- if true, game skips undertaker scenes and uses a simple "lives left" transition screen instead.
local show_hitboxes = false  -- if true, draw a rectangle around where you can shoot something.
local show_crosshairs = true -- if false, don't draw the crosshairs (useful if you have a real lightgun instead of a mouse).
local reload_on_action2 = false -- if true, right mouse clicks will reload; the Sinden Lightgun sends a right click when pointing offscreen and firing.
local infinite_bullets = false -- if true, firing the gun doesn't cost a bullet, so you never need to reload.

DirkSimple.cvars = {
    { name="starting_lives", desc="Number of lives player starts with", values="5|4|3|2|1", setter=function(name, value) starting_lives = DirkSimple.to_int(value) end },
    { name="infinite_lives", desc="Don't lose a life when failing", values="false|true", setter=function(name, value) infinite_lives = DirkSimple.to_bool(value) end },
    { name="god_mode", desc="Game plays itself perfectly, never failing", values="false|true", setter=function(name, value) god_mode = DirkSimple.to_bool(value) end },
    { name="skip_tutorial", desc="Skip tutorial at game start", values="false|true", setter=function(name, value) skip_tutorial = DirkSimple.to_bool(value) end },
    { name="skip_undertaker", desc="Skip undertaker scenes", values="false|true", setter=function(name, value) skip_undertaker = DirkSimple.to_bool(value) end },
    { name="show_hitboxes", desc="Show hitboxes", values="false|true", setter=function(name, value) show_hitboxes = DirkSimple.to_bool(value) end },
    { name="show_crosshairs", desc="Show crosshairs (turn off for real lightguns)", values="true|false", setter=function(name, value) show_crosshairs = DirkSimple.to_bool(value) end },
    { name="reload_on_action2", desc="Reload with right mouse click (turn on for Sinden lightgun, etc)", values="false|true", setter=function(name, value) reload_on_action2 = DirkSimple.to_bool(value) end },
    { name="infinite_bullets", desc="Shooting the gun doesn't cost a bullet, so no reloads needed", values="false|true", setter=function(name, value) infinite_bullets = DirkSimple.to_bool(value) end },
}

-- SOME INITIAL SETUP STUFF
local scenes = nil  -- gets set up later in the file.
local test_scene_name = nil  -- set to name of scene to test. nil otherwise!
--test_scene_name = "lives_left"

-- GAME STATE
local current_ticks = 0
local current_inputs = nil
local accepted_input = nil
local scene_manager = { initialized=false }

-- will be set when ticking.
local xscale = nil
local yscale = nil

-- scoring
local bottle_points = 50
local badguy_points = 100
local headshot_bonus_points = 25

local function time_laserdisc_noseek()
    return -1
end

local function laserdisc_frame_to_ms(frame)
    return ((frame / 29.970) * 1000.0)
end

local function time_to_ms(seconds, ms)
    return (seconds * 1000) + ms
end

local fonttable = {
    ["font-score-14"] = {
        ["0"] = { x=17, y=49, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["1"] = { x=81, y=81, w=4, h=14, x0=6, y0=-14, advance=16 },
        ["2"] = { x=49, y=65, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["3"] = { x=33, y=65, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["4"] = { x=65, y=81, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["5"] = { x=49, y=49, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["6"] = { x=65, y=49, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["7"] = { x=81, y=49, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["8"] = { x=1, y=51, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["9"] = { x=17, y=65, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["!"] = { x=97, y=1, w=2, h=14, x0=6, y0=-14, advance=16 },
        ["."] = { x=97, y=33, w=2, h=2, x0=6, y0=-2, advance=16 },
        ["A"] = { x=33, y=49, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["B"] = { x=81, y=65, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["C"] = { x=1, y=67, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["D"] = { x=17, y=81, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["E"] = { x=33, y=81, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["F"] = { x=49, y=81, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["G"] = { x=65, y=65, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["H"] = { x=65, y=17, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["I"] = { x=97, y=17, w=2, h=14, x0=6, y0=-14, advance=16 },
        ["J"] = { x=17, y=1, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["K"] = { x=33, y=1, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["L"] = { x=49, y=1, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["M"] = { x=65, y=1, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["N"] = { x=81, y=1, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["O"] = { x=17, y=17, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["P"] = { x=33, y=17, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["Q"] = { x=1, y=1, w=14, h=16, x0=0, y0=-14, advance=16 },
        ["R"] = { x=49, y=17, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["S"] = { x=81, y=17, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["T"] = { x=1, y=19, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["U"] = { x=17, y=33, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["V"] = { x=33, y=33, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["W"] = { x=49, y=33, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["X"] = { x=65, y=33, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["Y"] = { x=81, y=33, w=14, h=14, x0=0, y0=-14, advance=16 },
        ["Z"] = { x=1, y=35, w=14, h=14, x0=0, y0=-14, advance=16 },
        [" "] = { x=97, y=37, w=0, h=0, x0=0, y0=0, advance=16 },
    },
    ["font-score-42"] = {
        ["0"] = { x=46, y=136, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["1"] = { x=271, y=1, w=13, h=43, x0=18, y0=-43, advance=48.888889 },
        ["2"] = { x=136, y=181, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["3"] = { x=91, y=181, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["4"] = { x=181, y=226, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["5"] = { x=136, y=136, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["6"] = { x=181, y=136, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["7"] = { x=226, y=136, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["8"] = { x=1, y=143, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["9"] = { x=46, y=181, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["!"] = { x=286, y=1, w=7, h=43, x0=18, y0=-43, advance=48.888889 },
        ["."] = { x=280, y=46, w=7, h=7, x0=18, y0=-7, advance=48.888889 },
        ["A"] = { x=91, y=136, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["B"] = { x=226, y=181, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["C"] = { x=1, y=188, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["D"] = { x=46, y=226, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["E"] = { x=91, y=226, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["F"] = { x=136, y=226, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["G"] = { x=181, y=181, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["H"] = { x=181, y=46, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["I"] = { x=271, y=46, w=7, h=43, x0=18, y0=-43, advance=48.888889 },
        ["J"] = { x=46, y=1, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["K"] = { x=91, y=1, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["L"] = { x=136, y=1, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["M"] = { x=181, y=1, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["N"] = { x=226, y=1, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["O"] = { x=46, y=46, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["P"] = { x=91, y=46, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["Q"] = { x=1, y=1, w=43, h=50, x0=0, y0=-43, advance=48.888889 },
        ["R"] = { x=136, y=46, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["S"] = { x=226, y=46, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["T"] = { x=1, y=53, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["U"] = { x=46, y=91, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["V"] = { x=91, y=91, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["W"] = { x=136, y=91, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["X"] = { x=181, y=91, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["Y"] = { x=226, y=91, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        ["Z"] = { x=1, y=98, w=43, h=43, x0=0, y0=-43, advance=48.888889 },
        [" "] = { x=295, y=1, w=0, h=0, x0=0, y0=0, advance=48.888889 },
    },
    ["font-gambler-72"] = {
        ["0"] = { x=26, y=208, w=18, h=67, x0=7, y0=-66, advance=32.128754 },
        ["1"] = { x=63, y=208, w=14, h=67, x0=9, y0=-66, advance=32.128754 },
        ["2"] = { x=219, y=139, w=24, h=67, x0=4, y0=-66, advance=32.128754 },
        ["3"] = { x=128, y=70, w=28, h=67, x0=2, y0=-66, advance=32.128754 },
        ["4"] = { x=194, y=208, w=23, h=66, x0=5, y0=-65, advance=32.128754 },
        ["5"] = { x=158, y=70, w=28, h=67, x0=2, y0=-66, advance=32.128754 },
        ["6"] = { x=1, y=139, w=26, h=67, x0=3, y0=-66, advance=32.128754 },
        ["7"] = { x=98, y=70, w=28, h=67, x0=2, y0=-66, advance=32.128754 },
        ["8"] = { x=168, y=208, w=24, h=66, x0=4, y0=-65, advance=32.128754 },
        ["9"] = { x=139, y=139, w=25, h=67, x0=4, y0=-66, advance=32.128754 },
        ["!"] = { x=46, y=208, w=15, h=67, x0=0, y0=-66, advance=20.712446 },
        ["."] = { x=219, y=208, w=17, h=16, x0=0, y0=-15, advance=22.669527 },
        ["A"] = { x=1, y=70, w=32, h=67, x0=1, y0=-66, advance=39.141628 },
        ["B"] = { x=217, y=70, w=27, h=67, x0=0, y0=-66, advance=33.759655 },
        ["C"] = { x=1, y=208, w=23, h=67, x0=0, y0=-66, advance=29.274677 },
        ["D"] = { x=246, y=70, w=27, h=67, x0=0, y0=-66, advance=33.515022 },
        ["E"] = { x=166, y=139, w=25, h=67, x0=0, y0=-66, advance=30.660944 },
        ["F"] = { x=85, y=139, w=25, h=67, x0=0, y0=-66, advance=27.236052 },
        ["G"] = { x=29, y=139, w=26, h=67, x0=0, y0=-66, advance=32.618027 },
        ["H"] = { x=68, y=70, w=28, h=67, x0=0, y0=-66, advance=34.330471 },
        ["I"] = { x=79, y=208, w=12, h=67, x0=0, y0=-66, advance=18.347639 },
        ["J"] = { x=245, y=139, w=24, h=67, x0=0, y0=-66, advance=27.317596 },
        ["K"] = { x=253, y=1, w=32, h=67, x0=0, y0=-66, advance=33.515022 },
        ["L"] = { x=112, y=139, w=25, h=67, x0=0, y0=-66, advance=25.931330 },
        ["M"] = { x=53, y=1, w=45, h=67, x0=0, y0=-66, advance=47.459225 },
        ["N"] = { x=182, y=1, w=34, h=67, x0=0, y0=-66, advance=36.939915 },
        ["O"] = { x=275, y=70, w=24, h=67, x0=0, y0=-66, advance=29.356222 },
        ["P"] = { x=57, y=139, w=26, h=67, x0=0, y0=-66, advance=32.454933 },
        ["Q"] = { x=218, y=1, w=33, h=67, x0=0, y0=-66, advance=38.978539 },
        ["R"] = { x=35, y=70, w=31, h=67, x0=0, y0=-66, advance=37.266094 },
        ["S"] = { x=271, y=139, w=24, h=67, x0=-1, y0=-66, advance=27.236052 },
        ["T"] = { x=188, y=70, w=27, h=67, x0=0, y0=-66, advance=29.356222 },
        ["U"] = { x=141, y=1, w=39, h=67, x0=0, y0=-66, advance=34.738197 },
        ["V"] = { x=134, y=208, w=32, h=66, x0=0, y0=-65, advance=33.351929 },
        ["W"] = { x=1, y=1, w=50, h=67, x0=0, y0=-66, advance=52.107296 },
        ["X"] = { x=100, y=1, w=39, h=67, x0=-1, y0=-66, advance=43.545063 },
        ["Y"] = { x=93, y=208, w=39, h=66, x0=0, y0=-65, advance=42.892704 },
        ["Z"] = { x=193, y=139, w=24, h=67, x0=0, y0=-66, advance=26.175964 },
        [" "] = { x=297, y=139, w=0, h=0, x0=0, y0=0, advance=16.798283 },
    },
    ["font-gambler-144"] = {
        ["0"] = { x=537, y=407, w=37, h=132, x0=14, y0=-131, advance=64.595703 },
        ["1"] = { x=483, y=407, w=26, h=133, x0=19, y0=-132, advance=64.595703 },
        ["2"] = { x=307, y=407, w=47, h=133, x0=9, y0=-132, advance=64.595703 },
        ["3"] = { x=335, y=272, w=56, h=133, x0=4, y0=-132, advance=64.595703 },
        ["4"] = { x=404, y=407, w=45, h=133, x0=10, y0=-131, advance=64.595703 },
        ["5"] = { x=393, y=272, w=55, h=133, x0=5, y0=-132, advance=64.595703 },
        ["6"] = { x=513, y=1, w=50, h=134, x0=7, y0=-132, advance=64.595703 },
        ["7"] = { x=450, y=272, w=55, h=133, x0=5, y0=-132, advance=64.595703 },
        ["8"] = { x=356, y=407, w=46, h=133, x0=9, y0=-131, advance=64.595703 },
        ["9"] = { x=104, y=407, w=49, h=133, x0=8, y0=-132, advance=64.595703 },
        ["!"] = { x=451, y=407, w=30, h=133, x0=1, y0=-132, advance=41.642918 },
        ["."] = { x=1, y=408, w=33, h=30, x0=0, y0=-29, advance=45.577679 },
        ["A"] = { x=488, y=137, w=63, h=133, x0=3, y0=-132, advance=78.695274 },
        ["B"] = { x=349, y=1, w=54, h=134, x0=0, y0=-133, advance=67.874672 },
        ["C"] = { x=99, y=137, w=46, h=134, x0=0, y0=-133, advance=58.857510 },
        ["D"] = { x=293, y=1, w=54, h=134, x0=0, y0=-133, advance=67.382828 },
        ["E"] = { x=155, y=407, w=49, h=133, x0=0, y0=-132, advance=61.644634 },
        ["F"] = { x=53, y=273, w=49, h=133, x0=0, y0=-132, advance=54.758797 },
        ["G"] = { x=405, y=1, w=52, h=134, x0=0, y0=-133, advance=65.579399 },
        ["H"] = { x=277, y=272, w=56, h=133, x0=0, y0=-132, advance=69.022316 },
        ["I"] = { x=511, y=407, w=24, h=133, x0=0, y0=-132, advance=36.888409 },
        ["J"] = { x=206, y=407, w=49, h=133, x0=0, y0=-132, advance=54.922745 },
        ["K"] = { x=212, y=272, w=63, h=133, x0=0, y0=-132, advance=67.382828 },
        ["L"] = { x=1, y=273, w=50, h=133, x0=0, y0=-132, advance=52.135620 },
        ["M"] = { x=249, y=137, w=89, h=133, x0=0, y0=-132, advance=95.418022 },
        ["N"] = { x=418, y=137, w=68, h=133, x0=0, y0=-132, advance=74.268669 },
        ["O"] = { x=50, y=137, w=47, h=134, x0=0, y0=-133, advance=59.021458 },
        ["P"] = { x=459, y=1, w=52, h=134, x0=0, y0=-133, advance=65.251503 },
        ["Q"] = { x=160, y=1, w=67, h=134, x0=0, y0=-133, advance=78.367378 },
        ["R"] = { x=229, y=1, w=62, h=134, x0=0, y0=-133, advance=74.924461 },
        ["S"] = { x=1, y=137, w=47, h=134, x0=-1, y0=-133, advance=54.758797 },
        ["T"] = { x=507, y=272, w=53, h=133, x0=0, y0=-132, advance=59.021458 },
        ["U"] = { x=1, y=1, w=78, h=134, x0=0, y0=-133, advance=69.842056 },
        ["V"] = { x=147, y=272, w=63, h=133, x0=0, y0=-131, advance=67.054932 },
        ["W"] = { x=147, y=137, w=100, h=133, x0=0, y0=-132, advance=104.763084 },
        ["X"] = { x=81, y=1, w=77, h=134, x0=-1, y0=-132, advance=87.548492 },
        ["Y"] = { x=340, y=137, w=76, h=133, x0=1, y0=-131, advance=86.236908 },
        ["Z"] = { x=257, y=407, w=48, h=133, x0=0, y0=-132, advance=52.627464 },
        [" "] = { x=36, y=408, w=0, h=0, x0=0, y0=0, advance=33.773388 },
    }

}

local function draw_text(font, str, x, y, modr, modg, modb)
    local metrics = fonttable[font]
    if modr == nil then modr = 255 end
    if modg == nil then modg = 255 end
    if modb == nil then modb = 255 end

    for i = 1, #str do
        local ch = str:sub(i,i)
        local glyph = metrics[ch]
        if glyph == nil then
            glyph = metric["!"]
        end
        if ch ~= ' ' then  -- don't draw space chars.
            local sw = glyph.w
            local sh = glyph.h
            local sx = glyph.x
            local sy = glyph.y
            local dx = (x + glyph.x0) * xscale
            local dy = (y + glyph.y0) * yscale
            local dw = sw * xscale
            local dh = sh * yscale
            --DirkSimple.log("draw_sprite(" .. sx .. ", " .. sy .. ", " .. sw .. ", " .. sh .. ", " .. dx .. ", " .. dy .. ", " .. dw .. ", " .. dh .. ")")
            DirkSimple.draw_sprite(font, sx, sy, sw, sh, dx, dy, dw, dh, modr, modg, modb)
        end
        x = x + glyph.advance  -- we don't have kerning here, but that's probably okay.
    end
end

-- this function is for the red numbers that are separate glyphs per image, not in a font atlas.
local function draw_number(num, maxdigits, dx, dy, glyphscale)
    glyphscale = glyphscale or 2 -- looks better doubled in size
    local sw = 13
    local sh = 29
    local dw = sw * xscale * glyphscale
    local dh = sh * yscale * glyphscale

    local digits = {}
    while num > 0 do
        digits[#digits + 1] = DirkSimple.to_int(num % 10)
        num = DirkSimple.to_int(num / 10)
    end

    if #digits > maxdigits then   -- just max it out at 99999, or whatever.
        for i = 1, maxdigits do
            DirkSimple.draw_sprite("num9", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
            dx = dx + dw
        end
    else
        for i = 1, maxdigits - #digits do  -- pad out with zeroes.
            DirkSimple.draw_sprite("num0", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
            dx = dx + dw
        end
        for i = #digits, 1, -1 do
            DirkSimple.draw_sprite("num" .. digits[i], 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
            dx = dx + dw
        end
    end
end

local function draw_hitboxes()
    local actions = scene_manager.current_sequence.actions
    if actions ~= nil then
        local rect_xscale = (1440.0 / 360.0) * xscale
        local rect_yscale = (1080.0 / 240.0) * yscale
        for i,v in ipairs(actions) do
            -- ignore if not in the time window for this input, or not a shooting action.
            if (v.input == "action") and ((v.from == nil) or ((scene_manager.current_sequence_ticks >= v.from) and (scene_manager.current_sequence_ticks <= v.to))) then
                -- !!! FIXME: draw enemies in red, civilians in green, and skulls/spitoons in yellow
                local area = v.area
                if area ~= nil then
                    local x = area[1]
                    local y = area[2]
                    local w = area[3] - x
                    local h = area[4] - y
                    DirkSimple.draw_rect(x * rect_xscale, y * rect_yscale, w * rect_xscale, h * rect_yscale, 255, 0, 0)
                end
            end
        end
    end
end

local function draw_crosshair(inputs)
    if show_crosshairs then
        -- !!! FIXME: add cvar to choose different crosshair
        local sw = 23
        local sh = 25
        local dw = sw * xscale * 2   -- looks better doubled in size
        local dh = sh * yscale * 2
        local dx = (DirkSimple.video_width * inputs.pointerx) - (dw / 2)
        local dy = (DirkSimple.video_height * inputs.pointery) - (dh / 2)
        DirkSimple.draw_sprite("crosshaird", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
    end
end

local function draw_hud()
    local sw, sh, dw, dh, dx, dy

    local hud_topline = DirkSimple.video_height * 0.80

    -- draw score
    -- !!! FIXME: The score was _yellow_ in the arcade; maybe the HD version changed it to red...?
    local scorew = 13 * xscale * 5 * 4  -- glyph size times scale times 5 numbers, quadrupled to look better.
    local scoreh = 29 * yscale * 4
    local scorex = (DirkSimple.video_width - scorew) / 2   -- center it
    dw = scorew
    dh = scoreh
    dx = scorex
    dy = hud_topline
    draw_number(scene_manager.current_score, 5, dx, dy, 4)

    -- draw lives left
    sw = 15
    sh = 14
    dw = sw * xscale * 4   -- quadrupled to look better
    dh = sh * yscale * 4   -- quadrupled  to look better
    dx = dx - dw  -- move back from start of score by size of a star sprite to get to new starting point.
    dy = hud_topline

    local starhalf = dw / 2.0
    if scene_manager.lives_left >= 1 then
        dx = dx - starhalf
        dy = dy + dh
        DirkSimple.draw_sprite("star", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
    end

    if scene_manager.lives_left >= 2 then
        dx = dx - starhalf
        dy = dy - dh
        DirkSimple.draw_sprite("star", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
    end

    if scene_manager.lives_left >= 3 then
        dx = dx - starhalf
        dy = dy + dh
        DirkSimple.draw_sprite("star", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
    end

    -- !!! FIXME: can there be more than three lives in a game? If so, should we draw them?

    -- draw loaded bullets
    sw = 8
    sh = 11
    dw = sw * xscale * 4   -- looks better quadrupled in size
    dh = sh * yscale * 4
    dy = hud_topline
    local bullet_row_x = scorex + scorew + dw

    local remaining_bullets = scene_manager.loaded_bullets
    if (remaining_bullets > 12) then
        remaining_bullets = 12  -- don't draw more than this, even if available.
    end

    while remaining_bullets > 0 do
        local bullets_in_row = remaining_bullets
        if bullets_in_row > 6 then
            bullets_in_row = 6
        end
        dx = bullet_row_x
        for i = 1, bullets_in_row do
            DirkSimple.draw_sprite("bullet", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)
            dx = dx + (dw * 1.5)
        end

        dy = (hud_topline + scoreh) - dh  -- second row align to bottom of score.
        remaining_bullets = remaining_bullets - bullets_in_row
    end
end

local function draw_available_credits()
    -- !!! FIXME: I don't know what free play mode actually looked like, or if it even existed for this game.
    -- !!! FIXME: so just lie and say at least 1 credit is always available.
    if (current_ticks % 2000) > 1000 then  -- blink available credits message every other second.
        local credits = scene_manager.credits
        if credits < 1 then credits = 1 elseif credits > 9 then credits = 9 end
        local sw, sh, dw, dh, dx, dy
        sw = 93
        sh = 30
        dw = sw * xscale * 2  -- these look better doubled in size.
        dh = sh * yscale * 2
        dx = (DirkSimple.video_width - dw) / 2     --((1440 - sw) / 2) * xscale
        dy = 970 * yscale
        DirkSimple.draw_sprite("credits", 0, 0, sw, sh, dx, dy, dw, dh, 255, 255, 255)

        dx = dx + dw + 10  --(((1440 + sw) / 2) + 10) * xscale
        draw_number(credits, 1, dx, dy)
    end
end

local function setup_scene_manager()
    -- save off existing credits value, since we reinit when starting a game and would lose this.
    -- (this is part of the serialized state, though, so we need it to be in scene_manager and not a global).
    local credits = 1
    if (scene_manager ~= nil) and (scene_manager.credits ~= nil) then
        credits = scene_manager.credits
    end

    scene_manager.initialized = true
    scene_manager.lives_left = starting_lives
    scene_manager.credits = credits
    scene_manager.current_score = 0
    scene_manager.last_seek = 0
    scene_manager.current_scene = nil
    scene_manager.current_scene_name = nil
    scene_manager.current_sequence = nil
    scene_manager.current_sequence_name = nil
    scene_manager.current_sequence_ticks = 0
    scene_manager.current_sequence_tick_offset = 0
    scene_manager.unserialize_offset = 0
    scene_manager.bottle_plan = 0
    scene_manager.bottle_index = 0
    scene_manager.loaded_bullets = 6
    scene_manager.reload_allowed = true
    scene_manager.previous_scene_name = nil
    scene_manager.died_in_scene_name = nil
end

local function start_sequence(sequencename)
    DirkSimple.log("Starting sequence '" .. sequencename .. "'")

    local prev_sequence = scene_manager.current_sequence

    scene_manager.current_sequence_name = sequencename
    scene_manager.current_sequence = scene_manager.current_scene[sequencename]
    accepted_input = nil

    -- !!! FIXME: need to be able to stop scene_manager.current_sequence.audio for previous sequence, but this needs changes to dirksimple.c

    local start_time = scene_manager.current_sequence.start_time
    if start_time < 0 then  -- if negative, no seek desired (just keep playing from current location)
        -- deal with situation where we are paused on a frame and starting a sequence from that frame forward (shot a bottle in the tutorial).
        if prev_sequence and prev_sequence.is_single_frame and not scene_manager.current_sequence.is_single_frame then
            scene_manager.current_sequence_tick_offset = 0
            DirkSimple.continue_clip()
        else
            scene_manager.current_sequence_tick_offset = scene_manager.current_sequence_tick_offset + scene_manager.current_sequence_ticks
        end
    else
        -- will suspend ticking until the seek completes and reset sequence tick count
        if scene_manager.current_sequence.is_single_frame then
            DirkSimple.show_single_frame(start_time)
        else
            DirkSimple.start_clip(start_time)
        end
        scene_manager.last_seek = start_time
        scene_manager.current_sequence_tick_offset = 0
        scene_manager.unserialize_offset = 0
    end

    if scene_manager.current_sequence.init ~= nil then
        scene_manager.current_sequence.init()
    end

    if scene_manager.current_sequence.audio ~= nil then
        DirkSimple.play_sound(scene_manager.current_sequence.audio)
    end
end

local function start_scene(scenename)
    DirkSimple.log("Starting scene '" .. scenename .. "'")
    scene_manager.previous_scene_name = scene_manager.current_scene_name
    scene_manager.current_scene_name = scenename
    scene_manager.current_scene = scenes[scenename]

    -- bullets are infinite; they just need to be reloaded. Assume our hero had time to reload during all transitions.
    if scene_manager.loaded_bullets < 6 then
        scene_manager.loaded_bullets = 6
    end

    start_sequence('start')
end

local function choose_next_scene(requested)
    if test_scene_name ~= nil then
        start_scene(test_scene_name)  -- restart this scene always if testing.
        return
    elseif requested ~= nil then
        start_scene(requested)
        return
    end

    CrashTheGame()  -- !!! FIXME
end

local function start_attract_mode()
    start_scene('attract_mode')
end

local function start_game()
    DirkSimple.log("Start game!")
    setup_scene_manager()
    if test_scene_name ~= nil then
        start_scene(test_scene_name)
    elseif skip_tutorial then
        start_scene("level1")
    else
        start_scene("tutorial")
    end
end

local function crosshairs_in_area(area)
    local x = current_inputs.pointerx
    local y = current_inputs.pointery
    return (x >= (area[1] / 360.0)) and (y >= (area[2] / 240.0)) and (x < (area[3] / 360.0)) and (y < (area[4] / 240.0))
end

local function check_actions(inputs)
    -- we don't care about inserting coins, but we'll play the sound if you
    -- hit the coinslot button and keep track of "credits"
    if inputs.pressed["coinslot"] then
        scene_manager.credits = scene_manager.credits + 1
        DirkSimple.play_sound("arcadecoin")
    end

    if not scene_manager.current_sequence.crosshairs_disabled and not scene_manager.current_sequence.gunfire_disabled and not god_mode then
        --DirkSimple.log("x=" .. tostring(inputs.pointerx) .. " y=" .. tostring(inputs.pointery) .. " pressed=" .. tostring(inputs.pressed["action"] or false) .. " held=" .. tostring(inputs.held["action"] or false).. " released=" .. tostring(inputs.held["released"] or false))
        if inputs.pressed["action"] then
            local gunsound
            if scene_manager.loaded_bullets == 0 then
                gunsound = "empty"
            else
                gunsound = "shot"
                if not infinite_bullets then
                    scene_manager.loaded_bullets = scene_manager.loaded_bullets - 1
                end
            end
            DirkSimple.play_sound(gunsound)
        else  -- only allow reload management if we haven't tried to fire this frame.
            local do_reload = false

            -- the reload stuff is totally my own and might suck, so we'll tweak as necessary.
            -- in the original arcade game, you had to point the gun down to reload, but we don't have that luxury here.
            -- So if you're pointing at the very bottom of the screen, we'll treat that as a reload,
            -- but you have to bring the pointer back up to about the middle of the screen before you can reload again.
            -- alternately, turn on the reload_on_action2 cvar and you can just use the right mouse button whenever. The
            -- Sinden lightgun sends a right mouse button when you point offscreen and fire.
            if reload_on_action2 then
                if inputs.pressed["action2"] then
                    do_reload = true
                end
            elseif inputs.pointery >= 0.99 then   -- in the reload area.
                if scene_manager.reload_allowed then
                    do_reload = true
                    scene_manager.reload_allowed = false  -- you have to move back up the screen to reload again.
                end
            elseif inputs.pointery < 0.60 then   -- in the reload area.
                scene_manager.reload_allowed = true   -- gun was lifted enough, allow another reload.
            end

            if do_reload and scene_manager.loaded_bullets < 6 then  -- !!! FIXME: cvar for reload count?
                scene_manager.loaded_bullets = 6  -- !!! FIXME: cvar for reload count?
                DirkSimple.play_sound("reload")
            end
        end
    end

    if accepted_input ~= nil then
        return true  -- ignore all input until end of sequence.
    end

    local actions = scene_manager.current_sequence.actions
    if actions ~= nil then
        for i,v in ipairs(actions) do
            -- ignore if not in the time window for this input.
            if (v.from == nil) or ((scene_manager.current_sequence_ticks >= v.from) and (scene_manager.current_sequence_ticks <= v.to)) then
                local input = v.input
                local area = v.area
                if god_mode and v.best then
                    if area == nil then
                        DirkSimple.log("(god mode) accepted action '" .. input .. "' at " .. tostring(scene_manager.current_sequence_ticks / 1000.0))
                    else
                        -- move the crosshair to show where the shot was.
                        inputs.pointerx = ((area[1] + area[3]) / 2) / 360.0
                        inputs.pointery = ((area[2] + area[4]) / 2) / 240.0
                        DirkSimple.log("(god mode) accepted action '" .. input .. "' for area { " .. area[1] .. ", " .. area[2] .. ", " .. area[3] .. ", " .. area[4] .. " } at " .. tostring(scene_manager.current_sequence_ticks / 1000.0))
                        DirkSimple.play_sound("shot")
                    end
                    accepted_input = v
                    return true
                elseif inputs.pressed[input] then  -- we got one?
                    if area == nil then  -- we got one!
                        DirkSimple.log("accepted action '" .. input .. "' at " .. tostring(scene_manager.current_sequence_ticks / 1000.0))
                        accepted_input = v
                        return true
                    elseif crosshairs_in_area(area) then  -- we got one!
                        DirkSimple.log("accepted action '" .. input .. "' for area { " .. area[1] .. ", " .. area[2] .. ", " .. area[3] .. ", " .. area[4] .. " } at " .. tostring(scene_manager.current_sequence_ticks / 1000.0))
                        accepted_input = v
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function check_timeout()
    local done_with_sequence = false
    if scene_manager.current_sequence_ticks >= scene_manager.current_sequence.timeout.when then  -- whole sequence has run to completion.
        done_with_sequence = true
    elseif (accepted_input ~= nil) then --and accepted_input.interrupt ~= nil then  -- If interrupting, forego the timeout.
        done_with_sequence = true
    elseif (accepted_input ~= nil) and (type(accepted_input.nextsequence) == "string") and (scene_manager.current_scene[accepted_input.nextsequence].start_time ~= time_laserdisc_noseek()) then  -- If action leads to a laserdisc seek, forego the timeout.
        done_with_sequence = true
    end

    if not done_with_sequence then
        return  -- sequence is not complete yet.
    end

    DirkSimple.log("Done with current sequence")

    local outcome
    if accepted_input ~= nil then
        outcome = accepted_input
    else
        outcome = scene_manager.current_sequence.timeout
    end

    if outcome.points ~= nil then
        scene_manager.current_score = scene_manager.current_score + outcome.points
    end

    if outcome.interrupt ~= nil then
        outcome.interrupt()
    elseif outcome.nextsequence ~= nil then  -- not end of scene?
        local nextseq = outcome.nextsequence
        if type(nextseq) == 'function' then
            nextseq = nextseq()
        end
        start_sequence(nextseq)
    else
        choose_next_scene(outcome.nextscene)
    end

    -- as a special hack, if the new sequence has a timeout of 0, we process it immediately without
    -- waiting for the next tick, since it's just trying to set up some state before an actual
    -- sequence and we don't want the video to move ahead in a completed sequence or progress
    -- before the actual sequence is ticking.
    if scene_manager.current_sequence.timeout.when == 0 then
        check_timeout()
    end
end

DirkSimple.serialize = function()
    if not scene_manager.initialized then
        setup_scene_manager()   -- just so we can serialize a default state.
    end

    local state = {}
    state[#state + 1] = 1   -- current serialization version
    state[#state + 1] = scene_manager.lives_left
    state[#state + 1] = scene_manager.credits
    state[#state + 1] = scene_manager.current_score
    state[#state + 1] = scene_manager.last_seek
    state[#state + 1] = scene_manager.current_scene_name
    state[#state + 1] = scene_manager.current_sequence_name
    state[#state + 1] = scene_manager.current_sequence_ticks
    state[#state + 1] = scene_manager.current_sequence_tick_offset
    state[#state + 1] = scene_manager.bottle_plan
    state[#state + 1] = scene_manager.bottle_index
    state[#state + 1] = scene_manager.loaded_bullets
    state[#state + 1] = scene_manager.reload_allowed
    state[#state + 1] = scene_manager.previous_scene_name
    state[#state + 1] = scene_manager.died_in_scene_name

    return state
end


DirkSimple.unserialize = function(state)
    -- !!! FIXME: this function assumes that `state` is completely valid. It doesn't check array length or data types.
    setup_scene_manager()

    local idx = 1
    local version = state[idx] ; idx = idx + 1
    scene_manager.lives_left = state[idx] ; idx = idx + 1
    scene_manager.credits = state[idx] ; idx = idx + 1
    scene_manager.current_score = state[idx] ; idx = idx + 1
    scene_manager.last_seek = state[idx] ; idx = idx + 1
    scene_manager.current_scene_name = state[idx] ; idx = idx + 1
    scene_manager.current_sequence_name = state[idx] ; idx = idx + 1
    scene_manager.current_sequence_ticks = state[idx] ; idx = idx + 1
    scene_manager.current_sequence_tick_offset = state[idx] ; idx = idx + 1
    scene_manager.bottle_plan = state[idx] ; idx = idx + 1
    scene_manager.bottle_index = state[idx] ; idx = idx + 1
    scene_manager.loaded_bullets = state[idx] ; idx = idx + 1
    scene_manager.reload_allowed = state[idx] ; idx = idx + 1
    scene_manager.previous_scene_name = state[idx] ; idx = idx + 1
    scene_manager.died_in_scene_name = state[idx] ; idx = idx + 1
    scene_manager.unserialize_offset = scene_manager.current_sequence_ticks + scene_manager.current_sequence_tick_offset
    scene_manager.current_sequence_tick_offset = 0  -- unserialize_offset will handle everything up until now, until the next sequence starts.

    if scene_manager.current_scene_name ~= nil then
        scene_manager.current_scene = scenes[scene_manager.current_scene_name]
        if scene_manager.current_sequence_name ~= nil then
            scene_manager.current_sequence = scene_manager.current_scene[scene_manager.current_sequence_name]
            local start_time = scene_manager.last_seek
            if scene_manager.current_sequence.is_single_frame then
                DirkSimple.show_single_frame(start_time)
            else
                DirkSimple.start_clip(start_time + scene_manager.unserialize_offset)
            end
        end
    end

    return true
end

DirkSimple.tick = function(ticks, sequenceticks, inputs)
    xscale = DirkSimple.video_width / 1440.0
    yscale = DirkSimple.video_height / 1080.0

    -- if in god mode, take control of the crosshairs.
    if god_mode then
        if current_inputs == nil then
            inputs.pointerx = 0.5
            inputs.pointery = 0.5
        else
            inputs.pointerx = current_inputs.pointerx
            inputs.pointery = current_inputs.pointery
        end
    end

    current_ticks = ticks
    current_inputs = inputs

    if not scene_manager.initialized then
        setup_scene_manager()
    end

    scene_manager.current_sequence_ticks = (sequenceticks + scene_manager.unserialize_offset) - scene_manager.current_sequence_tick_offset
    --DirkSimple.log("LUA TICK(ticks=" .. tostring(current_ticks) .. ", sequenceticks=" .. tostring(scene_manager.current_sequence_ticks) .. ", tick_offset=" .. tostring(scene_manager.current_sequence_tick_offset) .. ", unserialize_offset=" .. tostring(scene_manager.unserialize_offset) .. ")")

    if scene_manager.current_sequence == nil then
        start_attract_mode()
    end

    if scene_manager.current_sequence ~= nil then
        if scene_manager.current_sequence.overlay ~= nil then
            scene_manager.current_sequence.overlay()
        end
        if not scene_manager.current_sequence.hud_disabled then
            draw_hud()
        end
        if scene_manager.current_sequence.show_credits then
            draw_available_credits()
        end
        if show_hitboxes then
            draw_hitboxes()
        end
        if not scene_manager.current_sequence.crosshairs_disabled then
            draw_crosshair(inputs)
        end
    end

    check_actions(inputs)   -- check inputs before timeout, in case an input came through at the last possible moment, even if we're over time.
    check_timeout()
end

-- this is called when starting the tutorial, to decide what bottles will be popping up.
local bottle_sequences = { { 1, 3, 5, 6 }, { 2, 4, 3, 6 }, { 3, 4, 1, 5 }, { 4, 6, 2, 3 }, { 5, 2, 3, 1 }, { 6, 5, 2, 4 }, { 3, 1, 2, 4 }, { 1, 4, 3, 6 } }
local function bottle_plan()
    --bottle_sequences = { { 1, 2, 3, 4, 5, 6 } }
    local choice = DirkSimple.to_int(current_ticks % #bottle_sequences) + 1
    local seq = bottle_sequences[choice]
    DirkSimple.log("bottle_plan: choosing #" .. choice .. ": { " .. seq[1] .. ", " .. seq[2] .. ", " .. seq[3] .. ", " .. seq[4] .. " }")
    scene_manager.bottle_plan = choice
    scene_manager.bottle_index = 0
end

-- this is called to choose the next bottle, based on the previously-decided bottle_plan.
local function next_bottle()
    local seq = bottle_sequences[scene_manager.bottle_plan]
    if scene_manager.bottle_index == #seq then  -- already did the last bottle?
        return "tutorial_complete"
    end
    scene_manager.bottle_index = scene_manager.bottle_index + 1
    return "bottle" .. seq[scene_manager.bottle_index]
end

-- this is called when the tutorial thinks you missed your shot(s). Prospector says one of two things at random.
local function missed_tutorial_bottle()
    local seq = bottle_sequences[scene_manager.bottle_plan]
    if scene_manager.bottle_index == #seq then  -- that was the last bottle, don't say anything.
        return "tutorial_complete"
    elseif (current_ticks % 2) == 1 then
        return "missed_that_one"
    end
    return "try_another"
end

-- this is called when the tutorial thinks you hit your shot. Prospector says something, or tutorial ends.
local function shot_tutorial_bottle()
    local seq = bottle_sequences[scene_manager.bottle_plan]
    if scene_manager.bottle_index == #seq then  -- that was the last bottle, don't say anything.
        return "tutorial_complete"
    end
    return "nice_shooting"
end

local function init_undertaker()
    scene_manager.lives_left = scene_manager.lives_left - 1  -- if you're here, you died.
    if infinite_lives and (scene_manager.lives_left < 3) then
        scene_manager.lives_left = 3   -- just keep bumping this back up.
    elseif scene_manager.lives_left < 0 then
        scene_manager.lives_left = 0  -- just in case.
    end

    -- the undertaker is the current scene at this point, so save the previous scene's name.
    scene_manager.died_in_scene_name = scene_manager.previous_scene_name

    if skip_undertaker then
        start_scene("lives_left")  -- do this instead.
    end
end

local function choose_undertaker_normal_sequence()
    local lives_left = scene_manager.lives_left
    if lives_left == 0 then
        return "zero_lives"
    elseif lives_left == 1 then
        return "one_life"
    elseif lives_left == 2 then
        return "two_lives"
    elseif (current_ticks % 2) == 1 then  -- two scenes at random for all other cases.
        return "first_random"
    else
        return "second_random"
    end
end

-- init_undertaker() already subtracted a life. This just chooses the next thing after the undertaker/lives_left scene.
local function handle_death()
    -- choose the next scene after dying...game over screen, back to retry the previous scene, etc.
    if scene_manager.lives_left <= 0 then  -- game over, but maybe continue
        start_scene("continue_screen")
    else  -- still have lives left, go back and try the scene again.
        local died_in_scene_name = scene_manager.died_in_scene_name
        scene_manager.died_in_scene_name = nil  -- reset this until next death.
        start_scene(died_in_scene_name)
    end
end

local function overlay_lives_left()
    local lives_left = scene_manager.lives_left
    if (lives_left < 0) then lives_left = 0 elseif (lives_left > 9) then lives_left = 9 end
    local sw = 13 * 4  -- quadrupled to look better
    local sh = 29 * 4  -- quadrupled to look better
    local dx = (DirkSimple.video_width - sw) / 2   -- center it
    local dy = DirkSimple.video_height * 0.27
    draw_number(lives_left, 1, dx, dy, 4)
end

local function handle_gameover()
    -- Decide if we're going to a highscore screen first, or straight to the Game Over message.
    -- !!! FIXME: we need to write the highscore screen first.  :)
    start_scene("game_over")
end

local function handle_game_continued()
    scene_manager.credits = scene_manager.credits - 1
    if scene_manager.credits < 1 then
        scene_manager.credits = 1   -- we're effectively always in free-play mode, so you always have at least one credit inserted.
    end

    scene_manager.lives_left = starting_lives
    scene_manager.current_score = 0  -- tragically, you lose your accumulated score on continue.

    -- !!! FIXME: you have a random chance of hitting a showdown scene here before continuing with the intended scene.
    local died_in_scene_name = scene_manager.died_in_scene_name
    scene_manager.died_in_scene_name = nil  -- reset this until next death.
    start_scene(died_in_scene_name)  -- !!! FIXME: do some of these bring you back to choice scenes to pick a different scene instead?
end

local function overlay_credits_page1()
    local font = "font-gambler-72"
    draw_text(font, "P R O D U C E R", 300, 110)
    draw_text(font, "R O B E R T  G R E B E", 350, 180)
    draw_text(font, "D I R E C T O R", 300, 300)
    draw_text(font, "D A V I D   O.  R O B E R T S", 350, 370)
    draw_text(font, "C I N E M A T O G R A P H Y", 300, 490)
    draw_text(font, "B A R R Y   K I R K", 350, 560)
    draw_text(font, "S T O R Y   B Y", 300, 680)
    draw_text(font, "J I M   P A T T I S O N", 350, 750)
end

local function overlay_credits_page2()
    local font = "font-gambler-72"
    draw_text(font, "S O F T W A R E", 300, 110)
    draw_text(font, "P I E R R E   M A L O K A", 350, 180)
    draw_text(font, "S P E C I A L   T H A N K S   T O", 300, 300)
    draw_text(font, "T H E   C R E W   A T", 350, 370)
    draw_text(font, "S O U T H W E S T   P R O D U C T I O N S", 350, 440)
end

local function overlay_credits_page3()
    local font = "font-gambler-72"
    draw_text(font, "P R O G R A M  B Y", 300, 110)
    draw_text(font, "R D G  2 0 1 0", 350, 180)
    draw_text(font, "S I N G E  2  P O R T", 300, 300)
    draw_text(font, "P O I U  2 0 2 0", 350, 370)
    draw_text(font, "S I N G E  2  B U I L D", 300, 490)
    draw_text(font, "S C O T T  D U E N S I N G", 350, 560)
    draw_text(font, "H D  P O R T", 300, 680)
    draw_text(font, "K A R I S", 350, 750)
    draw_text(font, "D I R K S I M P L E   R E B U I L D", 300, 870)
    draw_text(font, "R Y A N   C .   G O R D O N", 350, 940)
end

local function overlay_highscores()
    draw_text("font-gambler-72", "T O P  S H O O T E R S", 820, 120, 255, 0, 0)

    -- !!! FIXME: actually track highscores and save them somewhere.
    local y = 250

    draw_text("font-score-42", "1. RCG", 820, y, 255, 0, 0)
    draw_text("font-score-42", "10000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "2. CLO", 820, y, 255, 0, 0)
    draw_text("font-score-42", "9000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "3. OFG", 820, y, 255, 0, 0)
    draw_text("font-score-42", "8000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "3. ZJS", 820, y, 255, 0, 0)
    draw_text("font-score-42", "7000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "4. GSR", 820, y, 255, 0, 0)
    draw_text("font-score-42", "6000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "5. CJG", 820, y, 255, 0, 0)
    draw_text("font-score-42", "5000", 1170, y, 255, 0, 0)
    y = y + 80
    draw_text("font-score-42", "6. SLO", 820, y, 255, 0, 0)
    draw_text("font-score-42", "4000", 1170, y, 255, 0, 0)
    y = y + 80
end



-- The scene table!
scenes = {
    attract_mode = {
        start = {
            timeout = { when=0, nextsequence="attract_movie" },
            crosshairs_disabled = true,
            hud_disabled = true,
            start_time = time_laserdisc_noseek(),
        },

        attract_movie = {
            start_time = laserdisc_frame_to_ms(2444),
            timeout = { when=laserdisc_frame_to_ms(2016), nextsequence="title_screen" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        title_screen = {
            start_time = laserdisc_frame_to_ms(41600),
            is_single_frame = true,
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            timeout = { when=time_to_ms(5, 0), nextsequence="mayors_daughter" },
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        mayors_daughter = {
            start_time = laserdisc_frame_to_ms(37192),
            timeout = { when=laserdisc_frame_to_ms(750), nextsequence="prospector_intro" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        prospector_intro = {
            start_time = laserdisc_frame_to_ms(0),
            timeout = { when=laserdisc_frame_to_ms(975), nextsequence="credits_start" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        credits_start = {
            start_time = laserdisc_frame_to_ms(4460 + 558),
            timeout = { when=laserdisc_frame_to_ms(17), nextsequence="credits_page1" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        credits_page1 = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(126), nextsequence="credits_page2" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        credits_page2 = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(141), nextsequence="credits_page3" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        credits_page3 = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(143), nextsequence="high_scores" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        high_scores = {
            start_time = laserdisc_frame_to_ms(2444 + 150),
            is_single_frame = true,
            timeout = { when=time_to_ms(6, 0), nextsequence="how_to_play" },
            show_credits = true,
            audio = "hs",
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
        how_to_play = {
            start_time = laserdisc_frame_to_ms(39381 + 50),
            timeout = { when=laserdisc_frame_to_ms(1075), nextsequence="attract_movie" },
            show_credits = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {
                -- Player hit start to start the game
                { input="start", interrupt=start_game, nextsequence=nil },
            }
        },
    },

    tutorial = {
        start = {
            timeout = { when=0, nextsequence="lets_see" },
            init = bottle_plan,
            start_time = time_laserdisc_noseek(),
        },
        lets_see = {
            start_time = laserdisc_frame_to_ms(39381 + 1132),
            timeout = { when=laserdisc_frame_to_ms(110), nextsequence=next_bottle },
        },
        nice_shooting = {
            start_time = laserdisc_frame_to_ms(39381 + 1242),
            timeout = { when=laserdisc_frame_to_ms(78), nextsequence=next_bottle },
        },
        missed_that_one = {
            start_time = laserdisc_frame_to_ms(39381 + 1320),
            timeout = { when=laserdisc_frame_to_ms(90), nextsequence=next_bottle },
        },
        try_another = {
            start_time = laserdisc_frame_to_ms(39381 + 1410),
            timeout = { when=laserdisc_frame_to_ms(40), nextsequence=next_bottle },
        },
        bottle_shot = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(32), nextsequence=shot_tutorial_bottle },
        },
        bottle1 = {
            start_time = laserdisc_frame_to_ms(39381 + 1454),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={74, 57, 89, 80}, points=bottle_points, nextsequence="bottle1_shot", best=true },
                { input="action", area={78, 42, 85, 64}, points=bottle_points, nextsequence="bottle1_shot" },
            }
        },
        bottle1_shot = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(31), nextsequence=shot_tutorial_bottle },
        },
        bottle2 = {
            start_time = laserdisc_frame_to_ms(39381 + 1487),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={115, 81, 120, 89}, points=bottle_points, nextsequence="bottle_shot", best=true },
                { input="action", area={117, 76, 119, 85}, points=bottle_points, nextsequence="bottle_shot" },
            }
        },
        bottle3 = {
            start_time = laserdisc_frame_to_ms(39381 + 1521),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={184, 77, 192, 89}, points=bottle_points, nextsequence="bottle_shot", best=true },
                { input="action", area={186, 69, 190, 81}, points=bottle_points, nextsequence="bottle_shot" },
            }
        },
        bottle4 = {
            start_time = laserdisc_frame_to_ms(39381 + 1555),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={286, 76, 298, 93}, points=bottle_points, nextsequence="bottle_shot", best=true },
                { input="action", area={289, 66, 294, 77}, points=bottle_points, nextsequence="bottle_shot" },
            }
        },
        bottle5 = {
            start_time = laserdisc_frame_to_ms(39381 + 1588),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={127, 158, 140, 178}, points=bottle_points, nextsequence="bottle_shot", best=true },
                { input="action", area={132, 143, 137, 159}, points=bottle_points, nextsequence="bottle_shot" },
            }
        },
        bottle6 = {
            start_time = laserdisc_frame_to_ms(39381 + 1623),
            is_single_frame = true,
            timeout = { when=time_to_ms(3, 0), nextsequence=missed_tutorial_bottle },
            actions = {
                { input="action", area={288, 155, 301, 176}, points=bottle_points, nextsequence="bottle6_shot", best=true },
                { input="action", area={292, 141, 297, 157}, points=bottle_points, nextsequence="bottle6_shot" },
            }
        },
        bottle6_shot = {
            start_time = time_laserdisc_noseek(),
            timeout = { when=laserdisc_frame_to_ms(38), nextsequence=shot_tutorial_bottle },
        },
        tutorial_complete = {
            start_time = laserdisc_frame_to_ms(39381 + 1662),
            timeout = { when=laserdisc_frame_to_ms(2), nextscene="level1" },
        }
    },

    level1 = {
        start = {
            start_time = laserdisc_frame_to_ms(0),
            gunfire_disabled = true,  -- there's nothing to shoot in this piece, but we don't want to make sound or spend a bullet if we shoot to skip ahead.
            actions = {  -- you can skip the scenic view and chatter here by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=laserdisc_frame_to_ms(0), to=laserdisc_frame_to_ms(600), nextsequence="skip_to_fight" },
            },
            timeout = { when=laserdisc_frame_to_ms(1001), nextsequence="actual_fight" },
        },
        skip_to_fight = {  -- do the seek here so actual_fight can be time_laserdisc_noseek() on all paths.
            start_time = time_laserdisc_noseek(),
            timeout = { when=0, nextsequence="actual_fight" },
        },
        actual_fight = {
            start_time = laserdisc_frame_to_ms(1001),
            timeout = { when=laserdisc_frame_to_ms(9), nextsequence="first_shooter" },
        },
        first_shooter = {
            start_time = time_laserdisc_noseek(),
            actions = {
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={290, 103, 300, 114}, points=badguy_points+headshot_bonus_points, nextsequence="first_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={285, 114, 306, 138}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={285, 146, 291, 163}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={286, 137, 306, 147}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={301, 147, 309, 158}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={306, 158, 312, 178}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={280, 159, 285, 176}, points=badguy_points, nextsequence="first_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(90), to=laserdisc_frame_to_ms(109), area={280, 115, 285, 129}, points=badguy_points, nextsequence="first_shooter_dies" },
            },
            timeout = { when=laserdisc_frame_to_ms(109), nextsequence="first_shooter_kills" },
        },
        first_shooter_dies = {
            start_time = laserdisc_frame_to_ms(1119),
            timeout = { when=laserdisc_frame_to_ms(106), nextsequence="second_shooter" }
        },
        first_shooter_kills = {
            start_time = laserdisc_frame_to_ms(1830),
            timeout = { when=laserdisc_frame_to_ms(318), nextscene="undertaker_normal" }
        },
        second_shooter = {
            start_time = time_laserdisc_noseek(),
            actions = {
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={301, 106, 312, 122}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={296, 123, 317, 155}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={289, 149, 299, 165}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={312, 155, 327, 164}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={285, 165, 296, 171}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={318, 165, 324, 193}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={282, 168, 288, 185}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(1), to=laserdisc_frame_to_ms(2), area={279, 177, 285, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={298, 106, 308, 122}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={293, 122, 313, 154}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={289, 147, 298, 164}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={307, 153, 322, 163}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={283, 162, 293, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={315, 163, 322, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(3), to=laserdisc_frame_to_ms(4), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={294, 106, 305, 122}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={290, 120, 313, 152}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={287, 148, 296, 165}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={306, 152, 321, 162}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={283, 162, 293, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={315, 162, 322, 190}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(5), to=laserdisc_frame_to_ms(6), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={292, 103, 301, 119}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={287, 119, 310, 151}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={287, 148, 296, 165}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={305, 150, 317, 162}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={283, 162, 293, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={314, 162, 321, 190}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(7), to=laserdisc_frame_to_ms(9), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={291, 102, 300, 118}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={286, 116, 309, 149}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={286, 148, 296, 163}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={304, 148, 317, 160}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={283, 162, 293, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={315, 160, 322, 188}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(10), to=laserdisc_frame_to_ms(13), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={291, 102, 300, 118}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={287, 115, 310, 147}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={286, 148, 296, 163}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={304, 148, 317, 160}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={283, 162, 293, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={315, 160, 322, 188}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(14), to=laserdisc_frame_to_ms(15), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={291, 101, 299, 116}, points=badguy_points, nextsequence="second_shooter_dies", best=true },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={287, 115, 310, 147}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={286, 148, 295, 162}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={305, 147, 317, 160}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={283, 162, 291, 168}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={314, 160, 321, 188}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={280, 167, 286, 184}, points=badguy_points, nextsequence="second_shooter_dies" },
                { input="action", from=laserdisc_frame_to_ms(16), to=laserdisc_frame_to_ms(19), area={277, 177, 282, 191}, points=badguy_points, nextsequence="second_shooter_dies" },
            },
            timeout = { when=laserdisc_frame_to_ms(19), nextsequence="second_shooter_kills" },
        },
        second_shooter_dies = {
            start_time = laserdisc_frame_to_ms(1243),
            timeout = { when=laserdisc_frame_to_ms(585), nextsequence=nil }
        },
        second_shooter_kills = {
            start_time = laserdisc_frame_to_ms(2150),
            timeout = { when=laserdisc_frame_to_ms(293), nextscene="undertaker_normal" }
        },
    },

    undertaker_normal = {
        start = {
            start_time = time_laserdisc_noseek(),
            crosshairs_disabled = true,
            init = init_undertaker,  -- subtract a life, might jump to simplifed lives_left scene instead.
            timeout = { when=0, nextsequence=choose_undertaker_normal_sequence },
        },
        zero_lives = {
            start_time = laserdisc_frame_to_ms(12292),
            crosshairs_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=time_to_ms(0, 0), to=time_to_ms(30, 0), interrupt=handle_death },
            },
            timeout = { when=laserdisc_frame_to_ms(359), interrupt=handle_death }
        },
        one_life = {
            start_time = laserdisc_frame_to_ms(12045),
            crosshairs_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=time_to_ms(0, 0), to=time_to_ms(30, 0), interrupt=handle_death },
            },
            timeout = { when=laserdisc_frame_to_ms(246), interrupt=handle_death }
        },
        two_lives = {
            start_time = laserdisc_frame_to_ms(11291),
            crosshairs_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=time_to_ms(0, 0), to=time_to_ms(30, 0), interrupt=handle_death },
            },
            timeout = { when=laserdisc_frame_to_ms(251), interrupt=handle_death }
        },
        first_random = {
            start_time = laserdisc_frame_to_ms(10661),
            crosshairs_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=time_to_ms(0, 0), to=time_to_ms(30, 0), interrupt=handle_death },
            },
            timeout = { when=laserdisc_frame_to_ms(254), interrupt=handle_death }
        },
        second_random = {
            start_time = laserdisc_frame_to_ms(10916),
            crosshairs_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=time_to_ms(0, 0), to=time_to_ms(30, 0), interrupt=handle_death },
            },
            timeout = { when=laserdisc_frame_to_ms(374), interrupt=handle_death }
        },
    },

    -- this is used if the undertaker shouldn't be shown, through a cvar.
    lives_left = {
        start = {
            start_time = laserdisc_frame_to_ms(41527),
            overlay = overlay_lives_left,
            is_single_frame = true,
            crosshairs_disabled = true,
            hud_disabled = true,
            actions = {  -- you can skip this scene by firing the gun. The Singe version does this, I doubt the arcade does.
                { input="action", from=laserdisc_frame_to_ms(0), to=time_to_ms(3, 0), interrupt=handle_death },
            },
            timeout = { when=time_to_ms(3, 0), interrupt=handle_death },
        }
    },

    continue_screen = {
        start = {
            start_time = laserdisc_frame_to_ms(41108),
            crosshairs_disabled = true,
            hud_disabled = true,
            show_credits = true,
            actions = {
                { input="coinslot", nextsequence="start" },  -- adding a "coin" restarts the continue countdown.
                { input="start", interrupt=handle_game_continued },  -- pressing start accepts the continue.
            },
            timeout = { when=laserdisc_frame_to_ms(299), interrupt=handle_gameover },
        }
    },

    game_over = {
        start = {
            start_time = laserdisc_frame_to_ms(41408),
            crosshairs_disabled = true,
            hud_disabled = true,
            show_credits = true,
            timeout = { when=laserdisc_frame_to_ms(118), nextscene="attract_mode" },
        }
    }
}

-- end of maddog.lua ...

