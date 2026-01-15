package com.cost.costserver.grid.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("T_COST_USER_GRID_CONFIG")
public class UserGridConfig {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long userId;
    private String pageCode;
    private String gridKey;
    private String configData;

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
