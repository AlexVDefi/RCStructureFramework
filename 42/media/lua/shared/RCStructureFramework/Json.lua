
---@class RCStructureFrameworkJson
local Json = {}

---@type table<string, string>
local jsonEscapes = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
}

---@param s string
---@return string
---@nodiscard
local function jsonEncodeString(s)
    local result = '"'
    for i = 1, #s do
        local ch = string.sub(s, i, i)
        local esc = jsonEscapes[ch]
        if esc then
            result = result .. esc
        elseif string.byte(ch) < 32 then
            result = result .. string.format("\\u%04x", string.byte(ch))
        else
            result = result .. ch
        end
    end
    return result .. '"'
end

---@param t table
---@return boolean
---@return integer
---@nodiscard
local function isArray(t)
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then return false, count end
        count = count + 1
    end
    for i = 1, count do
        if t[i] == nil then return false, count end
    end
    return true, count
end

local jsonEncodeValue

---@param value any
---@return string
---@nodiscard
jsonEncodeValue = function(value)
    local valueType = type(value)
    if value == nil then
        return "null"
    elseif valueType == "boolean" then
        if value then
            return "true"
        end
        return "false"
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        if value == math.floor(value) then
            return tostring(math.floor(value))
        end
        return tostring(value)
    elseif valueType == "string" then
        return jsonEncodeString(value)
    elseif valueType == "table" then
        local arr, count = isArray(value)
        if arr then
            local parts = {}
            for i = 1, count do
                parts[i] = jsonEncodeValue(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = jsonEncodeString(tostring(k)) .. ":" .. jsonEncodeValue(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local jsonDecodeValue

---@param s string
---@param i integer
---@return integer
---@nodiscard
local function jsonSkipWhitespace(s, i)
    while i <= #s do
        local ch = string.sub(s, i, i)
        if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
            return i
        end
        i = i + 1
    end
    return i
end

---@param s string
---@param i integer
---@return string|nil
---@return integer|string
---@nodiscard
local function jsonDecodeString(s, i)
    if string.sub(s, i, i) ~= '"' then return nil, "expected string" end
    i = i + 1
    local result = ""
    while i <= #s do
        local ch = string.sub(s, i, i)
        if ch == '"' then
            return result, i + 1
        elseif ch == "\\" then
            local nxt = string.sub(s, i + 1, i + 1)
            if nxt == '"' then result = result .. '"'
            elseif nxt == "\\" then result = result .. "\\"
            elseif nxt == "/" then result = result .. "/"
            elseif nxt == "n" then result = result .. "\n"
            elseif nxt == "r" then result = result .. "\r"
            elseif nxt == "t" then result = result .. "\t"
            elseif nxt == "b" then result = result .. "\b"
            elseif nxt == "f" then result = result .. "\f"
            elseif nxt == "u" then
                local hex = string.sub(s, i + 2, i + 5)
                if #hex ~= 4 then return nil, "bad unicode" end
                local code = tonumber(hex, 16)
                if not code then return nil, "bad unicode" end
                if code < 128 then
                    result = result .. string.char(code)
                else
                    result = result .. "?"
                end
                i = i + 4
            else
                return nil, "bad escape"
            end
            i = i + 2
        else
            result = result .. ch
            i = i + 1
        end
    end
    return nil, "unterminated string"
end

---@param s string
---@param i integer
---@return number|nil
---@return integer|string
---@nodiscard
local function jsonDecodeNumber(s, i)
    local start = i
    if string.sub(s, i, i) == "-" then i = i + 1 end
    while i <= #s do
        local ch = string.sub(s, i, i)
        if (ch >= "0" and ch <= "9") or ch == "." or ch == "e" or ch == "E" or ch == "+" or ch == "-" then
            i = i + 1
        else
            break
        end
    end
    local num = tonumber(string.sub(s, start, i - 1))
    if num == nil then return nil, "bad number" end
    return num, i
end

---@param s string
---@param i integer
---@return table|nil
---@return integer|string
---@nodiscard
local function jsonDecodeArray(s, i)
    i = i + 1
    local result = {}
    i = jsonSkipWhitespace(s, i)
    if string.sub(s, i, i) == "]" then return result, i + 1 end
    while i <= #s do
        local v, ni = jsonDecodeValue(s, i)
        if v == nil and ni == nil then return nil, "bad array value" end
        result[#result + 1] = v
        i = jsonSkipWhitespace(s, ni)
        local ch = string.sub(s, i, i)
        if ch == "]" then return result, i + 1 end
        if ch ~= "," then return nil, "expected , or ]" end
        i = jsonSkipWhitespace(s, i + 1)
    end
    return nil, "unterminated array"
end

---@param s string
---@param i integer
---@return table|nil
---@return integer|string
---@nodiscard
local function jsonDecodeObject(s, i)
    i = i + 1
    local result = {}
    i = jsonSkipWhitespace(s, i)
    if string.sub(s, i, i) == "}" then return result, i + 1 end
    while i <= #s do
        i = jsonSkipWhitespace(s, i)
        local key, ni = jsonDecodeString(s, i)
        if key == nil then return nil, "expected object key" end
        i = jsonSkipWhitespace(s, ni)
        if string.sub(s, i, i) ~= ":" then return nil, "expected :" end
        i = jsonSkipWhitespace(s, i + 1)
        local v, vi = jsonDecodeValue(s, i)
        if v == nil and vi == nil then return nil, "bad object value" end
        result[key] = v
        i = jsonSkipWhitespace(s, vi)
        local ch = string.sub(s, i, i)
        if ch == "}" then return result, i + 1 end
        if ch ~= "," then return nil, "expected , or }" end
        i = i + 1
    end
    return nil, "unterminated object"
end

---@param s string
---@param i integer
---@return any|nil, integer|string|nil
---@nodiscard
jsonDecodeValue = function(s, i)
    i = jsonSkipWhitespace(s, i)
    local ch = string.sub(s, i, i)
    if ch == '"' then
        return jsonDecodeString(s, i)
    elseif ch == "{" then
        return jsonDecodeObject(s, i)
    elseif ch == "[" then
        return jsonDecodeArray(s, i)
    elseif ch == "t" and string.sub(s, i, i + 3) == "true" then
        return true, i + 4
    elseif ch == "f" and string.sub(s, i, i + 4) == "false" then
        return false, i + 5
    elseif ch == "n" and string.sub(s, i, i + 3) == "null" then
        return nil, i + 4
    elseif ch == "-" or (ch >= "0" and ch <= "9") then
        return jsonDecodeNumber(s, i)
    end
    return nil, nil
end

---@param value any
---@return string
---@nodiscard
function Json.encode(value)
    return jsonEncodeValue(value)
end

---@param text string
---@return any|nil
---@nodiscard
function Json.decode(text)
    if type(text) ~= "string" or text == "" then return nil end
    local value, _ = jsonDecodeValue(text, 1)
    return value
end

return Json
