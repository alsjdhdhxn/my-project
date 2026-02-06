-- ============================================================
-- 存储过程定义
-- 成本管理系统所有存储过程
-- ============================================================

-- 同步客户和分销商数据
CREATE OR REPLACE PROCEDURE PROC_SYNC_CUSTOMER AS
BEGIN
    MERGE INTO T_COST_CUSTOMER t
    USING (SELECT CUSTOMID, CUSTOMNAME, ZONE FROM PUB_CUSTOMER@hyerp) s
    ON (t.CUSTOMID = s.CUSTOMID)
    WHEN MATCHED THEN
        UPDATE SET t.CUSTOMNAME = s.CUSTOMNAME, t.ZONE = s.ZONE,
                   t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
    WHEN NOT MATCHED THEN
        INSERT (CUSTOMID, CUSTOMNAME, ZONE, ISERP, DELETED, CREATE_BY, CREATE_TIME)
        VALUES (s.CUSTOMID, s.CUSTOMNAME, s.ZONE, 1, 0, 'sync', SYSTIMESTAMP);

    MERGE INTO T_COST_TRANPOSER t
    USING (SELECT TRANPOSID, COMPANYID AS CUSTOMID, TRANPOSNAME FROM BMS_TR_POS_DEF@hyerp) s
    ON (t.TRANPOSID = s.TRANPOSID)
    WHEN MATCHED THEN
        UPDATE SET t.CUSTOMID = s.CUSTOMID, t.TRANPOSNAME = s.TRANPOSNAME,
                   t.UPDATE_TIME = SYSTIMESTAMP, t.ISERP = 1, t.DELETED = 0
    WHEN NOT MATCHED THEN
        INSERT (TRANPOSID, CUSTOMID, TRANPOSNAME, ISERP, DELETED, CREATE_BY, CREATE_TIME)
        VALUES (s.TRANPOSID, s.CUSTOMID, s.TRANPOSNAME, 1, 0, 'sync', SYSTIMESTAMP);
    COMMIT;
END;
/

-- 同步物料价格数据
CREATE OR REPLACE PROCEDURE PROC_SYNC_GOODS_PRICE AS
BEGIN
  MERGE INTO T_COST_GOODS_PRICE T
  USING (SELECT a.GOODSID, a.GOODSNAME, a.price AS NEW_PRICE, a.USEFLAG, a.goodstype, a.packtype, a.FACTORYNAME
         FROM pub_goods_v a WHERE a.USEFLAG NOT IN ('产成品','半成品')) S
  ON (T.GOODSID = S.GOODSID)
  WHEN MATCHED THEN
    UPDATE SET T.GOODSNAME = S.GOODSNAME, T.USEFLAG = S.USEFLAG, T.GOODSTYPE = S.goodstype,
           T.PACKTYPE = S.packtype, T.FACTORYNAME = S.FACTORYNAME, T.ISERP = 1, T.UPDATE_TIME = SYSTIMESTAMP,
           T.PRICE = CASE WHEN T.PRICE IS NULL OR T.UPDATE_BY IS NULL OR T.UPDATE_BY = 'system' THEN S.NEW_PRICE ELSE T.PRICE END,
           T.UPDATE_BY = CASE WHEN T.PRICE IS NULL OR T.UPDATE_BY IS NULL OR T.UPDATE_BY = 'system' THEN 'system' ELSE T.UPDATE_BY END
  WHEN NOT MATCHED THEN
    INSERT (GOODSID, GOODSNAME, PRICE, USEFLAG, GOODSTYPE, PACKTYPE, FACTORYNAME, ISERP, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
    VALUES (S.GOODSID, S.GOODSNAME, S.NEW_PRICE, S.USEFLAG, S.goodstype, S.packtype, S.FACTORYNAME, 1, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'system');
  COMMIT;
END;
/

-- 同步WMS库存数据
CREATE OR REPLACE PROCEDURE PROC_SYNC_WMS_QTY AS
BEGIN
    DELETE FROM T_WMS_QTY WHERE UPDATE_BY = 'system' OR UPDATE_BY IS NULL OR GOODSGP IS NULL;
    INSERT INTO T_WMS_QTY (id, conid, goodsid, goodsgp, lotno, goodsno, packsize, qty_show, pcs,
                           deleted, create_time, update_time, create_by, update_by)
    SELECT SEQ_WMS_QTY.NEXTVAL, s.conid, s.goodsid, s.goodsgp, s.lotno, s.goodsno,
           s.packsize, s.qty_show, s.pcs, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'system', 'system'
    FROM (
        SELECT a.conid, a.goodsid, a.goodsname || '(' || a.packtype || ')' AS goodsgp,
               a.lotno, a.goodsno, b.packsize,
               TO_CHAR(NVL(b.goodsqty_total, 0)) || b.packname || '（零头' ||
               TO_CHAR(NVL(b.goodsqty_oddtray1, 0)) || b.packname || '）成品__' || b.packname || '）' AS qty_show, b.pcs
        FROM (SELECT a.conid, a.goodsid, a.goodsno, a.goodsname, a.lotno, a.packtype
              FROM bms_sa_con_dtl_v@hyerp a GROUP BY a.conid, a.goodsid, a.goodsno, a.goodsname, a.lotno, a.packtype) a,
             (SELECT x.goodsownid, x.lotno, x.packname, x.packsize, SUM(x.goodsqty) AS goodsqty_total,
                     SUM(CASE WHEN x.oddtray = 1 THEN x.goodsqty ELSE 0 END) AS goodsqty_oddtray1,
                     SUM(CEIL(x.goodsqty / x.packsize)) AS pcs
              FROM wms_st_qty_lst_baseunit_v@to_wms x GROUP BY x.goodsownid, x.lotno, x.packname, x.packsize) b
        WHERE a.goodsid = b.goodsownid(+) AND a.lotno = b.lotno(+)
    ) s WHERE NOT EXISTS (SELECT 1 FROM T_WMS_QTY t WHERE t.conid = s.conid AND t.goodsid = s.goodsid AND t.lotno = s.lotno);
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END PROC_SYNC_WMS_QTY;
/

-- BOM生成明细
CREATE OR REPLACE PROCEDURE P_COST_BOM_INSERT (p_docid IN t_cost_pinggu.docid%TYPE) AS
    v_goodsid varchar2(20);
    v_raw_goodsid t_cost_pinggu.goodsid%TYPE;
BEGIN
    SELECT goodsid INTO v_raw_goodsid FROM t_cost_pinggu WHERE docid = p_docid;
    IF v_raw_goodsid IS NULL THEN RAISE_APPLICATION_ERROR(-20003, '该产品在ERP中不存在BOM'); END IF;
    v_goodsid := '-' || v_raw_goodsid || '-';
    DELETE FROM t_cost_pinggu_dtl WHERE docid = p_docid;
    INSERT INTO t_cost_pinggu_dtl (dtlid, docid, apex_goodsid, spec, batch_qty, price, BASE_PRICE, modifydate, cost_batch,
                                   DTL_USEFLAG, APEX_GOODSNAME, APEX_FACTORYNAME, GOODSTYPE)
    SELECT SEQ_COST_PINGGU_DTL.NEXTVAL, p_docid, v.goodsid, v.standardtype, v.useqty, f.PRICE, f.PRICE, sysdate,
           nvl(v.useqty,0)*nvl(f.price,0), decode(v.useflag,4,'原料',2,'辅料',3,'非印字包材',5,'印字包材'),
           f.GOODSNAME, f.FACTORYNAME, f.GOODSTYPE
    FROM t_cost_bom_goods_tree_v v, PUB_GOODS_V f
    WHERE v.treeid LIKE v_goodsid||'%' AND v.pid <> '-1' AND v.USEFLAG NOT IN (0,1) AND v.goodsid = f.goodsid(+);
    p_pinggu_dtl_compute(p_docid, 0);
    p_pinggu_compute(p_docid);
    COMMIT;
END P_COST_BOM_INSERT;
/

-- 成本核算主表计算
CREATE OR REPLACE PROCEDURE p_pinggu_compute (p_docid IN NUMBER) IS
  v_apex_pl NUMBER; v_p_perpack NUMBER; v_yield NUMBER; v_out_price_rmb NUMBER; v_annual_qty NUMBER;
  v_total_fl NUMBER; v_total_bc NUMBER; v_total_yl NUMBER; v_total_cost NUMBER;
  v_salemoney NUMBER; v_jgf_batch NUMBER; v_jgf_perqp NUMBER; v_cost_perqp NUMBER;
  v_ml_perqp NUMBER; v_y_jg_re NUMBER; v_y_ml NUMBER; v_y_sale NUMBER; v_cost_perbox NUMBER;
  v_sum_yl NUMBER := 0; is_exists NUMBER;
BEGIN
  SELECT COUNT(1) INTO is_exists FROM t_cost_pinggu WHERE docid = p_docid;
  IF is_exists > 0 THEN
    SELECT apex_pl, p_perpack, yield, out_price_rmb, annual_qty, cost_perqp
    INTO v_apex_pl, v_p_perpack, v_yield, v_out_price_rmb, v_annual_qty, v_cost_perqp
    FROM t_cost_pinggu WHERE docid = p_docid;
    
    SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch ELSE 0 END), 0) INTO v_sum_yl
    FROM t_cost_pinggu_dtl WHERE docid = p_docid;
    
    IF v_sum_yl > 0 THEN
      SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch / 1.13 ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag = '辅料' THEN cost_batch / 1.13 ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag IN ('非印字包材', '印字包材') THEN cost_batch / 1.13 ELSE 0 END), 0)
      INTO v_total_yl, v_total_fl, v_total_bc FROM t_cost_pinggu_dtl WHERE docid = p_docid;
    ELSE
      SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag = '辅料' THEN cost_batch ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag IN ('非印字包材', '印字包材') THEN cost_batch ELSE 0 END), 0)
      INTO v_total_yl, v_total_fl, v_total_bc FROM t_cost_pinggu_dtl WHERE docid = p_docid;
    END IF;
    
    v_total_cost := v_total_fl + v_total_bc + v_total_yl;
    v_salemoney := ROUND(NVL(v_out_price_rmb, 0) / NULLIF(v_p_perpack, 0) * NVL(v_apex_pl, 0) * (NVL(v_yield, 0) / 100), 2);
    v_jgf_batch := ROUND(NVL(v_salemoney, 0) - NVL(v_total_cost, 0), 2);
    v_cost_perbox := ROUND(NVL(v_total_cost, 0) / NULLIF(v_apex_pl, 0) * NVL(v_p_perpack, 0), 2);
    v_jgf_perqp := ROUND(NVL(v_jgf_batch, 0) / NULLIF(v_apex_pl, 0) * 1000, 2);
    v_ml_perqp := ROUND(NVL(v_jgf_perqp, 0) - NVL(v_cost_perqp, 0), 2);
    v_y_jg_re := ROUND(NVL(v_jgf_perqp, 0) / 1000 * NVL(v_annual_qty, 0), 2);
    v_y_ml := ROUND(NVL(v_ml_perqp, 0) / 1000 * NVL(v_annual_qty, 0), 2);
    v_y_sale := ROUND(NVL(v_salemoney, 0) / NULLIF(v_apex_pl, 0) * NVL(v_annual_qty, 0), 2);
    
    UPDATE t_cost_pinggu SET salemoney = v_salemoney, jgf_batch = v_jgf_batch, jgf_perqp = v_jgf_perqp,
           cost_perbox = v_cost_perbox, ml_perqp = v_ml_perqp, y_jg_re = v_y_jg_re, y_ml = v_y_ml, y_sale = v_y_sale,
           total_fl = v_total_fl, total_bc = v_total_bc, total_yl = v_total_yl, total_cost = v_total_cost
    WHERE docid = p_docid;
  END IF;
EXCEPTION WHEN NO_DATA_FOUND THEN ROLLBACK; RAISE; WHEN OTHERS THEN ROLLBACK; RAISE;
END p_pinggu_compute;
/

-- 批量计算所有成本核算
CREATE OR REPLACE PROCEDURE p_pinggu_compute_all AS
BEGIN
  UPDATE t_cost_pinggu_dtl a SET a.price = (SELECT PRICE FROM t_cost_goods_price x WHERE x.GOODSID = a.apex_goodsid AND x.USEFLAG NOT IN ('产成品'));
  FOR i IN (SELECT DOCID FROM t_cost_pinggu) LOOP
    p_pinggu_dtl_compute(i.docid, 1);
    p_pinggu_compute(i.docid);
  END LOOP;
END;
/

-- 成本核算明细计算
CREATE OR REPLACE PROCEDURE p_pinggu_dtl_compute(p_docid NUMBER, is_all_comp NUMBER) AS
  v_apex_pl NUMBER; v_dtl_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_dtl_count FROM t_cost_pinggu_dtl WHERE docid = p_docid;
  IF v_dtl_count = 0 THEN RETURN; END IF;
  BEGIN SELECT a.apex_pl INTO v_apex_pl FROM t_cost_pinggu a WHERE a.docid = p_docid;
  EXCEPTION WHEN NO_DATA_FOUND THEN RETURN; END;
  
  IF is_all_comp = 0 THEN
    UPDATE t_cost_pinggu_dtl a SET a.per_hl = a.batch_qty / v_apex_pl * 1000000
    WHERE a.docid = p_docid AND a.dtl_useflag IN ('原料', '辅料');
    UPDATE t_cost_pinggu_dtl a SET a.per_hl = a.batch_qty / v_apex_pl * 1000000
    WHERE a.docid = p_docid AND a.dtl_useflag IN ('印字包材', '非印字包材') AND REGEXP_LIKE(a.apex_goodsname, '硬片|铝箔');
  END IF;
  
  UPDATE t_cost_pinggu_dtl a SET a.cost_batch = a.batch_qty * a.price WHERE a.docid = p_docid;
END;
/

-- 重置密码
CREATE OR REPLACE PROCEDURE P_RESET_PASSWORD(p_ids IN VARCHAR2, p_user_id IN NUMBER, p_result OUT NUMBER, p_message OUT VARCHAR2) AS
    v_count NUMBER := 0; v_operator VARCHAR2(50);
    v_new_password VARCHAR2(100) := '$2a$10$igs26ZAhFQFArWFszhIrn.MSMheCLYW9ertSP5J53jrgjKRpFhdE.';
BEGIN
    BEGIN SELECT USERNAME INTO v_operator FROM T_COST_USER WHERE ID = p_user_id;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_operator := 'system'; END;
    UPDATE T_COST_USER SET PASSWORD = v_new_password, UPDATE_TIME = SYSDATE, UPDATE_BY = v_operator
    WHERE ID IN (SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(p_ids, '[^,]+', 1, LEVEL))) FROM DUAL CONNECT BY LEVEL <= REGEXP_COUNT(p_ids, ',') + 1);
    v_count := SQL%ROWCOUNT;
    IF v_count > 0 THEN p_result := 0; p_message := '已重置 ' || v_count || ' 个用户密码为 admin'; COMMIT;
    ELSE p_result := 1; p_message := '未找到要重置的用户'; END IF;
EXCEPTION WHEN OTHERS THEN ROLLBACK; p_result := 1; p_message := '重置密码失败: ' || SQLERRM;
END P_RESET_PASSWORD;
/

-- 按发运单同步WMS数据
CREATE OR REPLACE PROCEDURE P_WMS_SYNC_BY_CONID(p_conid IN NUMBER) AS
BEGIN
  DELETE FROM T_WMS_QTY WHERE CONID = p_conid;
  DELETE FROM T_WMS_QTY_DETAIL WHERE CONID = p_conid;
  INSERT INTO T_WMS_QTY (ID, CONID, GOODSID, GOODSGP, LOTNO, GOODSNO, PACKSIZE, QTY_SHOW, PCS, TRANPOSNAME, DELETED, CREATE_TIME, CREATE_BY)
  SELECT SEQ_WMS_QTY.NEXTVAL, t.conid, t.goodsid, t.goodsgp, t.lotno, t.goodsno, t.packsize, t.qty_show, t.pcs, t.tranposname, 0, SYSTIMESTAMP, 'system'
  FROM T_WMS_QTY_V t WHERE t.conid = p_conid;
  INSERT INTO T_WMS_QTY_DETAIL (ID, RN, CONID, GOODSID, GOODSNAME, LOTNO, PCS, VALIDDATE, DELETED, CREATE_TIME, CREATE_BY, Goodsqty, containerno)
  SELECT SEQ_WMS_QTY_DETAIL.NEXTVAL, t.rn, t.conid, t.goodsid, t.goodsname, t.lotno, t.pcs, t.validdate, 0, SYSTIMESTAMP, 'system', Goodsqty, t.containerno
  FROM T_WMS_QTY_DETAIL_V t WHERE t.conid = p_conid;
  COMMIT;
END;
/

-- 备份成本核算表
CREATE OR REPLACE PROCEDURE sp_backup_pinggu_tables AS
BEGIN
  INSERT INTO t_cost_pinggu_his (goodsid, goodsname, strength, ma_no, apex_pl, mah, p_perpack, form, s_perback, packtype,
    x_perback, total_fl, total_bc, total_yl, memo, usestatus, docid, dosage, annual_qty, yield, total_cost, out_price_f,
    out_price_rmb, salemoney, jgf_batch, jgf_perqp, cost_perqp, ml_perqp, y_jg_re, y_ml, y_sale, customid, customname,
    country, projectno, useflag, yield_time, apex_pl_time, fmname, fmrate, goodsname_en, livery, deleted, create_time,
    update_time, create_by, update_by, cost_perbox, backup_time)
  SELECT t.goodsid, t.goodsname, t.strength, t.ma_no, t.apex_pl, t.mah, t.p_perpack, t.form, t.s_perback, t.packtype,
    t.x_perback, t.total_fl, t.total_bc, t.total_yl, t.memo, t.usestatus, t.docid, t.dosage, t.annual_qty, t.yield,
    t.total_cost, t.out_price_f, t.out_price_rmb, t.salemoney, t.jgf_batch, t.jgf_perqp, t.cost_perqp, t.ml_perqp,
    t.y_jg_re, t.y_ml, t.y_sale, t.customid, t.customname, t.country, t.projectno, t.useflag, t.yield_time, t.apex_pl_time,
    t.fmname, t.fmrate, t.goodsname_en, t.livery, t.deleted, t.create_time, t.update_time, t.create_by, t.update_by,
    t.cost_perbox, SYSDATE FROM t_cost_pinggu t;
  INSERT INTO t_cost_pinggu_dtl_his (docid, apex_goodsid, apex_goodsname, dtl_useflag, spec, per_hl, exadd_mater, batch_qty,
    price, cost_batch, memo, dtlid, apex_factoryname, apex_factoryid, modifydate, base_price, suqty, goodstype, goodsname_en,
    deleted, create_time, update_time, create_by, update_by, backup_time)
  SELECT t.docid, t.apex_goodsid, t.apex_goodsname, t.dtl_useflag, t.spec, t.per_hl, t.exadd_mater, t.batch_qty, t.price,
    t.cost_batch, t.memo, t.dtlid, t.apex_factoryname, t.apex_factoryid, t.modifydate, t.base_price, t.suqty, t.goodstype,
    t.goodsname_en, t.deleted, t.create_time, t.update_time, t.create_by, t.update_by, SYSDATE FROM t_cost_pinggu_dtl t;
  COMMIT;
END;
/

-- 同步产品信息
CREATE OR REPLACE PROCEDURE SP_SYNC_COST_GOODS AS
BEGIN
    MERGE INTO T_COST_GOODS T
    USING (
        SELECT B.GOODSID, B.GOODSNO, B.GOODSNAME, C.LASTPRICE AS PRICE, C.LASTSUQTY AS SUQTY,
               (CASE WHEN B.ZX_WMS_GOODSCLASS IN (1, 12) AND B.GSPFLAG = 1 AND B.GOODSNO LIKE '%A%' THEN '原料'
                     WHEN B.ZX_WMS_GOODSCLASS IN (10) AND B.GSPFLAG = 1 THEN '产成品'
                     WHEN B.ZX_WMS_GOODSCLASS IN (7, 8, 9) AND B.GSPFLAG = 1 THEN '半成品'
                     WHEN B.ZX_WMS_GOODSCLASS IN (5, 13) AND B.GSPFLAG = 1 THEN '非印字包材'
                     WHEN B.ZX_WMS_GOODSCLASS IN (6) AND B.GSPFLAG = 1 THEN '印字包材'
                     WHEN B.ZX_WMS_GOODSCLASS IN (1, 2, 3, 4) AND B.GSPFLAG = 1 AND B.GOODSNO NOT LIKE '%A%' THEN '辅料'
               END) AS USEFLAG, B.FACTORYNAME, B.STANDARDTYPE, B.ZX_PL, B.ZX_MINIMUM, B.APPROVEDOCNO, E.BASEUNITQTY,
               B.ZX_CUSTOMERID, B.CUSTOMNAME, F.TARGETMARKET, B.HOLDERSNAME, B.GOODSTYPE, B.PACKTYPE, B.TRANPOSNAME,
               D.BOMID, C.LASTSUQTY AS LASTSUQTY2, B.TRANPOSID
        FROM PUB_GOODS_V@hyerp B, BMS_SU_SUPPLYGOODS_DOC@hyerp C, MPCS_PR_BOM_DOC@hyerp D, PUB_GOODS_UNIT_V@hyerp E, BMS_TR_POS_DEF@hyerp F
        WHERE B.GOODSID = C.GOODSID(+) AND B.GOODSID = D.PGOODSID(+) AND D.USESTATUS(+) = 1 AND B.USESTATUS = 1
          AND C.ENTRYID(+) = 1 AND B.GOODSID = E.GOODSID(+) AND E.GOODSDTLFLAG(+) = 1 AND E.BASEFLAG(+) <> 1
          AND B.GOODSID < 1000000 AND B.ZX_CUSTOMERID = F.COMPANYID(+) AND B.TRANPOSID = F.TRANPOSID(+)
    ) S ON (T.GOODSID = S.GOODSID)
    WHEN MATCHED THEN
        UPDATE SET T.GOODSNO = S.GOODSNO, T.GOODSNAME = S.GOODSNAME, T.PRICE = S.PRICE, T.SUQTY = S.SUQTY,
            T.USEFLAG = S.USEFLAG, T.FACTORYNAME = S.FACTORYNAME, T.STANDARDTYPE = S.STANDARDTYPE, T.ZX_PL = S.ZX_PL,
            T.ZX_MINIMUM = S.ZX_MINIMUM, T.APPROVEDOCNO = S.APPROVEDOCNO, T.BASEUNITQTY = S.BASEUNITQTY,
            T.ZX_CUSTOMERID = S.ZX_CUSTOMERID, T.TARGETMARKET = S.TARGETMARKET, T.HOLDERSNAME = S.HOLDERSNAME,
            T.GOODSTYPE = S.GOODSTYPE, T.PACKTYPE = S.PACKTYPE, T.BOMID = S.BOMID, T.LASTSUQTY = S.LASTSUQTY2,
            T.TRANPOSID = S.TRANPOSID, T.ISERP = 1, T.UPDATE_TIME = SYSTIMESTAMP, T.UPDATE_BY = 'ERP_SYNC', T.DELETED = 0
    WHEN NOT MATCHED THEN
        INSERT (GOODSID, GOODSNO, GOODSNAME, PRICE, SUQTY, USEFLAG, FACTORYNAME, STANDARDTYPE, ZX_PL, ZX_MINIMUM,
                APPROVEDOCNO, BASEUNITQTY, ZX_CUSTOMERID, TARGETMARKET, HOLDERSNAME, ISERP, GOODSTYPE, PACKTYPE,
                BOMID, LASTSUQTY, TRANPOSID, DELETED, CREATE_TIME, UPDATE_TIME, CREATE_BY, UPDATE_BY)
        VALUES (S.GOODSID, S.GOODSNO, S.GOODSNAME, S.PRICE, S.SUQTY, S.USEFLAG, S.FACTORYNAME, S.STANDARDTYPE, S.ZX_PL,
                S.ZX_MINIMUM, S.APPROVEDOCNO, S.BASEUNITQTY, S.ZX_CUSTOMERID, S.TARGETMARKET, S.HOLDERSNAME, 1,
                S.GOODSTYPE, S.PACKTYPE, S.BOMID, S.LASTSUQTY2, S.TRANPOSID, 0, SYSTIMESTAMP, SYSTIMESTAMP, 'ERP_SYNC', 'ERP_SYNC');
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/

-- ============================================================
-- 液体版存储过程
-- ============================================================

-- 成本核算明细计算(液体)
CREATE OR REPLACE PROCEDURE p_pinggu_dtl_compute_lq(p_docid NUMBER, is_all_comp NUMBER) AS
  v_apex_pl NUMBER; v_dtl_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_dtl_count FROM t_cost_pinggu_dtl_lq WHERE docid = p_docid;
  IF v_dtl_count = 0 THEN RETURN; END IF;
  BEGIN SELECT a.apex_pl INTO v_apex_pl FROM t_cost_pinggu_lq a WHERE a.docid = p_docid;
  EXCEPTION WHEN NO_DATA_FOUND THEN RETURN; END;
  
  IF is_all_comp = 0 THEN
    UPDATE t_cost_pinggu_dtl_lq a SET a.per_hl = a.batch_qty / v_apex_pl * 1000000
    WHERE a.docid = p_docid AND a.dtl_useflag IN ('原料', '辅料');
    UPDATE t_cost_pinggu_dtl_lq a SET a.per_hl = a.batch_qty / v_apex_pl * 1000000
    WHERE a.docid = p_docid AND a.dtl_useflag IN ('印字包材', '非印字包材') AND REGEXP_LIKE(a.apex_goodsname, '硬片|铝箔');
  END IF;
  
  UPDATE t_cost_pinggu_dtl_lq a SET a.cost_batch = a.batch_qty * a.price WHERE a.docid = p_docid;
END;
/

-- 成本核算主表计算(液体)
CREATE OR REPLACE PROCEDURE p_pinggu_compute_lq (p_docid IN NUMBER) IS
  v_apex_pl NUMBER; v_p_perpack NUMBER; v_yield NUMBER; v_out_price_rmb NUMBER; v_annual_qty NUMBER;
  v_total_fl NUMBER; v_total_bc NUMBER; v_total_yl NUMBER; v_total_cost NUMBER;
  v_salemoney NUMBER; v_jgf_batch NUMBER; v_jgf_perqp NUMBER; v_cost_perqp NUMBER;
  v_ml_perqp NUMBER; v_y_jg_re NUMBER; v_y_ml NUMBER; v_y_sale NUMBER; v_cost_perbox NUMBER;
  v_sum_yl NUMBER := 0; is_exists NUMBER;
BEGIN
  SELECT COUNT(1) INTO is_exists FROM t_cost_pinggu_lq WHERE docid = p_docid;
  IF is_exists > 0 THEN
    SELECT apex_pl, p_perpack, yield, out_price_rmb, annual_qty, cost_perqp
    INTO v_apex_pl, v_p_perpack, v_yield, v_out_price_rmb, v_annual_qty, v_cost_perqp
    FROM t_cost_pinggu_lq WHERE docid = p_docid;
    
    SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch ELSE 0 END), 0) INTO v_sum_yl
    FROM t_cost_pinggu_dtl_lq WHERE docid = p_docid;
    
    IF v_sum_yl > 0 THEN
      SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch / 1.13 ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag = '辅料' THEN cost_batch / 1.13 ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag IN ('非印字包材', '印字包材') THEN cost_batch / 1.13 ELSE 0 END), 0)
      INTO v_total_yl, v_total_fl, v_total_bc FROM t_cost_pinggu_dtl_lq WHERE docid = p_docid;
    ELSE
      SELECT NVL(SUM(CASE WHEN dtl_useflag = '原料' THEN cost_batch ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag = '辅料' THEN cost_batch ELSE 0 END), 0),
             NVL(SUM(CASE WHEN dtl_useflag IN ('非印字包材', '印字包材') THEN cost_batch ELSE 0 END), 0)
      INTO v_total_yl, v_total_fl, v_total_bc FROM t_cost_pinggu_dtl_lq WHERE docid = p_docid;
    END IF;
    
    v_total_cost := v_total_fl + v_total_bc + v_total_yl;
    v_salemoney := ROUND(NVL(v_out_price_rmb, 0) / NULLIF(v_p_perpack, 0) * NVL(v_apex_pl, 0) * (NVL(v_yield, 0) / 100), 2);
    v_jgf_batch := ROUND(NVL(v_salemoney, 0) - NVL(v_total_cost, 0), 2);
    v_cost_perbox := ROUND(NVL(v_total_cost, 0) / NULLIF(v_apex_pl, 0) * NVL(v_p_perpack, 0), 2);
    v_jgf_perqp := ROUND(NVL(v_jgf_batch, 0) / NULLIF(v_apex_pl, 0) * 1000, 2);
    v_ml_perqp := ROUND(NVL(v_jgf_perqp, 0) - NVL(v_cost_perqp, 0), 2);
    v_y_jg_re := ROUND(NVL(v_jgf_perqp, 0) / 1000 * NVL(v_annual_qty, 0), 2);
    v_y_ml := ROUND(NVL(v_ml_perqp, 0) / 1000 * NVL(v_annual_qty, 0), 2);
    v_y_sale := ROUND(NVL(v_salemoney, 0) / NULLIF(v_apex_pl, 0) * NVL(v_annual_qty, 0), 2);
    
    UPDATE t_cost_pinggu_lq SET salemoney = v_salemoney, jgf_batch = v_jgf_batch, jgf_perqp = v_jgf_perqp,
           cost_perbox = v_cost_perbox, ml_perqp = v_ml_perqp, y_jg_re = v_y_jg_re, y_ml = v_y_ml, y_sale = v_y_sale,
           total_fl = v_total_fl, total_bc = v_total_bc, total_yl = v_total_yl, total_cost = v_total_cost
    WHERE docid = p_docid;
  END IF;
EXCEPTION WHEN NO_DATA_FOUND THEN ROLLBACK; RAISE; WHEN OTHERS THEN ROLLBACK; RAISE;
END p_pinggu_compute_lq;
/

-- BOM生成明细(液体)
CREATE OR REPLACE PROCEDURE P_COST_BOM_INSERT_LQ (p_docid IN t_cost_pinggu_lq.docid%TYPE) AS
    v_goodsid varchar2(20);
    v_raw_goodsid t_cost_pinggu_lq.goodsid%TYPE;
BEGIN
    SELECT goodsid INTO v_raw_goodsid FROM t_cost_pinggu_lq WHERE docid = p_docid;
    IF v_raw_goodsid IS NULL THEN RAISE_APPLICATION_ERROR(-20003, '该产品在ERP中不存在BOM'); END IF;
    v_goodsid := '-' || v_raw_goodsid || '-';
    DELETE FROM t_cost_pinggu_dtl_lq WHERE docid = p_docid;
    INSERT INTO t_cost_pinggu_dtl_lq (dtlid, docid, apex_goodsid, spec, batch_qty, price, BASE_PRICE, modifydate, cost_batch,
                                   DTL_USEFLAG, APEX_GOODSNAME, APEX_FACTORYNAME, GOODSTYPE)
    SELECT SEQ_COST_PINGGU_DTL_LQ.NEXTVAL, p_docid, v.goodsid, v.standardtype, v.useqty, f.PRICE, f.PRICE, sysdate,
           nvl(v.useqty,0)*nvl(f.price,0), decode(v.useflag,4,'原料',2,'辅料',3,'非印字包材',5,'印字包材'),
           f.GOODSNAME, f.FACTORYNAME, f.GOODSTYPE
    FROM t_cost_bom_goods_tree_v v, PUB_GOODS_V f
    WHERE v.treeid LIKE v_goodsid||'%' AND v.pid <> '-1' AND v.USEFLAG NOT IN (0,1) AND v.goodsid = f.goodsid(+);
    p_pinggu_dtl_compute_lq(p_docid, 0);
    p_pinggu_compute_lq(p_docid);
    COMMIT;
END P_COST_BOM_INSERT_LQ;
/

-- 批量计算所有成本核算(液体)
CREATE OR REPLACE PROCEDURE p_pinggu_compute_all_lq AS
BEGIN
  UPDATE t_cost_pinggu_dtl_lq a SET a.price = (SELECT PRICE FROM t_cost_goods_price x WHERE x.GOODSID = a.apex_goodsid AND x.USEFLAG NOT IN ('产成品'));
  FOR i IN (SELECT DOCID FROM t_cost_pinggu_lq) LOOP
    p_pinggu_dtl_compute_lq(i.docid, 1);
    p_pinggu_compute_lq(i.docid);
  END LOOP;
END;
/

-- 备份成本核算表(液体)
CREATE OR REPLACE PROCEDURE sp_backup_pinggu_tables_lq AS
BEGIN
  INSERT INTO t_cost_pinggu_his_lq (goodsid, goodsname, strength, ma_no, apex_pl, mah, p_perpack, form, s_perback, packtype,
    x_perback, total_fl, total_bc, total_yl, memo, usestatus, docid, dosage, annual_qty, yield, total_cost, out_price_f,
    out_price_rmb, salemoney, jgf_batch, jgf_perqp, cost_perqp, ml_perqp, y_jg_re, y_ml, y_sale, customid, customname,
    country, projectno, useflag, yield_time, apex_pl_time, fmname, fmrate, goodsname_en, livery, deleted, create_time,
    update_time, create_by, update_by, cost_perbox, backup_time)
  SELECT t.goodsid, t.goodsname, t.strength, t.ma_no, t.apex_pl, t.mah, t.p_perpack, t.form, t.s_perback, t.packtype,
    t.x_perback, t.total_fl, t.total_bc, t.total_yl, t.memo, t.usestatus, t.docid, t.dosage, t.annual_qty, t.yield,
    t.total_cost, t.out_price_f, t.out_price_rmb, t.salemoney, t.jgf_batch, t.jgf_perqp, t.cost_perqp, t.ml_perqp,
    t.y_jg_re, t.y_ml, t.y_sale, t.customid, t.customname, t.country, t.projectno, t.useflag, t.yield_time, t.apex_pl_time,
    t.fmname, t.fmrate, t.goodsname_en, t.livery, t.deleted, t.create_time, t.update_time, t.create_by, t.update_by,
    t.cost_perbox, SYSDATE FROM t_cost_pinggu_lq t;
  INSERT INTO t_cost_pinggu_dtl_his_lq (docid, apex_goodsid, apex_goodsname, dtl_useflag, spec, per_hl, exadd_mater, batch_qty,
    price, cost_batch, memo, dtlid, apex_factoryname, apex_factoryid, modifydate, base_price, suqty, goodstype, goodsname_en,
    deleted, create_time, update_time, create_by, update_by, backup_time)
  SELECT t.docid, t.apex_goodsid, t.apex_goodsname, t.dtl_useflag, t.spec, t.per_hl, t.exadd_mater, t.batch_qty, t.price,
    t.cost_batch, t.memo, t.dtlid, t.apex_factoryname, t.apex_factoryid, t.modifydate, t.base_price, t.suqty, t.goodstype,
    t.goodsname_en, t.deleted, t.create_time, t.update_time, t.create_by, t.update_by, SYSDATE FROM t_cost_pinggu_dtl_lq t;
  COMMIT;
END;
/
