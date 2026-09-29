package.preload["ISUI/ISPanel"] = function()
    local panel = {}
    function panel:derive(name) return setmetatable({ Type = name }, { __index = self }) end
    ISPanel = panel
    return panel
end
package.preload["ISUI/ISButton"] = function() ISButton = {}; return ISButton end
package.preload["ISUI/ISScrollingListBox"] = function() ISScrollingListBox = {}; return ISScrollingListBox end

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
local selectionPanel = { showCount = 0 }
function selectionPanel:showSelection() self.showCount = self.showCount + 1 end
local selectionList = {}
function selectionList:setOnMouseDownFunction(target, callback)
    self.target = target
    self.onmousedown = callback
end
review.bindSelectionHandler(selectionList, selectionPanel)
selectionList.onmousedown(selectionList.target, compatible)
assert(selectionPanel.selectedModule == compatible and selectionPanel.showCount == 1,
    "native list click callback must receive the panel target and selected module")

for _, size in ipairs({ { 800, 600 }, { 1920, 1080 }, { 640, 480 } }) do
    local bounds = review.layout(size[1], size[2])
    assert(bounds.x >= 0 and bounds.y >= 0 and bounds.x + bounds.width <= size[1]
        and bounds.y + bounds.height <= size[2], "review layout exceeded the screen")
end
local gate = review.layout(1920, 1080, true)
assert(gate.x == 12 and gate.y == 12 and gate.width == 1896 and gate.height == 1056,
    "startup review gate must cover the main menu")

print("KnoxBridge Workshop UI offline checks PASS checks=31")
