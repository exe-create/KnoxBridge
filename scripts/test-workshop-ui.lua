package.preload["ISUI/ISPanel"] = function()
    local panel = {}
    function panel:derive(name) return setmetatable({ Type = name }, { __index = self }) end
    function panel:new(x, y, width, height)
        return setmetatable({ x = x, y = y, width = width, height = height, children = {} }, { __index = self })
    end
    function panel:initialise() end
    function panel:instantiate() self:createChildren() end
    function panel:addChild(child) self.children[#self.children + 1] = child end
    function panel:setVisible(visible) self.visible = visible end
    function panel:bringToTop() end
    function panel:getIsVisible() return self.visible end
    function panel:removeChild(child)
        for index, value in ipairs(self.children) do
            if value == child then table.remove(self.children, index); break end
        end
    end
    ISPanel = panel
    return panel
end
local function widget(x, y, width, height, name)
    local item = { x = x, y = y, width = width, height = height, name = name }
    function item:initialise() end
    function item:setName(value) self.name = value end
    function item:setTitle(value) self.title = value end
    function item:setEnable(value) self.enabled = value end
    return item
end
package.preload["ISUI/ISButton"] = function()
    ISButton = {}
    function ISButton:new(x, y, width, height, title, target, callback)
        local button = widget(x, y, width, height, title)
        button.title, button.target, button.callback = title, target, callback
        return button
    end
    return ISButton
end
package.preload["ISUI/ISScrollingListBox"] = function()
    ISScrollingListBox = {}
    function ISScrollingListBox:new(x, y, width, height)
        local list = widget(x, y, width, height)
        list.items, list.drawnTexts = {}, {}
        function list:clear() self.items = {} end
        function list:addItem(text, item) self.items[#self.items + 1] = { text = text, item = item } end
        function list:setOnMouseDownFunction(target, callback) self.target, self.onmousedown = target, callback end
        function list:getWidth() return self.width end
        function list:drawRect() end
        function list:drawText(text) self.drawnTexts[#self.drawnTexts + 1] = text end
        return list
    end
    return ISScrollingListBox
end

ISLabel = {}
function ISLabel:new(x, y, height, name)
    return widget(x, y, 0, height, name)
end
UIFont = { Small = {}, Medium = {} }

local decisionsFile
local failNextWrite = false
local failNextClose = false
function getFileReader()
    if not decisionsFile then return nil end
    local lines = {}
    for line in decisionsFile:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    local index = 0
    return {
        readLine = function()
            index = index + 1
            return lines[index]
        end,
        close = function() end,
    }
end
function getFileWriter()
    local content
    return {
        write = function(_, value)
            if failNextWrite then failNextWrite = false; error("fixture write failure") end
            content = value
        end,
        close = function()
            if failNextClose then failNextClose = false; error("fixture close failure") end
            decisionsFile = content
        end,
    }
end

Events = {
    OnMainMenuEnter = { Add = function() end },
    OnTick = { Add = function() end },
    OnResolutionChange = { Add = function() end },
    OnGameStart = { Add = function() end },
}

local review = dofile("workshop/mod/42/media/lua/client/KnoxBridgeModuleReview.lua")
local hash = string.rep("a", 64)
local manifest = {
    "KNOXBRIDGE-MODULES-2",
    "org.example.module\t1.2.3\t" .. hash .. "\tExample Mod\tExample Author\tBLOCKED BY DEFAULT\tmodule.jar",
    "LegacyMod\tunknown\t" .. string.rep("b", 64) .. "\tLegacy Java Mod\tNot provided\tNOT BRIDGE-COMPATIBLE\tlegacy.jar",
}
local modules, err = review.parseManifest(manifest)
assert(modules and #modules == 2, err or "expected both enabled JARs in the review list")
assert(modules[1].jarName == "legacy.jar" or modules[2].jarName == "legacy.jar", "JAR filename missing")
assert(review.validHash(hash), "valid SHA-256 rejected")
assert(not review.validHash("not-a-hash"), "invalid SHA-256 accepted")
local compatible
local unsupported
for _, module in ipairs(modules) do
    if module.id == "org.example.module" then compatible = module else unsupported = module end
end
assert(review.canAllow(compatible), "valid Bridge module should be allowable")
assert(not review.canAllow(unsupported), "unsupported JAR must remain non-allowable")
assert(not review.canAllow({ hash = string.rep("d", 64), state = "NOT A MODULE: KnoxBridge compile-time API only" }),
    "compile-time API JAR must never be loadable")
assert(review.parseManifest({ "wrong-version" }) == nil, "unknown manifest version accepted")
assert(review.parseManifest({ "KNOXBRIDGE-MODULES-2", "bad\trow\tbad\trow" }) == nil,
    "malformed or hashless manifest row accepted")

local decisions = review.serializeDecisions({
    [hash] = { decision = "allow", remember = true },
    [string.rep("c", 64)] = { decision = "deny", remember = false },
    invalid = { decision = "allow", remember = true },
})
assert(decisions:find("KNOXBRIDGE-DECISIONS-2", 1, true), "decision format header missing")
assert(decisions:find(hash .. "\tallow\tremember", 1, true), "remembered allow choice missing from queue")
assert(decisions:find(string.rep("c", 64) .. "\tdeny\tonce", 1, true), "one-time deny choice missing from queue")
assert(decisions:find("KNOXBRIDGE-COMMIT-1", 1, true), "partial-write guard missing")
assert(not decisions:find("invalid", 1, true), "invalid hash entered trust queue")
local legacyQueue = review.parseDecisionQueue({
    "KNOXBRIDGE-DECISIONS-1", hash .. "\tallow", "KNOXBRIDGE-COMMIT-1",
})
assert(legacyQueue[hash].decision == "allow" and legacyQueue[hash].remember,
    "legacy queue choices remain remembered when read by the updated UI")
local onceQueue = review.parseDecisionQueue({
    "KNOXBRIDGE-DECISIONS-2", hash .. "\tallow\tonce", "KNOXBRIDGE-COMMIT-1",
})
assert(onceQueue[hash].decision == "allow" and not onceQueue[hash].remember,
    "one-launch queue is read without upgrading it to a remembered choice")
local malformedQueue, malformedQueueError = review.parseDecisionQueue({
    "KNOXBRIDGE-DECISIONS-2", hash .. "\tallow\tremember", "bad-row", "KNOXBRIDGE-COMMIT-1",
})
assert(malformedQueue == nil and malformedQueueError, "invalid queue row must reject the complete queue")
local conflictingQueue = review.parseDecisionQueue({
    "KNOXBRIDGE-DECISIONS-2", hash .. "\tallow\tremember", hash .. "\tdeny\tonce", "KNOXBRIDGE-COMMIT-1",
})
assert(conflictingQueue == nil, "conflicting duplicate hash must reject the complete queue")
assert(review.choiceChangesLoadedSet(compatible, "allow"), "new allow must request restart to load the module")
assert(not review.choiceChangesLoadedSet(compatible, "deny"), "blocking a default-denied module must not request restart")
assert(not review.choiceChangesLoadedSet({ state = "ALLOWED" }, "allow"), "unchanged allow must not restart")
assert(review.choiceChangesLoadedSet({ state = "ALLOWED" }, "deny"), "denying a loaded module must request restart")
local pendingUndo = { [hash] = { decision = "allow", remember = false } }
assert(review.hasPendingChoice(pendingUndo, compatible), "selected JAR should expose undo for its pending choice")
assert(review.pendingRestartRequired(modules, pendingUndo), "pending allow should keep the single restart requirement")
local loadedModule = { hash = string.rep("e", 64), state = "ALLOWED" }
pendingUndo[loadedModule.hash] = { decision = "deny", remember = true }
pendingUndo[hash] = nil
assert(not review.hasPendingChoice(pendingUndo, compatible), "undo should remove the selected pending choice")
assert(review.pendingRestartRequired({ compatible, loadedModule }, pendingUndo), "undoing one JAR must preserve another JAR's restart requirement")
pendingUndo[loadedModule.hash] = nil
assert(not review.pendingRestartRequired({ compatible, loadedModule }, pendingUndo), "undoing all load-set changes should clear restart requirement")
assert(not review.hasPendingChoice(pendingUndo, unsupported), "unsupported JAR without a queued choice should not expose undo")
local secondModule = {
    id = "org.example.second", version = "2.0", hash = string.rep("f", 64),
    name = "Second Example", author = "Second Author", state = "BLOCKED BY DEFAULT", jarName = "second.jar",
}
local selectionPanel = review.newPanel(0, 0, 1000, 600, { compatible, secondModule }, nil)
assert(selectionPanel.selectedModule == compatible and selectionPanel.moduleList.selected == 1,
    "initial selected module and row must agree")
assert(selectionPanel.detail.name:find("SELECTED JAR: module.jar", 1, true), "details must identify the selected JAR")
assert(selectionPanel.allowButton.title == "Allow selected JAR" and selectionPanel.denyButton.title == "Deny selected JAR",
    "action buttons must identify that actions apply to the selected JAR")
selectionPanel.moduleList.selected = 2
selectionPanel.moduleList.onmousedown(selectionPanel.moduleList.target, secondModule)
assert(selectionPanel.selectedModule == secondModule and selectionPanel.moduleList.selected == 2
    and selectionPanel.detail.name:find("SELECTED JAR: second.jar", 1, true),
    "native list click must synchronize row selection and the named details")
selectionPanel.moduleList.drawnTexts = {}
selectionPanel.moduleList.doDrawItem(selectionPanel.moduleList, 0, { item = secondModule }, false)
assert(selectionPanel.moduleList.drawnTexts[1]:find("SELECTED", 1, true), "selected list row must be visibly marked")
selectionPanel.moduleList.selected = 1
assert(selectionPanel:syncSelection() and selectionPanel.selectedModule == compatible
    and selectionPanel.detail.name:find("SELECTED JAR: module.jar", 1, true),
    "keyboard/list-index changes must synchronize the action target and details")

selectionPanel.moduleList.onmousedown(selectionPanel.moduleList.target, compatible)
selectionPanel:onToggleRemember()
assert(selectionPanel.rememberChoices, "remember toggle must arm one choice")
selectionPanel:onAllow()
assert(selectionPanel.pending[hash].decision == "allow" and selectionPanel.pending[hash].remember,
    "armed next choice should be remembered for this hash")
assert(not selectionPanel.rememberChoices and selectionPanel.rememberButton.title == "[ ] Remember next choice",
    "remember toggle must reset after one successfully saved decision")
selectionPanel.moduleList.onmousedown(selectionPanel.moduleList.target, secondModule)
selectionPanel:onAllow()
assert(selectionPanel.pending[secondModule.hash].decision == "allow" and not selectionPanel.pending[secondModule.hash].remember,
    "following choice must be one-launch unless remember is armed again")
local savedQueue, savedQueueError = review.parseDecisionQueue((function()
    local lines = {}
    for line in decisionsFile:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    return lines
end)())
assert(savedQueue, (savedQueueError or "saved queue could not be parsed") .. "\n" .. tostring(decisionsFile))
assert(savedQueue[hash].remember and not savedQueue[secondModule.hash].remember,
    "saved queue must preserve mixed one-launch/remember decisions")
assert(selectionPanel.restartRequired, "allow choices for blocked modules must request restart")
local quitCalls = 0
getCore = function() return { quit = function() quitCalls = quitCalls + 1 end } end
local reopenedPanel = review.newPanel(0, 0, 1000, 600, { compatible, secondModule }, nil)
assert(not reopenedPanel.rememberChoices and reopenedPanel.restartRequired
    and reopenedPanel.moduleList.selected == 1
    and reopenedPanel.stateLabel.name:find("ALLOW remembered", 1, true),
    "reopening the review should restore queued scope, restart state, and matching selected details")
reopenedPanel:onClose()
assert(quitCalls == 0 and reopenedPanel.continueButton.title == "Confirm quit"
    and reopenedPanel.statusText:find("Restart PZ through Steam", 1, true),
    "first restart action must warn and request confirmation without exiting")
reopenedPanel:onClose()
assert(quitCalls == 1, "confirmed restart action should quit but must not claim to relaunch the game")

decisionsFile = nil
failNextClose = true
local saveFailurePanel = review.newPanel(0, 0, 1000, 600, { compatible }, nil)
saveFailurePanel:onToggleRemember()
saveFailurePanel:onAllow()
assert(saveFailurePanel.rememberChoices and not saveFailurePanel.pending[hash]
    and saveFailurePanel.statusText:find("fixture close failure", 1, true),
    "failed file close must retain the toggle and roll back the pending decision")

for _, size in ipairs({ { 800, 600 }, { 1920, 1080 }, { 640, 480 } }) do
    local bounds = review.layout(size[1], size[2])
    assert(bounds.x >= 0 and bounds.y >= 0 and bounds.x + bounds.width <= size[1]
        and bounds.y + bounds.height <= size[2], "review layout exceeded the screen")
end
local gate = review.layout(1920, 1080, true)
assert(gate.x == 12 and gate.y == 12 and gate.width == 1896 and gate.height == 1056,
    "startup review gate must cover the main menu")

print("KnoxBridge Workshop UI offline checks PASS checks=47")
