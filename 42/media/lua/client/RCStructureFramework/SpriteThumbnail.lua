require("ISUI/ISUIElement")

---@class RCStructureSpriteThumbnail : ISUIElement
RCStructureSpriteThumbnail = ISUIElement:derive("RCStructureSpriteThumbnail")

---@type table<string, IsoSprite>
local SPRITE_CACHE = {}

---@param spriteName string
---@return IsoSprite
---@nodiscard
local function getCachedSprite(spriteName)
    local cached = SPRITE_CACHE[spriteName]
    if not cached then
        cached = IsoSprite.new()
        cached:LoadSingleTexture(spriteName)
        SPRITE_CACHE[spriteName] = cached
    end
    return cached
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param spriteName string?
---@return RCStructureSpriteThumbnail
function RCStructureSpriteThumbnail:new(x, y, w, h, spriteName)
    local o = ISUIElement.new(self, x, y, w, h)
    o.spriteName = spriteName
    o.bgColor = { r = 0.08, g = 0.08, b = 0.10, a = 1 }
    o.borderColor = { r = 0.40, g = 0.40, b = 0.45, a = 1 }
    o.padding = 2
    return o
end

---@param spriteName string?
---@return nil
function RCStructureSpriteThumbnail:setSpriteName(spriteName)
    self.spriteName = spriteName
end

---@return nil
function RCStructureSpriteThumbnail:prerender()
    self:drawRect(0, 0, self.width, self.height,
        self.bgColor.a, self.bgColor.r, self.bgColor.g, self.bgColor.b)

    if self.spriteName then
        local sprite = getCachedSprite(self.spriteName)
        local texture = sprite and sprite:getTextureForCurrentFrame()
        if texture then
            local tw = texture:getWidth()
            local th = texture:getHeight()
            if tw > 0 and th > 0 then
                local available = math.max(1, self.width - self.padding * 2)
                local availableH = math.max(1, self.height - self.padding * 2)
                local scale = math.min(available / tw, availableH / th)
                local drawW = math.max(1, math.floor(tw * scale))
                local drawH = math.max(1, math.floor(th * scale))
                local drawX = math.floor((self.width - drawW) / 2)
                local drawY = math.floor((self.height - drawH) / 2)
                self:drawTextureScaled(texture, drawX, drawY, drawW, drawH, 1, 1, 1, 1)
            end
        end
    end

    self:drawRectBorder(0, 0, self.width, self.height,
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

---@return nil
function RCStructureSpriteThumbnail:render()
end

return RCStructureSpriteThumbnail
