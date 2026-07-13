$ErrorActionPreference = "Stop"

$script = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowsDir = "F:\Roblox\PuchWall\work\automation\flows"

node $script --flows-dir $flowsDir --all
