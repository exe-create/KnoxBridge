require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

local Review = {}
local Panel = ISPanel:derive("KnoxBridgeModuleReviewPanel")
local MANIFEST_FILE = "KnoxBridge/module-review.txt"
local DECISIONS_FILE = "KnoxBridge/module-decisions.txt"
local MANIFEST_HEADER = "KNOXBRIDGE-MODULES-2"
local DECISIONS_HEADER = "KNOXBRIDGE-DECISIONS-2"
local LEGACY_DECISIONS_HEADER = "KNOXBRIDGE-DECISIONS-1"
local DECISIONS_COMMIT = "KNOXBRIDGE-COMMIT-1"
local BUTTON_KEY = "knoxBridgeModuleReviewButton"
local PANEL_KEY = "knoxBridgeModuleReviewPanel"

local function splitTsv(line, expected)
    local fields, cursor = {}, 1
    for index = 1, expected - 1 do
        local delimiter = string.find(line, "\t", cursor, true)
        if not delimiter then return nil end
        fields[index] = string.sub(line, cursor, delimiter - 1)
        cursor = delimiter + 1
    end
    fields[expected] = string.sub(line, cursor)
    if string.find(fields[expected], "\t", 1, true) then return nil end
    return fields
end

local function validHash(hash)
    return type(hash) == "string" and #hash == 64 and not string.find(hash, "[^0-9a-f]")
end

local function readLines(path)
    local ok, reader = pcall(getFileReader, path, false)
    if not ok or not reader then return nil end
    local lines = {}
    local readOk, readError = pcall(function()
        while true do
            local line = reader:readLine()
            if not line then break end
            lines[#lines + 1] = tostring(line)
        end
    end)
    pcall(function() reader:close() end)
    if not readOk then return nil, tostring(readError) end
    return lines
end

local function parseManifest(lines)
    if not lines or lines[1] ~= MANIFEST_HEADER then return nil, "Bridge module list is not available yet." end
    local modules = {}
    for index = 2, #lines do
        if lines[index] ~= "" then
            local fields = splitTsv(lines[index], 7)
            if not fields or (fields[3] ~= "" and not validHash(fields[3])) then
                return nil, "Bridge module list is invalid. No trust changes were written."
            end
            modules[#modules + 1] = {
                id = fields[1], version = fields[2], hash = fields[3], name = fields[4],
                author = fields[5], state = fields[6], jarName = fields[7],
            }
        end
    end
    table.sort(modules, function(a, b)
        local left = string.lower(a.name .. a.id)
        local right = string.lower(b.name .. b.id)
        return left < right
    end)
    return modules
end

local function parseDecisionQueue(lines)
    local pending = {}
    local version2 = lines and lines[1] == DECISIONS_HEADER
    local version1 = lines and lines[1] == LEGACY_DECISIONS_HEADER
    if not lines or #lines < 2 or (not version1 and not version2)
        or lines[#lines] ~= DECISIONS_COMMIT then return pending end
    for index = 2, #lines - 1 do
        local fields = splitTsv(lines[index], version2 and 3 or 2)
        if fields and validHash(fields[1]) and (fields[2] == "allow" or fields[2] == "deny") then
            local remember = version1 or fields[3] == "remember"
            if version1 or remember or fields[3] == "once" then
                pending[fields[1]] = { decision = fields[2], remember = remember }
            end
        end
    end
    return pending
end

local function readQueuedDecisions()
    return parseDecisionQueue(readLines(DECISIONS_FILE))
end

local function saveQueuedDecisions(pending)
    local content = Review.serializeDecisions(pending)
    local ok, writer = pcall(getFileWriter, DECISIONS_FILE, true, false)
    if not ok or not writer then return false, "Could not open the Bridge settings file." end
    local writeOk, writeError = pcall(function() writer:write(content) end)
    pcall(function() writer:close() end)
    if not writeOk then return false, tostring(writeError) end
    return true
end

function Review.serializeDecisions(pending)
    local hashes = {}
    for hash, choice in pairs(pending) do
        local decision = type(choice) == "table" and choice.decision or choice
        if validHash(hash) and (decision == "allow" or decision == "deny") then hashes[#hashes + 1] = hash end
    end
    table.sort(hashes)
    local content = "KNOXBRIDGE-DECISIONS-2\n"
    for _, hash in ipairs(hashes) do
        local choice = pending[hash]
        local decision = type(choice) == "table" and choice.decision or choice
        local remember = type(choice) ~= "table" or choice.remember ~= false
        content = content .. hash .. "\t" .. decision .. "\t" .. (remember and "remember" or "once") .. "\n"
    end
    content = content .. DECISIONS_COMMIT .. "\n"
    return content
end

local function canAllow(module)
    return validHash(module.hash) and not string.find(module.state, "^NOT BRIDGE%-COMPATIBLE")
        and not string.find(module.state, "^NOT A MODULE") and not string.find(module.state, "^INCOMPATIBLE")
end

Review.parseManifest = parseManifest
Review.parseDecisionQueue = parseDecisionQueue
Review.validHash = validHash
Review.canAllow = canAllow
function Review.choiceChangesLoadedSet(module, decision)
    return (decision == "allow" and module.state ~= "ALLOWED")
        or (decision == "deny" and module.state == "ALLOWED")
end

function Review.hasPendingChoice(pending, module)
    return module ~= nil and validHash(module.hash) and pending[module.hash] ~= nil or false
end

function Review.pendingRestartRequired(modules, pending)
    for _, candidate in ipairs(modules) do
        local choice = candidate.hash ~= "" and pending[candidate.hash] or nil
        if choice and Review.choiceChangesLoadedSet(candidate, choice.decision) then return true end
    end
    return false
end

function Review.bindSelectionHandler(list, panel)
    list:setOnMouseDownFunction(panel, function(target, module)
        target.selectedModule = module
        target:showSelection()
    end)
end

function Panel:new(x, y, width, height, modules, manifestError)
    local object = ISPanel:new(x, y, width, height)
    setmetatable(object, self)
    self.__index = self
    object.modules = modules or {}
    object.manifestError = manifestError
    object.pending = readQueuedDecisions()
    object.rememberChoices = false
    object.startupGate = Review.startupGate == true
    object.restartRequired = false
    object.statusText = "Unknown JARs are blocked until approved. Review choices before entering a world."
    object:initialise()
    object:instantiate()
    object.backgroundColor = { r = 0.04, g = 0.05, b = 0.06, a = 0.97 }
    object.borderColor = { r = 0.55, g = 0.62, b = 0.68, a = 0.95 }
    object.moveWithMouse = true
    return object
end

function Panel:createChildren()
    local margin = 18
    local header = ISLabel:new(margin, 12, 26, "KnoxBridge — Java module review", 1, 1, 1, 1, UIFont.Medium, true)
    header:initialise()
    self:addChild(header)
    local help = ISLabel:new(margin, 40, 22,
        "Unknown JARs stay blocked by default. Author names are mod.info claims, not verified identities.",
        0.88, 0.9, 0.92, 1, UIFont.Small, true)
    help:initialise()
    self:addChild(help)

    local listWidth = math.floor(self.width * 0.54)
    self.moduleList = ISScrollingListBox:new(margin, 72, listWidth, self.height - 154)
    self.moduleList:initialise()
    self.moduleList.itemheight = 52
    self.moduleList.drawBorder = true
    self.moduleList.doDrawItem = function(list, y, item, alternate)
        if alternate then list:drawRect(0, y, list:getWidth(), list.itemheight, 0.12, 0.1, 0.12, 0.14) end
        local module = item.item
        local queued = module.hash ~= "" and self.pending[module.hash] or nil
        local state = queued and (string.upper(queued.decision) .. (queued.remember and " REMEMBERED" or " ONCE NEXT LAUNCH")) or module.state
        list:drawText(module.jarName .. "  —  " .. state, 8, y + 4, 0.95, 0.95, 0.95, 1, UIFont.Small)
        list:drawText(module.name .. "  |  " .. module.id, 8, y + 25, 0.72, 0.78, 0.82, 1, UIFont.Small)
        return y + list.itemheight
    end
    self:addChild(self.moduleList)

    local rightX = margin + listWidth + 18
    local rightWidth = self.width - rightX - margin
    self.detail = ISLabel:new(rightX, 78, 20, "Select a JAR to review its details.", 0.95, 0.95, 0.95, 1, UIFont.Small, true)
    self.detail:initialise()
    self:addChild(self.detail)
    self.hashLabel1 = ISLabel:new(rightX, 116, 20, "", 0.78, 0.84, 0.88, 1, UIFont.Small, true)
    self.hashLabel1:initialise()
    self:addChild(self.hashLabel1)
    self.hashLabel2 = ISLabel:new(rightX, 138, 20, "", 0.78, 0.84, 0.88, 1, UIFont.Small, true)
    self.hashLabel2:initialise()
    self:addChild(self.hashLabel2)
    self.idLabel = ISLabel:new(rightX, 174, 20, "", 0.82, 0.86, 0.88, 1, UIFont.Small, true)
    self.idLabel:initialise()
    self:addChild(self.idLabel)
    self.versionLabel = ISLabel:new(rightX, 198, 20, "", 0.82, 0.86, 0.88, 1, UIFont.Small, true)
    self.versionLabel:initialise()
    self:addChild(self.versionLabel)
    self.stateLabel = ISLabel:new(rightX, 222, 20, "", 0.82, 0.86, 0.88, 1, UIFont.Small, true)
    self.stateLabel:initialise()
    self:addChild(self.stateLabel)
    self.allowButton = ISButton:new(rightX, 264, rightWidth, 34, "Allow exact JAR", self, self.onAllow)
    self.allowButton:initialise()
    self:addChild(self.allowButton)
    self.denyButton = ISButton:new(rightX, 306, rightWidth, 34, "Keep JAR denied", self, self.onDeny)
    self.denyButton:initialise()
    self:addChild(self.denyButton)
    self.rememberButton = ISButton:new(margin, self.height - 52, 240, 34, "[ ] Remember next choice", self, self.onToggleRemember)
    self.rememberButton:initialise()
    self.rememberButton.tooltip = "Save the next Allow or Deny choice for this exact JAR hash across launches."
    self:addChild(self.rememberButton)
    self.continueButton = ISButton:new(self.width - 258, self.height - 52, 240, 34, "Continue", self, self.onClose)
    self.continueButton:initialise()
    self:addChild(self.continueButton)
    self.statusLabel = ISLabel:new(margin, self.height - 68, 18, self.statusText, 0.86, 0.88, 0.9, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)

    Review.bindSelectionHandler(self.moduleList, self)
    self:refreshList()
    self:showSelection()
end

function Panel:refreshList()
    self.moduleList:clear()
    for _, module in ipairs(self.modules) do
        self.moduleList:addItem(module.jarName .. " — " .. module.state, module)
    end
    if #self.modules > 0 and not self.selectedModule then
        self.moduleList.selected = 1
        self.selectedModule = self.modules[1]
    end
end

function Panel:showSelection()
    local module = self.selectedModule
    if not module then
        self.detail:setName(self.manifestError or "No enabled Java archive files were found.")
        self.hashLabel1:setName("")
        self.hashLabel2:setName("")
        self.idLabel:setName("")
        self.versionLabel:setName("")
        self.stateLabel:setName("Only JARs with a valid Bridge descriptor can be allowed; other JARs remain blocked.")
        self.allowButton:setEnable(false)
        self.denyButton:setEnable(false)
        self.denyButton:setTitle("Keep JAR denied")
        return
    end
    self.detail:setName(module.jarName .. "  |  " .. module.name .. "  |  " .. module.author .. " (unverified claim)")
    local hash = module.hash ~= "" and module.hash or "unavailable"
    self.hashLabel1:setName("SHA-256: " .. string.sub(hash, 1, 32))
    self.hashLabel2:setName(string.sub(hash, 33))
    self.idLabel:setName("Module ID: " .. module.id)
    self.versionLabel:setName("Version: " .. module.version)
    self.stateLabel:setName("State: " .. module.state)
    local queued = module.hash ~= "" and self.pending[module.hash] or nil
    local queuedDecision = queued and queued.decision or nil
    local queuedMatches = queued and queued.remember == self.rememberChoices
    local compatible = canAllow(module)
    self.allowButton:setEnable(compatible and (module.state ~= "ALLOWED" or self.rememberChoices)
        and (queuedDecision ~= "allow" or not queuedMatches))
    local hasPending = Review.hasPendingChoice(self.pending, module)
    self.denyButton:setTitle(hasPending and "Undo pending choice" or "Keep JAR denied")
    self.denyButton:setEnable(hasPending or (validHash(module.hash) and (module.state ~= "DENIED" or self.rememberChoices)
        and (queuedDecision ~= "deny" or not queuedMatches)))
    self.continueButton:setTitle(self.restartRequired and "Quit to restart" or "Continue")
end

function Panel:queueDecision(decision)
    local module = self.selectedModule
    if not module or not validHash(module.hash) then return end
    if decision == "allow" and not canAllow(module) then return end
    local previous = self.pending[module.hash]
    if previous and previous.decision == decision and previous.remember == self.rememberChoices then return end
    self.pending[module.hash] = { decision = decision, remember = self.rememberChoices }
    local ok, reason = saveQueuedDecisions(self.pending)
    if not ok then
        self.pending[module.hash] = previous
        self.statusText = "Could not save the choice: " .. tostring(reason)
    else
        local changesLoadedSet = Review.choiceChangesLoadedSet(module, decision)
        self.restartRequired = Review.pendingRestartRequired(self.modules, self.pending)
        self.statusText = changesLoadedSet
            and "Saved. Quit and restart Project Zomboid to apply this change."
            or "Saved. The blocked default is unchanged; no restart is needed."
    end
    self.statusLabel:setName(self.statusText)
    self:refreshList()
    self:showSelection()
end

function Panel:onAllow() self:queueDecision("allow") end
function Panel:onDeny()
    if Review.hasPendingChoice(self.pending, self.selectedModule) then return self:onUndo() end
    self:queueDecision("deny")
end
function Panel:onUndo()
    local module = self.selectedModule
    if not Review.hasPendingChoice(self.pending, module) then return end
    local previous = self.pending[module.hash]
    self.pending[module.hash] = nil
    local ok, reason = saveQueuedDecisions(self.pending)
    if not ok then
        self.pending[module.hash] = previous
        self.statusText = "Could not undo the choice: " .. tostring(reason)
    else
        self.restartRequired = Review.pendingRestartRequired(self.modules, self.pending)
        self.statusText = "Pending choice removed. "
            .. (self.restartRequired and "Other choices still require one restart." or "No restart is needed.")
    end
    self.statusLabel:setName(self.statusText)
    self:refreshList()
    self:showSelection()
end
function Panel:onToggleRemember()
    self.rememberChoices = not self.rememberChoices
    self.rememberButton:setTitle(self.rememberChoices and "[x] Remember next choice" or "[ ] Remember next choice")
    self:showSelection()
end
function Panel:onClose()
    if self.restartRequired then
        local ok, reason = pcall(function() getCore():quit() end)
        if not ok then
            self.statusText = "Saved. Restart Project Zomboid to apply. " .. tostring(reason)
            self.statusLabel:setName(self.statusText)
        end
        return
    end
    self.startupGate = false
    Review.startupGate = false
    self:setVisible(false)
end

local function readModules()
    local lines, readError = readLines(MANIFEST_FILE)
    local modules, parseError = parseManifest(lines)
    if not modules then
        print("[KnoxBridge] Module review unavailable: " .. tostring(readError or parseError))
        return {}, readError or parseError
    end
    return modules, nil
end

function Review.layout(screenWidth, screenHeight, startupGate)
    local width = startupGate and math.max(360, screenWidth - 24) or math.max(360, math.min(1040, screenWidth - 24))
    local height = startupGate and math.max(320, screenHeight - 24) or math.max(320, math.min(680, screenHeight - 24))
    return { x = math.floor((screenWidth - width) / 2), y = math.floor((screenHeight - height) / 2), width = width, height = height }
end

function Review.open()
    local screen = MainScreen and MainScreen.instance or nil
    if not screen or screen.inGame then return false end
    if screen[PANEL_KEY] then
        screen[PANEL_KEY].modules, screen[PANEL_KEY].manifestError = readModules()
        screen[PANEL_KEY].selectedModule = nil
        screen[PANEL_KEY]:refreshList()
        screen[PANEL_KEY]:setVisible(true)
        screen[PANEL_KEY]:bringToTop()
        return true
    end
    local core = getCore()
    local bounds = Review.layout(core:getScreenWidth(), core:getScreenHeight(), Review.startupGate)
    local modules, manifestError = readModules()
    local panel = Panel:new(bounds.x, bounds.y, bounds.width, bounds.height, modules, manifestError)
    screen:addChild(panel)
    screen[PANEL_KEY] = panel
    panel:setVisible(true)
    return true
end

Review.autoPending = false

function Review.ensureButton()
    local screen = MainScreen and MainScreen.instance or nil
    if not screen or screen.inGame or (screen.getIsVisible and not screen:getIsVisible()) then return false end
    if screen[BUTTON_KEY] then return true end
    local core = getCore()
    local label = "Review Java Mods"
    local width = math.max(176, getTextManager():MeasureStringX(UIFont.Small, label) + 32)
    local button = ISButton:new(core:getScreenWidth() - width - 18, 18, width, 32, label, Review, Review.open)
    button:initialise()
    button:setAnchorLeft(false)
    button:setAnchorRight(true)
    button:setAnchorTop(true)
    button:setAnchorBottom(false)
    button.backgroundColor = { r = 0.14, g = 0.25, b = 0.34, a = 0.96 }
    button.backgroundColorMouseOver = { r = 0.20, g = 0.38, b = 0.50, a = 1 }
    button.tooltip = "Review enabled-mod JAR files; unknown files stay blocked until approved."
    screen:addChild(button)
    screen[BUTTON_KEY] = button
    return true
end

local function onMainMenuEnter()
    Review.ensureButton()
    Review.startupGate = true
    Review.autoPending = true
end

local function update()
    Review.ensureButton()
    if Review.autoPending and Review.open() then Review.autoPending = false end
end

local function onResolutionChange()
    local screen = MainScreen and MainScreen.instance or nil
    if not screen then return end
    local wasOpen = screen[PANEL_KEY] and screen[PANEL_KEY]:getIsVisible()
    if screen[BUTTON_KEY] then screen:removeChild(screen[BUTTON_KEY]); screen[BUTTON_KEY] = nil end
    if screen[PANEL_KEY] then screen:removeChild(screen[PANEL_KEY]); screen[PANEL_KEY] = nil end
    Review.ensureButton()
    if wasOpen then Review.open() end
end

local function onGameStart()
    local screen = MainScreen and MainScreen.instance or nil
    if not screen then return end
    if screen[BUTTON_KEY] then screen:removeChild(screen[BUTTON_KEY]); screen[BUTTON_KEY] = nil end
    if screen[PANEL_KEY] then screen:removeChild(screen[PANEL_KEY]); screen[PANEL_KEY] = nil end
end

Events.OnMainMenuEnter.Add(onMainMenuEnter)
Events.OnTick.Add(update)
Events.OnResolutionChange.Add(onResolutionChange)
Events.OnGameStart.Add(onGameStart)

return Review
