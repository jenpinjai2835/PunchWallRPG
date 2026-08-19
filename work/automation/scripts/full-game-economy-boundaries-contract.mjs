#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const flowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "full-game-economy-boundaries.json",
);

const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function count(source, token) {
  return source.split(token).length - 1;
}

function includesEvery(source, tokens) {
  return tokens.every((token) => source.includes(token));
}

const executeSteps = flow.steps.filter(
  (step) => step.type === "call" && step.tool === "execute_luau",
);
const allCode = executeSteps
  .map((step) => step.args?.code || "")
  .join("\n");
const realSpinPattern =
  /actionRemote\s*:\s*FireServer\s*\(\s*\{\s*action\s*=\s*['"]Spin['"]\s*\}\s*\)/g;
const realSpinCalls = allCode.match(realSpinPattern) || [];
const spinClientSteps = executeSteps.filter(
  (step) =>
    step.args?.datamodel_type === "Client"
    && (step.args?.code || "").includes(
      "actionRemote:FireServer({action='Spin'})",
    ),
);

const cooldownSeed = executeSteps.find((step) =>
  step.label?.includes("seed authoritative spin cooldown boundary"),
);
const cooldownClient = executeSteps.find((step) =>
  step.label?.includes("real cooldown Spin emits one bounded Fail"),
);
const cooldownServer = executeSteps.find((step) =>
  step.label?.includes("real cooldown Spin leaves every authoritative reward field unchanged"),
);
const creditSeed = executeSteps.find((step) =>
  step.label?.includes("seed one authoritative bonus spin credit"),
);
const creditClient = executeSteps.find((step) =>
  step.label?.includes("real credit Spin emits one bounded result"),
);
const creditServer = executeSteps.find((step) =>
  step.label?.includes("server confirms credit path preserved cooldown"),
);

const spinBoundarySteps = [
  cooldownSeed,
  cooldownClient,
  cooldownServer,
  creditSeed,
  creditClient,
  creditServer,
];
const cooldownClientCode = cooldownClient?.args?.code || "";
const cooldownServerCode = cooldownServer?.args?.code || "";
const creditClientCode = creditClient?.args?.code || "";
const creditServerCode = creditServer?.args?.code || "";

check(
  "flow_identity_and_edit_cleanup",
  flow.name === "full-game-economy-boundaries"
    && flow.studioName === "^(?:PunchWallRPGPlayable_v1_final|PunchWallRPG_ManualPlaytest_20260818_FistAuraV10)\\.rbxlx$"
    && Array.isArray(flow.cleanup)
    && flow.cleanup.some(
      (step) =>
        step.type === "call"
        && step.tool === "start_stop_play"
        && step.args?.is_start === false
        && step.allowError === true,
    )
    && flow.steps.at(-1)?.tool === "start_stop_play"
    && flow.steps.at(-1)?.args?.is_start === false,
  "The economy boundary flow must target the final place and return Studio to Edit both normally and after failure.",
);

check(
  "honor_uses_leaderstats_and_cross_vm_shared_is_banned",
  !allCode.includes("RPGStats.Honor")
    && !/\bshared\b/.test(allCode)
    && (allCode.match(/leaderstats\.Honor\.Value/g) || []).length >= 8,
  "Every Honor read must use leaderstats.Honor, and flow snippets must not carry state through shared across Assistant VMs.",
);

check(
  "exactly_two_real_action_request_spins_without_retry",
  realSpinCalls.length === 2
    && spinClientSteps.length === 2
    && spinClientSteps.every(
      (step) =>
        count(step.args.code, "actionRemote:FireServer({action='Spin'})") === 1
        && step.args.code.includes("RS.PunchWallEvents.ActionRequest"),
    )
    && !/\w+\s*:\s*Invoke\s*\(\s*['"]Spin['"]/.test(allCode),
  `Expected two one-shot ActionRequest Spin calls and no automation Spin retry; found ${realSpinCalls.length} real calls across ${spinClientSteps.length} client steps.`,
);

check(
  "spin_event_lifetime_is_local_to_each_client_call",
  spinClientSteps.every((step) => {
    const source = step.args.code;
    const connectIndex = source.indexOf("feedbackRemote.OnClientEvent:Connect");
    const fireIndex = source.indexOf("actionRemote:FireServer({action='Spin'})");
    const disconnectIndex = source.indexOf("connection:Disconnect()");
    return includesEvery(source, [
      "local events={}",
      "local connection",
      "local ok,err=xpcall(function()",
      "if connection then connection:Disconnect() end",
    ])
      && connectIndex >= 0
      && fireIndex > connectIndex
      && disconnectIndex > fireIndex;
  }),
  "Each client probe must connect, perform its one action, verify, and disconnect within the same execute_luau VM.",
);

check(
  "all_spin_waits_are_bounded",
  spinClientSteps.every((step) =>
    includesEvery(step.args.code, [
      "replicationDeadline=os.clock()+3",
      "eventDeadline=os.clock()+2",
      "while #events==0 and os.clock()<eventDeadline",
      "presentationDeadline=os.clock()+.5",
      "duplicateWindowDeadline=os.clock()+.15",
    ])
    && step.args.code
      .split("\n")
      .filter((line) => line.trimStart().startsWith("while "))
      .every((line) => line.includes("os.clock()<")))
    && includesEvery(creditClientCode, [
      "mutationDeadline=os.clock()+1",
      "while event and not applied and os.clock()<mutationDeadline",
    ]),
  "Replication, event, mutation, presentation, and duplicate-observation waits must all have explicit monotonic deadlines.",
);

check(
  "cooldown_probe_requires_one_fail_and_zero_mutation",
  includesEvery(cooldownClientCode, [
    "expect(#events==1,'event_count')",
    "expect(event and event.type=='Fail','event_type')",
    "expect(event and event.target=='Spin','event_target')",
    "after.lastSpinAt==baseline.lastSpinAt",
    "after.credits==baseline.credits",
    "after.coins==baseline.coins",
    "after.power==baseline.power",
    "after.honor==baseline.honor",
    "after.pets==baseline.pets",
    "expect(feedbackDelta==1,'feedback_delta')",
    "expect(toastSequenceDelta==1,'toast_sequence_delta')",
    "expect(rewardSequenceDelta==0,'reward_sequence_leak')",
    "VisibleItemCount') or 0)<=3",
  ])
    && includesEvery(cooldownSeed?.args?.code || "", [
      "config.Spin.CooldownSeconds+30",
      "EconomyCooldownBaselineLastSpinAt",
      "SpinCredits=0",
      "Honor=11",
      "PetInventoryJSON='[]'",
    ])
    && includesEvery(cooldownServerCode, [
      "result.lastSpinAt==result.baselineLastSpinAt",
      "result.credits==0",
      "result.coins==37",
      "result.power==43",
      "result.honor==11",
      "result.pets=='[]'",
    ]),
  "The cooldown path must prove exactly one Fail plus exact client and server no-mutation snapshots, with no reward presentation leak.",
);

check(
  "credit_probe_requires_one_result_and_one_exact_reward_path",
  includesEvery(creditClientCode, [
    "expect(#events==1,'event_count')",
    "expect(event and event.type=='SpinResult','event_type')",
    "expect(event and event.target~='','event_target')",
    "expect(event and event.reward~='','event_reward')",
    "expect(event and event.amount>0,'event_amount')",
    "if event.kind=='Coins' then return after.credits==0 and after.coins==baseline.coins+event.amount",
    "if event.kind=='Power' then return after.credits==0 and after.power==baseline.power+event.amount",
    "if event.kind=='Honor' then return after.credits==0 and after.honor==baseline.honor+event.amount",
    "if event.kind=='BonusSpin' then return after.credits==1",
    "expect(after.lastSpinAt==baseline.lastSpinAt,'cooldown_timestamp_changed')",
    "expect(feedbackDelta==1,'feedback_delta')",
    "expect(toastSequenceDelta==1,'toast_sequence_delta')",
    "expect(rewardSequenceDelta==0,'reward_sequence_leak')",
    "VisibleItemCount') or 0)<=3",
  ])
    && includesEvery(creditServerCode, [
      "local bonus=result.credits==1 and result.coins==0 and result.power==15 and result.honor==0 and result.pets=='[]'",
      "local coins=result.credits==0 and result.coins>0 and result.power==15 and result.honor==0 and result.pets=='[]'",
      "local power=result.credits==0 and result.coins==0 and result.power>15 and result.honor==0 and result.pets=='[]'",
      "local honor=result.credits==0 and result.coins==0 and result.power==15 and result.honor>0 and result.pets=='[]'",
      "result.rewardApplied=pathCount==1",
      "result.lastSpinAt==result.baselineLastSpinAt",
    ]),
  "The credited path must prove exactly one SpinResult, the event-sized client mutation, and exactly one accepted server reward branch.",
);

check(
  "spin_steps_preserve_authoritative_order_and_snapshots",
  spinBoundarySteps.every(Boolean)
    && cooldownSeed.args?.datamodel_type === "Server"
    && cooldownClient.args?.datamodel_type === "Client"
    && cooldownServer.args?.datamodel_type === "Server"
    && creditSeed.args?.datamodel_type === "Server"
    && creditClient.args?.datamodel_type === "Client"
    && creditServer.args?.datamodel_type === "Server"
    && executeSteps.indexOf(cooldownSeed) < executeSteps.indexOf(cooldownClient)
    && executeSteps.indexOf(cooldownClient) < executeSteps.indexOf(cooldownServer)
    && executeSteps.indexOf(cooldownServer) < executeSteps.indexOf(creditSeed)
    && executeSteps.indexOf(creditSeed) < executeSteps.indexOf(creditClient)
    && executeSteps.indexOf(creditClient) < executeSteps.indexOf(creditServer),
  "Seed, real client action, and authoritative server snapshot must remain serialized for cooldown and credit cases.",
);

check(
  "spin_failures_emit_actionable_diagnostics",
  spinBoundarySteps.every((step) =>
    step.args.code.includes("H:JSONEncode(result)"))
    && spinClientSteps.every((step) =>
      includesEvery(step.args.code, [
        "local failures={}",
        "valid=#failures==0",
        "probe crashed:",
        "client contract failed:",
      ])),
  "Every spin boundary must return a JSON snapshot, while client failures name the failed invariant and preserve crash traces.",
);

check(
  "console_assertion_is_terminal",
  flow.steps.some(
    (step) =>
      step.type === "assertNoConsoleErrors"
      && step.source === "console",
  )
    && flow.steps.at(-2)?.type === "assertNoConsoleErrors"
    && flow.steps.at(-1)?.tool === "start_stop_play",
  "The final evidence sequence must assert a clean console before returning Studio to Edit.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      executeLuauSteps: executeSteps.length,
      realSpinCalls: realSpinCalls.length,
      checks,
      files: [path.relative(repositoryRoot, flowPath)],
    },
    null,
    2,
  ),
);
