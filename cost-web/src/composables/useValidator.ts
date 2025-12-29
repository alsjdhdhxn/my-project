/**
 * 前端验证器
 * 从元数据 RULES_CONFIG.validate 读取验证规则，按 order 顺序执行
 */

export interface ValidateRule {
  order: number;
  type: 'required' | 'notZero' | 'min' | 'max' | 'pattern' | 'custom';
  value?: any;
  message: string;
  expression?: string; // custom 类型使用
}

export interface ValidationResult {
  valid: boolean;
  field?: string;
  rowId?: any;
  message?: string;
}

/**
 * 从列元数据提取验证规则
 */
export function extractValidateRules(columns: any[]): Map<string, ValidateRule[]> {
  const rulesMap = new Map<string, ValidateRule[]>();
  
  for (const col of columns) {
    if (!col.rulesConfig) continue;
    
    let config: any;
    try {
      config = typeof col.rulesConfig === 'string' 
        ? JSON.parse(col.rulesConfig) 
        : col.rulesConfig;
    } catch {
      continue;
    }
    
    if (config.validate && Array.isArray(config.validate)) {
      // 按 order 排序
      const rules = [...config.validate].sort((a, b) => (a.order || 0) - (b.order || 0));
      rulesMap.set(col.fieldName, rules);
    }
  }
  
  return rulesMap;
}

/**
 * 验证单个字段值
 */
export function validateField(value: any, rules: ValidateRule[]): ValidationResult {
  for (const rule of rules) {
    const result = checkRule(value, rule);
    if (!result.valid) {
      return result;
    }
  }
  return { valid: true };
}

/**
 * 检查单条规则
 */
function checkRule(value: any, rule: ValidateRule): ValidationResult {
  switch (rule.type) {
    case 'required':
      if (value === null || value === undefined || value === '') {
        return { valid: false, message: rule.message };
      }
      break;
      
    case 'notZero':
      if (value === 0 || value === '0') {
        return { valid: false, message: rule.message };
      }
      break;
      
    case 'min':
      if (typeof value === 'number' && value < rule.value) {
        return { valid: false, message: rule.message };
      }
      break;
      
    case 'max':
      if (typeof value === 'number' && value > rule.value) {
        return { valid: false, message: rule.message };
      }
      break;
      
    case 'pattern':
      if (typeof value === 'string' && rule.value) {
        const regex = new RegExp(rule.value);
        if (!regex.test(value)) {
          return { valid: false, message: rule.message };
        }
      }
      break;
      
    case 'custom':
      // 自定义表达式验证，后续扩展
      break;
  }
  
  return { valid: true };
}

/**
 * 验证整个数据集
 * @param rows 数据行
 * @param rulesMap 字段 → 验证规则映射
 * @returns 第一个验证失败的结果，或 valid: true
 */
export function validateRows(
  rows: any[], 
  rulesMap: Map<string, ValidateRule[]>
): ValidationResult {
  for (const row of rows) {
    // 跳过已删除的行
    if (row._isDeleted) continue;
    
    for (const [field, rules] of rulesMap) {
      const value = row[field];
      const result = validateField(value, rules);
      
      if (!result.valid) {
        return {
          valid: false,
          field,
          rowId: row.id,
          message: result.message
        };
      }
    }
  }
  
  return { valid: true };
}
