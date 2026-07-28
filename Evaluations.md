# Feature: Evaluations

## Files Changed
### New Files

- `lib/EvaluationTemplate.php` — evaluation **template** definitions (stages/criteria CRUD, positioning, generic vs. per-job-order templates)
- `lib/Evaluations.php` — evaluation **instances** (create/update instance, add/rename evaluator, save criteria values)
- `modules/settings/CustomizeEvaluationTemplate.tpl` — the stage/criteria editor UI
- `modules/joborders/Evaluate.tpl` — the evaluation form page (stages/criteria, evaluator add/rename, per-stage save)

### Modified Files

- `modules/settings/SettingsUI.php`: added `customizeEvaluationTemplate()` / `onCustomizeEvaluationTemplate()` cases in `handlerequest()`
- `modules/joborders/JobOrdersUI.php`: added `evaluate()` / `onEvaluate()` cases in `handleRequest()`; also the edit-display method that fetches `getFullTemplate()` for the read-only view
- `modules/joborders/Edit.tpl` — read-only "Evaluation Template" stages/criteria display + link into the template editor
- `modules/joborders/Show.tpl` — pipeline-row entry point link into the evaluate page

## Database Changes
- `evaluation_template` — template definitions (`site_id`, `job_order_id`; `NULL` = generic)
- `evaluation_stage` — stages per template
- `evaluation_criteria` — criteria per stage
- `evaluation_instance` — one evaluation instance per (evaluator, candidate, job order)
- `evaluation_criteria_value` — per-criterion values for an instance

```sql
CREATE TABLE evaluation_criteria (
    criteria_id    INT(11) NOT NULL AUTO_INCREMENT,
    stage_id       INT(11) NOT NULL,
    site_id        INT(11) NOT NULL,
    criteria_name  VARCHAR(255) NOT NULL,
    position       INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (criteria_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE evaluation_template (
    template_id    INT(11) NOT NULL AUTO_INCREMENT,
    site_id        INT(11) NOT NULL,
    job_order_id   INT(11) DEFAULT NULL,
    PRIMARY KEY (template_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE evaluation_instance (
    instance_id    INT(11) NOT NULL AUTO_INCREMENT,
    site_id        INT(11) NOT NULL,
    candidate_id   INT(11) NOT NULL,
    job_order_id   INT(11) NOT NULL,
    template_id    INT(11) NOT NULL,
    date_created   DATETIME DEFAULT NULL,
    PRIMARY KEY (instance_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE evaluation_stage_evaluator (
    evaluator_id    INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    instance_id     INT(10) UNSIGNED NOT NULL,
    stage_id        INT(10) UNSIGNED NOT NULL,
    evaluator_name  VARCHAR(255) NOT NULL,
    site_id         INT(10) UNSIGNED NOT NULL,
    PRIMARY KEY (evaluator_id),
    INDEX idx_instance (instance_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE evaluation_stage (
    stage_id     INT(11) NOT NULL AUTO_INCREMENT,
    template_id  INT(11) NOT NULL,
    site_id      INT(11) NOT NULL,
    stage_name   VARCHAR(255) NOT NULL,
    position     INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (stage_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
```

## Notes
- This list reflects everything touched across the feature's development so far. Some pieces (e.g. `Evaluate.tpl`, the candidate-side entry link) were designed/drafted in chat but may not yet be confirmed as pasted into your actual files — worth a quick `grep` check (e.g. `grep -n "case 'evaluate'" modules/joborders/JobOrdersUI.php`) before relying on this as a complete record.