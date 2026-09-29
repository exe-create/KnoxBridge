require "ISUI/ISButton"

local SupportButton = {}
local SUPPORT_URL = "https://ko-fi.com/drganja"
local LABEL = "Buy Me A Coffee!"
local ICON = "media/ui/knoxKofi.png"
local BUTTON_KEY = "knoxBridgeSupportButton"

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function SupportButton.layout(screenWidth, screenHeight, fontHeight, textWidth)
    local scale = clamp((tonumber(fontHeight) or 14) / 14, 0.8, 1.75)
    local margin = math.max(12, math.floor(18 * scale))
    local iconSize = math.max(18, math.floor((tonumber(fontHeight) or 14) + 4))
    local height = math.max(30, math.floor((tonumber(fontHeight) or 14) + 12))
    local width = math.ceil((tonumber(textWidth) or 120) + iconSize + math.floor(32 * scale))
    width = math.min(width, math.max(0, screenWidth - margin * 2))
    return {
        x = math.max(margin, screenWidth - margin - width),
        y = margin,
        width = width,
        height = height,
        iconSize = math.min(iconSize, height - 6),
    }
end

local function removeButton(screen)
    if screen and screen[BUTTON_KEY] then
        screen:removeChild(screen[BUTTON_KEY])
        screen[BUTTON_KEY] = nil
    end
end

function SupportButton.openSupportPage()
    if isSteamOverlayEnabled and isSteamOverlayEnabled() then
        activateSteamOverlayToWebPage(SUPPORT_URL)
        return true
    end
    if openUrl then
        openUrl(SUPPORT_URL)
        return true
    end
    return false
end

function SupportButton.onClick()
    local ok, result = pcall(SupportButton.openSupportPage)
    if not ok then print("[KnoxBridge] Could not open the Ko-fi page: " .. tostring(result)) end
end

function SupportButton.ensure()
    local screen = MainScreen and MainScreen.instance or nil
    if not screen then return false end
    if screen.inGame then
        removeButton(screen)
        return false
    end
    if not screen.getIsVisible or not screen:getIsVisible() then return false end
    if screen[BUTTON_KEY] then return true end

    local core = getCore()
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, LABEL)
    local bounds = SupportButton.layout(core:getScreenWidth(), core:getScreenHeight(), fontHeight, textWidth)
    if bounds.width <= 0 then return false end
    bounds.y = bounds.y + 42

    local button = ISButton:new(bounds.x, bounds.y, bounds.width, bounds.height, LABEL,
        SupportButton, SupportButton.onClick)
    button:initialise()
    button:setAnchorLeft(false)
    button:setAnchorRight(true)
    button:setAnchorTop(true)
    button:setAnchorBottom(false)
    button.iconTexture = getTexture(ICON)
    button.joypadTextureWH = bounds.iconSize
    button.backgroundColor = { r = 0.72, g = 0.20, b = 0.12, a = 0.92 }
    button.backgroundColorMouseOver = { r = 0.92, g = 0.28, b = 0.16, a = 1.0 }
    button.textColor = { r = 1, g = 1, b = 1, a = 1 }
    button.tooltip = "Support KnoxBridge development on Ko-fi"
    button.isBaseBackgroundVisible = true
    button.isHighlightedBackgroundVisible = true
    button:setVisible(screen.bottomPanel == nil or screen.bottomPanel:getIsVisible())
    screen:addChild(button)
    screen[BUTTON_KEY] = button
    return true
end

local function update()
    if SupportButton.ensure() then
        local screen = MainScreen.instance
        local button = screen[BUTTON_KEY]
        if button and screen.bottomPanel then button:setVisible(screen.bottomPanel:getIsVisible()) end
    end
end

local function onResolutionChange()
    local screen = MainScreen and MainScreen.instance or nil
    removeButton(screen)
    SupportButton.ensure()
end

local function onGameStart()
    removeButton(MainScreen and MainScreen.instance or nil)
end

Events.OnMainMenuEnter.Add(SupportButton.ensure)
Events.OnTick.Add(update)
Events.OnResolutionChange.Add(onResolutionChange)
Events.OnGameStart.Add(onGameStart)

return SupportButton
