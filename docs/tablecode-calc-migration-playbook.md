# tableCode.field Migration Playbook

## 1. Export SQL Data For Patch Generation

Run:

`cost-server/src/main/resources/db/init/03_增量更新/CALC_tablecode_required_queries.sql`

Send me all query results (CSV/Excel/text all OK). I will generate final patch `INSERT` statements for `T_COST_PAGE_RULE_CALC_PATCH_20260304`.

## 2. Apply Migration

1. Execute:
   - `cost-server/src/main/resources/db/init/03_增量更新/CALC_tablecode_migration_template.sql`
2. Fill and execute the generated `INSERT INTO T_COST_PAGE_RULE_CALC_PATCH_20260304 ...` statements.
3. Execute the `MERGE` section in the same migration SQL.
4. Run verification SQL in the file.

## 3. Full-Page Regression

Use checklist:

`docs/tablecode-calc-regression-checklist.md`

## 4. Rollback (Code + SQL)

### Git rollback

If this migration branch is only for this change:

`git reset --hard <before_migration_commit>`

If already pushed/shared:

`git revert <migration_commit_sha>`

### SQL rollback

Execute:

`cost-server/src/main/resources/db/init/03_增量更新/CALC_tablecode_rollback.sql`

This restores `T_COST_PAGE_RULE.RULES` and `UPDATE_TIME` from backup table `T_COST_PAGE_RULE_CALC_BAK_20260304`.
