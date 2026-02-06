prompt PL/SQL Developer Export User Objects for user CMX@192.168.11.5/ORCL
prompt Created by admin on 2026年2月6日
set define off
spool 1.log

prompt
prompt Creating table T_COST_AUDIT_LOG
prompt ===============================
prompt
create table CMX.T_COST_AUDIT_LOG
(
  id             NUMBER(19) not null,
  user_name      VARCHAR2(100),
  operation_time TIMESTAMP(6) default SYSTIMESTAMP,
  page_code      VARCHAR2(100),
  table_code     VARCHAR2(100),
  table_name     VARCHAR2(200),
  record_id      NUMBER(19),
  operation_type VARCHAR2(20),
  field_changes  CLOB,
  create_time    TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_AUDIT_LOG
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_TABLE_METADATA
prompt ====================================
prompt
create table CMX.T_COST_TABLE_METADATA
(
  id                NUMBER(19) not null,
  table_code        VARCHAR2(64) not null,
  table_name        VARCHAR2(128) not null,
  query_view        VARCHAR2(64),
  target_table      VARCHAR2(64) not null,
  sequence_name     VARCHAR2(64),
  pk_column         VARCHAR2(64) default 'ID',
  parent_table_code VARCHAR2(64),
  parent_fk_column  VARCHAR2(64),
  audit_enabled     NUMBER(1) default 0,
  validation_rules  CLOB,
  action_rules      CLOB,
  description       VARCHAR2(500),
  deleted           NUMBER(1) default 0,
  create_time       TIMESTAMP(6) default SYSTIMESTAMP,
  update_time       TIMESTAMP(6) default SYSTIMESTAMP,
  create_by         VARCHAR2(64),
  update_by         VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_TABLE_METADATA
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_TABLE_METADATA
  add unique (TABLE_CODE)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_COLUMN_METADATA
prompt =====================================
prompt
create table CMX.T_COST_COLUMN_METADATA
(
  id                NUMBER(19) not null,
  table_metadata_id NUMBER(19) not null,
  field_name        VARCHAR2(64) not null,
  column_name       VARCHAR2(64) not null,
  query_column      VARCHAR2(128),
  target_column     VARCHAR2(64),
  header_text       VARCHAR2(128) not null,
  data_type         VARCHAR2(32) default 'text',
  display_order     NUMBER(5) default 0,
  sortable          NUMBER(1) default 1,
  filterable        NUMBER(1) default 1,
  is_virtual        NUMBER(1) default 0,
  dict_type         VARCHAR2(64),
  deleted           NUMBER(1) default 0,
  create_time       TIMESTAMP(6) default SYSTIMESTAMP,
  update_time       TIMESTAMP(6) default SYSTIMESTAMP,
  create_by         VARCHAR2(64),
  update_by         VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_COLUMN_TABLE_ID on CMX.T_COST_COLUMN_METADATA (TABLE_METADATA_ID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_COLUMN_METADATA
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_COLUMN_METADATA
  add constraint FK_COLUMN_TABLE foreign key (TABLE_METADATA_ID)
  references CMX.T_COST_TABLE_METADATA (ID);

prompt
prompt Creating table T_COST_CUSTOMER
prompt ==============================
prompt
create table CMX.T_COST_CUSTOMER
(
  customid    NUMBER(19) not null,
  zone        VARCHAR2(500),
  customname  VARCHAR2(500),
  iserp       NUMBER(1) default 0,
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_CUSTOMER
  add primary key (CUSTOMID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_DEPARTMENT
prompt ================================
prompt
create table CMX.T_COST_DEPARTMENT
(
  id          NUMBER(19) not null,
  dept_code   VARCHAR2(64) not null,
  dept_name   VARCHAR2(128) not null,
  parent_id   NUMBER(19),
  sort_order  NUMBER(5) default 0,
  deleted     NUMBER(1) default 0,
  create_by   VARCHAR2(64),
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_by   VARCHAR2(64),
  update_time TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_DEPARTMENT
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_DEPARTMENT
  add unique (DEPT_CODE)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_DICTIONARY_TYPE
prompt =====================================
prompt
create table CMX.T_COST_DICTIONARY_TYPE
(
  id          NUMBER(19) not null,
  type_code   VARCHAR2(64) not null,
  type_name   VARCHAR2(128) not null,
  description VARCHAR2(500),
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255;
alter table CMX.T_COST_DICTIONARY_TYPE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255;
alter table CMX.T_COST_DICTIONARY_TYPE
  add unique (TYPE_CODE)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255;

prompt
prompt Creating table T_COST_DICTIONARY_ITEM
prompt =====================================
prompt
create table CMX.T_COST_DICTIONARY_ITEM
(
  id           NUMBER(19) not null,
  type_id      NUMBER(19) not null,
  item_code    VARCHAR2(64) not null,
  item_name    VARCHAR2(128) not null,
  item_value   VARCHAR2(200),
  sort_order   NUMBER(5) default 0,
  extra_config VARCHAR2(1000),
  deleted      NUMBER(1) default 0,
  create_time  TIMESTAMP(6) default SYSTIMESTAMP,
  update_time  TIMESTAMP(6) default SYSTIMESTAMP,
  create_by    VARCHAR2(64),
  update_by    VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255;
create index CMX.IDX_DICT_ITEM_TYPE on CMX.T_COST_DICTIONARY_ITEM (TYPE_ID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255;
alter table CMX.T_COST_DICTIONARY_ITEM
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255;
alter table CMX.T_COST_DICTIONARY_ITEM
  add constraint FK_DICT_ITEM_TYPE foreign key (TYPE_ID)
  references CMX.T_COST_DICTIONARY_TYPE (ID);

prompt
prompt Creating table T_COST_EXPORT_CONFIG
prompt ===================================
prompt
create table CMX.T_COST_EXPORT_CONFIG
(
  id                 NUMBER(19) not null,
  export_code        VARCHAR2(100) not null,
  export_name        VARCHAR2(200) not null,
  page_code          VARCHAR2(100) not null,
  master_sql         CLOB not null,
  master_table_alias VARCHAR2(50),
  pk_column          VARCHAR2(100),
  page_view_alias    VARCHAR2(50) default 'p',
  page_fk_column     VARCHAR2(100),
  master_link_column VARCHAR2(100),
  columns            CLOB,
  master_sheet_name  VARCHAR2(100) default 'master',
  display_order      NUMBER(5) default 0,
  deleted            NUMBER(1) default 0,
  create_by          VARCHAR2(64),
  create_time        TIMESTAMP(6) default SYSTIMESTAMP,
  update_by          VARCHAR2(64),
  update_time        TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_EXPORT_CONFIG_PAGE on CMX.T_COST_EXPORT_CONFIG (PAGE_CODE)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_EXPORT_CONFIG_CODE on CMX.T_COST_EXPORT_CONFIG (EXPORT_CODE)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_EXPORT_CONFIG
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_EXPORT_CONFIG_DETAIL
prompt ==========================================
prompt
create table CMX.T_COST_EXPORT_CONFIG_DETAIL
(
  id                 NUMBER(19) not null,
  export_config_id   NUMBER(19) not null,
  tab_key            VARCHAR2(100),
  sheet_name         VARCHAR2(100),
  detail_sql         CLOB not null,
  master_table_alias VARCHAR2(50),
  detail_table_alias VARCHAR2(50),
  detail_link_column VARCHAR2(100),
  columns            CLOB,
  display_order      NUMBER(5) default 0
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_EXPORT_DTL_CONFIG on CMX.T_COST_EXPORT_CONFIG_DETAIL (EXPORT_CONFIG_ID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_EXPORT_CONFIG_DETAIL
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_EXPORT_CONFIG_DETAIL
  add constraint FK_EXPORT_DTL_CONFIG foreign key (EXPORT_CONFIG_ID)
  references CMX.T_COST_EXPORT_CONFIG (ID);

prompt
prompt Creating table T_COST_FORMONEY
prompt ==============================
prompt
create table CMX.T_COST_FORMONEY
(
  fmid        NUMBER(10) not null,
  fmopcode    VARCHAR2(60),
  fmname      VARCHAR2(120),
  fmsign      VARCHAR2(60),
  fmunit      VARCHAR2(60),
  fmrate      NUMBER(16,6),
  usestatus   NUMBER(2),
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_FORMONEY
  add constraint PK_COST_FORMONEY primary key (FMID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_GOODS
prompt ===========================
prompt
create table CMX.T_COST_GOODS
(
  goodsid       NUMBER(19) not null,
  goodsno       VARCHAR2(100),
  goodsname     VARCHAR2(1000),
  price         NUMBER,
  suqty         NUMBER,
  useflag       VARCHAR2(100) default '产成品',
  factoryname   VARCHAR2(1500),
  standardtype  VARCHAR2(500),
  zx_pl         NUMBER,
  zx_minimum    NUMBER,
  approvedocno  VARCHAR2(500),
  baseunitqty   NUMBER,
  zx_customerid NUMBER(19),
  targetmarket  VARCHAR2(1000),
  holdersname   VARCHAR2(1000),
  iserp         NUMBER(1) default 0,
  goodstype     VARCHAR2(500),
  packtype      VARCHAR2(500),
  bomid         NUMBER(19),
  lastsuqty     NUMBER,
  tranposid     NUMBER(19),
  deleted       NUMBER(1) default 0,
  create_time   TIMESTAMP(6) default SYSTIMESTAMP,
  update_time   TIMESTAMP(6) default SYSTIMESTAMP,
  create_by     VARCHAR2(320),
  update_by     VARCHAR2(320)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_GOODS
  add primary key (GOODSID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_GOODS_PRICE
prompt =================================
prompt
create table CMX.T_COST_GOODS_PRICE
(
  goodsid     NUMBER(10) not null,
  goodsname   VARCHAR2(300),
  price       NUMBER,
  useflag     VARCHAR2(15),
  goodstype   VARCHAR2(3000),
  packtype    VARCHAR2(600),
  factoryname VARCHAR2(300),
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64),
  iserp       NUMBER(1) default 0
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_GOODS_PRICE
  add primary key (GOODSID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_LOOKUP_CONFIG
prompt ===================================
prompt
create table CMX.T_COST_LOOKUP_CONFIG
(
  id              NUMBER(19) not null,
  lookup_code     VARCHAR2(64) not null,
  lookup_name     VARCHAR2(128) not null,
  data_source     VARCHAR2(200) not null,
  display_columns CLOB,
  value_field     VARCHAR2(64) not null,
  label_field     VARCHAR2(64) not null,
  deleted         NUMBER(1) default 0,
  create_time     TIMESTAMP(6) default SYSTIMESTAMP,
  update_time     TIMESTAMP(6) default SYSTIMESTAMP,
  create_by       VARCHAR2(64),
  update_by       VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_LOOKUP_CONFIG
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_LOOKUP_CONFIG
  add unique (LOOKUP_CODE)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_OPERATION_LOG
prompt ===================================
prompt
create table CMX.T_COST_OPERATION_LOG
(
  id              NUMBER(19) not null,
  user_id         NUMBER(19),
  user_name       VARCHAR2(64),
  operation_type  VARCHAR2(32) not null,
  table_code      VARCHAR2(64),
  record_id       NUMBER(19),
  record_desc     VARCHAR2(256),
  total_sql_count NUMBER(10) default 0,
  total_cost_ms   NUMBER(10) default 0,
  status          VARCHAR2(16) default 'SUCCESS',
  error_msg       VARCHAR2(1000),
  create_time     TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_OPERATION_LOG_TIME on CMX.T_COST_OPERATION_LOG (CREATE_TIME)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_OPERATION_LOG_USER on CMX.T_COST_OPERATION_LOG (USER_ID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_OPERATION_LOG
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_OPERATION_LOG_DETAIL
prompt ==========================================
prompt
create table CMX.T_COST_OPERATION_LOG_DETAIL
(
  id            NUMBER(19) not null,
  log_id        NUMBER(19) not null,
  seq_no        NUMBER(5) not null,
  sql_type      VARCHAR2(16),
  sql_text      CLOB,
  cost_ms       NUMBER(10) default 0,
  affected_rows NUMBER(10),
  status        VARCHAR2(16) default 'SUCCESS',
  error_msg     VARCHAR2(1000),
  create_time   TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_OPERATION_LOG_DETAIL
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_OPERATION_LOG_DETAIL
  add constraint FK_LOG_DETAIL_LOG foreign key (LOG_ID)
  references CMX.T_COST_OPERATION_LOG (ID);

prompt
prompt Creating table T_COST_PAGE_COMPONENT
prompt ====================================
prompt
create table CMX.T_COST_PAGE_COMPONENT
(
  id               NUMBER(19) not null,
  page_code        VARCHAR2(64) not null,
  component_key    VARCHAR2(64) not null,
  component_type   VARCHAR2(32) not null,
  parent_key       VARCHAR2(64),
  component_config CLOB,
  ref_table_code   VARCHAR2(64),
  slot_name        VARCHAR2(32),
  sort_order       NUMBER(5) default 0,
  deleted          NUMBER(1) default 0,
  description      VARCHAR2(200),
  create_time      TIMESTAMP(6) default SYSTIMESTAMP,
  update_time      TIMESTAMP(6) default SYSTIMESTAMP,
  create_by        VARCHAR2(64),
  update_by        VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_PAGE_COMP_PAGE on CMX.T_COST_PAGE_COMPONENT (PAGE_CODE)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_PAGE_COMP_KEY on CMX.T_COST_PAGE_COMPONENT (PAGE_CODE, COMPONENT_KEY)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_PAGE_COMPONENT
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_PAGE_RULE
prompt ===============================
prompt
create table CMX.T_COST_PAGE_RULE
(
  id            NUMBER(19) not null,
  page_code     VARCHAR2(64) not null,
  component_key VARCHAR2(64) not null,
  rule_type     VARCHAR2(32) not null,
  rules         CLOB not null,
  sort_order    NUMBER(5) default 0,
  description   VARCHAR2(200),
  deleted       NUMBER(1) default 0,
  create_time   TIMESTAMP(6) default SYSTIMESTAMP,
  update_time   TIMESTAMP(6) default SYSTIMESTAMP,
  create_by     VARCHAR2(64),
  update_by     VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_PAGE_RULE_PAGE on CMX.T_COST_PAGE_RULE (PAGE_CODE)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_PAGE_RULE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_PINGGU
prompt ============================
prompt
create table CMX.T_COST_PINGGU
(
  goodsid       NUMBER,
  goodsname     VARCHAR2(100),
  strength      VARCHAR2(50),
  ma_no         VARCHAR2(30),
  apex_pl       NUMBER,
  mah           VARCHAR2(100),
  p_perpack     NUMBER,
  form          VARCHAR2(20),
  s_perback     NUMBER,
  packtype      VARCHAR2(30),
  x_perback     NUMBER,
  total_fl      NUMBER,
  total_bc      NUMBER,
  total_yl      NUMBER,
  memo          VARCHAR2(100),
  usestatus     VARCHAR2(100) default 0,
  docid         NUMBER generated by default on null as identity,
  dosage        VARCHAR2(20),
  annual_qty    NUMBER,
  yield         NUMBER,
  total_cost    NUMBER,
  out_price_f   NUMBER,
  out_price_rmb NUMBER,
  salemoney     NUMBER,
  jgf_batch     NUMBER,
  jgf_perqp     NUMBER,
  cost_perqp    NUMBER,
  ml_perqp      NUMBER,
  y_jg_re       NUMBER,
  y_ml          NUMBER,
  y_sale        NUMBER,
  customid      NUMBER,
  customname    VARCHAR2(50),
  country       VARCHAR2(20),
  projectno     VARCHAR2(20),
  useflag       NUMBER default 0,
  yield_time    DATE default SYSDATE,
  apex_pl_time  DATE default SYSDATE,
  fmname        VARCHAR2(100) default '人民币',
  fmrate        NUMBER default 1,
  goodsname_en  VARCHAR2(2000),
  livery        VARCHAR2(100),
  deleted       NUMBER(1) default 0,
  create_time   TIMESTAMP(6) default SYSTIMESTAMP,
  update_time   TIMESTAMP(6) default SYSTIMESTAMP,
  create_by     VARCHAR2(64),
  update_by     VARCHAR2(64),
  cost_perbox   NUMBER
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
comment on column CMX.T_COST_PINGGU.cost_perbox
  is '每盒成本';
alter table CMX.T_COST_PINGGU
  add constraint PK_COST_PINGGU primary key (DOCID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_PINGGU_DTL
prompt ================================
prompt
create table CMX.T_COST_PINGGU_DTL
(
  docid            NUMBER(10) not null,
  apex_goodsid     NUMBER(10),
  apex_goodsname   VARCHAR2(500),
  dtl_useflag      VARCHAR2(100),
  spec             VARCHAR2(100),
  per_hl           NUMBER,
  exadd_mater      NUMBER,
  batch_qty        NUMBER,
  price            NUMBER,
  cost_batch       NUMBER,
  memo             VARCHAR2(100),
  dtlid            NUMBER(10) generated by default on null as identity,
  apex_factoryname VARCHAR2(200),
  apex_factoryid   NUMBER(10),
  modifydate       DATE,
  base_price       NUMBER,
  suqty            NUMBER,
  goodstype        VARCHAR2(4000),
  goodsname_en     VARCHAR2(2000),
  deleted          NUMBER(1) default 0,
  create_time      TIMESTAMP(6) default SYSTIMESTAMP,
  update_time      TIMESTAMP(6) default SYSTIMESTAMP,
  create_by        VARCHAR2(64),
  update_by        VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_PINGGU_DTL
  add constraint PK_COST_PINGGU_DTL primary key (DTLID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_PINGGU_DTL_HIS
prompt ====================================
prompt
create table CMX.T_COST_PINGGU_DTL_HIS
(
  docid            NUMBER(10) not null,
  apex_goodsid     NUMBER(10),
  apex_goodsname   VARCHAR2(500),
  dtl_useflag      VARCHAR2(100),
  spec             VARCHAR2(100),
  per_hl           NUMBER,
  exadd_mater      NUMBER,
  batch_qty        NUMBER,
  price            NUMBER,
  cost_batch       NUMBER,
  memo             VARCHAR2(100),
  dtlid            NUMBER(10) not null,
  apex_factoryname VARCHAR2(200),
  apex_factoryid   NUMBER(10),
  modifydate       DATE,
  base_price       NUMBER,
  suqty            NUMBER,
  goodstype        VARCHAR2(4000),
  goodsname_en     VARCHAR2(2000),
  deleted          NUMBER(1),
  create_time      TIMESTAMP(6),
  update_time      TIMESTAMP(6),
  create_by        VARCHAR2(64),
  update_by        VARCHAR2(64),
  backup_time      DATE
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_PINGGU_DTL_HIS on CMX.T_COST_PINGGU_DTL_HIS (DTLID, BACKUP_TIME)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_PINGGU_HIS
prompt ================================
prompt
create table CMX.T_COST_PINGGU_HIS
(
  goodsid       NUMBER,
  goodsname     VARCHAR2(100),
  strength      VARCHAR2(50),
  ma_no         VARCHAR2(30),
  apex_pl       NUMBER,
  mah           VARCHAR2(100),
  p_perpack     NUMBER,
  form          VARCHAR2(20),
  s_perback     NUMBER,
  packtype      VARCHAR2(30),
  x_perback     NUMBER,
  total_fl      NUMBER,
  total_bc      NUMBER,
  total_yl      NUMBER,
  memo          VARCHAR2(100),
  usestatus     VARCHAR2(100),
  docid         NUMBER not null,
  dosage        VARCHAR2(20),
  annual_qty    NUMBER,
  yield         NUMBER,
  total_cost    NUMBER,
  out_price_f   NUMBER,
  out_price_rmb NUMBER,
  salemoney     NUMBER,
  jgf_batch     NUMBER,
  jgf_perqp     NUMBER,
  cost_perqp    NUMBER,
  ml_perqp      NUMBER,
  y_jg_re       NUMBER,
  y_ml          NUMBER,
  y_sale        NUMBER,
  customid      NUMBER,
  customname    VARCHAR2(50),
  country       VARCHAR2(20),
  projectno     VARCHAR2(20),
  useflag       NUMBER,
  yield_time    DATE,
  apex_pl_time  DATE,
  zx_source     VARCHAR2(100),
  fmname        VARCHAR2(100),
  fmrate        NUMBER,
  goodsname_en  VARCHAR2(2000),
  livery        VARCHAR2(100),
  deleted       NUMBER(1),
  create_time   TIMESTAMP(6),
  update_time   TIMESTAMP(6),
  create_by     VARCHAR2(64),
  update_by     VARCHAR2(64),
  backup_time   DATE,
  cost_perbox   NUMBER
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_PINGGU_HIS on CMX.T_COST_PINGGU_HIS (DOCID, BACKUP_TIME)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_RESOURCE
prompt ==============================
prompt
create table CMX.T_COST_RESOURCE
(
  id            NUMBER(19) not null,
  resource_name VARCHAR2(128) not null,
  resource_type VARCHAR2(20) not null,
  page_code     VARCHAR2(64),
  icon          VARCHAR2(64),
  route         VARCHAR2(128),
  parent_id     NUMBER(19),
  sort_order    NUMBER(5) default 0,
  is_hardcoded  NUMBER(1) default 0
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_RESOURCE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_ROLE
prompt ==========================
prompt
create table CMX.T_COST_ROLE
(
  id          NUMBER(19) not null,
  role_code   VARCHAR2(64) not null,
  role_name   VARCHAR2(128) not null,
  description VARCHAR2(500)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_ROLE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_ROLE
  add unique (ROLE_CODE)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_ROLE_PAGE
prompt ===============================
prompt
create table CMX.T_COST_ROLE_PAGE
(
  id            NUMBER(19) not null,
  role_id       NUMBER(19) not null,
  page_code     VARCHAR2(64) not null,
  button_policy VARCHAR2(1000),
  column_policy CLOB,
  row_policy    VARCHAR2(2000)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_ROLE_PAGE on CMX.T_COST_ROLE_PAGE (ROLE_ID, PAGE_CODE)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_ROLE_PAGE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_TRANPOSER
prompt ===============================
prompt
create table CMX.T_COST_TRANPOSER
(
  tranposid   NUMBER(19) not null,
  customid    NUMBER(19),
  tranposname VARCHAR2(500),
  iserp       NUMBER(1) default 0,
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_TRANPOSER
  add primary key (TRANPOSID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_USER
prompt ==========================
prompt
create table CMX.T_COST_USER
(
  id            NUMBER(19) not null,
  username      VARCHAR2(64) not null,
  password      VARCHAR2(256) not null,
  real_name     VARCHAR2(128),
  email         VARCHAR2(128),
  phone         VARCHAR2(32),
  department_id NUMBER(19),
  status        VARCHAR2(32) default 'ACTIVE',
  deleted       NUMBER(1) default 0,
  create_by     VARCHAR2(64),
  create_time   TIMESTAMP(6) default SYSTIMESTAMP,
  update_by     VARCHAR2(64),
  update_time   TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_USER
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_USER
  add unique (USERNAME)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_USER_GRID_CONFIG
prompt ======================================
prompt
create table CMX.T_COST_USER_GRID_CONFIG
(
  id          NUMBER(19) not null,
  user_id     NUMBER(19) not null,
  page_code   VARCHAR2(64) not null,
  grid_key    VARCHAR2(64) not null,
  config_data CLOB,
  deleted     NUMBER(1) default 0,
  update_time TIMESTAMP(6) default SYSTIMESTAMP
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_USER_GRID_CONF on CMX.T_COST_USER_GRID_CONFIG (USER_ID, PAGE_CODE, GRID_KEY)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_USER_GRID_CONFIG
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_COST_USER_ROLE
prompt ===============================
prompt
create table CMX.T_COST_USER_ROLE
(
  id      NUMBER(19) not null,
  user_id NUMBER(19) not null,
  role_id NUMBER(19) not null
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_USER_ROLE on CMX.T_COST_USER_ROLE (USER_ID, ROLE_ID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_COST_USER_ROLE
  add primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_WMS_QTY
prompt ========================
prompt
create table CMX.T_WMS_QTY
(
  id          NUMBER(19) not null,
  conid       NUMBER(19),
  goodsid     NUMBER(19),
  goodsgp     VARCHAR2(500),
  lotno       VARCHAR2(100),
  goodsno     VARCHAR2(100),
  packsize    NUMBER(18,6),
  qty_show    VARCHAR2(500),
  pcs         NUMBER,
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64),
  tranposname VARCHAR2(500)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_WMS_QTY on CMX.T_WMS_QTY (CONID, GOODSID, LOTNO)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_WMS_QTY
  add constraint PK_T_WMS_QTY primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

prompt
prompt Creating table T_WMS_QTY_DETAIL
prompt ===============================
prompt
create table CMX.T_WMS_QTY_DETAIL
(
  id          NUMBER(19) not null,
  rn          NUMBER(10),
  conid       NUMBER(19),
  goodsid     NUMBER(19),
  goodsname   VARCHAR2(500),
  lotno       VARCHAR2(100),
  goodsqty    NUMBER(18,6),
  pcs         NUMBER,
  validdate   DATE,
  containerno VARCHAR2(100),
  jz          NUMBER(18,6),
  mz          NUMBER(18,6),
  tj          NUMBER(18,6),
  deleted     NUMBER(1) default 0,
  create_time TIMESTAMP(6) default SYSTIMESTAMP,
  update_time TIMESTAMP(6) default SYSTIMESTAMP,
  create_by   VARCHAR2(64),
  update_by   VARCHAR2(64),
  memo        VARCHAR2(500)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index CMX.IDX_WMS_QTY_DETAIL_CONID on CMX.T_WMS_QTY_DETAIL (CONID)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create unique index CMX.UK_WMS_QTY_DETAIL on CMX.T_WMS_QTY_DETAIL (CONID, RN)
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
alter table CMX.T_WMS_QTY_DETAIL
  add constraint PK_T_WMS_QTY_DETAIL primary key (ID)
  using index 
  tablespace USERS
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );


prompt Done
spool off
set define on
