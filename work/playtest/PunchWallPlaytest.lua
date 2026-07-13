local RunService = game:GetService("RunService")

local function waitFor(parent, name, timeout)
	local started = os.clock()
	local child = parent:FindFirstChild(name)
	while not child and os.clock() - started < timeout do
		task.wait(0.1)
		child = parent:FindFirstChild(name)
	end
	assert(child, ("Missing %s under %s"):format(name, parent:GetFullName()))
	return child
end

local function countChildren(parent)
	local count = 0
	for _, _ in ipairs(parent:GetChildren()) do
		count += 1
	end
	return count
end

print("[PunchWallTest] Starting")
print("[PunchWallTest] RunService before:", RunService:IsRunning())

local serverScriptService = game:GetService("ServerScriptService")
local starterPlayer = game:GetService("StarterPlayer")
local replicatedStorage = game:GetService("ReplicatedStorage")

assert(serverScriptService:FindFirstChild("PunchWallBootstrap"), "Server bootstrap script missing")
assert(starterPlayer.StarterPlayerScripts:FindFirstChild("PunchWallClient"), "Client HUD script missing")
assert(workspace:FindFirstChild("PunchWallRPG"), "Static preview map missing")

RunService:Run()
task.wait(4)

local root = waitFor(workspace, "PunchWallRPG", 4)
local walls = waitFor(root, "Walls", 2)
local interactables = waitFor(root, "Interactables", 2)
local remotes = waitFor(replicatedStorage, "PunchWallEvents", 2)

local wallCount = countChildren(walls)
local interactableCount = countChildren(interactables)

assert(wallCount >= 7, "Expected at least 7 playable walls, got " .. wallCount)
assert(interactableCount >= 9, "Expected training/shop/pet/rebirth interactables, got " .. interactableCount)
assert(remotes:FindFirstChild("Notify"), "Notify remote missing")
assert(remotes:FindFirstChild("StatsChanged"), "StatsChanged remote missing")

local brickWall = assert(walls:FindFirstChild("Brick Wall"), "Brick Wall missing")
assert(brickWall:GetAttribute("MaxHP") == 120, "Brick Wall MaxHP mismatch")
assert(brickWall:FindFirstChildOfClass("ClickDetector"), "Brick Wall has no ClickDetector")

local titanWall = assert(walls:FindFirstChild("Titan Server Wall"), "Titan Server Wall missing")
assert(titanWall:GetAttribute("MaxHP") == 5000000, "Titan wall MaxHP mismatch")
assert(interactables:FindFirstChild("Pet Egg Machine"), "Pet egg machine missing")
assert(interactables:FindFirstChild("Rebirth Shrine"), "Rebirth shrine missing")

print(("[PunchWallTest] PASS wallCount=%d interactableCount=%d brickHP=%s titanHP=%s"):format(
	wallCount,
	interactableCount,
	tostring(brickWall:GetAttribute("MaxHP")),
	tostring(titanWall:GetAttribute("MaxHP"))
))

RunService:Stop()
