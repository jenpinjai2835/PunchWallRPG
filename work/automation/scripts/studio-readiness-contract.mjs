import assert from "node:assert/strict";
import { waitForDataModels } from "./studio_mcp_client.mjs";

const checks = {};
let attempts = 0;
await waitForDataModels({
  async callTool(name, args) {
    assert.equal(name, "execute_luau");
    assert.equal(args.datamodel_type, "Client");
    attempts += 1;
    return attempts === 1
      ? { isError: true, text: "Target is not reachable (createExecuteLuauBridge_loadCodeAsync, Client)" }
      : { isError: false, text: "Ready place" };
  },
}, ["Client"], 1000);
assert.equal(attempts, 2);
checks.transient_execution_bridge_retried = true;

for (const error of [
  "attempt to index nil with 'PlayerGui'",
  "Target is not reachable (RemoteServiceGate_Get, Standalone)",
]) {
  let calls = 0;
  await assert.rejects(waitForDataModels({
    async callTool() { calls += 1; return { isError: true, text: error }; },
  }, ["Client"], 1000), /readiness probe failed/);
  assert.equal(calls, 1);
}
checks.non_readiness_errors_fail_immediately = true;

await assert.rejects(waitForDataModels({
  async callTool() {
    return { isError: true, text: "Target is not reachable (createExecuteLuauBridge_loadCodeAsync, Server)" };
  },
}, ["Server"], 10), /Timed out waiting for DataModel\(s\) Server/);
checks.persistent_unreachable_bridge_remains_failure = true;
console.log(JSON.stringify({ ok: true, checks }, null, 2));
