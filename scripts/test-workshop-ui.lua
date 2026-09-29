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

local decisions = review.serializeDecisions({ [hash] = "allow", [string.rep("c", 64)] = "deny", invalid = "allow" })
assert(decisions:find("KNOXBRIDGE-DECISIONS-1", 1, true), "decision format header missing")
assert(decisions:find(hash .. "\tallow", 1, true), "allow choice missing from queue")
assert(decisions:find(string.rep("c", 64) .. "\tdeny", 1, true), "deny choice missing from queue")
assert(decisions:find("KNOXBRIDGE-COMMIT-1", 1, true), "partial-write guard missing")
assert(not decisions:find("invalid", 1, true), "invalid hash entered trust queue")

for _, size in ipairs({ { 800, 600 }, { 1920, 1080 }, { 640, 480 } }) do
    local bounds = review.layout(size[1], size[2])
    assert(bounds.x >= 0 and bounds.y >= 0 and bounds.x + bounds.width <= size[1]
        and bounds.y + bounds.height <= size[2], "review layout exceeded the screen")
end

print("KnoxBridge Workshop UI offline checks PASS checks=17")
