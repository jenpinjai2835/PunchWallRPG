# Mandatory Agent HQ Delivery Workflow

This policy is the non-negotiable operating model for every actionable user request in the Punch Wall RPG repository. It turns Agent HQ into the task ledger, dependency board, progress monitor, and delivery record for work coordinated by Codex.

The objective is not to promise impossible zero-defect software. The objective is to finish each accepted scope with reproducible validation, no known in-scope defect, no silent skipped gate, and no loss or overwrite of unrelated work.

## 1. Scope and Authority

- Apply this workflow to code, gameplay, UI, assets, maps, automation, documentation, Git, release work, investigations that produce artifacts, and repository maintenance.
- Register the task in Agent HQ before changing files or external state.
- Read-only questions that require no artifact or state change may be answered directly, but the Coordinator must use Agent HQ if the investigation becomes actionable work.
- A user may override this workflow only through an explicit instruction for that specific task.
- Urgency, a small diff, an interrupted session, or a stale dashboard is not an override.
- Repository-specific safeguards in `AGENTS.md`, the project skill, and `work/docs/GIT_BRANCH_DEVELOPMENT_RULES.md` remain in force.

## 2. Roles

### Coordinator

The Coordinator is the single integration and delivery owner. The Coordinator must:

1. Restate the requested outcome.
2. Define measurable acceptance criteria.
3. Inspect the repository, active worktrees, branches, and existing dirty state.
4. Classify risk and select required validation gates.
5. Decompose non-trivial work into independently verifiable subtasks.
6. Define dependency and integration order before implementation.
7. Assign one owner and one non-overlapping scope to every subtask.
8. Keep Agent HQ status, checklist, and history aligned with real work.
9. Integrate worker handoffs in the declared order.
10. Run post-integration validation against the combined result.
11. Review the final diff and preserve unrelated user work.
12. Deliver the result with evidence, limitations, and any blocked gate stated clearly.

The Coordinator is Agent 4 in the current Agent HQ layout.

### Agents 1-3

Agents 1-3 are interchangeable workers. They do not have permanent specialties or titles.

- Assign workers by availability, task fit, and the ability to keep ownership boundaries clean.
- A worker owns only the paths and deliverables recorded in its subtask.
- A worker may inspect shared context but must not modify another owner's files.
- A worker reports checklist progress at meaningful milestones, not invented percentages.
- A worker's `READY` handoff means eligible for Coordinator integration, not that the overall task is complete.

## 3. Required Intake Record

Before execution, the Agent HQ parent task must record:

- requested outcome;
- acceptance criteria;
- affected repository or external system;
- risk classification;
- known constraints;
- dependencies;
- required validation gates;
- integration owner;
- definition of done.

Each subtask must record:

- one owner;
- branch and worktree;
- allowed paths or components;
- forbidden or shared paths;
- concrete deliverable;
- checklist items;
- upstream dependencies;
- downstream consumers;
- integration order;
- expected validation and evidence.

If a task is atomic, keep one Agent HQ task and record why delegation would add more coordination or conflict risk than value. Atomic status does not waive testing, evidence, or final review.

## 4. Planning and Decomposition

Decompose work along ownership boundaries that can be validated independently. Prefer:

- source implementation;
- automation or test coverage;
- visual or content assets;
- documentation and evidence;
- final integration or release artifact.

Do not create artificial subtasks merely to keep all agents busy. Parallel work is appropriate only when scopes do not overlap and dependencies allow it.

For dependent work:

1. Record the prerequisite and resume condition.
2. Keep the dependent worker `WAITING`.
3. Verify and integrate the prerequisite or provide an immutable handoff commit/artifact.
4. Refresh the dependent branch from the accepted integration state.
5. Change the dependent worker to `WORKING`.

## 5. Status Contract

Agent HQ status must represent executable reality.

### `WORKING` — yellow

Use only while an agent is actively executing assigned work.

- Show the current task description above the character.
- Show the segmented checklist progress bar.
- A segment represents one real checklist item.
- Update progress when a checklist item becomes durably complete.
- Do not use elapsed time, changed-file count, or guessed percentages as progress.

### `WAITING` — dark purple

Use when no executable work remains until a named upstream dependency finishes.

- Record the blocking dependency.
- Record the exact resume condition.
- Do not edit dependency-owned files while waiting.

### `READY` — green

Use when the worker has completed its owned checklist and supplied a valid handoff, or when an agent has no assigned work and is available.

- Do not show an old task description or progress bar above the character.
- Worker `READY` does not make the parent task ready.

### `BLOCKED` — red

Use when:

- a required check fails or cannot run;
- required access, environment, or input is unavailable;
- a defect prevents an acceptance criterion;
- ownership or repository state cannot be reconciled safely.

Record the owner, impact, evidence, attempted actions, and next required action. Never convert a required failed, skipped, or unavailable gate into `READY`.

## 6. Progress and History

- Checklist totals must reflect real, independently verifiable work items.
- A completed segment requires durable evidence: a file, commit, test result, screenshot, log, or accepted handoff.
- Do not keep a completed task description above a `READY` character.
- Preserve completed work in Agent HQ history before clearing the active task.
- Every history entry should identify the task, owner, result, key validation, and integration state.
- Dashboard state is observability, not evidence by itself.

## 7. Conflict-Free Execution

### Single ownership

- Assign exactly one owner to every file before edits begin.
- Component ownership never overrides file ownership.
- Two agents must never edit the same file concurrently.
- If overlap is discovered, both workers stop editing the overlapping scope and notify the Coordinator.

### Isolated branches and worktrees

- Implementation work uses a task-specific branch and isolated worktree based on the required integration base, normally `origin/develop`.
- Agent worktrees are execution containers, not permanent roles.
- Before assignment, inspect `git status --short --branch`, the current branch and HEAD, and base divergence.
- Do not automatically reuse a dirty or stale worktree.
- Preserve all existing changes and select a clean worktree or perform an explicit handoff.

Never:

- run `git reset --hard` or `git clean -fd` against agent worktrees;
- force checkout over existing work;
- force-push a shared branch;
- stage, amend, commit, move, or delete another task's files;
- rebase a dirty worktree without an explicit, reviewed preservation plan.

### Shared and high-conflict files

The Coordinator must serialize ownership of:

- `AGENTS.md`;
- project manifests and central configuration;
- lockfiles;
- shared registries and automation indexes;
- generated `.rbxlx` files;
- Agent HQ state and configuration;
- release artifacts.

Workers without direct ownership should return a minimal patch or specification for the integration owner.

Only one task may own `outputs/PunchWallRPGPlayable_v1_final.rbxlx` at a time. Rebuild it only after source and automation changes are integrated and verified.

### Ownership transfer

Before another worker takes over a file, the current owner must report:

- branch and worktree;
- commit SHA or explicit uncommitted paths;
- dirty state;
- changed files;
- behavior or contract changed;
- checks and results;
- remaining risks;
- dependencies unblocked;
- known conflicts.

The Coordinator must explicitly accept the handoff before the next owner edits the file.

## 8. Integration Order

Define merge order before execution. Unless the task requires a different dependency graph, integrate:

1. lowest-level source or contract changes;
2. direct consumers;
3. tests and automation;
4. documentation and evidence;
5. shared registries;
6. generated and release artifacts.

Conflict resolution happens once on the integration branch by the Coordinator or assigned integration owner. Multiple workers must not resolve the same conflict independently.

Before integrating a worker handoff, verify:

- allowed-path compliance;
- focused diff with no unrelated user change;
- documented clean or intentional dirty state;
- accepted base freshness;
- relevant worker checks passed;
- complete handoff evidence.

After every integration, rerun checks affected by that integration. After all integrations, run the combined regression required by the highest affected risk.

## 9. Risk-Based Quality Gates

The Coordinator classifies every task before work begins. Apply the gates for the highest-risk affected category.

### Documentation or configuration

- Validate paths, links, examples, and commands.
- Inspect the consumed or rendered result when applicable.
- Run a formatter or `git diff --check`.
- Confirm no unrelated file changed.

### Internal tools

- Run lint, type, unit, or equivalent checks.
- Run a focused smoke test of the changed command or API.
- Verify expected error handling.

### UI, visual, or map work

- Run the matching Visual/UI automation profile.
- Inspect the real player view, not only object structure.
- Verify relevant desktop and mobile safe areas.
- Confirm a clean Studio console.

### Gameplay, economy, network, purchase, save, or progression

- Prove server authority.
- Test positive, negative, boundary, fresh-player, failure, and gate paths.
- Add or update a recorded flow in `work/automation/flows/`.
- Run targeted regression during iteration.
- Run full affected regression after integration.

### Shared architecture, final artifact, or release

- Sync the integrated source to Studio.
- Run the complete affected suite after all branches are integrated.
- Rebuild `.rbxlx` only from the accepted source.
- Test the rebuilt artifact itself.

Tests against stale Studio state, a non-integrated agent branch, or an old artifact are not final delivery evidence.

## 10. Evidence Contract

Every completed checklist item records:

- acceptance criterion;
- exact command, flow, or manual view checked;
- `PASS`, `FAIL`, or `BLOCKED`;
- source commit, integrated state, or artifact tested;
- relevant output, screenshot, or log reference.

“Tested” without reproducible evidence is not a pass. Skipped and not-run checks must be explicit.

Any integration change invalidates earlier evidence for affected paths until those checks are rerun against the combined state.

## 11. Definition of Done

A worker subtask may become `READY` only when:

- every owned checklist item is complete;
- focused positive and negative paths pass;
- required automation and documentation are updated;
- changes stay within assigned ownership;
- no unresolved known defect breaks its acceptance criteria;
- handoff evidence is complete.

The overall task may become `READY` only when:

1. all acceptance criteria are traceably satisfied;
2. dependencies are integrated in the planned order;
3. post-integration gates required by risk pass;
4. desktop, mobile, visual, server-authority, and artifact checks pass where applicable;
5. source, tests, documents, and outputs are mutually traceable;
6. no required gate is failed, blocked, skipped, stale, or run only against a non-integrated branch;
7. no known in-scope defect remains;
8. the Coordinator reviews the final diff and confirms unrelated work is preserved;
9. final evidence and history are recorded in Agent HQ.

Use precise delivery language:

> All required checks passed, and no known in-scope defect remains.

Do not claim absolute bug-free software.

## 12. Restart and Recovery Protocol

After a Codex, Agent HQ, browser, or machine restart:

1. Inspect live agent sessions.
2. Check Agent HQ health and current task records.
3. Inspect every assigned branch and worktree.
4. Reconcile each `WORKING` record with durable files, commits, and test evidence.
5. Recreate or reassign lost agent sessions.
6. Set non-executable dependency work to `WAITING`.
7. Set unrecoverable or unsafe work to `BLOCKED`.
8. Rerun interrupted or non-terminal checks.
9. Continue only from verified durable state.

A stale `WORKING` label, progress segment, elapsed timer, or prior chat message is never proof that work completed.

## 13. Task Closure

When delivery is complete, the Coordinator must:

1. Record final validation and integration evidence.
2. Mark the parent checklist complete.
3. Set the Coordinator to `READY`.
4. Preserve the completed task in Agent HQ history.
5. Clear active descriptions and progress bars so all idle agents show only `READY`.
6. Report changed files, checks, limitations, and Git state to the user.

If required work remains, do not close the task. Use `WAITING` or `BLOCKED` with the exact next action.

## 14. Coordinator Checklist Template

```text
[ ] Request restated and acceptance criteria recorded
[ ] Repository, branches, worktrees, and dirty state inspected
[ ] Risk classification and validation gates selected
[ ] Subtasks, ownership, allowed paths, and dependencies recorded
[ ] Agents assigned without overlapping file ownership
[ ] Worker handoffs verified and integrated in dependency order
[ ] Combined risk-appropriate regression passed
[ ] Final diff reviewed; unrelated work preserved
[ ] No known in-scope defect remains
[ ] Agent HQ evidence/history updated; active tasks cleared
```
