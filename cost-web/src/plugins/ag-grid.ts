/**
 * AG Grid 模块注册
 * 在应用启动时全局注册，企业版功能通过 try/catch 动态加载
 */
import { ModuleRegistry, AllCommunityModule } from 'ag-grid-community';

// 全局标记企业版是否可用
declare global {
  interface Window {
    __AG_GRID_ENTERPRISE__: boolean;
  }
}

export async function setupAgGrid() {
  // 默认注册社区版模块
  ModuleRegistry.registerModules([AllCommunityModule]);
  window.__AG_GRID_ENTERPRISE__ = false;

  try {
    // 动态导入企业版模块
    const { AllEnterpriseModule, LicenseManager } = await import('ag-grid-enterprise');
    
    // 设置 License Key
    LicenseManager.setLicenseKey(
      '[TRIAL]_this_{AG_Charts_and_AG_Grid}_Enterprise_key_{AG-117218}_is_granted_for_evaluation_only___Use_in_production_is_not_permitted___Please_report_misuse_to_legal@ag-grid.com___For_help_with_purchasing_a_production_key_please_contact_info@ag-grid.com___You_are_granted_a_{Single_Application}_Developer_License_for_one_application_only___All_Front-End_JavaScript_developers_working_on_the_application_would_need_to_be_licensed___This_key_will_deactivate_on_{5 February 2026}____[v3]_[0102]_MTc3MDI0OTYwMDAwMA==9d3efdd51844a5a7d4f5ab5808f942f1'
    );
    
    // 注册企业版模块（会覆盖社区版）
    ModuleRegistry.registerModules([AllEnterpriseModule]);
    window.__AG_GRID_ENTERPRISE__ = true;
    
    console.log('✅ AG Grid 企业版已启用');
  } catch (e) {
    console.warn('⚠️ AG Grid 企业版未安装，使用社区版功能');
  }
}

/**
 * 检查企业版是否可用
 */
export function isEnterpriseEnabled(): boolean {
  return window.__AG_GRID_ENTERPRISE__ === true;
}
