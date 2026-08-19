#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const inventoryPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "InventoryUI.lua",
);
const source = fs.readFileSync(inventoryPath, "utf8").replace(/\r\n?/g, "\n");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function block(start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing start sentinel: ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `Missing end sentinel: ${end}`);
  return source.slice(startIndex, endIndex);
}

function tail(start) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing tail sentinel: ${start}`);
  return source.slice(startIndex);
}

function orderedTokens(text, tokens) {
  let cursor = 0;
  for (const token of tokens) {
    const tokenIndex = text.indexOf(token, cursor);
    if (tokenIndex < 0) {
      return false;
    }
    cursor = tokenIndex + token.length;
  }
  return true;
}

function tailSatisfies(text, start, required = [], forbidden = []) {
  const startIndex = text.indexOf(start);
  if (startIndex < 0) {
    return false;
  }
  const remainder = text.slice(startIndex);
  return required.every((token) => remainder.includes(token))
    && forbidden.every((token) => !remainder.includes(token));
}

const clearCards = block(
  "function InventoryUI:_clearCards()",
  "function InventoryUI:_applyCardSelectionVisual",
);
const selectionVisual = block(
  "function InventoryUI:_applyCardSelectionVisual(key, selected)",
  "function InventoryUI:_renderGrid()",
);
const renderGrid = block(
  "function InventoryUI:_renderGrid()",
  "function InventoryUI:_clearActionButtons()",
);
const applyFilter = block(
  "function InventoryUI:_applyFilter(resetDrawer)",
  "function InventoryUI:SetVisible",
);
const selectItem = block(
  "function InventoryUI:SelectItem(key, includeDiagnostics)",
  "function InventoryUI:_findAction",
);
const getSnapshot = block(
  "function InventoryUI:GetSnapshot()",
  "function InventoryUI:Destroy()",
);
const timedRefresh = block(
  "function InventoryUI:_stopTimedRefresh()",
  "function InventoryUI:_refreshDeleteConfirmationLabel",
);
const refreshTimedItems = block(
  "function InventoryUI:_refreshTimedItems(now)",
  "function InventoryUI:_syncTimedRefresh()",
);
const deleteConfirmation = block(
  "function InventoryUI:_refreshDeleteConfirmationLabel()",
  "function InventoryUI:_applyAtlasIcon",
);
const responsive = block(
  "function InventoryUI:ApplyResponsive(viewport, compact, uiScale)",
  "function InventoryUI:_enabledActionNames",
);
const absoluteSizeCallback = block(
  'self:_connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()',
  'self:_connect(self.Root:GetPropertyChangedSignal("Visible"), function()',
);
const destroy = tail("function InventoryUI:Destroy()");

check(
  "selection_avoids_grid_rebuild",
  !selectItem.includes("_renderGrid")
    && selectItem.includes("self:_applyCardSelectionVisual(previousKey, false)")
    && selectItem.includes("self:_applyCardSelectionVisual(self._selectedKey, true)"),
  "SelectItem must update only the old/new keyed card visuals.",
);
check(
  "selection_preserves_public_api",
  source.includes("function InventoryUI:SelectItem(key, includeDiagnostics)")
    && selectItem.includes("return self:_snapshotResult(includeDiagnostics)")
    && source.includes("function InventoryUI:SetCategory(name, includeDiagnostics)")
    && source.includes("function InventoryUI:SetSearch(text, includeDiagnostics)")
    && source.includes("function InventoryUI:SetRarity(name, includeDiagnostics)"),
  "The public method signatures and optional diagnostic return contract must remain compatible.",
);
check(
  "filter_and_authoritative_refresh_still_rebuild",
  applyFilter.includes("self:_renderGrid()")
    && source.includes("self._snapshot = self:_buildSnapshot(stats)")
    && source.includes("self:_applyFilter(false)"),
  "Filter or authoritative snapshot changes still need a complete content render.",
);
check(
  "keyed_refs_cover_duplicate_keys",
  source.includes("self._cardRefsByKey = {}")
    && renderGrid.includes("local keyedRefs = self._cardRefsByKey[key]")
    && renderGrid.includes("table.insert(keyedRefs, cardRef)")
    && selectionVisual.includes("for _, ref in ipairs(refs) do"),
  "Keyed refs must retain every rendered card even if an invalid duplicate key reaches the view.",
);
check(
  "selection_restores_hover_and_rarity_visuals",
  selectionVisual.includes("elseif ref.hovered then")
    && selectionVisual.includes("stroke.Color = ref.accent")
    && selectionVisual.includes("stroke.Color = PALETTE.Gold")
    && selectionVisual.includes("stroke.Thickness = 3")
    && renderGrid.includes("cardRef.hovered = true")
    && renderGrid.includes("cardRef.hovered = false"),
  "Old/new selection changes must preserve hover, rarity accent, and selected styling.",
);
check(
  "card_state_fidelity_is_unchanged",
  [
    'card:SetAttribute("InventoryCategory"',
    'card:SetAttribute("InventoryRarity"',
    'card:SetAttribute("InventoryEquipped"',
    'card:SetAttribute("InventoryLocked"',
    'local usesPetPreview = self:_applyPetPreview(cardRef.petPreview, item)',
    'local artMode = usesPetPreview and "ModelMatchedViewportV1" or self:_applyItemArt(art, item)',
    'card:SetAttribute("ArtMode", artMode)',
    'Name = "ItemRarity"',
    'Name = "ItemName"',
    'Name = "ItemQuantity"',
    'Name = "EquippedBadge"',
    'Name = "LockedBadge"',
  ].every((token) => renderGrid.includes(token)),
  "Full renders must retain art, text, quantity, rarity, equipped, and locked state.",
);

const connectionAdds = (
  renderGrid.match(/self:_connectScoped\(self\._cardConnections,/g) || []
).length;
check(
  "card_connections_are_fixed_per_rendered_card",
  connectionAdds === 3
    && orderedTokens(clearCards, [
      "self:_disconnectPool(self._cardConnections)",
      "card:Destroy()",
    ])
    && clearCards.includes("table.clear(self._cardRefsByKey)")
    && !selectionVisual.includes("_connect")
    && !selectItem.includes("_connect"),
  "Each live card has exactly MouseEnter, MouseLeave, and Activated connections; rebuild clears them first.",
);
check(
  "render_counters_are_observable",
  renderGrid.includes("self._gridRebuildCount = self._gridRebuildCount + 1")
    && selectItem.includes(
      "self._selectionVisualUpdateCount = self._selectionVisualUpdateCount + 1",
    )
    && getSnapshot.includes("gridRebuilds = self._gridRebuildCount")
    && getSnapshot.includes("selectionVisualUpdates = self._selectionVisualUpdateCount")
    && getSnapshot.includes("liveCards = #self._cards")
    && getSnapshot.includes("cardConnections = #self._cardConnections")
    && getSnapshot.includes(
      "cardConnectionBounded = #self._cardConnections <= (#self._cards * 3)",
    ),
  "Automation snapshots must expose rebuild, fast-selection, live-card, and connection counters.",
);
check(
  "compact_rarity_menu_is_bounded_and_scrollable",
  source.includes('self.RarityMenu = create("ScrollingFrame", self.GridPane')
    && source.includes("AutomaticCanvasSize = Enum.AutomaticSize.Y")
    && source.includes("ClipsDescendants = true")
    && responsive.includes(
      "availableRarityMenuHeight = compactContentHeight - rarityMenuTop - 4",
    )
    && responsive.includes(
      "math.min(desiredRarityMenuHeight, math.max(touchTarget + 12, availableRarityMenuHeight))",
    )
    && responsive.includes(
      "button.Size = UDim2.new(1, 0, 0, touchTarget)",
    )
    && responsive.includes(
      "self.RarityMenu.ScrollBarThickness = rarityMenuHeight < desiredRarityMenuHeight and 5 or 0",
    ),
  "Compact rarity options must retain touch height inside a clipped, adaptively bounded scrolling menu.",
);
check(
  "timed_heartbeat_requires_visible_detail_text",
  orderedTokens(timedRefresh, [
    "local selectedTimedVisible = selectedEndsAt",
    "selectedEndsAt > now",
    "self.Detail.Visible",
    "self.DetailDescription.Visible",
  ])
    && (timedRefresh.match(/if selectedTimedVisible then/g) || []).length >= 2,
  "Heartbeat countdowns require both the detail pane and its description text to be visible.",
);
const timedDetailMutationCalls = (
  refreshTimedItems.match(/self:_updateTimedItemDetail\(item, now\)/g) || []
).length;
const visibleSelectedTimedDetailMutation =
  /if item == self\._selectedItem\s+and self\.Detail\.Visible\s+and self\.DetailDescription\.Visible\s+then\s+local changed = self:_updateTimedItemDetail\(item, now\)\s+if changed then\s+selectedDetailChanged = true\s+end\s+end/.test(
    refreshTimedItems,
  );
check(
  "timed_detail_mutation_requires_visible_selected_item",
  timedDetailMutationCalls === 1 && visibleSelectedTimedDetailMutation,
  "The only per-second detail mutation must be structurally enclosed by selected-item, visible-detail, and visible-description guards.",
);
check(
  "timed_detail_ticks_do_not_rebuild_grid_or_actions",
  timedRefresh.includes(
    'self.Root:SetAttribute("InventoryTimedRefreshMode", "SelectedDetailHeartbeat")',
  )
    && timedRefresh.includes(
      "self.DetailDescription.Text = tostring(self._selectedItem.description",
    )
    && orderedTokens(refreshTimedItems, [
      "if expired then",
      "self:_applyFilter(false)",
    ])
    && tailSatisfies(
      timedRefresh,
      "RunService.Heartbeat:Connect",
      [],
      ["self:_renderGrid()", "self:_renderDetail()"],
    ),
  "Second-level countdown updates may touch selected detail text; full filter/grid/action rebuilding is reserved for expiry.",
);
check(
  "nonselected_timers_use_one_cancellable_expiry",
  timedRefresh.includes(
    'self.Root:SetAttribute("InventoryTimedRefreshMode", "ExpiryDelay")',
  )
    && timedRefresh.includes("self._timerThread = task.delay(")
    && timedRefresh.includes("task.cancel(timerThread)")
    && timedRefresh.includes("self._timerModeKey == modeKey")
    && destroy.includes("self:_stopTimedRefresh()"),
  "A nonselected boost must schedule one keyed expiry task that is cancelled on resync or destroy.",
);
check(
  "responsive_detail_visibility_resyncs_timer_mode",
  orderedTokens(absoluteSizeCallback, [
    "self:ApplyResponsive(",
    "self:_syncTimedRefresh()",
  ])
    && !responsive.includes("self:_syncTimedRefresh()"),
  "A resize must resync the selected-detail timer after responsive visibility changes without recursing from ApplyResponsive.",
);
check(
  "delete_confirmation_visibly_expires_and_cancels",
  deleteConfirmation.includes("self._deleteConfirmThread = task.delay(3")
    && deleteConfirmation.includes("generation ~= self._deleteConfirmGeneration")
    && deleteConfirmation.includes("task.cancel(confirmThread)")
    && deleteConfirmation.includes("self:_refreshDeleteConfirmationLabel()")
    && deleteConfirmation.includes(
      'button.Text = string.upper(awaitingConfirmation and "CONFIRM DELETE" or normalLabel)',
    )
    && tailSatisfies(
      deleteConfirmation,
      "self._deleteConfirmThread = task.delay(3",
      [
        'self.Root:SetAttribute("InventoryDeleteConfirmationKey", "")',
        "self:_refreshDeleteConfirmationLabel()",
      ],
    )
    && source.includes("self:_armDeleteConfirmation(key)")
    && destroy.includes("self:_cancelDeleteConfirmation(false)"),
  "Delete confirmation needs one cancellable generation-scoped delay that restores the visible action label.",
);

class CardLifecycleContract {
  constructor(connectionsPerCard) {
    this.connectionsPerCard = connectionsPerCard;
    this.gridRebuilds = 0;
    this.selectionVisualUpdates = 0;
    this.visibleKeys = new Set();
    this.selectedKey = undefined;
    this.liveCards = 0;
    this.cardConnections = 0;
  }

  rebuild(keys) {
    this.visibleKeys = new Set(keys);
    this.liveCards = keys.length;
    this.cardConnections = keys.length * this.connectionsPerCard;
    this.gridRebuilds += 1;
    if (!this.visibleKeys.has(this.selectedKey)) {
      this.selectedKey = keys[0];
    }
  }

  select(key) {
    if (!this.visibleKeys.has(key)) {
      return false;
    }
    if (this.selectedKey !== key) {
      this.selectedKey = key;
      this.selectionVisualUpdates += 1;
    }
    return true;
  }

  snapshot() {
    return {
      gridRebuilds: this.gridRebuilds,
      selectionVisualUpdates: this.selectionVisualUpdates,
      liveCards: this.liveCards,
      cardConnections: this.cardConnections,
      cardConnectionBounded:
        this.cardConnections <= this.liveCards * this.connectionsPerCard,
    };
  }
}

const lifecycle = new CardLifecycleContract(connectionAdds);
lifecycle.rebuild(Array.from({ length: 12 }, (_, index) => `item:${index + 1}`));
const warmed = lifecycle.snapshot();
for (let index = 0; index < 10_000; index += 1) {
  lifecycle.select(index % 2 === 0 ? "item:2" : "item:11");
}
const selected = lifecycle.snapshot();
check(
  "runtime_style_selection_stays_bounded",
  selected.gridRebuilds === warmed.gridRebuilds
    && selected.liveCards === warmed.liveCards
    && selected.cardConnections === warmed.cardConnections
    && selected.cardConnectionBounded
    && selected.selectionVisualUpdates === 10_000,
  "10,000 alternating selections must not rebuild cards or add connections.",
);

lifecycle.rebuild(["item:3", "item:7", "item:9"]);
const filtered = lifecycle.snapshot();
check(
  "runtime_style_filter_rebuild_replaces_pool",
  filtered.gridRebuilds === 2
    && filtered.liveCards === 3
    && filtered.cardConnections === 9
    && filtered.cardConnectionBounded,
  "A filter rebuild must replace, rather than accumulate, the live card connection pool.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      lifecycle: {
        warmed,
        afterSelections: selected,
        afterFilter: filtered,
      },
      files: [path.relative(repositoryRoot, inventoryPath)],
    },
    null,
    2,
  ),
);
