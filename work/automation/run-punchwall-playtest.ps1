$ErrorActionPreference = "Stop"

$script = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flow = "F:\Roblox\PuchWall\work\automation\flows\punchwall-smoke.json"

node $script --flow $flow
