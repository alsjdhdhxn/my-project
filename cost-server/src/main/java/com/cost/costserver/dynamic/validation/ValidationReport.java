package com.cost.costserver.dynamic.validation;

import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class ValidationReport {
    private boolean passed;
    private String message;
    private List<RuleResult> results = new ArrayList<>();

    public static ValidationReport success() {
        ValidationReport report = new ValidationReport();
        report.setPassed(true);
        return report;
    }

    public static ValidationReport fail(String message) {
        ValidationReport report = new ValidationReport();
        report.setPassed(false);
        report.setMessage(message);
        return report;
    }
}
