#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import { classifyStudioConsole, runAssertion } from "./flow_runner.mjs";

// Exact console body from smash-camera-shop-stability-repeat2-20260906.json.
const helper = "sabuiltin_Assistant.rbxm.Assistant.Packages._Index.AssistantUI.AssistantUI.Util.TestAutomationUtils";
const header = `[Roblox][${helper}] VirtualInput::SendMousePosition: position (82.9, 67.4) hits CoreGUI.`;
const frames = [`Script '${helper}', Line 286`, `Script '${helper}', Line 164`];
const block = [header, "Stack Begin", ...frames, "Stack End"].join("\n");
const notice = "[PunchWallRPG] Studio session is EPHEMERAL by default; live profile reads and writes are disabled.";
const recordedConsole = `${notice}\n${block}`;
const gameError = "Script Runtime Error: Players.Test.PlayerScripts.PunchWallClient:44: attempt to index nil";
const gameFrame = "Script 'Players.Test.PlayerScripts.PunchWallClient', Line 44";
const cases = [
  ["actual_tool_warning_with_game_notice", recordedConsole, true, 1],
  ["complete_known_block", block, true, 1],
  ["crlf_keeps_original_bytes", recordedConsole.replaceAll("\n", "\r\n"), true, 1],
  ["two_known_blocks_preserve_surrounding_messages", `before\n${block}\nbetween\n${block}\nafter`, true, 2],
  ["ordinary_console", `${notice}\nShop opened`, true, 0],
  ["empty_console", "", true, 0],
  ["appended_game_error_still_fails", `${block}\n${gameError}`, false, 1],
  ["prepended_game_error_still_fails", `${gameError}\n${block}`, false, 1],
  ["mixed_game_frame_is_not_classified", [header, "Stack Begin", frames[0], gameFrame, "Stack End"].join("\n"), false, 0],
  ["only_game_frames_are_not_classified", [header, "Stack Begin", gameFrame, "Stack End"].join("\n"), false, 0],
  ["similar_helper_suffix_is_not_classified", block.replace(frames[1], frames[1].replace("TestAutomationUtils'", "TestAutomationUtilsExtra'")), false, 0],
  ["unknown_helper_frame_is_not_classified", block.replace(frames[1], "Script 'sabuiltin_OtherPlugin.Helper', Line 164"), false, 0],
  ["different_header_is_not_classified", block.replace("hits CoreGUI.", "failed for an unknown reason."), false, 0],
  ["unrelated_stack_is_not_classified", `Unknown error\nStack Begin\n${frames[0]}\nStack End`, false, 0],
  ["missing_stack_end_is_not_classified", block.replace("\nStack End", ""), false, 0],
  ["missing_stack_begin_is_not_classified", block.replace("Stack Begin\n", ""), false, 0],
  ["empty_stack_is_not_classified", `${header}\nStack Begin\nStack End`, false, 0],
  ["lone_known_header_fails_closed", header, false, 0],
  ["interleaved_blank_line_is_not_classified", block.replace(frames[1], `\n${frames[1]}`), false, 0],
  ["unrecognized_frame_annotation_is_not_classified", block.replace(frames[1], `${frames[1]} - function sendInput`), false, 0],
  ["extra_header_message_is_not_classified", block.replace(header, `${header} ${gameError}`), false, 0],
  ["different_virtual_input_method_is_not_classified", block.replace("SendMousePosition", "SendKeyEvent"), false, 0],
  ["non_numeric_position_is_not_classified", block.replace("82.9, 67.4", "unknown, 67.4"), false, 0],
  ["unrelated_trailing_stack_end_is_retained", `${block}\nStack End`, false, 1],
  ["nested_warning_inside_game_stack_is_not_classified", `Stack Begin\n${gameFrame}\n${block}\nStack End`, false, 0],
  ["unknown_incomplete_stack_owns_following_lines", `Stack Begin\n${gameFrame}\n${block}`, false, 0],
  ["long_console_preserved_without_summary_truncation", `${"normal output\n".repeat(500)}${block}`, true, 1],
  ["existing_custom_error_patterns_are_applied", `${block}\nASSET_FAILED`, false, 1, ["ASSET_FAILED"]],
];
const checks = {};
for (const [name, text, expectedOK, expectedWarnings, patterns] of cases) {
  const result = classifyStudioConsole(text, patterns);
  assert.equal(result.ok, expectedOK, name);
  assert.equal(result.identifiedToolWarningCount, expectedWarnings, name);
  assert.equal(result.identifiedToolWarnings.length, expectedWarnings, name);
  assert.equal(result.originalText, text, `${name}: console text changed`);
  const sourceLines = text.split(/\r?\n/);
  const classifiedLineNumbers = new Set();
  for (const warning of result.identifiedToolWarnings) {
    assert.equal(sourceLines[warning.startLine - 1], warning.header, `${name}: wrong warning start`);
    assert.equal(sourceLines[warning.endLine - 1], "Stack End", `${name}: incomplete warning`);
    assert.equal(warning.frameCount, warning.endLine - warning.startLine - 2, name);
    for (let line = warning.startLine; line <= warning.endLine; line += 1) classifiedLineNumbers.add(line);
  }
  assert.equal(result.retainedLines.length + classifiedLineNumbers.size, sourceLines.length, `${name}: lost console lines`);
  for (const line of result.retainedLines) {
    assert.equal(sourceLines[line.lineNumber - 1], line.text, `${name}: retained line changed`);
    assert.equal(classifiedLineNumbers.has(line.lineNumber), false, `${name}: line both retained and classified`);
  }
  if (expectedWarnings === 0) assert.deepEqual(result.retainedLines.map(line => line.text), sourceLines, `${name}: unrecognized block was suppressed`);
  const context = { console: text };
  const evidence = [];
  const action = { type: "assertNoConsoleErrors", source: "console", label: name, ...(patterns ? { patterns } : {}) };
  if (expectedOK) assert.deepEqual(runAssertion(action, context, evidence), result, `${name}: assertion path differs`);
  else assert.throws(() => runAssertion(action, context, evidence), /Console contains suspicious lines/, name);
  assert.equal(context.console, text, `${name}: assertion mutated console source`);
  assert.equal(evidence.length, 1, `${name}: missing result evidence`);
  assert.equal(evidence[0].source, "console", name);
  assert.equal(evidence[0].label, name, name);
  assert.equal(evidence[0].originalText, text, `${name}: failure/success lost original console`);
  assert.equal(evidence[0].identifiedToolWarningCount, expectedWarnings, name);
  checks[name] = true;
}
const runner = fs.readFileSync(new URL("./flow_runner.mjs", import.meta.url), "utf8");
assert.equal((runner.match(/      consoleClassifications,/g) || []).length, 2, "both success and failure results must preserve classifications");
assert.ok(runner.includes("identified Studio input warnings:"), "successful assertion checks must expose classified count");
console.log(JSON.stringify({ ok: true, passed: cases.length, total: cases.length, actualWarningCount: classifyStudioConsole(recordedConsole).identifiedToolWarningCount, checks }, null, 2));
