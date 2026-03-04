# tableCode.field Regression Checklist

## Scope
- Runtime: `cost-web` v3 master-detail pages.
- Rule source: `T_COST_PAGE_RULE` with `RULE_TYPE='CALC'`.
- Formula syntax: `tableCode.field`.

## Pre-check
1. Migration SQL applied successfully.
2. Browser cache cleared and frontend rebuilt.
3. Ensure no `BROADCAST` rules are active.

## Core cases (each target page)
1. Open page with existing records.
2. Edit one master field used by detail formulas.
3. Verify all detail tabs recalc immediately.
4. Switch between stack mode and tab mode and verify values are consistent.
5. Edit one detail field used by detail formulas.
6. Verify same-row detail calc updates immediately.
7. Verify aggregate fields on master recalc immediately.
8. Save and re-query; verify values persist and match recalc.

## Interaction cases
1. Lookup fillback on master row:
   - Fillback field changes.
   - Master formula recalcs.
   - Related detail tabs recalc.
2. Lookup fillback on detail row:
   - Detail formula recalcs.
   - Master aggregate recalcs.
3. Add detail row (manual add):
   - Initial calc runs.
   - Aggregate recalcs.
4. Batch select add detail rows:
   - New rows calculated.
   - Aggregate recalcs.
5. Delete/mark delete detail row:
   - Aggregate recalcs excluding deleted rows.

## Metadata hot reload
1. Modify a CALC rule in metadata config.
2. Trigger metadata reload (or refresh page).
3. Re-edit same source field and verify new formula takes effect.

## Negative/guard cases
1. Invalid table code in expression should fail fast in UI validation/review process.
2. Formula referencing non-existing field should not crash page; should log error and set result `0`.
3. Circular dependencies should not hang UI (verify max-pass convergence).

## Performance smoke
1. On a page with 200+ detail rows, edit a high-frequency master field.
2. Ensure UI stays responsive and recalculation finishes in acceptable time.

## Rollback drill
1. Reset git branch to pre-migration commit (or `git revert`).
2. Execute SQL rollback script.
3. Rebuild frontend and re-open one key page; verify old behavior restored.
