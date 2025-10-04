VERSION = "1.0.0"
DESCRIPTION = "42-style header generator for Micro editor"

local micro = import("micro")
local configuration = import("micro/config")
local buffer = import("micro/buffer")

local config = {
    asciiart = {
    -- "                         ",
    -- "            _            ",
    -- "          _ \\'-_,#       ",
    -- "         _\\'--','`|      ",
    -- "         \\`---`  /       ",
    -- "          `----'`        ",
    -- "                         "
    "                     ",
    "          _          ",
    "        _ \\'-_,#     ",
    "       _\\'--','`|    ",
    "       \\`---`  /     ",
    "        `----'`      ",
    "                     "
    },
    start = "/*",
    stop = "*/",
    fill = "*",
    length = 80,
    margin = 5,
    types = {
        [".c$"]    = {"/*", "*/", "*"},
        [".h$"]    = {"/*", "*/", "*"},
        [".cpp$"]  = {"/*", "*/", "*"},
        [".hpp$"]  = {"/*", "*/", "*"},
        [".php$"]  = {"/*", "*/", "*"},
        [".html$"] = {"<!--", "-->", "*"},
        [".xml$"]  = {"<!--", "-->", "*"},
        [".js$"]   = {"//", "//", "*"},
        [".tex$"]  = {"%", "%", "*"},
        [".ml$"]   = {"(*", "*)", "*"},
        [".vim$"]  = {"\"", "\"", "*"},
        [".el$"]   = {";", ";", "*"},
        [".f90$"]  = {"!", "!", "/"}
    }
}

function init()
    configuration.MakeCommand("stdheader", stdheader, configuration.NoComplete)
end

-- Helpers
local function filename(bp)
    local name = bp.Buf.Path:match("([^/]+)$") or "< new >"
    return name
end

local function user()
    return os.getenv("USER") or "marvin"
end

local function mail()
    return os.getenv("MAIL") or "marvin@42.fr"
end

local function date()
    return os.date("%Y/%m/%d %H:%M:%S")
end

local function filetype(bp)
    local fname = filename(bp)
    config.start, config.stop, config.fill = "#", "#", "*"
    for pattern, defs in pairs(config.types) do
        if fname:match(pattern) then
            config.start, config.stop, config.fill = defs[1], defs[2], defs[3]
            break
        end
    end
end

local function ascii(n)
    return config.asciiart[n - 2] or ""
end

local function get_line_locs(buf, n)
    -- Try the modern API first
    if type(buf.StartOfLine) == "function" and type(buf.EndOfLine) == "function" then
        return buf:StartOfLine(n), buf:EndOfLine(n)
    end

    -- Fallback for older Micro versions that expose .StartOfLine as tables
    if type(buf.StartOfLine) == "table" and type(buf.EndOfLine) == "table" then
        return buf.StartOfLine[n], buf.EndOfLine[n]
    end

    -- Ultimate fallback: construct Locs manually
    return { X = 0, Y = n }, { X = #buf:Line(n), Y = n }
end

local function textline(left, right)
    local l = left:sub(1, config.length - config.margin * 3 - #right + 1)
    local middle = string.rep(" ", config.length - config.margin * 2 - #l - #right)
    return config.start .. string.rep(" ", config.margin - #config.start) .. l ..
           middle .. right ..
           string.rep(" ", config.margin - #config.stop) .. config.stop
end

local function line(n, bp)
    if n == 1 or n == 11 then
        return config.start .. " " ..
               string.rep(config.fill, config.length - #config.start - #config.stop - 2) ..
               " " .. config.stop
    elseif n == 2 or n == 10 then
        return textline("", "")
    elseif n == 3 or n == 5 or n == 7 then
        return textline("", ascii(n))
    elseif n == 4 then
        return textline(filename(bp), ascii(n))
    elseif n == 6 then
        return textline("By: " .. user() .. " <" .. mail() .. ">", ascii(n))
    elseif n == 8 then
        return textline("Created: " .. date() .. " by " .. user(), ascii(n))
    elseif n == 9 then
        return textline("Updated: " .. date() .. " by " .. user(), ascii(n))
    end
end

-- Insert header
local function insert(bp)
    local lines = {}
    for i = 1, 11 do
        table.insert(lines, line(i, bp))
    end
    table.insert(lines, "") -- empty line after header

    local text = table.concat(lines, "\n") .. "\n"
    local xy = buffer.Loc(0, 0)
    local start = xy
    bp.Buf:Insert(start, text)
end

-- Update header
local function update(bp)
    filetype(bp)  -- sets config.start, config.stop, config.fill
    
    if not bp.Buf then
        print("Error: bp.Buf is nil!")
        return false
    end

    local buf = bp.Buf
    local nlines = 0
    while true do
        local line = buf:Line(nlines)
        if line == nil or line == "" then
            break
        end
        nlines = nlines + 1
        if nlines > 11 then break end  -- safety guard
    end
    
    -- only proceed if we have at least 9 lines
    if nlines >= 9 then
        local line9 = buf:Line(8) -- Lua is 0-based, so 9th line = 8
        local prefix = config.start .. string.rep(" ", config.margin - #config.start) .. "Updated: "

        if line9:find(prefix, 1, true) then
            -- replace line 9
            local start9, end9 = get_line_locs(buf, 8)
            buf:Replace(start9, end9, line(9, bp))
            -- replace line 4 (filename)
            local start4, end4 = get_line_locs(buf, 3)
            buf:Replace(start4, end4, line(4, bp))
            return false
        end
    end

    return true
end


function onRune(bp, r)
    update(bp)
end

function onSave(bp) onRune(bp); end

-- Main entry
function stdheader(bp)
    if update(bp) then
        insert(bp)
    end
end

