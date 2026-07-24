<!-- modules/joborders/Evaluate.tpl -->

<?php TemplateUtility::printHeader('Evaluate - ' . $this->candidateName, array('js/lib.js')); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>

<div id="main">
    <?php TemplateUtility::printQuickSearch(); ?>

    <div id="contents">

        <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
                <td class="pageHeading">
                    Evaluate: <?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?>
                    <br>Job Order: 
                    <?php echo htmlspecialchars($this->jobOrderTitle, ENT_QUOTES, 'UTF-8'); ?>
                </td>
            </tr>
        </table>

<?php if ($this->noTemplate): ?>

    <table border="0" cellpadding="10" cellspacing="0" width="100%">
        <tr>
            <td>
                <span style="color:#888;">No evaluation template has been defined for this job order yet.</span>
                <?php if ($this->getUserAccessLevel('joborders.edit') >= ACCESS_LEVEL_EDIT): ?>
                    <br /><a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=settings&a=customizeEvaluationTemplate&jobOrderID=' . $this->jobOrderID); ?>">[Define a template]</a>
                <?php endif; ?>
            </td>
        </tr>
    </table>

<?php else: ?>

    <?php foreach ($this->stages as $stage): ?>

        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top:20px;">
            <tr>
                <td class="subHeading">
                  Stage:  <?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?>
                </td>
            </tr>
        </table>

        <?php foreach ($stage['evaluators'] as $evaluator): ?>

            <form method="post" action="<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=evaluate">
                <input type="hidden" name="jobOrderID" value="<?php echo (int) $this->jobOrderID; ?>" />
                <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                <input type="hidden" name="stageID" value="<?php echo (int) $stage['stage_id']; ?>" />
                <input type="hidden" name="evaluatorID" value="<?php echo (int) $evaluator['evaluator_id']; ?>" />
                <input type="hidden" name="postback" value="1" />

                <table border="0" cellpadding="4" cellspacing="0" width="100%" class="editTable" style="margin:8px 0;">
                    <tr>
                        <td class="vertical" width="160">Evaluator Name:</td>
                        <td class="data">
                            <input type="text" name="evaluatorName" size="40"
                                value="<?php echo htmlspecialchars($evaluator['evaluator_name'], ENT_QUOTES, 'UTF-8'); ?>" />
                        </td>
                    </tr>

                    <?php foreach ($stage['criteria'] as $criterion): ?>
                        <tr>
                            <td class="vertical" width="160">
                                <?php echo htmlspecialchars($criterion['criteria_name'], ENT_QUOTES, 'UTF-8'); ?>:
                            </td>
                            <td class="data">
                                <?php
                                    $criteriaID = $criterion['criteria_id'];
                                    $value = isset($evaluator['values'][$criteriaID]) ? $evaluator['values'][$criteriaID] : '';
                                ?>
                                <textarea name="values[<?php echo (int) $criteriaID; ?>]" rows="2" cols="60"><?php echo htmlspecialchars($value, ENT_QUOTES, 'UTF-8'); ?></textarea>
                            </td>
                        </tr>
                    <?php endforeach; ?>

                    <tr>
                        <td colspan="2" style="padding:6px 0;">
                            <input type="submit" value="Save" class="button" />
                        </td>
                    </tr>
                </table>
            </form>

            <a href="#" onclick="if (confirm('Remove this evaluator and all their entries?')) { document.getElementById('deleteEvaluator<?php echo (int) $evaluator['evaluator_id']; ?>').submit(); } return false;">
                <img src="images/actions/delete.gif" width="16" height="16" class="absmiddle" alt="" border="0" title="Remove Evaluator" />
            </a>

            <form id="deleteEvaluator<?php echo (int) $evaluator['evaluator_id']; ?>" method="post" action="<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=deleteEvaluator" style="display:none;">
                <input type="hidden" name="jobOrderID" value="<?php echo (int) $this->jobOrderID; ?>" />
                <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                <input type="hidden" name="evaluatorID" value="<?php echo (int) $evaluator['evaluator_id']; ?>" />
            </form>

        <?php endforeach; ?>

        <!-- Add a new evaluator to this stage — collapsed behind a button, -->
        <!-- form only appears once clicked. -->
        <div id="addEvaluatorButton<?php echo (int) $stage['stage_id']; ?>" style="margin-top:16px;">
            <a href="#" onclick="document.getElementById('addEvaluatorForm<?php echo (int) $stage['stage_id']; ?>').style.display=''; document.getElementById('addEvaluatorButton<?php echo (int) $stage['stage_id']; ?>').style.display='none'; return false;">
                <img src="images/actions/add.gif" width="16" height="16" class="absmiddle" alt="" border="0" />&nbsp;Add Evaluator
            </a>
        </div>

        <div id="addEvaluatorForm<?php echo (int) $stage['stage_id']; ?>" style="display:none;">
            <form method="post" action="<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=evaluate">
                <input type="hidden" name="jobOrderID" value="<?php echo (int) $this->jobOrderID; ?>" />
                <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                <input type="hidden" name="stageID" value="<?php echo (int) $stage['stage_id']; ?>" />
                <input type="hidden" name="evaluatorID" value="0" />
                <input type="hidden" name="postback" value="1" />

                <table border="0" cellpadding="4" cellspacing="0" width="100%" style="margin:8px 0;">
                    <tr>
                        <td class="vertical" width="160">Evaluator Name:</td>
                        <td class="data">
                            <input type="text" name="evaluatorName" size="40" value="" />
                        </td>
                    </tr>

                    <?php foreach ($stage['criteria'] as $criterion): ?>
                        <tr>
                            <td class="vertical" width="160">
                                <?php echo htmlspecialchars($criterion['criteria_name'], ENT_QUOTES, 'UTF-8'); ?>:
                            </td>
                            <td class="data">
                                <textarea name="values[<?php echo (int) $criterion['criteria_id']; ?>]" rows="2" cols="60"></textarea>
                            </td>
                        </tr>
                    <?php endforeach; ?>

                    <tr>
                        <td colspan="2" style="padding:6px 0;">
                            <input type="submit" value="Add Evaluator" class="button" />
                        </td>
                    </tr>
                </table>

            </form>
        </div>

    <?php endforeach; ?>

<?php endif; ?>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>