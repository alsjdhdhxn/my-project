declare module '@/logic/calc-engine' {
  export interface CalcRule {
    targetField?: string;
    deps?: string[];
    [key: string]: any;
  }

  export interface ParsedPageConfig {
    groupField?: string;
    tabs?: Array<{
      key: string;
      mode?: string;
      groupValue?: string;
      groupValues?: string[];
      [key: string]: any;
    }>;
    [key: string]: any;
  }

  export interface RowData {
    id?: number | string | null;
    _isNew?: boolean;
    _isDeleted?: boolean;
    _changeType?: Record<string, string>;
    [key: string]: any;
  }

  export function compileCalcRules(...args: any[]): any;
  export function compileAggRules(...args: any[]): any;
  export function calcRowFields(...args: any[]): any;
  export function calcAggregates(...args: any[]): any;
  export function getAffectedRules(...args: any[]): any;
  export function generateTempId(...args: any[]): any;
  export function initRowData(...args: any[]): any;
  export function clearRowChanges(...args: any[]): any;
}
