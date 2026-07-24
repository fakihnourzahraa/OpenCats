<!-- modules/joborders/Evaluate.tpl -->

<?php TemplateUtility::printHeader('Evaluate - ' . $this->candidateName, array('js/lib.js')); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>

<script type="text/javascript">
    var CATS_CSRF_TOKEN = <?php echo json_encode($_SESSION['CATS']->getCSRFToken()); ?>;
</script>

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

    <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <tr>
            <td width="40" style="vertical-align:top; padding-top:10px; padding-right:16px;">
                <a href="#" onclick="if (confirm('Remove this evaluator and all their entries?')) { document.getElementById('deleteEvaluator<?php echo (int) $evaluator['evaluator_id']; ?>').submit(); } return false;">
                    <img src="images/actions/delete.gif" width="16" height="16" class="absmiddle" alt="" border="0" title="Remove Evaluator" />
                </a>
                <a href="#" style="margin-left:4px;" onclick="editEvaluator_<?php echo (int) $evaluator['evaluator_id']; ?>(); return false;">
                    <img src="images/edit.gif" width="16" height="16" class="absmiddle" alt="" border="0" title="Edit Evaluator" />
                </a>
                <br />
                <input type="submit" form="evaluatorForm_<?php echo (int) $evaluator['evaluator_id']; ?>"
                       value="Save" class="button" style="margin-top:8px;" />
            </td>
            <td>
                <form id="evaluatorForm_<?php echo (int) $evaluator['evaluator_id']; ?>" method="post" action="<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=evaluate">
                    <input type="hidden" name="jobOrderID" value="<?php echo (int) $this->jobOrderID; ?>" />
                    <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                    <input type="hidden" name="stageID" value="<?php echo (int) $stage['stage_id']; ?>" />
                    <input type="hidden" name="evaluatorID" value="<?php echo (int) $evaluator['evaluator_id']; ?>" />
                    <input type="hidden" name="postback" value="1" />
                    <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />

                    <table border="0" cellpadding="4" cellspacing="0" width="600" class="editTable" style="margin:8px 0;">
                        <tr>
                            <td class="vertical" width="110">Evaluator Name:</td>
                            <td class="data" style="padding-left:0;">
                                <input type="text" name="evaluatorName" size="40" readonly="readonly"
                                    id="evaluatorNameInput_<?php echo (int) $evaluator['evaluator_id']; ?>"
                                    style="padding-left:0; margin-left:0;"
                                    value="<?php echo htmlspecialchars($evaluator['evaluator_name'], ENT_QUOTES, 'UTF-8'); ?>" />
                            </td>
                        </tr>

                        <?php foreach ($stage['criteria'] as $criterion): ?>
                            <tr>
                                <td class="vertical" width="110">
                                    <?php echo htmlspecialchars($criterion['criteria_name'], ENT_QUOTES, 'UTF-8'); ?>:
                                </td>
                                <td class="data" style="padding-left:0;">
                                    <?php
                                        $criteriaID = $criterion['criteria_id'];
                                        $value = isset($evaluator['values'][$criteriaID]) ? $evaluator['values'][$criteriaID] : '';
                                    ?>
                                    <textarea name="values[<?php echo (int) $criteriaID; ?>]" rows="2" cols="50" readonly="readonly"
                                        style="padding-left:0; margin-left:0;"
                                        class="evaluatorField_<?php echo (int) $evaluator['evaluator_id']; ?>"><?php echo htmlspecialchars($value, ENT_QUOTES, 'UTF-8'); ?></textarea>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </table>
                </form>
            </td>
        </tr>
    </table>

    <form id="deleteEvaluator<?php echo (int) $evaluator['evaluator_id']; ?>" method="post" action="<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=deleteEvaluator" style="display:none;">
        <input type="hidden" name="jobOrderID" value="<?php echo (int) $this->jobOrderID; ?>" />
        <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
        <input type="hidden" name="evaluatorID" value="<?php echo (int) $evaluator['evaluator_id']; ?>" />
        <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
    </form>

    <script type="text/javascript">
        function editEvaluator_<?php echo (int) $evaluator['evaluator_id']; ?>() {
            var nameInput = document.getElementById('evaluatorNameInput_<?php echo (int) $evaluator['evaluator_id']; ?>');
            nameInput.removeAttribute('readonly');
            nameInput.classList.add('editableField');

            var fields = document.getElementsByClassName('evaluatorField_<?php echo (int) $evaluator['evaluator_id']; ?>');
            for (var i = 0; i < fields.length; i++) {
                fields[i].removeAttribute('readonly');
                fields[i].classList.add('editableField');
            }

            nameInput.focus();
        }
    </script>

<?php endforeach; ?>

        <script type="text/javascript">
            var stageCriteria_<?php echo (int) $stage['stage_id']; ?> = <?php echo json_encode(array_map(function($c) {
                return array('id' => (int) $c['criteria_id'], 'name' => $c['criteria_name']);
            }, $stage['criteria'])); ?>;

            function addEvaluatorBlock_<?php echo (int) $stage['stage_id']; ?>() {
                var container = document.getElementById('newEvaluatorsContainer_<?php echo (int) $stage['stage_id']; ?>');
                var criteria  = stageCriteria_<?php echo (int) $stage['stage_id']; ?>;

                var form = document.createElement('form');
                form.method = 'post';
                form.action = '<?php echo CATSUtility::getIndexName(); ?>?m=joborders&a=evaluate';
                form.style.margin = '8px 0';

                function addHidden(name, value) {
                    var input = document.createElement('input');
                    input.type  = 'hidden';
                    input.name  = name;
                    input.value = value;
                    form.appendChild(input);
                    return input;
                }

                addHidden('jobOrderID',  '<?php echo (int) $this->jobOrderID; ?>');
                addHidden('candidateID', '<?php echo (int) $this->candidateID; ?>');
                addHidden('stageID',     '<?php echo (int) $stage['stage_id']; ?>');
                var evaluatorIDInput = addHidden('evaluatorID', '0');
                addHidden('postback',    '1');
                addHidden('csrfToken',   CATS_CSRF_TOKEN);
                addHidden('ajax',        '1');

                var table = document.createElement('table');
                table.setAttribute('border', '0');
                table.setAttribute('cellpadding', '4');
                table.setAttribute('cellspacing', '0');
                table.setAttribute('width', '100%');
                var tbody = document.createElement('tbody');
                table.appendChild(tbody);

                function addRow(labelText, inputEl) {
                    var row = tbody.insertRow(tbody.rows.length);
                    var tdLabel = row.insertCell(0);
                    tdLabel.className = 'vertical';
                    tdLabel.width = '160';
                    tdLabel.textContent = labelText;
                    var tdData = row.insertCell(1);
                    tdData.className = 'data';
                    tdData.appendChild(inputEl);
                }

                var nameInput = document.createElement('input');
                nameInput.type = 'text';
                nameInput.name = 'evaluatorName';
                nameInput.size = 40;
                addRow('Evaluator Name:', nameInput);

                for (var i = 0; i < criteria.length; i++) {
                    var textarea = document.createElement('textarea');
                    textarea.name = 'values[' + criteria[i].id + ']';
                    textarea.rows = 2;
                    textarea.cols = 60;
                    addRow(criteria[i].name + ':', textarea);
                }
                

                var saveRow = tbody.insertRow(tbody.rows.length);
                var saveCell = saveRow.insertCell(0);
                saveCell.colSpan = 2;
                saveCell.style.padding = '6px 0';
                var saveBtn = document.createElement('input');
                saveBtn.type  = 'submit';
                saveBtn.value = 'Save';
                saveBtn.className = 'button';
                saveCell.appendChild(saveBtn);

                form.onsubmit = function (evt) {
                    evt.preventDefault();

                    saveBtn.disabled = true;
                    saveBtn.value = 'Saving...';

                    var fd = new FormData(form);

                    fetch(form.action, {
                        method: 'POST',
                        body: fd,
                        credentials: 'same-origin'
                    })
                    .then(function (resp) { return resp.json(); })
                    .then(function (data) {
                        saveBtn.disabled = false;

                        if (data.success) {
                            evaluatorIDInput.value = data.evaluatorID;
                            saveBtn.value = 'Save';
                        } else {
                            saveBtn.value = 'Save (failed, try again)';
                        }
                    })
                    .catch(function () {
                        saveBtn.disabled = false;
                        saveBtn.value = 'Save (failed, try again)';
                    });
                };

                form.appendChild(table);
                container.appendChild(form);

                document.getElementById('addAnotherButtonWrap_<?php echo (int) $stage['stage_id']; ?>').style.display = '';
            }
        </script>

        <div id="addEvaluatorButton_<?php echo (int) $stage['stage_id']; ?>" style="margin-top:16px;">
            <input type="button" value="Add Evaluator" class="button"
                   onclick="
                       document.getElementById('addEvaluatorButton_<?php echo (int) $stage['stage_id']; ?>').style.display='none';
                       addEvaluatorBlock_<?php echo (int) $stage['stage_id']; ?>();" />
        </div>

        <div id="newEvaluatorsContainer_<?php echo (int) $stage['stage_id']; ?>"></div>

        <div id="addAnotherButtonWrap_<?php echo (int) $stage['stage_id']; ?>" style="display:none; margin-top:8px;">
            <input type="button" value="Add Evaluator" class="button"
                   onclick="addEvaluatorBlock_<?php echo (int) $stage['stage_id']; ?>();" />
        </div>

    <?php endforeach; ?>

<?php endif; ?>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>