import oracledb

conn = oracledb.connect(user="cmx", password="cmx", dsn="192.168.11.5:1521/orcl")
cursor = conn.cursor()

# 1. 删除列元数据（先删子表）
cursor.execute("""
    DELETE FROM T_COST_COLUMN_METADATA 
    WHERE TABLE_METADATA_ID IN (
        SELECT ID FROM T_COST_TABLE_METADATA WHERE TABLE_CODE NOT IN ('CostPinggu', 'CostPingguDtl')
    )
""")
print(f"删除列元数据: {cursor.rowcount} 行")

# 2. 删除表元数据
cursor.execute("DELETE FROM T_COST_TABLE_METADATA WHERE TABLE_CODE NOT IN ('CostPinggu', 'CostPingguDtl')")
print(f"删除表元数据: {cursor.rowcount} 行")

# 3. 删除页面组件
cursor.execute("DELETE FROM T_COST_PAGE_COMPONENT WHERE PAGE_CODE != 'cost-pinggu'")
print(f"删除页面组件: {cursor.rowcount} 行")

# 4. 删除菜单
cursor.execute("DELETE FROM T_COST_RESOURCE WHERE RESOURCE_CODE != 'pinggu'")
print(f"删除菜单: {cursor.rowcount} 行")

conn.commit()
print("\n删除完成！")

cursor.close()
conn.close()
