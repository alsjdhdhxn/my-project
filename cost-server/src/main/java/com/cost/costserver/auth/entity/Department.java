package com.cost.costserver.auth.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("T_COST_DEPARTMENT")
public class Department {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String deptCode;
    private String deptName;
    private Long parentId;
    private Integer sortOrder;

    @TableLogic
    private Integer deleted;
}
