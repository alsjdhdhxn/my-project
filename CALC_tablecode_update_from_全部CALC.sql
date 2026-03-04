prompt Updating CALC rules to tableCode.field mode...
set define off
set feedback on

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"batchQty","formulaField":"CostMaterial.apexGoodsname","formulas":{"__branch_0":{"key":"胶囊","expression":"CostPinggu.apexPl / 10000 * (1 + CostMaterial.exaddMater / 100)","triggerFields":["CostPinggu.apexPl","CostMaterial.exaddMater"],"matchType":"regex"},"__branch_1":{"key":"^(?!.*胶囊).*$","expression":"CostPinggu.apexPl * (1 + CostMaterial.exaddMater / 100) / 1000000","triggerFields":["CostPinggu.apexPl","CostMaterial.exaddMater"],"matchType":"regex"}}},{"field":"costBatch","expression":"CostMaterial.batchQty * CostMaterial.price","triggerFields":["CostMaterial.batchQty","CostMaterial.price"]}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 480
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"costBatch","expression":"CostPackage.batchQty * CostPackage.price","triggerFields":["CostPackage.batchQty","CostPackage.price"]},{"field":"batchQty","formulaField":"CostPackage.apexGoodsname","formulas":{"__branch_0":{"key":"桶|说明书|小盒|标签|瓶|盖","expression":"CostPinggu.apexPl / CostPinggu.pPerpack * (1 + CostPackage.exaddMater / 100)","triggerFields":["CostPinggu.apexPl","CostPinggu.pPerpack","CostPackage.exaddMater"],"matchType":"regex"},"__branch_1":{"key":"硬片|铝箔|复合膜","expression":"CostPackage.perHl * CostPinggu.apexPl * (1 + CostPackage.exaddMater / 100) / 1000000","triggerFields":["CostPackage.perHl","CostPinggu.apexPl","CostPackage.exaddMater"],"matchType":"regex"},"__branch_2":{"key":"大纸箱","expression":"ceil(CostPinggu.apexPl / (CostPinggu.pPerpack * CostPinggu.sPerback) * (1 + CostPackage.exaddMater / 100))","triggerFields":["CostPinggu.apexPl","CostPinggu.pPerpack","CostPinggu.sPerback","CostPackage.exaddMater"],"matchType":"regex"},"__branch_3":{"key":"托盘","expression":"ceil(CostPinggu.apexPl / (CostPinggu.pPerpack * CostPinggu.sPerback * CostPinggu.xPerback) * (1 + CostPackage.exaddMater / 100))","triggerFields":["CostPinggu.apexPl","CostPinggu.pPerpack","CostPinggu.sPerback","CostPinggu.xPerback","CostPackage.exaddMater"],"matchType":"regex"},"__branch_4":{"key":"中盒","expression":"ceil(CostPinggu.apexPl / (CostPinggu.mPerpack * CostPinggu.sPerback) * (1 + CostPackage.exaddMater / 100))","triggerFields":["CostPinggu.apexPl","CostPinggu.mPerpack","CostPinggu.sPerback","CostPackage.exaddMater"],"matchType":"regex"}}}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 484
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"salemoney","expression":"CostPingguLq.outPriceRmb / CostPingguLq.apexPl * (CostPingguLq.yield / 100)","triggerFields":["CostPingguLq.outPriceRmb","CostPingguLq.apexPl","CostPingguLq.yield"]},{"field":"jgfBatch","expression":"CostPingguLq.salemoney - CostPingguLq.totalCost","triggerFields":["CostPingguLq.salemoney","CostPingguLq.totalCost"]},{"field":"costPerbox","expression":"CostPingguLq.totalCost / CostPingguLq.apexPl","triggerFields":["CostPingguLq.totalCost","CostPingguLq.apexPl"]},{"field":"jgfPerqp","expression":"CostPingguLq.jgfBatch / CostPingguLq.apexPl * 1000","triggerFields":["CostPingguLq.jgfBatch","CostPingguLq.apexPl"]},{"field":"mlPerqp","expression":"CostPingguLq.jgfPerqp - CostPingguLq.costPerqp","triggerFields":["CostPingguLq.jgfPerqp","CostPingguLq.costPerqp"]},{"field":"yJgRe","expression":"CostPingguLq.jgfPerqp / CostPingguLq.annualQty","triggerFields":["CostPingguLq.jgfPerqp","CostPingguLq.annualQty"]},{"field":"yMl","expression":"CostPingguLq.mlPerqp / CostPingguLq.annualQty","triggerFields":["CostPingguLq.mlPerqp","CostPingguLq.annualQty"]},{"field":"ySale","expression":"CostPingguLq.annualQty * CostPingguLq.outPriceRmb * CostPingguLq.yield","triggerFields":["CostPingguLq.annualQty","CostPingguLq.outPriceRmb","CostPingguLq.yield"]}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 604
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"batchQty","expression":"CostMaterialLq.perHl * (1 + CostMaterialLq.exaddMater / 100) / 1000000","triggerFields":["CostMaterialLq.perHl","CostMaterialLq.exaddMater"]},{"field":"costBatch","expression":"CostMaterialLq.batchQty * CostMaterialLq.price","triggerFields":["CostMaterialLq.batchQty","CostMaterialLq.price"]}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 616
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"costBatch","expression":"CostPackageLq.batchQty * CostPackageLq.price","triggerFields":["CostPackageLq.batchQty","CostPackageLq.price"]},{"field":"batchQty","formulaField":"CostPackageLq.apexGoodsname","formulas":{"__branch_0":{"key":"桶|说明书|小盒|标签|瓶|盖注射器|适配器|量杯|勺|分度器","expression":"CostPingguLq.apexPl / CostPingguLq.pPerpack * (1 + CostPackageLq.exaddMater / 100)","triggerFields":["CostPingguLq.apexPl","CostPingguLq.pPerpack","CostPackageLq.exaddMater"],"matchType":"regex"},"__branch_1":{"key":"大纸箱","expression":"ceil(CostPingguLq.apexPl / (CostPingguLq.pPerpack * CostPingguLq.sPerback) * (1 + CostPackageLq.exaddMater / 100))","triggerFields":["CostPingguLq.apexPl","CostPingguLq.pPerpack","CostPingguLq.sPerback","CostPackageLq.exaddMater"],"matchType":"regex"},"__branch_2":{"key":"托盘","expression":"ceil(CostPingguLq.apexPl / (CostPingguLq.pPerpack * CostPingguLq.sPerback * CostPingguLq.xPerback) * (1 + CostPackageLq.exaddMater / 100))","triggerFields":["CostPingguLq.apexPl","CostPingguLq.pPerpack","CostPingguLq.sPerback","CostPingguLq.xPerback","CostPackageLq.exaddMater"],"matchType":"regex"}}}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 620
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

UPDATE t_cost_page_rule
   SET rules = q'~[{"field":"salemoney","expression":"CostPinggu.outPriceRmb / CostPinggu.pPerpack * CostPinggu.apexPl * (CostPinggu.yield / 100)","triggerFields":["CostPinggu.outPriceRmb","CostPinggu.pPerpack","CostPinggu.apexPl","CostPinggu.yield"]},{"field":"jgfBatch","expression":"CostPinggu.salemoney - CostPinggu.totalCost","triggerFields":["CostPinggu.salemoney","CostPinggu.totalCost"]},{"field":"costPerbox","expression":"CostPinggu.totalCost / CostPinggu.apexPl * CostPinggu.pPerpack","triggerFields":["CostPinggu.totalCost","CostPinggu.apexPl","CostPinggu.pPerpack"]},{"field":"jgfPerqp","expression":"CostPinggu.jgfBatch / CostPinggu.apexPl * 1000","triggerFields":["CostPinggu.jgfBatch","CostPinggu.apexPl"]},{"field":"mlPerqp","expression":"CostPinggu.jgfPerqp - CostPinggu.costPerqp","triggerFields":["CostPinggu.jgfPerqp","CostPinggu.costPerqp"]},{"field":"yJgRe","expression":"CostPinggu.jgfPerqp / 1000 * CostPinggu.annualQty","triggerFields":["CostPinggu.jgfPerqp","CostPinggu.annualQty"]},{"field":"yMl","expression":"CostPinggu.mlPerqp / 1000 * CostPinggu.annualQty","triggerFields":["CostPinggu.mlPerqp","CostPinggu.annualQty"]},{"field":"ySale","expression":"CostPinggu.annualQty / CostPinggu.pPerpack * CostPinggu.outPriceRmb * CostPinggu.yield","triggerFields":["CostPinggu.annualQty","CostPinggu.pPerpack","CostPinggu.outPriceRmb","CostPinggu.yield"]}]~',
       update_time = SYSTIMESTAMP
 WHERE id = 475
   AND rule_type = 'CALC'
   AND NVL(deleted, 0) = 0;

COMMIT;

prompt Verify updated rows:
SELECT id, page_code, component_key, rule_type, update_time
  FROM t_cost_page_rule
 WHERE id IN (475, 480, 484, 604, 616, 620)
 ORDER BY id;
