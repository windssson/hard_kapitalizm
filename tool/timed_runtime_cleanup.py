from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
changed_files: set[str] = set()


def fail(message: str) -> None:
    raise RuntimeError(message)


def load(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def save(rel: str, text: str) -> None:
    path = ROOT / rel
    old = path.read_text(encoding="utf-8")
    if text != old:
        path.write_text(text, encoding="utf-8")
        changed_files.add(rel)


def replace_exact(rel: str, old: str, new: str, expected: int = 1) -> None:
    text = load(rel)
    count = text.count(old)
    if count != expected:
        fail(f"{rel}: expected {expected} exact matches, found {count}: {old[:100]!r}")
    save(rel, text.replace(old, new, expected))


def remove_line_exact(rel: str, line: str, expected: int = 1) -> None:
    replace_exact(rel, line, "", expected)


def _matching_delimiter(text: str, start: int, opener: str, closer: str) -> int:
    if text[start] != opener:
        fail(f"delimiter scan did not start on {opener!r}")

    depth = 0
    i = start
    quote: str | None = None
    triple = False
    line_comment = False
    block_comment_depth = 0

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment_depth:
            if ch == "/" and nxt == "*":
                block_comment_depth += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_comment_depth -= 1
                i += 2
                continue
            i += 1
            continue

        if quote is not None:
            if triple:
                token = quote * 3
                if text.startswith(token, i):
                    quote = None
                    triple = False
                    i += 3
                    continue
                i += 1
                continue

            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_comment_depth = 1
            i += 2
            continue
        if ch in ("'", '"'):
            if text.startswith(ch * 3, i):
                quote = ch
                triple = True
                i += 3
            else:
                quote = ch
                triple = False
                i += 1
            continue

        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth == 0:
                return i
        i += 1

    fail(f"unterminated delimiter {opener}{closer} starting at {start}")
    return -1


def remove_named_function(rel: str, name: str, expected: int = 1) -> None:
    text = load(rel)
    pattern = re.compile(
        rf"(?m)^[ \t]*(?:Future<[^\n]+>|[A-Za-z_][A-Za-z0-9_<>,? ]*)\s+{re.escape(name)}\s*\("
    )
    matches = list(pattern.finditer(text))
    if len(matches) != expected:
        fail(f"{rel}: expected {expected} function(s) named {name}, found {len(matches)}")

    for match in reversed(matches):
        start = match.start()
        open_paren = text.find("(", match.start(), match.end())
        close_paren = _matching_delimiter(text, open_paren, "(", ")")
        body_open = text.find("{", close_paren + 1)
        if body_open < 0:
            fail(f"{rel}: body not found for {name}")
        body_close = _matching_delimiter(text, body_open, "{", "}")
        end = body_close + 1
        while end < len(text) and text[end] in "\r\n":
            end += 1
        text = text[:start] + text[end:]

    save(rel, text)


def remove_if_block(rel: str, marker: str, expected: int = 1) -> None:
    text = load(rel)
    positions: list[int] = []
    offset = 0
    while True:
        idx = text.find(marker, offset)
        if idx < 0:
            break
        positions.append(idx)
        offset = idx + len(marker)
    if len(positions) != expected:
        fail(f"{rel}: expected {expected} if-block markers, found {len(positions)}")

    for idx in reversed(positions):
        body_open = text.find("{", idx, idx + len(marker) + 8)
        if body_open < 0:
            fail(f"{rel}: opening brace missing for marker {marker!r}")
        body_close = _matching_delimiter(text, body_open, "{", "}")
        end = body_close + 1
        while end < len(text) and text[end] in "\r\n":
            end += 1
        text = text[:idx] + text[end:]

    save(rel, text)


# ---------------------------------------------------------------------------
# AR-GE: UI is presentation/manual-acceleration only. Natural completion is
# runtime-owned.
# ---------------------------------------------------------------------------
ARGE_SCREEN = "lib/features/arge/ui/arge_screen.dart"
replace_exact(
    ARGE_SCREEN,
    """  Future<void> _refresh() async {\n    await ref.read(argeActionProvider).completeDueBuildingUpgrades();\n    if (!mounted) return;\n    _refreshCenterEcosystem();\n  }\n""",
    """  Future<void> _refresh() async {\n    _refreshCenterEcosystem();\n  }\n""",
)
replace_exact(
    ARGE_SCREEN,
    """    ref.listen<AsyncValue<ArgeResearchModel?>>(activeArgeResearchProvider, (\n      previous,\n      next,\n    ) {\n      final research = next.value;\n      if (research != null && research.isDone) {\n        ref.read(argeActionProvider).completeResearch(research.id);\n      }\n    });\n\n""",
    "",
)
replace_exact(
    ARGE_SCREEN,
    """    ref.listen<AsyncValue<BuildingUpgradeModel?>>(\n      activeArgeCenterUpgradeProvider(centerId),\n      (previous, next) {\n        final upgrade = next.value;\n        if (upgrade != null && upgrade.finishAt.isBefore(DateTime.now())) {\n          ref.read(argeActionProvider).completeDueBuildingUpgrades();\n        }\n      },\n    );\n\n""",
    "",
)
remove_line_exact(ARGE_SCREEN, "                                              onCollect: _onCollect,\n")
remove_named_function(ARGE_SCREEN, "_onCollect")
replace_exact(
    ARGE_SCREEN,
    """              onPressed: isDone\n                  ? () => _onCompleteCenterConstruction(\n                      construction['id'].toString(),\n                    )\n                  : null,\n""",
    "              onPressed: null,\n",
)
replace_exact(
    ARGE_SCREEN,
    "                isDone ? 'KURULUMU TAMAMLA' : 'KURULUM DEVAM EDİYOR',\n",
    "                isDone ? 'TAMAMLANIYOR...' : 'KURULUM DEVAM EDİYOR',\n",
)
remove_named_function(ARGE_SCREEN, "_onCompleteCenterConstruction")

ARGE_PROVIDER = "lib/features/arge/data/arge_provider.dart"
for method in ("completeResearch", "completeConstruction", "completeDueBuildingUpgrades"):
    remove_named_function(ARGE_PROVIDER, method)
remove_line_exact(
    ARGE_PROVIDER,
    "import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';\n",
)

# ---------------------------------------------------------------------------
# Logistics construction countdown: remove post-frame natural completion.
# ---------------------------------------------------------------------------
LOGISTICS_SCREEN = "lib/features/logistics/ui/logistics_management_screen.dart"
remove_line_exact(LOGISTICS_SCREEN, "                  constructionId: constructionId,\n")
replace_exact(
    LOGISTICS_SCREEN,
    """                  onFinish: () =>\n                      _handleConstructionFinished(context, constructionId),\n""",
    "",
)
remove_named_function(LOGISTICS_SCREEN, "_handleConstructionFinished")
remove_line_exact(LOGISTICS_SCREEN, "  final String constructionId;\n")
remove_line_exact(LOGISTICS_SCREEN, "  final VoidCallback? onFinish;\n")
remove_line_exact(LOGISTICS_SCREEN, "    required this.constructionId,\n")
remove_line_exact(LOGISTICS_SCREEN, "    this.onFinish,\n")
remove_line_exact(LOGISTICS_SCREEN, "  bool _triggered = false;\n")
replace_exact(
    LOGISTICS_SCREEN,
    """    if (remaining.inSeconds <= 0 && !_triggered) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (!mounted || _triggered) return;\n        _triggered = true;\n        widget.onFinish?.call();\n      });\n    }\n""",
    "",
)
replace_exact(
    LOGISTICS_SCREEN,
    "                    ? 'Tamamlanmaya Hazır'\n",
    "                    ? 'Tamamlanıyor...'\n",
)
remove_named_function("lib/features/logistics/data/logistics_provider.dart", "completeConstruction")

# ---------------------------------------------------------------------------
# Warehouses: reads no longer complete upgrades; old natural-completion action
# methods are removed.
# ---------------------------------------------------------------------------
WAREHOUSE_PROVIDER = "lib/features/warehouse/data/warehouse_provider.dart"
remove_named_function(WAREHOUSE_PROVIDER, "_tryCompleteDueWarehouseUpgrades")
remove_line_exact(WAREHOUSE_PROVIDER, "    await _tryCompleteDueWarehouseUpgrades(supabase);\n")
replace_exact(
    WAREHOUSE_PROVIDER,
    """  try {\n    await _tryCompleteDueWarehouseUpgrades(supabase);\n  } catch (_) {}\n\n""",
    "",
)
for method in ("completeConstruction", "completeDueWarehouseUpgrades", "completeLogisticsTransfer"):
    remove_named_function(WAREHOUSE_PROVIDER, method)

WAREHOUSE_DETAIL = "lib/features/warehouse/ui/warehouse_detail_screen.dart"
remove_line_exact(
    WAREHOUSE_DETAIL,
    "    await ref.read(warehouseActionProvider).completeDueWarehouseUpgrades();\n",
    expected=2,
)

# ---------------------------------------------------------------------------
# Standard production/business providers: remove obsolete natural completion
# compatibility surfaces. Manual gold/ad actions remain intact.
# ---------------------------------------------------------------------------
for rel in (
    "lib/features/field/data/field_provider.dart",
    "lib/features/store/data/store_provider.dart",
    "lib/features/factory/data/factory_provider.dart",
    "lib/features/mine/data/mine_provider.dart",
    "lib/features/farm/data/farm_provider.dart",
):
    remove_named_function(rel, "completeConstruction")
    remove_named_function(rel, "completeDueBuildingUpgrades")

# The shared guard keeps only the read-only active-upgrade query helper.
replace_exact(
    "lib/core/data/building_upgrade_guard_service.dart",
    """\n/// Legacy compatibility shim.\n///\n/// Natural timed upgrade completion is exclusively owned by TimedTaskRuntime.\n/// Feature screens/providers may still call this method while the old surface\n/// API is being cleaned up, but it must never issue a completion RPC.\n@Deprecated('TimedTaskRuntime owns natural building-upgrade completion.')\nFuture<void> tryCompleteDueBuildingUpgrades(\n  SupabaseClient supabase,\n) async {\n  return;\n}\n""",
    "",
)

# ---------------------------------------------------------------------------
# Instant logistics transfers: start RPC returns a timed task; TimedTaskRuntime
# owns even zero-duration completion. UI must not call completion directly.
# ---------------------------------------------------------------------------
MARKET_SCREEN = "lib/features/market/ui/market_screen.dart"
remove_if_block(MARKET_SCREEN, "    if (isInstant && result['transfer_id'] != null) {")
replace_exact(
    MARKET_SCREEN,
    "          ? 'Market alımı anında tamamlandı ve deponuza teslim edildi!'\n",
    "          ? 'Market alımı başlatıldı; anlık teslimat işleniyor.'\n",
)

PUBLIC_PROFILE = "lib/features/auth/ui/public_profile_screen.dart"
remove_if_block(PUBLIC_PROFILE, "      if (isInstant && result['transfer_id'] != null) {")
replace_exact(
    PUBLIC_PROFILE,
    "            ? 'Satın alma işlemi anında tamamlandı!'\n",
    "            ? 'Satın alma işlemi başlatıldı; anlık teslimat işleniyor.'\n",
)

# ---------------------------------------------------------------------------
# Ownership assertions. After this cleanup, the old domain completion RPCs and
# helper surfaces must not exist anywhere in frontend lib/. Completion goes
# only through complete_timed_task_runtime_due.
# ---------------------------------------------------------------------------
forbidden = (
    "complete_building_construction",
    "complete_arge_research",
    "complete_logistics_transfer",
    "complete_due_player_building_upgrades",
    "complete_due_warehouse_upgrades",
    "process_tender_deliveries",
    "finish_building_boost",
    "completeResearch(",
    "completeDueBuildingUpgrades(",
    "completeDueWarehouseUpgrades(",
    "completeConstruction(",
    "completeLogisticsTransfer(",
    "tryCompleteDueBuildingUpgrades(",
    "_tryCompleteDueWarehouseUpgrades(",
    "_handleConstructionFinished",
    "_onCompleteCenterConstruction",
    "_onCollect",
    "onFinished:",
    "onFinish:",
)

violations: list[str] = []
runtime_due_count = 0
for path in (ROOT / "lib").rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT).as_posix()
    runtime_due_count += text.count("complete_timed_task_runtime_due")
    for token in forbidden:
        if token in text:
            for line_no, line in enumerate(text.splitlines(), 1):
                if token in line:
                    violations.append(f"{rel}:{line_no}: {token}: {line.strip()}")

if violations:
    print("Legacy timed-completion ownership violations remain:", file=sys.stderr)
    for item in violations:
        print(item, file=sys.stderr)
    sys.exit(2)

if runtime_due_count != 3:
    # Current service contains the RPC name in the call, validation error text,
    # and debug text. This assertion catches accidental removal or duplication.
    fail(f"expected 3 complete_timed_task_runtime_due references, found {runtime_due_count}")

print("Changed files:")
for rel in sorted(changed_files):
    print(f" - {rel}")
print("TimedTaskRuntime ownership cleanup assertions passed.")
