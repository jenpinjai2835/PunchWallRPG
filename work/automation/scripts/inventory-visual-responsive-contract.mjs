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
const flowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "inventory-visual-responsive.json",
);
const source = fs.readFileSync(inventoryPath, "utf8").replace(/\r\n?/g, "\n");
const flowSource = fs.readFileSync(flowPath, "utf8").replace(/\r\n?/g, "\n");
const flow = JSON.parse(flowSource);
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

function allocateToolbarWidths(totalWidth, compact, touchTarget = 44) {
  totalWidth = Math.max(0, Math.floor(Number(totalWidth) + 0.5));
  touchTarget = Math.max(1, Math.floor(Number(touchTarget) + 0.5));
  let gap = compact && totalWidth < 420 ? 6 : 8;
  let minimumSearchWidth = compact ? touchTarget : 160;
  let minimumCapacityWidth = Math.max(touchTarget, compact ? 78 : 86);
  let minimumRarityWidth = Math.max(touchTarget, compact ? 88 : 96);
  let requiredWidth =
    minimumSearchWidth + minimumCapacityWidth + minimumRarityWidth + gap * 2;
  if (totalWidth < requiredWidth) {
    gap = 4;
    minimumSearchWidth = touchTarget;
    minimumCapacityWidth = touchTarget;
    minimumRarityWidth = touchTarget;
    requiredWidth =
      minimumSearchWidth + minimumCapacityWidth + minimumRarityWidth + gap * 2;
  }
  const distributable = Math.max(0, totalWidth - requiredWidth);
  const searchExtra = Math.floor(distributable * 0.6);
  const controlsExtra = distributable - searchExtra;
  const capacityExtra = Math.floor(controlsExtra * 0.55);
  let search = minimumSearchWidth + searchExtra;
  const capacity = minimumCapacityWidth + capacityExtra;
  const rarity = Math.max(
    touchTarget,
    totalWidth - search - capacity - gap * 2,
  );
  let used = search + capacity + rarity + gap * 2;
  if (used > totalWidth) {
    search = Math.max(touchTarget, search - (used - totalWidth));
    used = search + capacity + rarity + gap * 2;
  }
  return { search, capacity, rarity, gap, used, totalWidth };
}

function calculateResponsiveBounds(viewportWidth, viewportHeight, uiScale) {
  const scale = Math.min(1.2, Math.max(0.75, Number(uiScale) || 1));
  const availableWidth = viewportWidth / scale;
  const availableHeight = viewportHeight / scale;
  const compactMinimumWidth = 320 / scale;
  const compactMinimumHeight = 280 / scale;
  const compactMaximumWidth = Math.max(1, (viewportWidth - 20) / scale);
  const compactMaximumHeight = Math.max(1, (viewportHeight - 24) / scale);
  const compactDesiredWidth = Math.max(
    compactMinimumWidth,
    availableWidth - 12,
  );
  const compactDesiredHeight = Math.max(
    compactMinimumHeight,
    availableHeight - 12,
  );
  const width = Math.min(compactDesiredWidth, compactMaximumWidth);
  const height = Math.min(compactDesiredHeight, compactMaximumHeight);
  const touchTarget = Math.ceil(44 / scale);
  const bodyWidth = width - 16;
  const toolbarContentWidth = Math.max(0, bodyWidth - 8 - 16);
  const toolbar = allocateToolbarWidths(
    toolbarContentWidth,
    true,
    touchTarget,
  );
  const categoryWidth = Math.max(
    touchTarget,
    Math.floor((bodyWidth - 8 - 16 - 20) / 5),
  );
  const categoryUsedWidth = categoryWidth * 5 + 4 * 5 + 8;
  const categoryAvailableWidth = bodyWidth - 8;
  const gridContentWidth = Math.max(1, bodyWidth - 8 - 24);
  const padding = 8;
  const minimumCellWidth = Math.max(touchTarget, 92);
  const fittingColumns = Math.max(
    1,
    Math.floor(
      (gridContentWidth + padding) / (minimumCellWidth + padding),
    ),
  );
  const preferredColumns = viewportWidth < 800 ? 3 : 4;
  const columns = Math.min(preferredColumns, fittingColumns);
  const cellWidth = Math.max(
    touchTarget,
    Math.floor(
      (gridContentWidth - (columns - 1) * padding) / columns,
    ),
  );
  return {
    scale,
    width,
    height,
    renderedWidth: width * scale,
    renderedHeight: height * scale,
    renderedTouchTarget: touchTarget * scale,
    toolbar,
    categoryUsedWidth,
    categoryAvailableWidth,
    gridContentWidth,
    columns,
    cellWidth,
  };
}

const allocation = block(
  "local function allocateToolbarWidths(totalWidth, useCompact, touchTarget)",
  "local function hasTimedItem",
);
const categoryBuild = block(
  "for order, category in ipairs(CATEGORIES) do",
  'self.GridPane = create("Frame", self.Body',
);
const categoryVisual = block(
  "function InventoryUI:_applyCategoryVisual(category)",
  "function InventoryUI:_setCategoryInteractionState(category)",
);
const categoryInteraction = block(
  "function InventoryUI:_setCategoryInteractionState(category)",
  "function InventoryUI:_renderCategories()",
);
const responsive = block(
  "function InventoryUI:ApplyResponsive(viewport, compact, uiScale)",
  "function InventoryUI:_enabledActionNames",
);

check(
  "desktop_search_has_explicit_readable_minimum",
  allocation.includes("useCompact and touchTarget or 160")
    && responsive.includes(
      'self.Root:SetAttribute("InventorySearchMinimumWidth", toolbarWidths.minimumSearch * scale)',
    )
    && responsive.includes(
      'self.Root:SetAttribute("InventorySearchReadable", toolbarWidths.readable)',
    ),
  "Desktop allocation must target at least 160 px and expose the result.",
);

check(
  "toolbar_uses_real_grid_width",
  responsive.includes("local toolbarContentWidth = math.max(0, gridPaneWidth - 16)")
    && responsive.includes(
      "local toolbarWidths = allocateToolbarWidths(toolbarContentWidth, useCompact, touchTarget)",
    )
    && responsive.includes("self.Search.Size = UDim2.fromOffset(searchWidth, toolbarHeight)")
    && responsive.includes(
      "searchWidth + toolbarGap + rarityWidth + toolbarGap",
    ),
  "Search, rarity, and capacity widths must share the actual GridPane toolbar width.",
);

check(
  "compact_minimums_and_touch_targets_are_rendered_units",
  responsive.includes("local touchTarget = math.ceil(44 / scale)")
    && responsive.includes("local compactMinimumWidth = 320 / scale")
    && responsive.includes("local compactMinimumHeight = 280 / scale")
    && responsive.includes(
      "local compactMaximumWidth = math.max(1, (viewport.X - compactSafeInsetX) / scale)",
    )
    && responsive.includes(
      "local compactMaximumHeight = math.max(1, (viewport.Y - compactSafeInsetY) / scale)",
    )
    && allocation.includes(
      "touchTarget = math.max(1, math.floor((tonumber(touchTarget) or 44) + 0.5))",
    ),
  "Compact minima and 44 px targets must be divided by UIScale before sizing descendants.",
);

for (const viewport of [
  { width: 320, height: 280 },
  { width: 360, height: 240 },
  { width: 480, height: 280 },
  { width: 568, height: 320 },
]) {
  for (const scale of [0.8, 1, 1.2]) {
    const result = calculateResponsiveBounds(
      viewport.width,
      viewport.height,
      scale,
    );
    check(
      `compact_${viewport.width}x${viewport.height}_scale_${String(scale).replace(".", "_")}_is_render_safe`,
      result.renderedWidth <= viewport.width
        && result.renderedHeight <= viewport.height
        && result.renderedTouchTarget >= 44,
      `Unexpected compact bounds: ${JSON.stringify(result)}`,
    );
    check(
      `compact_${viewport.width}x${viewport.height}_scale_${String(scale).replace(".", "_")}_content_is_bounded`,
      result.toolbar.used <= result.toolbar.totalWidth
        && result.categoryUsedWidth <= result.categoryAvailableWidth
        && result.columns >= 1
        && result.cellWidth * result.columns
          + Math.max(0, result.columns - 1) * 8
          <= result.gridContentWidth,
      `Unexpected compact content allocation: ${JSON.stringify(result)}`,
    );
  }
}

check(
  "narrow_grid_reduces_columns_before_overflow",
  responsive.includes("local gridContentWidth = math.max(1, gridPaneWidth - 24)")
    && responsive.includes("local fittingColumns = math.max(")
    && responsive.includes(
      "local columns = math.min(preferredColumns, fittingColumns)",
    )
    && responsive.includes(
      "math.floor((gridContentWidth - (columns - 1) * padding) / columns)",
    ),
  "A narrow scaled grid must reduce its column count instead of relying on a synthetic 280 logical px width.",
);

check(
  "rendered_bounds_are_runtime_observable",
  responsive.includes(
    'self.Root:SetAttribute("InventoryRenderedWindowWidth", windowWidth * scale)',
  )
    && responsive.includes(
      'self.Root:SetAttribute("InventoryRenderedWindowHeight", windowHeight * scale)',
    )
    && responsive.includes(
      '"InventoryWindowBoundsSafe"',
    )
    && source.includes(
      'renderedWindowWidth = tonumber(self.Root:GetAttribute("InventoryRenderedWindowWidth")) or 0',
    )
    && source.includes(
      'boundsSafe = self.Root:GetAttribute("InventoryWindowBoundsSafe") == true',
    ),
  "Tester snapshots need the calculated rendered size and safe-bounds invariant.",
);

check(
  "runtime_flow_covers_narrow_phone_scale_matrix",
  flow.name === "inventory-visual-responsive"
    && flowSource.includes("Inventory Visual QA Phone 568x320")
    && flowSource.includes("for _,scale in ipairs({.8,1,1.2})")
    && flowSource.includes("l.boundsSafe and l.insideSafeArea")
    && flowSource.includes("l.minTouchTarget>=43.5")
    && flowSource.includes("l.toolbarNoOverlap")
    && flowSource.includes("Inventory_Visual_Responsive_Phone_568x320_Scale120")
    && flow.cleanup.some(
      (step) =>
        step.tool === "execute_luau"
        && String(step.args?.code || "").includes(
          "Inventory Visual QA Phone 568x320",
        ),
    ),
  "The Studio handoff flow must exercise all supported scales on a narrow phone and clean up its custom device.",
);

check(
  "toolbar_overlap_contract_is_observable",
  allocation.includes("noOverlap = usedWidth <= totalWidth")
    && responsive.includes(
      'self.Toolbar:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)',
    )
    && responsive.includes(
      'self.Root:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)',
    )
    && source.includes(
      'searchWidth = tonumber(self.Root:GetAttribute("InventorySearchExpectedWidth")) or 0',
    )
    && source.includes(
      'toolbarNoOverlap = self.Root:GetAttribute("InventoryToolbarNoOverlap") == true',
    ),
  "The allocator and runtime hierarchy must expose the no-overlap invariant.",
);

for (const testCase of [
  { name: "reported_1277_desktop_grid", width: 379, compact: false },
  { name: "medium_desktop_grid", width: 440, compact: false },
  { name: "wide_desktop_grid", width: 640, compact: false },
]) {
  const result = allocateToolbarWidths(testCase.width, testCase.compact);
  check(
    `${testCase.name}_is_readable_and_bounded`,
    result.search >= 160
      && result.capacity >= 44
      && result.rarity >= 44
      && result.used <= result.totalWidth,
    `Unexpected desktop allocation: ${JSON.stringify(result)}`,
  );
}

for (const width of [280, 320, 400]) {
  const result = allocateToolbarWidths(width, true);
  check(
    `compact_${width}_keeps_touch_targets`,
    result.search >= 44
      && result.capacity >= 44
      && result.rarity >= 44
      && result.used <= result.totalWidth,
    `Unexpected compact allocation: ${JSON.stringify(result)}`,
  );
}

check(
  "category_pointer_and_selection_states_are_connected_once",
  [
    "button.Activated",
    "button.MouseEnter",
    "button.MouseLeave",
    "button.SelectionGained",
    "button.SelectionLost",
  ].every((token) => categoryBuild.includes(token))
    && categoryBuild.includes(
      'self.Root:SetAttribute("InventoryCategoryConnectionCount", #CATEGORIES * 5)',
    ),
  "Every category needs one activation, pointer pair, and selection pair.",
);

check(
  "selected_state_precedes_hover_state",
  categoryVisual.includes(
    'local state = selected and "Selected" or hovered and "Hovered" or "Idle"',
  )
    && categoryVisual.includes(
      "widgets.stroke.Color = selected and PALETTE.Gold",
    )
    && categoryVisual.includes(
      "widgets.indicator.Visible = selected or hovered",
    )
    && categoryVisual.includes(
      "widgets.arrow.Visible = selected and not self._layout.compact",
    ),
  "Selected chrome must win over pointer or keyboard focus styling.",
);

check(
  "hover_state_is_observable_and_source_aware",
  categoryInteraction.includes(
    "widgets.hovered = widgets.pointerHovered == true or widgets.selectionHovered == true",
  )
    && categoryInteraction.includes(
      'self.Root:SetAttribute("InventoryHoveredCategory", category)',
    )
    && categoryVisual.includes(
      'widgets.button:SetAttribute("InventoryVisualState", state)',
    ),
  "Hover must remain active while either pointer or selection focus owns it.",
);

check(
  "category_interaction_has_no_render_loop_or_connection_churn",
  !categoryVisual.includes(":Connect(")
    && !categoryInteraction.includes(":Connect(")
    && !categoryVisual.includes("RunService")
    && !categoryInteraction.includes("RunService")
    && !categoryVisual.includes("task.")
    && !categoryInteraction.includes("task."),
  "A hover transition may only update the existing bounded widget set.",
);

check(
  "capacity_copy_adapts_without_hiding_full_value",
  source.includes('InventoryCapacityTextMode", "Compact"')
    && source.includes('InventoryCapacityTextMode", "Condensed"')
    && source.includes('InventoryCapacityTextMode", "Full"')
    && source.includes('InventoryCapacityFullText", fullText'),
  "Narrow capacity chrome must retain an inspectable full semantic label.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      files: [
        path.relative(repositoryRoot, inventoryPath),
        path.relative(repositoryRoot, flowPath),
      ],
    },
    null,
    2,
  ),
);
