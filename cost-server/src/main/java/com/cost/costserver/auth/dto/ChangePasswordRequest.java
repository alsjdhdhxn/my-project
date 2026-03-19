package com.cost.costserver.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class ChangePasswordRequest {

    @NotBlank(message = "新密码不能为空")
    @Pattern(
        regexp = "^[\\w!@#$%^&*(),.?\":{}|<>]{6,18}$",
        message = "密码格式不正确，6-18位字符"
    )
    private String newPassword;
}
