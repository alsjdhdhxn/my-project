prompt Importing table user_views...
set feedback off
set define off

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_BOM_GOODS_TREE_V', 836, 'select a.treeid,
       a.pid,
       a.goodsid,
       b.goodsname,
       (case
         when b.zx_wms_goodsclass in (1, 12) and b.gspflag = 1 and
              b.goodsno like ''%A%'' then
          ''4''
         when b.zx_wms_goodsclass in (10) and b.gspflag = 1 then
          ''0''
         when b.zx_wms_goodsclass in (7, 8, 9) and b.gspflag = 1 then
          ''1''
         when b.zx_wms_goodsclass in (5, 13) and b.gspflag = 1 then
          ''3''
         when b.zx_wms_goodsclass in (6) and b.gspflag = 1 then
          ''5''
         when b.zx_wms_goodsclass in (1, 2, 3, 4) and b.gspflag = 1 and
              b.goodsno not like ''%A%'' then
          ''2''
       end) useflag,
       b.standardtype,
       a.lvcode,
       a.useqty,
       a.entryid
  from MPCS_MRP_GOODS_TREE_V@HYERP a, pub_goods@HYERP b
 where a.goodsid = b.goodsid
', 'select a.treeid,
       a.pid,
       a.goodsid,
       b.goodsname,
       (case
         when b.zx_wms_goodsclass in (1, 12) and b.gspflag = 1 and
              b.goodsno like ''%A%'' then
          ''4''
         when b.zx_wms_goodsclass in (10) and b.gspflag = 1 then
          ''0''
         when b.zx_wms_goodsclass in (7, 8, 9) and b.gspflag = 1 then
          ''1''
         when b.zx_wms_goodsclass in (5, 13) and b.gspflag = 1 then
          ''3''
         when b.zx_wms_goodsclass in (6) and b.gspflag = 1 then
          ''5''
         when b.zx_wms_goodsclass in (1, 2, 3, 4) and b.gspflag = 1 and
              b.goodsno not like ''%A%'' then
          ''2''
       end) useflag,
       b.standardtype,
       a.lvcode,
       a.useqty,
       a.entryid
  from MPCS_MRP_GOODS_TREE_V@HYERP a, pub_goods@HYERP b
 where a.goodsid = b.goodsid
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_CUSTOMER_V', 196, 'SELECT CUSTOMID,
       CUSTOMNAME,
       ZONE,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_CUSTOMER
 WHERE DELETED = 0
', 'SELECT CUSTOMID,
       CUSTOMNAME,
       ZONE,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_CUSTOMER
 WHERE DELETED = 0
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_FORMONEY_V', 439, 'SELECT
    a.FMID,
    NVL(a.FMOPCODE, b.FMOPCODE) AS FMOPCODE,
    NVL(a.FMNAME, b.FMNAME) AS FMNAME,
    NVL(a.FMSIGN, b.FMSIGN) AS FMSIGN,
    NVL(a.FMUNIT, b.FMUNIT) AS FMUNIT,
    NVL(a.FMRATE, b.FMRATE) AS FMRATE,
    a.USESTATUS,
    a.DELETED,
    a.CREATE_TIME,
    a.UPDATE_TIME,
    a.CREATE_BY,
    a.UPDATE_BY
FROM T_COST_FORMONEY a
LEFT JOIN pub_formoney_v@hyerp b ON a.FMID = b.FMID
WHERE a.DELETED = 0 OR a.DELETED IS NULL
', 'SELECT
    a.FMID,
    NVL(a.FMOPCODE, b.FMOPCODE) AS FMOPCODE,
    NVL(a.FMNAME, b.FMNAME) AS FMNAME,
    NVL(a.FMSIGN, b.FMSIGN) AS FMSIGN,
    NVL(a.FMUNIT, b.FMUNIT) AS FMUNIT,
    NVL(a.FMRATE, b.FMRATE) AS FMRATE,
    a.USESTATUS,
    a.DELETED,
    a.CREATE_TIME,
    a.UPDATE_TIME,
    a.CREATE_BY,
    a.UPDATE_BY
FROM T_COST_FORMONEY a
LEFT JOIN pub_formoney_v@hyerp b ON a.FMID = b.FMID
WHERE a.DELETED = 0 OR a.DELETED IS NULL
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_GOODS_PRICE_V', 583, 'SELECT GOODSID,
       GOODSNAME,
       PRICE,
       USEFLAG,
       GOODSTYPE,
       PACKTYPE,
       FACTORYNAME,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY,
       ISERP,
       CASE
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), ''#'') <> ''system''
            AND PRICE IS NULL THEN ''erp-price-null''
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), ''#'') <> ''system'' THEN ''erp-updated''
           WHEN ISERP = 1 THEN ''erp''
           ELSE NULL
       END AS ROW_CLASS_FLAG
  FROM T_COST_GOODS_PRICE
', 'SELECT GOODSID,
       GOODSNAME,
       PRICE,
       USEFLAG,
       GOODSTYPE,
       PACKTYPE,
       FACTORYNAME,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY,
       ISERP,
       CASE
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), ''#'') <> ''system''
            AND PRICE IS NULL THEN ''erp-price-null''
           WHEN ISERP = 1
            AND NVL(LOWER(UPDATE_BY), ''#'') <> ''system'' THEN ''erp-updated''
           WHEN ISERP = 1 THEN ''erp''
           ELSE NULL
       END AS ROW_CLASS_FLAG
  FROM T_COST_GOODS_PRICE
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_GOODS_V', 760, 'SELECT a.GOODSID,
       a.GOODSNO,
       a.GOODSNAME,
       a.PRICE,
       a.SUQTY,
       a.USEFLAG,
       a.FACTORYNAME,
       a.STANDARDTYPE,
       a.ZX_PL,
       a.ZX_MINIMUM,
       a.APPROVEDOCNO,
       a.BASEUNITQTY,
       a.ZX_CUSTOMERID,
       b.CUSTOMNAME,
       a.TARGETMARKET,
       a.HOLDERSNAME,
       a.ISERP,
       a.GOODSTYPE,
       a.PACKTYPE,
       c.TRANPOSNAME,
       a.BOMID,
       a.LASTSUQTY,
       a.TRANPOSID,
       b.ZONE,
       a.DELETED,
       a.CREATE_TIME,
       a.UPDATE_TIME,
       a.CREATE_BY,
       a.UPDATE_BY
  FROM T_COST_GOODS a, T_COST_CUSTOMER b, T_COST_TRANPOSER c
 WHERE a.USEFLAG = ''产成品''
   AND a.DELETED = 0
   AND a.ZX_CUSTOMERID = b.CUSTOMID(+)
   AND a.TRANPOSID = c.TRANPOSID(+)
', 'SELECT a.GOODSID,
       a.GOODSNO,
       a.GOODSNAME,
       a.PRICE,
       a.SUQTY,
       a.USEFLAG,
       a.FACTORYNAME,
       a.STANDARDTYPE,
       a.ZX_PL,
       a.ZX_MINIMUM,
       a.APPROVEDOCNO,
       a.BASEUNITQTY,
       a.ZX_CUSTOMERID,
       b.CUSTOMNAME,
       a.TARGETMARKET,
       a.HOLDERSNAME,
       a.ISERP,
       a.GOODSTYPE,
       a.PACKTYPE,
       c.TRANPOSNAME,
       a.BOMID,
       a.LASTSUQTY,
       a.TRANPOSID,
       b.ZONE,
       a.DELETED,
       a.CREATE_TIME,
       a.UPDATE_TIME,
       a.CREATE_BY,
       a.UPDATE_BY
  FROM T_COST_GOODS a, T_COST_CUSTOMER b, T_COST_TRANPOSER c
 WHERE a.USEFLAG = ''产成品''
   AND a.DELETED = 0
   AND a.ZX_CUSTOMERID = b.CUSTOMID(+)
   AND a.TRANPOSID = c.TRANPOSID(+)
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_PINGGU_DTL_V', 527, 'select a.docid,
       a.apex_goodsid,
       a.apex_goodsname,
       a.dtl_useflag,
       a.spec,
       a.per_hl,
       a.exadd_mater,
       a.batch_qty,
       a.price,
       a.cost_batch,
       a.memo,
       a.dtlid,
       a.apex_factoryname,
       a.apex_factoryid,
       a.modifydate,
       a.base_price,
       a.suqty,
       a.goodstype,
       a.goodsname_en,
       b.APEX_PL,
       b.P_PERPACK,
       b.S_PERBACK,
       b.X_PERBACK
  from t_cost_pinggu_dtl a, t_cost_pinggu b
 where a.docid = b.docid
', 'select a.docid,
       a.apex_goodsid,
       a.apex_goodsname,
       a.dtl_useflag,
       a.spec,
       a.per_hl,
       a.exadd_mater,
       a.batch_qty,
       a.price,
       a.cost_batch,
       a.memo,
       a.dtlid,
       a.apex_factoryname,
       a.apex_factoryid,
       a.modifydate,
       a.base_price,
       a.suqty,
       a.goodstype,
       a.goodsname_en,
       b.APEX_PL,
       b.P_PERPACK,
       b.S_PERBACK,
       b.X_PERBACK
  from t_cost_pinggu_dtl a, t_cost_pinggu b
 where a.docid = b.docid
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('T_COST_TRANPOSER_V', 203, 'SELECT CUSTOMID,
       TRANPOSID,
       TRANPOSNAME,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_TRANPOSER
 WHERE DELETED = 0
', 'SELECT CUSTOMID,
       TRANPOSID,
       TRANPOSNAME,
       ISERP,
       DELETED,
       CREATE_TIME,
       UPDATE_TIME,
       CREATE_BY,
       UPDATE_BY
  FROM T_COST_TRANPOSER
 WHERE DELETED = 0
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_AUDIT_LOG', 207, 'SELECT
    ID,
    USER_NAME,
    OPERATION_TIME,
    PAGE_CODE,
    TABLE_CODE,
    TABLE_NAME,
    RECORD_ID,
    OPERATION_TYPE,
    FIELD_CHANGES,
    CREATE_TIME,
    0 AS DELETED
FROM T_COST_AUDIT_LOG
', 'SELECT
    ID,
    USER_NAME,
    OPERATION_TIME,
    PAGE_CODE,
    TABLE_CODE,
    TABLE_NAME,
    RECORD_ID,
    OPERATION_TYPE,
    FIELD_CHANGES,
    CREATE_TIME,
    0 AS DELETED
FROM T_COST_AUDIT_LOG
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_CUSTOMER_LOOKUP', 218, 'SELECT a.CUSTOMID,
       a.CUSTOMNAME,
       a.ZONE AS COUNTRY,
       b.TRANPOSNAME AS LIVERY,
       b.TRANPOSID,
       0 AS DELETED
  FROM T_COST_CUSTOMER_V a, T_COST_TRANPOSER_V b
 WHERE a.CUSTOMID = b.CUSTOMID
', 'SELECT a.CUSTOMID,
       a.CUSTOMNAME,
       a.ZONE AS COUNTRY,
       b.TRANPOSNAME AS LIVERY,
       b.TRANPOSID,
       0 AS DELETED
  FROM T_COST_CUSTOMER_V a, T_COST_TRANPOSER_V b
 WHERE a.CUSTOMID = b.CUSTOMID
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_GOODS_BY_APEX', 362, 'SELECT c.GOODSID AS P_GOODSID,
       c.GOODSNAME,
       c.GOODSTYPE,
       c.PACKTYPE,
       c.TRANPOSID,
       c.TRANPOSNAME,
       c.ZX_CUSTOMERID,
       c.CUSTOMNAME,
       c.ZONE,
       a.APEX_GOODSID AS GOODSID,
       0 AS DELETED
  FROM T_COST_PINGGU_DTL a, T_COST_PINGGU b, T_COST_GOODS_V c
 WHERE a.DOCID = b.DOCID
   AND b.GOODSID = c.GOODSID
', 'SELECT c.GOODSID AS P_GOODSID,
       c.GOODSNAME,
       c.GOODSTYPE,
       c.PACKTYPE,
       c.TRANPOSID,
       c.TRANPOSNAME,
       c.ZX_CUSTOMERID,
       c.CUSTOMNAME,
       c.ZONE,
       a.APEX_GOODSID AS GOODSID,
       0 AS DELETED
  FROM T_COST_PINGGU_DTL a, T_COST_PINGGU b, T_COST_GOODS_V c
 WHERE a.DOCID = b.DOCID
   AND b.GOODSID = c.GOODSID
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_GOODS_LOOKUP', 653, 'SELECT a.GOODSID,
       a.GOODSNAME,
       a.APPROVEDOCNO AS MA_NO,
       a.ZX_PL AS APEX_PL,
       a.HOLDERSNAME AS MAH,
       a.ZX_MINIMUM AS P_PERPACK,
       a.BASEUNITQTY AS S_PERBACK,
       a.ZX_CUSTOMERID AS CUSTOMID,
       a.CUSTOMNAME,
       CASE WHEN a.ISERP = 0 AND b.PGOODSID IS NULL THEN ''ERP未搭建BOM''
            ELSE ''ERP已搭建BOM'' END AS MEMO,
       a.GOODSTYPE AS STRENGTH,
       a.TRANPOSNAME AS LIVERY,
       a.DELETED
  FROM T_COST_GOODS_V a
  LEFT JOIN mpcs_pr_bom_doc@hyerp b ON a.GOODSID = b.PGOODSID AND b.USESTATUS = 1 AND a.ISERP = 1
 WHERE a.USEFLAG = ''产成品''
   AND (a.DELETED = 0 OR a.DELETED IS NULL)
', 'SELECT a.GOODSID,
       a.GOODSNAME,
       a.APPROVEDOCNO AS MA_NO,
       a.ZX_PL AS APEX_PL,
       a.HOLDERSNAME AS MAH,
       a.ZX_MINIMUM AS P_PERPACK,
       a.BASEUNITQTY AS S_PERBACK,
       a.ZX_CUSTOMERID AS CUSTOMID,
       a.CUSTOMNAME,
       CASE WHEN a.ISERP = 0 AND b.PGOODSID IS NULL THEN ''ERP未搭建BOM''
            ELSE ''ERP已搭建BOM'' END AS MEMO,
       a.GOODSTYPE AS STRENGTH,
       a.TRANPOSNAME AS LIVERY,
       a.DELETED
  FROM T_COST_GOODS_V a
  LEFT JOIN mpcs_pr_bom_doc@hyerp b ON a.GOODSID = b.PGOODSID AND b.USESTATUS = 1 AND a.ISERP = 1
 WHERE a.USEFLAG = ''产成品''
   AND (a.DELETED = 0 OR a.DELETED IS NULL)
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_PGOODS_BY_MGOODS', 527, 'SELECT a.apex_goodsid   goodsid,
       a.apex_goodsname,
       a.dtl_useflag,
       b.factoryname,
       a.price,
       b.goodsno,
       d.goodsid        pgoodsid,
       d.goodsno        pgoodsno,
       d.goodsname,
       c.apex_pl,
       a.batch_qty,
       a.deleted
  FROM T_COST_PINGGU_DTL a, t_cost_goods b, t_cost_pinggu c, t_cost_goods d
 WHERE a.apex_goodsid = b.goodsid
   AND a.docid = c.docid
   AND c.goodsid = d.goodsid
   and a.deleted = 0
   and b.deleted = 0
   and c.deleted = 0
   and d.deleted = 0
', 'SELECT a.apex_goodsid   goodsid,
       a.apex_goodsname,
       a.dtl_useflag,
       b.factoryname,
       a.price,
       b.goodsno,
       d.goodsid        pgoodsid,
       d.goodsno        pgoodsno,
       d.goodsname,
       c.apex_pl,
       a.batch_qty,
       a.deleted
  FROM T_COST_PINGGU_DTL a, t_cost_goods b, t_cost_pinggu c, t_cost_goods d
 WHERE a.apex_goodsid = b.goodsid
   AND a.docid = c.docid
   AND c.goodsid = d.goodsid
   and a.deleted = 0
   and b.deleted = 0
   and c.deleted = 0
   and d.deleted = 0
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_PINGGU_MATERIAL', 589, 'SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.APEX_FACTORYNAME,
    d.BASE_PRICE, d.GOODSTYPE, d.EXADD_MATER, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN d.DTL_USEFLAG = ''辅料'' AND REGEXP_LIKE(d.APEX_GOODSNAME, ''胶囊'') THEN ''B''
         WHEN d.DTL_USEFLAG IN (''原料'', ''辅料'') THEN ''C'' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN (''原料'', ''辅料'') AND (d.DELETED = 0 OR d.DELETED IS NULL)
', 'SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.APEX_FACTORYNAME,
    d.BASE_PRICE, d.GOODSTYPE, d.EXADD_MATER, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN d.DTL_USEFLAG = ''辅料'' AND REGEXP_LIKE(d.APEX_GOODSNAME, ''胶囊'') THEN ''B''
         WHEN d.DTL_USEFLAG IN (''原料'', ''辅料'') THEN ''C'' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN (''原料'', ''辅料'') AND (d.DELETED = 0 OR d.DELETED IS NULL)
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_PINGGU_PACKAGE', 734, 'SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.EXADD_MATER, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.SUQTY,
    d.APEX_FACTORYNAME, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''桶|说明书|小盒|标签|瓶|盖'') THEN ''A''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''硬片|铝箔|复合膜'') THEN ''D''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''大纸箱'') THEN ''E''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''托盘'') THEN ''F'' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN (''非印字包材'', ''印字包材'') AND (d.DELETED = 0 OR d.DELETED IS NULL)
', 'SELECT d.DTLID AS ID, d.DOCID AS MASTER_ID, d.APEX_GOODSID, d.APEX_GOODSNAME, d.DTL_USEFLAG,
    d.SPEC, d.PER_HL, d.EXADD_MATER, d.PRICE, d.BATCH_QTY, d.COST_BATCH, d.SUQTY,
    d.APEX_FACTORYNAME, d.MEMO, d.DELETED, d.CREATE_TIME, d.UPDATE_TIME,
    d.CREATE_BY, d.UPDATE_BY,
    CASE WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''桶|说明书|小盒|标签|瓶|盖'') THEN ''A''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''硬片|铝箔|复合膜'') THEN ''D''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''大纸箱'') THEN ''E''
         WHEN REGEXP_LIKE(d.APEX_GOODSNAME, ''托盘'') THEN ''F'' ELSE NULL END AS FORMULA_TYPE
FROM T_COST_PINGGU_DTL d
WHERE d.DTL_USEFLAG IN (''非印字包材'', ''印字包材'') AND (d.DELETED = 0 OR d.DELETED IS NULL)
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_RESOURCE_PERMISSION', 552, 'SELECT
    res.ID,
    res.PAGE_CODE,
    res.RESOURCE_NAME,
    res.RESOURCE_TYPE,
    res.IS_HARDCODED,
    res.ICON,
    res.ROUTE,
    res.PARENT_ID,
    res.SORT_ORDER,
    r.ID AS ROLE_ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    rp.ID AS ROLE_PAGE_ID,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY,
    CASE WHEN rp.ID IS NOT NULL THEN 1 ELSE 0 END AS IS_AUTHORIZED
FROM T_COST_RESOURCE res
CROSS JOIN T_COST_ROLE r
LEFT JOIN T_COST_ROLE_PAGE rp
    ON rp.PAGE_CODE = res.PAGE_CODE
    AND rp.ROLE_ID = r.ID
ORDER BY res.SORT_ORDER
', 'SELECT
    res.ID,
    res.PAGE_CODE,
    res.RESOURCE_NAME,
    res.RESOURCE_TYPE,
    res.IS_HARDCODED,
    res.ICON,
    res.ROUTE,
    res.PARENT_ID,
    res.SORT_ORDER,
    r.ID AS ROLE_ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    rp.ID AS ROLE_PAGE_ID,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY,
    CASE WHEN rp.ID IS NOT NULL THEN 1 ELSE 0 END AS IS_AUTHORIZED
FROM T_COST_RESOURCE res
CROSS JOIN T_COST_ROLE r
LEFT JOIN T_COST_ROLE_PAGE rp
    ON rp.PAGE_CODE = res.PAGE_CODE
    AND rp.ROLE_ID = r.ID
ORDER BY res.SORT_ORDER
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_ROLE', 88, 'SELECT
    r.ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    r.DESCRIPTION
FROM T_COST_ROLE r
', 'SELECT
    r.ID,
    r.ROLE_CODE,
    r.ROLE_NAME,
    r.DESCRIPTION
FROM T_COST_ROLE r
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_ROLE_PAGE', 237, 'SELECT
    rp.ID,
    rp.ROLE_ID,
    rp.PAGE_CODE,
    res.RESOURCE_NAME AS PAGE_NAME,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY
FROM T_COST_ROLE_PAGE rp
LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE
', 'SELECT
    rp.ID,
    rp.ROLE_ID,
    rp.PAGE_CODE,
    res.RESOURCE_NAME AS PAGE_NAME,
    rp.BUTTON_POLICY,
    rp.COLUMN_POLICY,
    rp.ROW_POLICY
FROM T_COST_ROLE_PAGE rp
LEFT JOIN T_COST_RESOURCE res ON rp.PAGE_CODE = res.PAGE_CODE
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_USER', 325, 'SELECT
    u.ID,
    u.USERNAME,
    u.PASSWORD,
    u.REAL_NAME,
    u.EMAIL,
    u.PHONE,
    u.DEPARTMENT_ID,
    d.DEPT_NAME,
    u.STATUS,
    u.DELETED,
    u.CREATE_BY,
    u.CREATE_TIME,
    u.UPDATE_BY,
    u.UPDATE_TIME
FROM T_COST_USER u
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID
WHERE u.DELETED = 0
', 'SELECT
    u.ID,
    u.USERNAME,
    u.PASSWORD,
    u.REAL_NAME,
    u.EMAIL,
    u.PHONE,
    u.DEPARTMENT_ID,
    d.DEPT_NAME,
    u.STATUS,
    u.DELETED,
    u.CREATE_BY,
    u.CREATE_TIME,
    u.UPDATE_BY,
    u.UPDATE_TIME
FROM T_COST_USER u
LEFT JOIN T_COST_DEPARTMENT d ON u.DEPARTMENT_ID = d.ID
WHERE u.DELETED = 0
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

insert into user_views (VIEW_NAME, TEXT_LENGTH, TEXT, TEXT_VC, TYPE_TEXT_LENGTH, TYPE_TEXT, OID_TEXT_LENGTH, OID_TEXT, VIEW_TYPE_OWNER, VIEW_TYPE, SUPERVIEW_NAME, EDITIONING_VIEW, READ_ONLY, CONTAINER_DATA, BEQUEATH, ORIGIN_CON_ID, DEFAULT_COLLATION, CONTAINERS_DEFAULT, CONTAINER_MAP, EXTENDED_DATA_LINK, EXTENDED_DATA_LINK_MAP, HAS_SENSITIVE_COLUMN, ADMIT_NULL, PDB_LOCAL_ONLY)
values ('V_COST_USER_ROLE', 170, 'SELECT
    ur.ID,
    ur.USER_ID,
    u.USERNAME,
    u.REAL_NAME,
    ur.ROLE_ID
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0
', 'SELECT
    ur.ID,
    ur.USER_ID,
    u.USERNAME,
    u.REAL_NAME,
    ur.ROLE_ID
FROM T_COST_USER_ROLE ur
LEFT JOIN T_COST_USER u ON ur.USER_ID = u.ID AND u.DELETED = 0
', null, null, null, null, null, null, null, 'N', 'N', 'N', 'DEFINER', 0, 'USING_NLS_COMP', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO', 'NO');

prompt Done.
