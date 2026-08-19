import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const config = read("punch-wall-rpg/src/shared/GameConfig.lua");
const profile = read("punch-wall-rpg/src/server/ProfilePersistence.lua");
const server = read("punch-wall-rpg/src/server/PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg/src/client/PunchWallClient.client.lua");
const flowText = read("automation/flows/honor-product-receipts.json");
const flow = JSON.parse(flowText);
const capture = read("automation/scripts/capture-honor-products.mjs");

const checks = {};
function check(name, condition, message) {
  checks[name] = Boolean(condition);
  assert.equal(Boolean(condition), true, `${name}: ${message}`);
}
const includesAll = (source, values) => values.every((value) => source.includes(value));
const expected = [
  ["HonorPouch25", "Honor Pouch", 25, 29, 3708804891, "STARTER", "46, 205, 255"],
  ["HonorCache90", "Honor Cache", 90, 79, 3708804911, "POPULAR", "89, 113, 255"],
  ["HonorVault300", "Honor Vault", 300, 199, 3708804933, "GREAT VALUE", "190, 78, 255"],
  ["HonorTreasury850", "Honor Treasury", 850, 499, 3708804944, "BEST VALUE", "255, 232, 105"],
];

check(
  "four_honor_pack_matrix_has_exact_live_ids",
  expected.every(([id, displayName, honor, robux, productId, badge, rgb]) => {
    const row = new RegExp(`id = "${id}"[^\\n]*displayName = "${displayName}"[^\\n]*robux = ${robux}[^\\n]*productId = ${productId}[^\\n]*honor = ${honor}[^\\n]*shopPage = "Honor"[^\\n]*worldOffer = false[^\\n]*valueBadge = "${badge}"[^\\n]*Color3\\.fromRGB\\(${rgb.replaceAll(", ", ",\\s*")}\\)`);
    return row.test(config);
  }),
  "Honor pack amounts, approved product IDs, prices, badges, colors, and routing must match Creator Dashboard.",
);
check(
  "existing_developer_product_ids_are_preserved_and_not_reused",
  includesAll(config, ["3708736246", "3708736283", "3708736312", "3708736344"])
    && expected.every(([, , , , productId]) => ![3708736246, 3708736283, 3708736312, 3708736344].includes(productId))
    && new Set(expected.map(([, , , , productId]) => productId)).size === 4,
  "Existing paid receipt mappings must remain stable and the four new IDs must be unique and unreused.",
);
check(
  "receipt_schema_persists_exact_honor_metadata",
  includesAll(profile, [
    'ProfilePersistence.ContractVersion = "2.2.0"',
    "entry.Honor = strictNonNegativeInteger(source.Honor)",
    'return nil, "receipt_entry_invalid_honor"',
    "profile.Honor += honorGrant",
    "entry.Honor = honorGrant",
    "snapshot.Honor += sanitizedEntry.Honor",
    "entry.Honor ~= nil",
  ]),
  "Honor must participate in sanitization, durable ledger metadata, snapshot reconcile, and grant recognition.",
);
check(
  "receipt_is_single_kind_and_overflow_fails_without_seen_entry",
  includesAll(profile, [
    "product_grant_kind_count_invalid",
    "invalid_honor_balance",
    "honor receipt replay granted twice",
    "rejected honor receipt changed balance or durable replay state",
    "ProfilePersistence.GetSeenReceiptProductId(cappedHonorProfile",
  ]),
  "A receipt may grant one exact kind; overflow and replay must never lose or duplicate paid Honor.",
);
check(
  "server_live_apply_and_prompt_are_fail_closed",
  includesAll(server, [
    "grantedHonor = durableEntry.Honor",
    "grantedHonor = product.honor",
    'setStat(player, "Honor", currentHonor + grantedHonor)',
    'reason = "honor_balance_headroom_required"',
    "profileReady(player, true)",
    "invalidProductIds",
    "validatePromptMetadata",
    '"product_identity_mismatch"',
    "promptState.__global = now + 1.5",
    "promptState[product.id] = now + 1.5",
    "MarketplaceService:PromptProductPurchase(player, product.productId)",
  ]),
  "Only a configured server-resolved product may prompt and a durable receipt must apply exact Honor with headroom.",
);
check(
  "honor_products_never_consume_world_offer_positions",
  includesAll(server, [
    "if product.worldOffer == false then",
    "placementIndex += 1",
    "Missing Premium Offer position",
  ]),
  "The four existing world offers must remain the complete bounded set.",
);
check(
  "shop_has_five_pages_and_filters_honor_products",
  includesAll(client, [
    'Pages = { "Fists", "Premium", "Boosts", "Honor", "Robux" }',
    'elseif page == "Honor" or page == "Robux" then',
    'if (source.shopPage or "Robux") ~= page then',
    "item.isHonorProduct = item.honor ~= nil",
    'pipHolder.Name = "HonorPackTierPips"',
    'card:SetAttribute("HonorPackPipCount", item.honorPackTier)',
    "GameConfig.ShopArt.HonorIcon",
    'or page == "Honor" and "HONOR PACKS"',
  ]),
  "Honor currency packs require a dedicated Shop tab and must not be mixed into Robux refills.",
);
check(
  "configured_ui_supports_truthful_live_price_and_interaction",
  includesAll(client, [
    '"HONOR %s  •  CURRENCY ONLY  •  GATES APPLY"',
    'or not identityValid and "WrongProduct"',
    'or info.IsForSale ~= true and "OffSale"',
    'purchaseReady = purchaseConfigured',
    'purchaseUiState == "Opening" and (compactCards and "OPEN" or "OPENING...")',
    'purchaseUiState == "CheckoutOpen" and (compactCards and "ROBLOX" or "CHECKOUT OPEN")',
    'purchaseUiState == "Verifying" and (compactCards and "VERIFY" or "VERIFYING...")',
    'purchaseUiState == "Granted" and (compactCards and "ADDED" or "GRANTED")',
    'item.regionalPriceState == "CheckoutOnly" and "SEE PRICE"',
    'shared.PunchWallPurchaseRuntime.SetProductUiState(item.id, "Opening"',
    "PromptProductPurchaseFinished:Connect",
    '"PURCHASE CANCELED • NO CHARGE"',
    "action.Active = actionEnabled",
    "action.Selectable = actionEnabled",
    "action.TextWrapped = false",
    "action.TextTruncate = Enum.TextTruncate.AtEnd",
    "compactActionTextConstraint.MinTextSize = 7",
    "compactActionTextConstraint.MaxTextSize = 10",
    "MarkControlUnavailable",
  ]),
  "Configured Honor cards must use Marketplace price state and bind BUY, while invalid metadata remains fail-closed.",
);
check(
  "purchase_success_is_bound_to_authoritative_receipt_feedback",
  includesAll(server, [
    'type = "PremiumPurchase"',
    "product = product.id",
    "newHonorBalance",
    '"+%d HONOR ADDED"',
  ]) && includesAll(client, [
    'payload.type == "PremiumPurchase"',
    'SetProductUiState(payload.product, "Granted"',
    'gui:SetAttribute("PurchaseUiBalance"',
  ]),
  "Prompt closure may only enter Verifying; exact Honor success must come from the durable receipt feedback payload.",
);
check(
  "hall_routes_to_optional_currency_page_without_bypassing_gates",
  includesAll(client, [
    '"OPTIONAL HONOR PACKS"',
    '"Currency only • relic Depth and Rebirth gates still apply"',
    '"GET HONOR"',
    'shared.PunchWallHeroShopPage = "Honor"',
  ]),
  "Hall spend/equip and Shop currency purchase journeys must remain separate and truthful.",
);
check(
  "studio_contract_covers_first_replay_mismatch_overflow_and_reconcile",
  includesAll(server, [
    'action == "HonorProductReceiptContract"',
    '"studio-honor-receipt"',
    'mismatchError == "receipt_product_mismatch"',
    'overflowError == "invalid_honor_balance"',
    "ApplyReceiptEntryToSnapshot(reconciled, entry)",
  ]),
  "The Studio-only harness must execute the durable receipt core without granting through a client bypass.",
);
check(
  "runtime_flow_is_exact_place_and_console_complete",
  flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725"
    && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$"
    && flow.steps.some((step) => step.label === "Honor receipt first replay mismatch overflow and reconcile are exact")
    && flow.steps.some((step) => step.label === "four Honor cards resolve exact live prices and bind safe purchase actions")
    && flow.steps.some((step) => step.label === "set deterministic 740 phone viewport")
    && flow.steps.some((step) => step.label === "compact transient purchase states and cancel recovery fit")
    && flow.steps.some((step) => step.label === "restore default viewport and remove Honor flow device")
    && flowText.includes("{{'Opening','OPEN'},{'CheckoutOpen','ROBLOX'},{'Verifying','VERIFY'},{'Granted','ADDED'}}")
    && flowText.includes("action.TextFits==true")
    && flow.steps.some((step) => step.type === "assertNoConsoleErrors" && step.source === "runtimeConsole")
    && flow.steps.some((step) => step.type === "assertNoConsoleErrors" && step.source === "postStopConsole"),
  "The focused flow must bind the exact Studio and prove both runtime and post-stop console cleanliness.",
);
check(
  "flow_never_manufactures_paid_receipt_state",
  !/ProcessReceipt\s*=|PromptProductPurchaseFinished|PurchaseGranted/.test(flowText)
    && !flowText.includes("ConfigurePurchaseTestIds"),
  "Studio may inspect metadata/UI and run the receipt core contract, but must not pretend a Roblox checkout occurred.",
);
check(
  "visual_capture_matrix_is_responsive_fingerprinted_and_clean",
  includesAll(capture, [
    'width: 1366, height: 768, form: "Desktop"',
    'width: 844, height: 390, form: "Phone"',
    'width: 740, height: 360, form: "Phone"',
    "HonorPackPipCount",
    "3708804891",
    "3708804944",
    "RegionalPriceResolved",
    "ShopActionBound",
    "b.Text=='BUY'",
    "runtime console",
    "post-stop console",
    "source mismatch for",
    "summary.cleanup.default !== true",
  ]),
  "Desktop and compact phone captures must attest exact sources, card semantics, clean consoles, and simulator cleanup.",
);

console.log(JSON.stringify({ ok: true, passed: Object.values(checks).filter(Boolean).length, total: Object.keys(checks).length, packs: expected.map(([id, , honor, robux, productId]) => ({ id, honor, robux, productId })), checks }, null, 2));
