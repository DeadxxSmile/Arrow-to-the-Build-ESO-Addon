local ATTB = ArrowToTheBuild
local Util = ATTB.Util

function Util.CleanName(value)
    if value == nil then
        return nil
    end
    return zo_strformat("<<1>>", tostring(value))
end

-- ESO's two-argument GetString overload takes the string-prefix name itself
-- (for example "SI_ARMORTYPE"), not the numeric value of the SI_* global.
-- Keeping enum lookup here prevents collectors from accidentally indexing some
-- unrelated localized string table when converting enum values to display text.
function Util.EnumName(stringPrefix, enumValue, fallback)
    if type(stringPrefix) ~= "string" or enumValue == nil then
        return fallback
    end

    local value = GetString(stringPrefix, enumValue)
    if value == nil or value == "" then
        return fallback
    end
    return tostring(value)
end

function Util.NormalizeName(value)
    local cleaned = Util.CleanName(value)
    return cleaned and zo_strlower(tostring(cleaned)) or nil
end

function Util.Now()
    return GetTimeStamp()
end

function Util.FormatAge(timestamp)
    local elapsed = math.max(0, Util.Now() - (tonumber(timestamp or 0) or 0))
    if timestamp == nil or tonumber(timestamp or 0) == 0 then
        return "never"
    elseif elapsed < 60 then
        return string.format("%ds ago", elapsed)
    elseif elapsed < 3600 then
        return string.format("%dm ago", math.floor(elapsed / 60))
    elseif elapsed < 86400 then
        return string.format("%dh ago", math.floor(elapsed / 3600))
    end
    return string.format("%dd ago", math.floor(elapsed / 86400))
end

function Util.GetCharacterKey(accountName, worldName, characterId)
    return table.concat({
        tostring(accountName or "Unknown Account"),
        tostring(worldName or "Unknown World"),
        tostring(characterId or "Unknown Character"),
    }, "|")
end

function Util.TableCount(values)
    local count = 0
    for _ in pairs(type(values) == "table" and values or {}) do
        count = count + 1
    end
    return count
end

function Util.Print(message)
    d(string.format("|c00B3E0ATTB|r: %s", tostring(message)))
end
