declare namespace Api {
  namespace Metadata {
    /** 表元数据 */
    interface TableMetadata {
      id: number;
      tableCode: string;
      tableName: string;
      queryView: string;
      targetTable: string;
      pkColumn: string;
      sequenceName: string;
      parentTableCode?: string;
      parentFkColumn?: string;
      columns: ColumnMetadata[];
    }

    /** 列元数据 */
    interface ColumnMetadata {
      id: number;
      fieldName: string;
      columnName: string;
      headerText: string;
      dataType: 'text' | 'number' | 'date' | 'datetime' | 'select' | 'lookup';
      displayOrder: number;
      editable: boolean;
      required: boolean;
      searchable: boolean;
      width?: number;
      dictType?: string;
      lookupCode?: string;
      rulesConfig?: string;
      /** 是否虚拟列：不存不取，只有公式计算 */
      isVirtual?: boolean;
    }

    /** 页面组件 */
    interface PageComponent {
      id: number;
      pageCode: string;
      componentKey: string;
      componentType: 'LAYOUT' | 'GRID' | 'FORM' | 'BUTTON' | 'TABS' | 'LOGIC_AGG' | 'LOGIC_BROADCAST' | 'LOGIC_FIELD' | 'LOGIC_MAPPING';
      parentKey?: string;
      refTableCode?: string;
      componentConfig?: string;
      sortOrder: number;
      children?: PageComponent[];
    }

    /** 字典项 */
    interface DictItem {
      value: string;
      label: string;
      sortOrder: number;
    }
  }
}
