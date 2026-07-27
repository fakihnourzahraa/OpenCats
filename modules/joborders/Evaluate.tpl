<!-- modules/joborders/Evaluate.tpl -->

<?php TemplateUtility::printHeader('Evaluate - ' . $this->candidateName, array('js/lib.js')); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>

<script type="text/javascript">
    var CATS_CSRF_TOKEN = <?php echo json_encode($_SESSION['CATS']->getCSRFToken()); ?>;

    // ------------------------------------------------------------------
    // Single shared builder used for EVERY evaluator block, whether it's
    // an existing evaluator loaded on page load or a brand new one added
    // via "Add Evaluator". There is intentionally only one code path here
    // so the two can never render or lock differently.
    // ------------------------------------------------------------------
    window.CATSStages = window.CATSStages || {};
    window.evaluatorBlocks = window.evaluatorBlocks || [];

    window.saveAllEvaluators = function () {
        var btn = document.getElementById('saveAllButton');
        var originalLabel = btn.value;
        btn.disabled = true;
        btn.value = 'Saving all...';

        var toSave = window.evaluatorBlocks.filter(function (block) {
            // Skip untouched blank "new evaluator" rows so Save All doesn't
            // send pointless empty submissions.
            return block.isSaved() || block.hasContent();
        });

        var promises = toSave.map(function (block) { return block.performSave(); });

        Promise.all(promises).then(function (results) {
            btn.disabled = false;
            var anyFailed = results.some(function (r) { return !r || !r.success; });
            btn.value = anyFailed ? 'Save All (some failed, retry)' : originalLabel;
            window.updateAverageRating();
        });
    };

    // Recomputes the average across every evaluator's "Rating" field,
    // across all stages, and updates the header display.
    window.updateAverageRating = function () {
        var display = document.getElementById('avgRatingDisplay');
        if (!display) {
            return;
        }

        var values = window.evaluatorBlocks
            .map(function (block) { return block.getRatingValue ? block.getRatingValue() : null; })
            .filter(function (v) { return v !== null; });

        if (values.length === 0) {
            display.textContent = 'N/A';
            return;
        }

        var avg = values.reduce(function (a, b) { return a + b; }, 0) / values.length;
        display.textContent = avg.toFixed(1);
    };

    // Adds a name to the shared "all evaluators" datalist if it isn't
    // already there, so it becomes selectable immediately without a
    // page reload (e.g. right after saving a brand new evaluator).
    window.registerEvaluatorName = function (name) {
        name = (name || '').trim();
        if (!name) {
            return;
        }

        var datalist = document.getElementById('evaluatorNamesList');
        if (!datalist) {
            return;
        }

        var alreadyThere = Array.prototype.some.call(datalist.options, function (opt) {
            return opt.value === name;
        });

        if (!alreadyThere) {
            var opt = document.createElement('option');
            opt.value = name;
            datalist.appendChild(opt);
        }
    };

    (function () {
        var uidCounter = 0;

        window.renderEvaluatorBlock = function (stageID, evaluatorID, evaluatorName, values) {
            var stage = window.CATSStages[stageID];
            var container = document.getElementById('evaluatorsContainer_' + stageID);
            var uid = 'uid' + (++uidCounter);

            values = values || {};

            function addHidden(form, name, value) {
                var input = document.createElement('input');
                input.type = 'hidden';
                input.name = name;
                input.value = value;
                form.appendChild(input);
                return input;
            }

            // ---- Outer 2-column layout: icons + Save on the left, form on the right ----
            var outer = document.createElement('table');
            outer.setAttribute('border', '0');
            outer.setAttribute('cellpadding', '0');
            outer.setAttribute('cellspacing', '0');
            outer.setAttribute('width', '100%');

            var row = outer.insertRow(-1);

            var iconTd = row.insertCell(-1);
            iconTd.width = '40';
            iconTd.style.verticalAlign = 'top';
            iconTd.style.paddingTop = '10px';
            iconTd.style.paddingRight = '16px';

            var iconsWrap = document.createElement('span');
            iconsWrap.style.display = evaluatorID > 0 ? '' : 'none';

            var deleteLink = document.createElement('a');
            deleteLink.href = '#';
            var deleteImg = document.createElement('img');
            deleteImg.src = 'images/actions/delete.gif';
            deleteImg.width = 16;
            deleteImg.height = 16;
            deleteImg.className = 'absmiddle';
            deleteImg.alt = '';
            deleteImg.setAttribute('border', '0');
            deleteImg.title = 'Remove Evaluator';
            deleteLink.appendChild(deleteImg);
            iconsWrap.appendChild(deleteLink);

            var editLink = document.createElement('a');
            editLink.href = '#';
            editLink.style.marginLeft = '4px';
            var editImg = document.createElement('img');
            editImg.src = 'images/edit.gif';
            editImg.width = 16;
            editImg.height = 16;
            editImg.className = 'absmiddle';
            editImg.alt = '';
            editImg.setAttribute('border', '0');
            editImg.title = 'Edit Evaluator';
            editLink.appendChild(editImg);
            iconsWrap.appendChild(editLink);

            iconTd.appendChild(iconsWrap);
            iconTd.appendChild(document.createElement('br'));

            var saveBtn = document.createElement('input');
            saveBtn.type = 'submit';
            saveBtn.value = 'Save';
            saveBtn.className = 'button';
            saveBtn.style.marginTop = '8px';
            iconTd.appendChild(saveBtn);

            var formTd = row.insertCell(-1);

            var form = document.createElement('form');
            form.id = 'evaluatorForm_' + uid;
            form.method = 'post';
            form.action = stage.indexName + '?m=joborders&a=evaluate';
            saveBtn.setAttribute('form', form.id);

            addHidden(form, 'jobOrderID', stage.jobOrderID);
            addHidden(form, 'candidateID', stage.candidateID);
            addHidden(form, 'stageID', stageID);
            var evaluatorIDInput = addHidden(form, 'evaluatorID', evaluatorID);
            addHidden(form, 'postback', '1');
            addHidden(form, 'csrfToken', stage.csrfToken);
            addHidden(form, 'ajax', '1');

            var table = document.createElement('table');
            table.setAttribute('border', '0');
            table.setAttribute('cellpadding', '4');
            table.setAttribute('cellspacing', '0');
            table.setAttribute('width', '600');
            table.className = 'editTable';
            table.style.margin = '8px 0';
            var tbody = document.createElement('tbody');
            table.appendChild(tbody);

            function addFieldRow(labelText, inputEl) {
                var r = tbody.insertRow(-1);
                var tdLabel = r.insertCell(-1);
                tdLabel.className = 'vertical';
                tdLabel.width = '110';
                tdLabel.textContent = labelText;
                var tdData = r.insertCell(-1);
                tdData.className = 'data';
                tdData.style.paddingLeft = '0';
                tdData.appendChild(inputEl);
            }

            var nameInput = document.createElement('input');
            nameInput.type = 'text';
            nameInput.name = 'evaluatorName';
            nameInput.className = 'inputbox';
            nameInput.autocomplete = 'off';    
            nameInput.size = 40;
            nameInput.setAttribute('list', 'evaluatorNamesList');
            nameInput.style.paddingLeft = '0';
            nameInput.style.marginLeft = '0';
            nameInput.value = evaluatorName || '';
            addFieldRow('Evaluator Name: *', nameInput);

            var textareas = [];
            var ratingField = null;
            stage.criteria.forEach(function (criterion) {
                var isRating = criterion.name.trim().toLowerCase() === 'rating';
                var field;

                if (isRating) {
                    field = document.createElement('input');
                    field.type = 'number';
                    field.step = 'any';
                    field.style.width = '100px';
                } else {
                    field = document.createElement('textarea');
                    field.rows = 2;
                    field.cols = 50;
                }

                field.name = 'values[' + criterion.id + ']';
                field.style.paddingLeft = '0';
                field.style.marginLeft = '0';
                field.value = values[criterion.id] || '';
                addFieldRow(criterion.name + ':', field);
                textareas.push(field);

                if (isRating) {
                    ratingField = field;
                }
            });

            if (ratingField) {
                ratingField.addEventListener('input', function () {
                    window.updateAverageRating();
                });
            }

            function getRatingValue() {
                if (!ratingField) {
                    return null;
                }
                var v = parseFloat(ratingField.value);
                return isNaN(v) ? null : v;
            }

            form.appendChild(table);
            formTd.appendChild(form);

            // ---- Hidden delete form ----
            var deleteForm = document.createElement('form');
            deleteForm.method = 'post';
            deleteForm.action = stage.indexName + '?m=joborders&a=deleteEvaluator';
            deleteForm.style.display = 'none';
            addHidden(deleteForm, 'jobOrderID', stage.jobOrderID);
            addHidden(deleteForm, 'candidateID', stage.candidateID);
            var deleteEvaluatorIDInput = addHidden(deleteForm, 'evaluatorID', evaluatorID);
            addHidden(deleteForm, 'csrfToken', stage.csrfToken);

            // ---- Lock / unlock behavior (shared, only ever defined once per block) ----
            function applyFieldStyle(el, isEditable) {
                el.readOnly = !isEditable;
                el.classList.toggle('editableField', isEditable);

                if (isEditable) {
                    el.style.background = '';
                    el.style.border = '';
                } else {
                    el.style.background = '#f5f5f5';
                    el.style.border = 'none';
                }
            }

            function setEditable(isEditable) {
                applyFieldStyle(nameInput, isEditable);
                textareas.forEach(function (t) { applyFieldStyle(t, isEditable); });
            }

            // Existing evaluators (evaluatorID > 0) start locked; a freshly
            // added block (evaluatorID === 0) starts editable.
            setEditable(evaluatorID === 0);

            editLink.onclick = function (e) {
                e.preventDefault();
                setEditable(true);
                nameInput.focus();
            };

            deleteLink.onclick = function (e) {
                e.preventDefault();
                if (confirm('Remove this evaluator and all their entries?')) {
                    deleteForm.submit();
                }
            };

            function performSave() {
                saveBtn.disabled = true;
                saveBtn.value = 'Saving...';

                var fd = new FormData(form);

                return fetch(form.action, {
                    method: 'POST',
                    body: fd,
                    credentials: 'same-origin'
                })
                .then(function (resp) { return resp.json(); })
                .then(function (data) {
                    saveBtn.disabled = false;

                    if (data.success) {
                        saveBtn.value = 'Save';
                        evaluatorIDInput.value = data.evaluatorID;
                        deleteEvaluatorIDInput.value = data.evaluatorID;
                        iconsWrap.style.display = '';
                        setEditable(false);
                        window.registerEvaluatorName(nameInput.value);
                    } else {
                        saveBtn.value = 'Save (failed, try again)';
                    }
                    window.updateAverageRating();
                    return data;
                })
                .catch(function () {
                    saveBtn.disabled = false;
                    saveBtn.value = 'Save (failed, try again)';
                    return { success: false };
                });
            }

            form.addEventListener('submit', function (evt) {
                evt.preventDefault();
                performSave();
            });

            function hasContent() {
                if (nameInput.value.trim()) {
                    return true;
                }
                return textareas.some(function (t) { return t.value.trim(); });
            }

            window.evaluatorBlocks.push({
                performSave: performSave,
                hasContent: hasContent,
                isSaved: function () { return Number(evaluatorIDInput.value) > 0; },
                getRatingValue: getRatingValue
            });

            container.appendChild(outer);
            container.appendChild(deleteForm);

            window.updateAverageRating();

            return outer;
        };
    })();
</script>

<div id="main">
    <?php TemplateUtility::printQuickSearch(); ?>

    <datalist id="evaluatorNamesList">
        <?php foreach ($this->allEvaluatorNames as $evaluatorName): ?>
            <option value="<?php echo htmlspecialchars($evaluatorName, ENT_QUOTES, 'UTF-8'); ?>"></option>
        <?php endforeach; ?>
    </datalist>

    <div id="contents">

        <table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tr>
                <td class="pageHeading">
                    Evaluate: <?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?>
                    <br>Job Order: 
                    <?php echo htmlspecialchars($this->jobOrderTitle, ENT_QUOTES, 'UTF-8'); ?>

                    <?php if (!$this->noTemplate): ?>
                        <br><span style="font-weight:normal; font-size:13px;">Rating: <span id="avgRatingDisplay">N/A</span></span>
                        <br><input type="button" id="saveAllButton" value="Save All" class="button" style="margin-top:6px;"
                               onclick="saveAllEvaluators();" />
                    <?php endif; ?>
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

        <?php $stageID = (int) $stage['stage_id']; ?>

        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top:20px;">
            <tr>
                <td class="subHeading">
                  Stage:  <?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?>
                </td>
            </tr>
        </table>

        <div id="evaluatorsContainer_<?php echo $stageID; ?>"></div>

        <script type="text/javascript">
            window.CATSStages[<?php echo $stageID; ?>] = {
                criteria: <?php echo json_encode(array_map(function ($c) {
                    return array('id' => (int) $c['criteria_id'], 'name' => $c['criteria_name']);
                }, $stage['criteria'])); ?>,
                jobOrderID: <?php echo (int) $this->jobOrderID; ?>,
                candidateID: <?php echo (int) $this->candidateID; ?>,
                indexName: <?php echo json_encode(CATSUtility::getIndexName()); ?>,
                csrfToken: CATS_CSRF_TOKEN
            };

            (function () {
                var evaluators = <?php echo json_encode(array_map(function ($e) {
                    return array(
                        'id'     => (int) $e['evaluator_id'],
                        'name'   => $e['evaluator_name'],
                        'values' => (object) (isset($e['values']) ? $e['values'] : array()),
                    );
                }, $stage['evaluators'])); ?>;

                evaluators.forEach(function (ev) {
                    renderEvaluatorBlock(<?php echo $stageID; ?>, ev.id, ev.name, ev.values);
                });
            })();
        </script>

        <div style="margin-top:16px;">
            <input type="button" value="Add Evaluator" class="button"
                   onclick="renderEvaluatorBlock(<?php echo $stageID; ?>, 0, '', {});" />
        </div>

    <?php endforeach; ?>

<?php endif; ?>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>