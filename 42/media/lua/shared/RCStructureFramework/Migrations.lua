---@class RCStructureFrameworkMigrations
local Migrations = {}

Migrations.CURRENT_PRESET_VERSION = 4

---@param preset table
---@return table
function Migrations.migrateV1ToV2(preset)
    preset.version = 2

    if type(preset.walls) == "table" then
        for i = 1, #preset.walls do
            local w = preset.walls[i]
            if type(w) == "table" and w.slotKind == nil then
                w.slotKind = "wall"
            end
        end
    end

    return preset
end

---@param preset table
---@return table
function Migrations.migrateV2ToV3(preset)
    preset.version = 3
    if type(preset.stairs)     ~= "table" then preset.stairs     = {} end
    if type(preset.furniture)  ~= "table" then preset.furniture  = {} end
    if type(preset.appliances) ~= "table" then preset.appliances = {} end
    return preset
end

---@param preset table
---@return table
function Migrations.migrateV3ToV4(preset)
    preset.version = 4
    if type(preset.decoratives) ~= "table" then preset.decoratives = {} end
    if type(preset.vegetation)  ~= "table" then preset.vegetation  = {} end
    return preset
end

---@param preset table
---@return table
function Migrations.migratePreset(preset)
    if type(preset) ~= "table" then return preset end

    local version = tonumber(preset.version) or 1
    if version < 2 then
        preset = Migrations.migrateV1ToV2(preset)
        version = 2
    end
    if version < 3 then
        preset = Migrations.migrateV2ToV3(preset)
        version = 3
    end
    if version < 4 then
        preset = Migrations.migrateV3ToV4(preset)
    end

    return preset
end

return Migrations
