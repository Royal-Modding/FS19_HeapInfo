--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 08/01/2021

---@class InfoHud : RoyalHudControl
InfoHud = {}
InfoHud_mt = Class(InfoHud, RoyalHudControl)

function InfoHud:new()
    local width, height = 280, 68

    local style = RoyalHudStyles.getStyle(FS19Style)

    ---@type InfoHud
    local hud = RoyalHudControl:new("heapInfo", 0.5, 0.875, width, height, style, nil, InfoHud_mt)
    hud.panel = RoyalHudPanel:new("heapInfoPanel", 0.5, 0.5, width, height, style, hud)

    ---@type RoyalHudImage[]
    hud.fillTypesIcons = {}
    for i, fillType in ipairs(g_fillTypeManager:getFillTypes()) do
        local iconFilename = fillType.hudOverlayFilename
        if g_screenHeight <= g_referenceScreenHeight then
            iconFilename = fillType.hudOverlayFilenameSmall
        end
        if iconFilename ~= "dataS2/menu/hud/fillTypes/hud_fill_fuel.png" and iconFilename ~= "" then
            local fillIcon = RoyalHudImage:new("fti_" .. i, iconFilename, 10, 10, 50, 50, hud.panel)
            fillIcon:setAlignment(RoyalHud.ALIGNS_VERTICAL_BOTTOM, RoyalHud.ALIGNS_HORIZONTAL_LEFT)
            fillIcon:setIsVisible(false)
            hud.fillTypesIcons[fillType.index] = fillIcon
        end
    end

    hud.fillLevelText = RoyalHudText:new("flt", "", 29, false, width - 17, 16, hud.panel)
    hud.fillLevelText:setAlignment(RoyalHud.ALIGNS_VERTICAL_BOTTOM, RoyalHud.ALIGNS_HORIZONTAL_RIGHT)

    hud.showTime = 0

    return hud
end

function InfoHud:update(dt)
    if self.showTime > 0 then
        self.showTime = self.showTime - dt
    end
end

function InfoHud:draw()
    if self.showTime > 0 then
        self:render()
    end
end

function InfoHud:show(fillType, fillLevel, time)
    time = time or 5000
    self:setFillTypeIconsVisibility(false)
    local fillTypeIcon = self.fillTypesIcons[fillType]
    if fillTypeIcon ~= nil then
        fillTypeIcon:setIsVisible(true)
    end
    self.fillLevelText:setText(string.format("%s l", g_i18n:formatNumber(fillLevel, 0, true)))
    self.showTime = time
end

function InfoHud:setFillTypeIconsVisibility(visible)
    for _, icon in pairs(self.fillTypesIcons) do
        icon:setIsVisible(visible)
    end
end
