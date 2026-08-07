local ATTB = ArrowToTheBuild
local Util = ATTB.Util

local function appendDiagnostic(kind, message)
    local diagnostics = ATTB.runtime.currentDiagnostics
    if not diagnostics then
        return
    end

    diagnostics[kind] = diagnostics[kind] or {}
    table.insert(diagnostics[kind], tostring(message))
end

function Util.AddWarning(message)
    appendDiagnostic("warnings", message)
end

function Util.AddError(message)
    appendDiagnostic("errors", message)
end

function Util.GetFunction(functionOrName)
    if type(functionOrName) == "function" then
        return functionOrName
    end
    if type(functionOrName) == "string" then
        local candidate = _G[functionOrName]
        if type(candidate) == "function" then
            return candidate
        end
    end
    return nil
end

-- Calls an ESO API function safely. The first return value indicates whether the
-- call itself succeeded. Remaining values are the API function's return values.
function Util.SafeCall(functionOrName, ...)
    local fn = Util.GetFunction(functionOrName)
    if not fn then
        return false, nil
    end

    local succeeded, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
    if not succeeded then
        Util.AddWarning(string.format("API call failed: %s", tostring(a)))
        return false, nil
    end

    return true, a, b, c, d, e, f, g, h, i, j, k, l
end

function Util.Value(functionOrName, defaultValue, ...)
    local succeeded, value = Util.SafeCall(functionOrName, ...)
    if succeeded and value ~= nil then
        return value
    end
    return defaultValue
end

function Util.Boolean(functionOrName, defaultValue, ...)
    local value = Util.Value(functionOrName, defaultValue, ...)
    return value == true
end

function Util.CleanName(value)
    if value == nil then
        return nil
    end

    local text = tostring(value)
    if text == "" then
        return text
    end

    if type(zo_strformat) == "function" then
        local succeeded, formatted = pcall(zo_strformat, "<<1>>", text)
        if succeeded and formatted then
            return formatted
        end
    end

    return text
end

function Util.NormalizeName(value)
    if value == nil then
        return nil
    end

    local cleaned = Util.CleanName(value)
    if cleaned == nil then
        return nil
    end

    if type(zo_strlower) == "function" then
        local succeeded, lowered = pcall(zo_strlower, tostring(cleaned))
        if succeeded and lowered then
            return lowered
        end
    end

    return string.lower(tostring(cleaned))
end

function Util.IdToString(value)
    if value == nil then
        return nil
    end

    if type(value) == "string" then
        return value
    end

    if type(Id64ToString) == "function" then
        local succeeded, converted = pcall(Id64ToString, value)
        if succeeded and converted and converted ~= "" then
            return converted
        end
    end

    return tostring(value)
end

function Util.Now()
    return Util.Value("GetTimeStamp", 0)
end

-- Formats an ESO Unix timestamp without depending on the restricted os library.
-- UTC is explicit so diagnostics remain unambiguous across local time zones.
function Util.FormatTimestamp(value)
    local timestamp = math.floor(tonumber(value or 0) or 0)
    if timestamp <= 0 then
        return "unknown"
    end

    local days = math.floor(timestamp / 86400)
    local secondsOfDay = timestamp - (days * 86400)
    local hour = math.floor(secondsOfDay / 3600)
    local minute = math.floor((secondsOfDay % 3600) / 60)
    local second = secondsOfDay % 60

    -- Civil date conversion adapted from the public-domain days-from-civil
    -- algorithm by Howard Hinnant. Unix day zero is 1970-01-01.
    local adjustedDays = days + 719468
    local era = math.floor(adjustedDays / 146097)
    local dayOfEra = adjustedDays - (era * 146097)
    local yearOfEra = math.floor(
        (dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096))
        / 365
    )
    local year = yearOfEra + (era * 400)
    local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
    local monthPrime = math.floor((5 * dayOfYear + 2) / 153)
    local day = dayOfYear - math.floor((153 * monthPrime + 2) / 5) + 1
    local month = monthPrime + (monthPrime < 10 and 3 or -9)
    if month <= 2 then
        year = year + 1
    end

    return string.format(
        "%04d-%02d-%02d %02d:%02d:%02d UTC",
        year,
        month,
        day,
        hour,
        minute,
        second
    )
end

function Util.GetApiVersion()
    return Util.Value("GetAPIVersion", 0)
end

function Util.GetAccountName()
    local value = Util.Value("GetDisplayName", "Unknown Account")
    return tostring(value or "Unknown Account")
end

function Util.GetWorldName()
    local value = Util.Value("GetWorldName", "Unknown World")
    return tostring(value or "Unknown World")
end

function Util.GetCharacterId()
    local rawId = Util.Value("GetCurrentCharacterId", nil)
    return Util.IdToString(rawId)
end

function Util.GetCharacterKey(accountName, worldName, characterId)
    return table.concat({
        tostring(accountName or "Unknown Account"),
        tostring(worldName or "Unknown World"),
        tostring(characterId or "Unknown Character"),
    }, "|")
end

function Util.GetStringForEnum(stringPrefix, enumValue, fallback)
    if enumValue == nil then
        return fallback
    end

    if type(GetString) == "function" then
        local succeeded, value = pcall(GetString, stringPrefix, enumValue)
        if succeeded and value and value ~= "" then
            return Util.CleanName(value)
        end
    end

    return fallback or tostring(enumValue)
end

function Util.CopyArray(values)
    local result = {}
    if type(values) ~= "table" then
        return result
    end
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

function Util.TableCount(values)
    local count = 0
    if type(values) ~= "table" then
        return count
    end
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

function Util.SafeRegisterEvent(eventName, eventConstantName, callback)
    if EVENT_MANAGER == nil or type(EVENT_MANAGER.RegisterForEvent) ~= "function" then
        return false
    end

    local eventCode = _G[eventConstantName]
    if eventCode == nil then
        return false
    end

    EVENT_MANAGER:RegisterForEvent(ATTB.eventNamespacePrefix .. eventName, eventCode, callback)
    return true
end

function Util.SafeUnregisterUpdate()
    if EVENT_MANAGER ~= nil and type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
        EVENT_MANAGER:UnregisterForUpdate(ATTB.updateRegistrationName)
    end
end

function Util.Print(message)
    if type(d) == "function" then
        d(string.format("|c00B3E0ATTB|r: %s", tostring(message)))
    end
end
