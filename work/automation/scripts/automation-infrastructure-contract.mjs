#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const currentScriptPath = fileURLToPath(import.meta.url);
const automationRoot = path.resolve(scriptDirectory, "..");
const flowsRoot = path.join(automationRoot, "flows");
const read = (file) => fs.readFileSync(file, "utf8").replace(/\r\n?/g, "\n");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

const automationFiles = [];
function collect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(target);
    else automationFiles.push(target);
  }
}
collect(automationRoot);

const portableFiles = automationFiles.filter((file) => /\.(?:mjs|ps1)$/i.test(file));
const absolutePathHits = [];
for (const file of portableFiles) {
  if (path.resolve(file) === path.resolve(currentScriptPath)) continue;
  const source = read(file);
  if (/F:\\\\Roblox\\\\PuchWall|F:\\Roblox\\PuchWall|C:\\\\Users\\\\|C:\\Users\\/.test(source)) {
    absolutePathHits.push(path.relative(automationRoot, file));
  }
}
check(
  "no_repository_or_profile_absolute_paths",
  absolutePathHits.length === 0,
  `Hardcoded paths remain in: ${absolutePathHits.join(", ")}`,
);

const runnerPath = path.join(scriptDirectory, "flow_runner.mjs");
const runner = read(runnerPath);
const studioMcpClient = read(path.join(scriptDirectory, "studio_mcp_client.mjs"));
check(
  "runner_has_no_first_studio_fallback",
  !runner.includes("studios[0]")
    && !runner.includes("?? studios")
    && runner.includes("resolveStudioCandidate")
    && runner.includes("--studio-instance-id"),
  "The local runner must select exact id/one match and never take the first Studio.",
);
check(
  "runner_waits_for_datamodel_readiness",
  runner.includes('waitForDataModels(client, ["Server", "Client"]')
    && runner.includes('waitForDataModels(client, ["Edit"]')
    && runner.includes("toolArgs.datamodel_type"),
  "Play, Edit, and per-action DataModels must be probed before execution.",
);
check(
  "runner_reports_selected_studio_and_place",
  runner.includes("selectedStudio")
    && runner.includes("selectedPlace")
    && runner.includes("inspectSelectedPlace"),
  "Every result must carry verified Studio and place identities.",
);
check(
  "mouse_path_coordinates_cache_only_within_one_tool_call",
  studioMcpClient.includes("const coordinateCache = new Map()")
    && studioMcpClient.includes("segments:${JSON.stringify(literalSegments.map(String))}")
    && studioMcpClient.includes("path:${String(copy.instance_path)}")
    && studioMcpClient.includes("coordinateCache.get(cacheKey)")
    && studioMcpClient.includes("coordinateCache.set(cacheKey, coordinates)")
    && runner.includes("identical move/down/up paths must resolve once")
    && runner.includes("distinct paths must resolve separately")
    && runner.includes("coordinate cache leaked across separate mouse input calls")
    && runner.includes("mouse normalization mutated its source arguments")
    && runner.includes("pathless actions no longer preserve pointer-position reuse"),
  "Mouse normalization must reuse an exact path only inside one gesture, stay fresh across calls, preserve distinct paths and pathless reuse, and never mutate source args.",
);

const wrapperNames = [
  "run-existing-flows.ps1",
  "run-fast-regression.ps1",
  "run-feature-qc-regression.ps1",
  "run-video-qc-regression.ps1",
  "run-punchwall-playtest.ps1",
  "run-studio-test-harness.ps1",
];
check(
  "wrappers_use_local_verified_runner",
  wrapperNames.every((name) => {
    const source = read(path.join(automationRoot, name));
    return source.includes("scripts\\flow_runner.mjs")
      && source.includes("StudioInstanceId")
      && source.includes("ExpectedPlaceName");
  }),
  "All regression wrappers must use the worktree runner and forward identity assertions.",
);

const syncSource = read(path.join(scriptDirectory, "sync_rojo_source_to_studio.mjs"));
const embedSource = read(path.join(automationRoot, "embed-source-into-rbxlx.ps1"));
const buildSource = read(path.join(automationRoot, "build-production.ps1"));
const verifierSource = read(path.join(automationRoot, "verify-exact-rbxlx-sources.ps1"));
const finalValidatorSource = read(path.join(automationRoot, "run-final-artifact-regression.ps1"));
const staticContractsSource = read(path.join(automationRoot, "run-automation-static-contracts.ps1"));
for (const moduleName of ["InventoryViewModel", "InventoryUI", "ProfilePersistence"]) {
  check(
    `sync_embed_verify_map_${moduleName}`,
    syncSource.includes(moduleName)
      && embedSource.includes(moduleName)
      && verifierSource.includes(moduleName),
    `${moduleName} must be mapped by sync, embed, and exact verifier.`,
  );
}
const profileMappingStart = syncSource.indexOf('name: "ProfilePersistence"');
const profileMappingEnd = syncSource.indexOf("},", profileMappingStart);
check(
  "profile_persistence_is_required_for_sync_and_build",
  profileMappingStart >= 0
    && !syncSource.slice(Math.max(0, profileMappingStart - 350), profileMappingEnd).includes("optional")
    && buildSource.includes('"server\\ProfilePersistence.lua"')
    && embedSource.includes("ProfilePersistence = [pscustomobject]")
    && verifierSource.includes("ProfilePersistence = [pscustomobject]"),
  "ProfilePersistence must be a required source in sync, embed, build, and exact verification.",
);
check(
  "build_consumes_exact_source_markers",
  buildSource.includes("exactSources")
    && buildSource.includes("exactSourceSha256")
    && embedSource.includes("Exact source validation failed"),
  "Production build must consume embed-time exact normalized source markers.",
);
check(
  "sync_verifies_exact_utf8_source_fingerprint",
  syncSource.includes("verifySyncedSource")
    && syncSource.includes("sourceFingerprint")
    && syncSource.includes("Buffer.byteLength")
    && syncSource.includes("adler32"),
  "Studio sync must verify byte length and deterministic content fingerprint after every source write.",
);
check(
  "production_build_publishes_from_verified_temporary_copy",
  buildSource.includes("$temporaryOutput")
    && buildSource.includes("Move-Item -LiteralPath $temporaryOutput")
    && embedSource.includes("Embedded parent validation failed"),
  "Production output must only replace the canonical file after exact source and parent validation.",
);
check(
  "embed_and_verifier_require_exact_service_hierarchy",
  [embedSource, verifierSource].every((source) =>
    source.includes("Resolve-ExpectedParent")
      && source.includes("ParentClass")
      && source.includes("ServiceClass")
      && source.includes("DocumentElement.SelectNodes")
      && source.includes("ReferenceEquals")),
  "Source embedding and verification must bind class-correct parents to an exact root service hierarchy.",
);
check(
  "static_gate_compiles_all_mapped_luau_at_o0_o1_o2",
  staticContractsSource.includes("Resolve-LuauCompiler")
    && staticContractsSource.includes("PunchWallClient.client.lua")
    && staticContractsSource.includes("ProfilePersistence.lua")
    && staticContractsSource.includes("foreach ($optimization in 0..2)")
    && staticContractsSource.includes("--null")
    && staticContractsSource.includes("luauCompileCases"),
  "The no-Studio gate must compile every mapped Luau source at all three optimization levels.",
);
check(
  "final_validator_binds_canonical_files_hashes_and_studio_identity",
  finalValidatorSource.includes("PunchWallRPGPlayable_v1_final.rbxlx")
    && finalValidatorSource.includes("PunchWallRPGPlayable_v1_final_validation.rbxlx")
    && finalValidatorSource.includes("rbxlxSha256")
    && finalValidatorSource.includes("normalizedSha256")
    && finalValidatorSource.includes("StudioInstanceId")
    && finalValidatorSource.includes("selectedStudio.id")
    && finalValidatorSource.includes("selectedPlace.name"),
  "Final validation must bind canonical byte-identical files, all exact source hashes, Studio id, and place identity.",
);

const flowFiles = fs.readdirSync(flowsRoot).filter((name) => name.endsWith(".json")).sort();
const invalidFlows = [];
const selectorlessFlows = [];
for (const name of flowFiles) {
  try {
    const flow = JSON.parse(read(path.join(flowsRoot, name)));
    if (!flow.studioName && !flow.studioInstanceId) selectorlessFlows.push(name);
    if (!Array.isArray(flow.steps)) invalidFlows.push(name);
  } catch {
    invalidFlows.push(name);
  }
}
check("all_flow_json_parses", invalidFlows.length === 0, `Invalid flows: ${invalidFlows.join(", ")}`);
check(
  "all_flows_have_fail_closed_selector",
  selectorlessFlows.length === 0,
  `Selectorless flows: ${selectorlessFlows.join(", ")}`,
);
const staleExactSceneCounts = flowFiles.filter((name) => {
  const source = read(path.join(flowsRoot, name));
  return source.includes('\\"parts\\"\\\\s*:\\\\s*1297')
    || source.includes('\\"sounds\\"\\\\s*:\\\\s*15')
    || source.includes('\\"particles\\"\\\\s*:\\\\s*26');
});
check(
  "flows_avoid_stale_exact_scene_counts",
  staleExactSceneCounts.length === 0,
  `Brittle exact scene counts remain in: ${staleExactSceneCounts.join(", ")}`,
);

const iteration04 = read(path.join(flowsRoot, "iteration04-armory-pets-feedback.json"));
check(
  "iteration04_uses_current_catalog_selector",
  !iteration04.includes("Gauntlet Palm")
    && iteration04.includes("cfg.PremiumFists")
    && iteration04.includes("PremiumFistShowcase"),
  "Iteration 04 must validate the current PremiumFist catalog, not removed fixtures.",
);
const reducedMotion = read(path.join(flowsRoot, "reduced-motion-performance.json"));
check(
  "reduced_motion_has_motion_aware_camera_contract",
  reducedMotion.includes("reducedValid")
    && reducedMotion.includes("(result.lead or math.huge)<.2")
    && !reducedMotion.includes('\\"parts\\"\\\\s*:\\\\s*1297'),
  "Reduced motion must validate suppressed-motion invariants and relative scene stability.",
);
for (const requiredFlow of [
  "inventory-delete-real-input.json",
  "feedback-holder-presentation.json",
  "generic-phone-game-menu-accessibility.json",
]) {
  check(
    `targeted_flow_${requiredFlow}`,
    flowFiles.includes(requiredFlow),
    `Required targeted flow missing: ${requiredFlow}`,
  );
}

const runnerSelfTest = spawnSync(process.execPath, [runnerPath, "--self-test"], {
  encoding: "utf8",
  timeout: 15000,
});
check(
  "runner_self_test_passes_without_studio",
  runnerSelfTest.status === 0 && /"ok"\s*:\s*true/.test(runnerSelfTest.stdout),
  runnerSelfTest.stderr || runnerSelfTest.stdout || "runner self-test returned no output",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(JSON.stringify({
  ok: passed === Object.keys(checks).length,
  passed,
  total: Object.keys(checks).length,
  flowCount: flowFiles.length,
  checks,
}, null, 2));
