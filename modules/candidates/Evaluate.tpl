<?php /* modules/candidates/Evaluate.tpl  IBC */ ?>

<?php TemplateUtility::printHeader('Evaluate - ' . $this->candidateName, array('js/lib.js')); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>

<script type="text/javascript">
    var CSRF_Token = <?php echo json_encode($_SESSION['CATS']->getCSRFToken()); ?>;
    var CATS_IndexName = <?php echo json_encode(CATSUtility::getIndexName()); ?>;
    var CATS_CandidateID = <?php echo (int) $this->candidateID; ?>;
    var CATS_InstanceID = <?php echo (int) $this->instanceID; ?>;

    /* A locked evaluation renders as a plain read-only record: no icons, no
       Save, no editable fields. The server refuses the writes regardless -
       this only keeps the page from offering controls that would fail. */
    var CATS_IsLocked = <?php echo $this->isLocked ? 'true' : 'false'; ?>;

    /* Rides along on every write so the job order survives the redirect back
       to this page. 0 is the Generic view, which files nothing. */
    var CATS_NavJobOrderID = <?php echo (int) $this->navJobOrderID; ?>;

    /* Navigation only. Unlike the template loader further down, this writes
       nothing - it just moves to another candidate's evaluation. */
    window.evalNavGo = function (candidateID, jobOrderID) {
        window.location = CATS_IndexName + '?m=candidates&a=evaluate'
            + '&candidateID=' + encodeURIComponent(candidateID)
            + '&navJobOrderID=' + encodeURIComponent(jobOrderID);
    };

    window.evalNavJobOrderChanged = function () {
        evalNavGo(CATS_CandidateID, document.getElementById('navJobOrder').value);
    };

    window.evalNavCandidateChanged = function () {
        var sel = document.getElementById('navCandidate');
        if (!sel || sel.value === '') { return; }
        evalNavGo(sel.value, document.getElementById('navJobOrder').value);
    };

    window.CATSStages = window.CATSStages || {};
    window.evaluatorBlocks = window.evaluatorBlocks || [];

    /* Same swap the settings template editor uses: the display span is hidden
       and an edit area takes its place, with the action icons left visible
       either side of it. Two explicit functions rather than one toggle,
       because a toggle can't tell "already open" from "never opened" once
       display has been set back to ''. */
    window.showEdit = function (displayID, editID, focusID) {
        var display = document.getElementById(displayID);
        var edit    = document.getElementById(editID);
        if (!display || !edit) {
            return;
        }

        display.style.display = 'none';
        edit.style.display    = '';

        if (focusID) {
            var field = document.getElementById(focusID);
            if (field) {
                field.focus();
            }
        }
    };

    window.hideEdit = function (displayID, editID) {
        var display = document.getElementById(displayID);
        var edit    = document.getElementById(editID);
        if (!display || !edit) {
            return;
        }

        edit.style.display    = 'none';
        display.style.display = '';
    };

    /* Stage edit mode: the criterion labels inside the evaluator block turn
       into inputs in place. Nothing new is drawn - it is the same table.
       A stage with no evaluators yet has no labels to edit, so one empty
       block is rendered first to edit them in. */
    window.showStageEditor = function (instanceStageID) {
        var stage = window.CATSStages[instanceStageID];

        if (!stage.editorBound) {
            renderEvaluatorBlock(instanceStageID, 0, '', {});
        }

        stage.labelDisplays.forEach(function (el) { el.style.display = 'none'; });
        stage.labelEdits.forEach(function (el) { el.style.display = ''; });

        document.getElementById('stageDisplay_' + instanceStageID).style.display = 'none';
        document.getElementById('stageNameEdit_' + instanceStageID).style.display = '';
        document.getElementById('stageNameInput_' + instanceStageID).focus();
    };

    window.hideStageEditor = function (instanceStageID) {
        var stage = window.CATSStages[instanceStageID];

        stage.labelDisplays.forEach(function (el) { el.style.display = ''; });
        stage.labelEdits.forEach(function (el) { el.style.display = 'none'; });

        document.getElementById('stageNameEdit_' + instanceStageID).style.display = 'none';
        document.getElementById('stageDisplay_' + instanceStageID).style.display = '';
    };

    window.saveAllEvaluators = function () {
        var btn = document.getElementById('saveAllButton');
        if (!btn) {
            return;
        }

        var originalLabel = btn.value;
        btn.disabled = true;
        btn.value = 'Saving';

        var toSave = window.evaluatorBlocks.filter(function (block) {
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

    window.updateAverageRating = function () {
        var display = document.getElementById('avgRatingDisplay');
        if (!display) {
            return;
        }

        var values = window.evaluatorBlocks
            .map(function (block) { return block.getRatingValue ? block.getRatingValue() : null; })
            .filter(function (v) { return v !== null; });

        if (values.length === 0) {
            display.textContent = 'Empty';
            return;
        }

        var avg = values.reduce(function (a, b) { return a + b; }, 0) / values.length;
        display.textContent = avg.toFixed(1);
    };

    /* Keeps the evaluator-name autocomplete list current within the session. */
    window.registerEvaluatorName = function (name) {
        name = (name || '').trim();
        if (!name) {
            return;
        }

        var datalist = document.getElementById('evaluatorNamesList');
        if (!datalist) {
            return;
        }

        var exists = Array.prototype.some.call(datalist.options, function (opt) {
            return opt.value === name;
        });

        if (!exists) {
            var opt = document.createElement('option');
            opt.value = name;
            datalist.appendChild(opt);
        }
    };

    /* evaluatorID 0 means "not saved yet". */
    (function () {
        var uniqueCount = 0;

        window.renderEvaluatorBlock = function (instanceStageID, evaluatorID, evaluatorName, values) {
            var stage = window.CATSStages[instanceStageID];
            var container = document.getElementById('evaluatorsContainer_' + instanceStageID);
            var uid = 'uid' + (++uniqueCount);
            var criteriaFormID = 'criteriaForm_' + instanceStageID;

            /* First block for this stage claims the criteria edit controls.
               A locked evaluation has no criteria editor at all. */
            var isEditorBlock = !CATS_IsLocked && !stage.editorBound;
            if (isEditorBlock) {
                stage.editorBound = true;
                stage.labelDisplays = [];
                stage.labelEdits = [];
            }

            values = values || {};

            function addHidden(form, name, value) {
                var input = document.createElement('input');
                input.type = 'hidden';
                input.name = name;
                input.value = value;
                form.appendChild(input);
                return input;
            }

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

            var saveBtn = document.createElement('input');
            saveBtn.type = 'submit';
            saveBtn.value = 'Save';
            saveBtn.className = 'button';
            saveBtn.style.marginTop = '8px';

            /* Locked: the icon column stays (it holds the layout) but is empty. */
            if (!CATS_IsLocked) {
                iconTd.appendChild(iconsWrap);
                iconTd.appendChild(document.createElement('br'));
                iconTd.appendChild(saveBtn);
            }

            var formTd = row.insertCell(-1);

            var form = document.createElement('form');
            form.id = 'evaluatorForm_' + uid;
            form.method = 'post';
            form.action = CATS_IndexName + '?m=candidates&a=evaluate';
            saveBtn.setAttribute('form', form.id);

            addHidden(form, 'candidateID', CATS_CandidateID);
            addHidden(form, 'instanceID', CATS_InstanceID);
            addHidden(form, 'navJobOrderID', CATS_NavJobOrderID);
            addHidden(form, 'instanceStageID', instanceStageID);
            var evaluatorIDInput = addHidden(form, 'evaluatorID', evaluatorID);
            addHidden(form, 'postback', 'postback');
            addHidden(form, 'csrfToken', CSRF_Token);
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

            function addFieldRow(labelContent, inputEl) {
                var r = tbody.insertRow(-1);
                var tdLabel = r.insertCell(-1);
                tdLabel.className = 'vertical';
                tdLabel.width = '110';
                if (typeof labelContent === 'string') {
                    tdLabel.textContent = labelContent;
                } else {
                    tdLabel.appendChild(labelContent);
                }
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
            if (!CATS_IsLocked) {
                nameInput.setAttribute('list', 'evaluatorNamesList');
            }
            nameInput.style.paddingLeft = '0';
            nameInput.style.marginLeft = '0';
            nameInput.value = evaluatorName || '';
            addFieldRow(CATS_IsLocked ? 'Evaluator Name:' : 'Evaluator Name: *', nameInput);

            var fields = [];
            var ratingField = null;

            stage.criteria.forEach(function (criterion) {
                var isRating = criterion.name.trim().toLowerCase() === 'rating';
                var type = criterion.type || 'text';
                var field;

                if (type === 'number') {
                    field = document.createElement('input');
                    field.type = 'number';
                    field.step = 'any';
                    field.style.width = '100px';
                } else if (type === 'date') {
                    field = document.createElement('input');
                    field.type = 'date';
                    field.style.width = '160px';
                } else {
                    field = document.createElement('textarea');
                    field.rows = 2;
                    field.cols = 50;
                }

                field.name = 'values[' + criterion.id + ']';
                field.style.paddingLeft = '0';
                field.style.marginLeft = '0';
                field.value = values[criterion.id] || '';

                /* The label is the criterion name, so this is where editing it
                   belongs. Only the first block rendered for a stage carries the
                   edit controls - the rest show the same criteria, and having
                   several editable copies of one name would be ambiguous. */
                var labelWrap = document.createElement('span');

                var labelDisplay = document.createElement('span');
                labelDisplay.textContent = criterion.name + ':';
                labelWrap.appendChild(labelDisplay);

                if (isEditorBlock) {
                    var labelEdit = document.createElement('span');
                    labelEdit.style.display = 'none';

                    var critNameInput = document.createElement('input');
                    critNameInput.type = 'text';
                    critNameInput.name = 'criteriaName[' + criterion.id + ']';
                    critNameInput.className = 'inputbox';
                    critNameInput.style.width = '95px';
                    critNameInput.value = criterion.name;
                    critNameInput.setAttribute('form', criteriaFormID);
                    labelEdit.appendChild(critNameInput);

                    var critTypeSelect = document.createElement('select');
                    critTypeSelect.name = 'criteriaType[' + criterion.id + ']';
                    critTypeSelect.className = 'inputbox';
                    critTypeSelect.style.width = '75px';
                    critTypeSelect.setAttribute('form', criteriaFormID);
                    ['text', 'date', 'number'].forEach(function (t) {
                        var opt = document.createElement('option');
                        opt.value = t;
                        opt.textContent = t;
                        if ((criterion.type || 'text') === t) { opt.selected = true; }
                        critTypeSelect.appendChild(opt);
                    });
                    labelEdit.appendChild(critTypeSelect);

                    labelWrap.appendChild(labelEdit);

                    stage.labelDisplays.push(labelDisplay);
                    stage.labelEdits.push(labelEdit);
                }

                addFieldRow(labelWrap, field);
                fields.push(field);

                if (isRating) {
                    ratingField = field;
                }
            });

            if (ratingField && !CATS_IsLocked) {
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

            var deleteForm = document.createElement('form');
            deleteForm.method = 'post';
            deleteForm.action = CATS_IndexName + '?m=candidates&a=deleteEvaluator';
            deleteForm.style.display = 'none';
            addHidden(deleteForm, 'candidateID', CATS_CandidateID);
            addHidden(deleteForm, 'instanceID', CATS_InstanceID);
            addHidden(deleteForm, 'navJobOrderID', CATS_NavJobOrderID);
            var deleteEvaluatorIDInput = addHidden(deleteForm, 'evaluatorID', evaluatorID);
            addHidden(deleteForm, 'postback', 'postback');
            addHidden(deleteForm, 'csrfToken', CSRF_Token);

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
                if (CATS_IsLocked) {
                    isEditable = false;
                }
                applyFieldStyle(nameInput, isEditable);
                fields.forEach(function (t) { applyFieldStyle(t, isEditable); });
            }

            setEditable(evaluatorID === 0);

            editLink.onclick = function (e) {
                e.preventDefault();
                setEditable(true);
                nameInput.focus();
            };

            deleteLink.onclick = function (e) {
                e.preventDefault();
                if (confirm('Remove this evaluator?')) {
                    deleteForm.submit();
                }
            };

            function performSave() {
                if (CATS_IsLocked) {
                    return Promise.resolve({ success: false });
                }

                /* An unnamed evaluator is what leaves a phantom saved block on
                   the page after a reload, so it never reaches the server. */
                if (!nameInput.value.trim()) {
                    alert('Evaluator name is required.');
                    setEditable(true);
                    nameInput.focus();
                    return Promise.resolve({ success: false });
                }

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
                    } else if (data.locked) {
                        /* Locked after this page was opened. */
                        saveBtn.value = 'Locked';
                        alert('This evaluation has been locked and can no longer be edited.');
                        setEditable(false);
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
                return fields.some(function (t) { return t.value.trim(); });
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

<?php
    /* Emitted into every form that writes, so onEvaluationCommand() /
       onEvaluate() / onDeleteEvaluator() redirect back here with the
       navigation state intact. */
    $navJobOrderField = '<input type="hidden" name="navJobOrderID" value="'
        . (int) $this->navJobOrderID . '" />';
?>

<div id="main">
    <?php TemplateUtility::printQuickSearch(); ?>

    <?php if (!$this->isLocked): ?>
        <datalist id="evaluatorNamesList">
            <?php foreach ($this->allEvaluatorNames as $evaluatorName): ?>
                <option value="<?php echo htmlspecialchars($evaluatorName, ENT_QUOTES, 'UTF-8'); ?>"></option>
            <?php endforeach; ?>
        </datalist>
    <?php endif; ?>

    <div id="contents">

        <table>
            <tr>
                <td width="3%">
                    <img src="images/candidate.gif" width="24" height="24" border="0" alt="Candidates" style="margin-top: 3px;" />&nbsp;
                </td>
                <td><h2>Candidates: Evaluation</h2></td>
            </tr>
        </table>

        <p class="note">
            <?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?>
        </p>

        <!-- Navigation. Job order on top, its candidates below; Generic means
             every candidate and their latest evaluation regardless of filing.
             This only MOVES between evaluations - it writes nothing, and is
             unrelated to the "Load stages from" line further down, which is
             what actually seeds structure. -->
        <?php $navJobOrderID = (int) $this->navJobOrderID; ?>
        <div style="margin-bottom:14px;">
            <select id="navJobOrder" class="inputbox" style="width:340px;"
                    onchange="evalNavJobOrderChanged();">
                <option value="0"<?php echo $navJobOrderID === 0 ? ' selected="selected"' : ''; ?>>Generic (all candidates)</option>
                <?php foreach ($this->jobOrdersRS as $jobOrderData): ?>
                    <?php $joID = (int) $jobOrderData['jobOrderID']; ?>
                    <option value="<?php echo $joID; ?>"<?php echo $navJobOrderID === $joID ? ' selected="selected"' : ''; ?>>
                        <?php echo htmlspecialchars($jobOrderData['title'], ENT_QUOTES, 'UTF-8'); ?><?php
                            if (!empty($jobOrderData['companyName']))
                            {
                                echo ' (' . htmlspecialchars($jobOrderData['companyName'], ENT_QUOTES, 'UTF-8') . ')';
                            }
                        ?>
                    </option>
                <?php endforeach; ?>
            </select>

            <div style="margin-top:4px;">
                <select id="navCandidate" class="inputbox" style="width:340px;"
                        onchange="evalNavCandidateChanged();">
                    <?php if (!$this->navCandidateHere): ?>
                        <option value="<?php echo (int) $this->candidateID; ?>" selected="selected">
                            <?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?> (not in this pipeline)
                        </option>
                    <?php endif; ?>
                    <?php foreach ($this->navCandidates as $navCandidate): ?>
                        <?php
                            $cID   = (int) $navCandidate['candidateID'];
                            $label = ($navCandidate['firstName'] . ' ' . $navCandidate['lastName']);
                            if (isset($this->navFiledMap[$cID])) { $label = '* ' . $label; }
                        ?>
                        <option value="<?php echo $cID; ?>"<?php echo $cID === (int) $this->candidateID ? ' selected="selected"' : ''; ?>>
                            <?php echo htmlspecialchars($label, ENT_QUOTES, 'UTF-8'); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
               
            </div>
        </div>

        <?php if ($this->isLocked): ?>
            <div class="warning" style="margin-bottom:10px;">
                <img src="images/key.png" width="16" height="16" border="0" class="absmiddle" alt="" />&nbsp;This
                evaluation is locked. It is read-only and cannot be unlocked.
            </div>
        <?php endif; ?>

        <?php if ($this->isDraft): ?>
            <div class="note" style="margin-bottom:10px; color:#666;">
                No evaluation here yet.
            </div>
        <?php endif; ?>

        <!-- Evaluation title (rename in place) -->
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:10px;">
            <tr>
                <td class="pageHeading">
                    <span id="evalTitleDisplay">
                        <?php echo htmlspecialchars($this->evaluationTitle, ENT_QUOTES, 'UTF-8'); ?>
                        <?php if (!$this->isLocked && !$this->isDraft): ?>
                            <a href="javascript:void(0);" style="margin-left:6px;"
                               onclick="showEdit('evalTitleDisplay', 'evalTitleEdit', 'evalTitleInput');">
                                <img src="images/edit.gif" border="0" class="absmiddle" alt="edit" />
                            </a>
                        <?php endif; ?>
                    </span>

                    <?php if (!$this->isLocked && !$this->isDraft): ?>
                        <span id="evalTitleEdit" style="display:none;">
                            <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand" style="display:inline;">
                                <input type="hidden" name="postback" value="postback" />
                                <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                                <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                                <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                                <?php echo $navJobOrderField; ?>
                                <input type="hidden" name="command" value="renameEvaluation" />
                                <input type="text" id="evalTitleInput" name="title" class="inputbox" size="40"
                                       value="<?php echo htmlspecialchars($this->evaluationTitle, ENT_QUOTES, 'UTF-8'); ?>" />
                                <input type="submit" class="button" value="Save" />
                                <input type="button" class="button" value="Cancel"
                                       onclick="hideEdit('evalTitleDisplay', 'evalTitleEdit');" />
                            </form>
                        </span>
                    <?php endif; ?>

                    <?php if (!$this->isEmpty): ?>
                        <br /><span style="font-weight:normal; font-size:13px;">Rating: <span id="avgRatingDisplay">Empty</span></span>
                        <?php if (!$this->isLocked): ?>
                            <br /><input type="button" id="saveAllButton" value="Save All" class="button" style="margin-top:6px;"
                                         onclick="saveAllEvaluators();" />
                        <?php endif; ?>
                    <?php endif; ?>
                </td>
            </tr>
        </table>

        <!-- Seed from a job order's template.
             COPIES stages/criteria in, merging by name: existing names are left
             alone and only what's missing gets added. It also FILES the
             evaluation under the job order picked here, replacing whatever it
             was filed under before. Picking the Generic template files it
             nowhere, which means it's only reachable through the Generic view.
             On a draft page this is what creates the evaluation.

             Kept as one plain line rather than a panel: it's an occasional
             setup action, not a section of the evaluation. -->
        <?php if (!$this->isLocked): ?>
        <div style="margin-bottom:16px;">
            <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand" style="display:inline;"
                  onsubmit="return confirm('Load this template into the evaluation?');">
                <input type="hidden" name="postback" value="postback" />
                <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                <?php echo $navJobOrderField; ?>
                <input type="hidden" name="command" value="seedTemplate" />

                <span >Load stages from</span>

<?php $selectedJobOrderID = isset($this->selectedJobOrderID) ? (int) $this->selectedJobOrderID : 0; ?>

<select name="jobOrderID" class="inputbox" style="width:300px;">
    <option value="0"<?php echo $selectedJobOrderID === 0 ? ' selected="selected"' : ''; ?>>
        Generic template<?php echo($this->hasGeneric ? '' : ' (not defined yet)'); ?>
    </option>
    <?php foreach ($this->jobOrdersRS as $jobOrderData): ?>
        <?php $joID = (int) $jobOrderData['jobOrderID']; ?>
        <option value="<?php echo $joID; ?>"<?php echo $selectedJobOrderID === $joID ? ' selected="selected"' : ''; ?>>
            <?php echo htmlspecialchars($jobOrderData['title'], ENT_QUOTES, 'UTF-8'); ?><?php
                if (!empty($jobOrderData['companyName']))
                {
                    echo ' (' . htmlspecialchars($jobOrderData['companyName'], ENT_QUOTES, 'UTF-8') . ')';
                }
            ?>
        </option>
    <?php endforeach; ?>
</select>

                <input type="submit" class="button" value="Load" />
            </form>
        </div>
        <?php endif; ?>

        <?php foreach ($this->stages as $stage): ?>
            <?php $instanceStageID = (int) $stage['instance_stage_id']; ?>

            <!-- Stage header. Icons sit to the LEFT of the name and stay
                 visible while the name is being edited, same as the settings
                 template editor. -->
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top:20px;">
                <tr>
                    <td class="subHeading">
                        <?php if (!$this->isLocked): ?>
                            <a href="javascript:void(0);"
                               onclick="if (confirm('Delete this stage?')) { document.getElementById('stageDelete_<?php echo $instanceStageID; ?>').submit(); }">
                                <img src="images/actions/delete.gif" border="0" alt="delete" />
                            </a>
                            <a href="javascript:void(0);" style="margin-left:4px;"
                               onclick="showStageEditor(<?php echo $instanceStageID; ?>);">
                                <img src="images/edit.gif" border="0" alt="edit" />
                            </a>&nbsp;<?php endif; ?><span id="stageDisplay_<?php echo $instanceStageID; ?>"><?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?></span>

                        <?php if (!$this->isLocked): ?>
                            <span id="stageNameEdit_<?php echo $instanceStageID; ?>" style="display:none;">
                                <input type="text" id="stageNameInput_<?php echo $instanceStageID; ?>"
                                       name="stageName" class="inputbox" style="width:140px;"
                                       form="criteriaForm_<?php echo $instanceStageID; ?>"
                                       value="<?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?>" />
                                <input type="submit" class="button" value="Save"
                                       form="criteriaForm_<?php echo $instanceStageID; ?>" />
                                <input type="button" class="button" value="Cancel"
                                       onclick="hideStageEditor(<?php echo $instanceStageID; ?>);" />
                            </span>
                        <?php endif; ?>
                    </td>
                </tr>
            </table>

            <?php if (!$this->isLocked): ?>
                <!-- Criteria/stage-name edits post here. The inputs live inside the
                     evaluator block's label cells and attach by form= id, since a
                     form can't be nested inside the evaluator block's own form. -->
                <form id="criteriaForm_<?php echo $instanceStageID; ?>" method="post"
                      action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand"
                      style="display:none;">
                    <input type="hidden" name="postback" value="postback" />
                    <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                    <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                    <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                    <?php echo $navJobOrderField; ?>
                    <input type="hidden" name="instanceStageID" value="<?php echo $instanceStageID; ?>" />
                    <input type="hidden" name="command" value="editStage" />
                </form>

                <!-- Outside the header so it isn't nested inside the rename form. -->
                <form id="stageDelete_<?php echo $instanceStageID; ?>" method="post"
                      action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand" style="display:none;">
                    <input type="hidden" name="postback" value="postback" />
                    <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                    <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                    <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                    <?php echo $navJobOrderField; ?>
                    <input type="hidden" name="instanceStageID" value="<?php echo $instanceStageID; ?>" />
                    <input type="hidden" name="command" value="deleteStage" />
                </form>
            <?php endif; ?>

            <div id="evaluatorsContainer_<?php echo $instanceStageID; ?>"></div>

            <script type="text/javascript">
                window.CATSStages[<?php echo $instanceStageID; ?>] = {
                    criteria: <?php echo json_encode(array_map(function ($c) {
                        return array(
                            'id'   => (int) $c['instance_criteria_id'],
                            'name' => $c['criteria_name'],
                            'type' => isset($c['data_type']) ? $c['data_type'] : 'text',
                        );
                    }, $stage['criteria'])); ?>
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
                        renderEvaluatorBlock(<?php echo $instanceStageID; ?>, ev.id, ev.name, ev.values);
                    });
                })();
            </script>

            <?php if (!$this->isLocked): ?>
                <div style="margin-top:12px;">
                    <input type="button" value="Add Evaluator" class="button"
                           onclick="renderEvaluatorBlock(<?php echo $instanceStageID; ?>, 0, '', {});" />
                </div>

                <!-- Add criteria closes out the stage, as the reveal-link pattern
                     from the settings editor. Unlike Add Evaluator this reloads,
                     because it changes what fields every evaluator block renders. -->
                <div id="addCriteriaLink_<?php echo $instanceStageID; ?>" style="margin-top:6px; margin-bottom:10px;">
                    <a href="javascript:void(0);"
                       onclick="showEdit('addCriteriaLink_<?php echo $instanceStageID; ?>', 'addCriteriaArea_<?php echo $instanceStageID; ?>', 'addCriteriaInput_<?php echo $instanceStageID; ?>');">
                        <img src="images/actions/add_small.gif" border="0" alt="add" />&nbsp;Add criteria
                    </a>
                </div>

                <div id="addCriteriaArea_<?php echo $instanceStageID; ?>" style="display:none; margin-top:6px; margin-bottom:10px;">
                    <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand" style="display:inline;">
                        <input type="hidden" name="postback" value="postback" />
                        <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                        <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                        <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                        <?php echo $navJobOrderField; ?>
                        <input type="hidden" name="instanceStageID" value="<?php echo $instanceStageID; ?>" />
                        <input type="hidden" name="command" value="addCriteria" />
                        <input type="text" id="addCriteriaInput_<?php echo $instanceStageID; ?>" name="criteriaName" class="inputbox" style="width:160px;" />
                        <select name="dataType" class="inputbox" style="width:90px;">
                            <option value="text">Text</option>
                            <option value="date">Date</option>
                            <option value="number">Number</option>
                        </select>
                        <input type="submit" class="button" value="Add Criteria" />
                        <input type="button" class="button" value="Cancel"
                               onclick="hideEdit('addCriteriaLink_<?php echo $instanceStageID; ?>', 'addCriteriaArea_<?php echo $instanceStageID; ?>');" />
                    </form>
                </div>
            <?php else: ?>
                <div style="margin-bottom:10px;"></div>
            <?php endif; ?>

        <?php endforeach; ?>


        <?php if (!$this->isLocked): ?>
            <!-- Add a stage. Same reveal-link pattern as Add criteria, and like a
                 template stage it arrives with Rating and Comments already on it.
                 On a draft page this is the other way an evaluation gets created,
                 for building one by hand without a template. -->
            <div id="addStageLink" style="margin-top:24px;">
                <a href="javascript:void(0);"
                   onclick="showEdit('addStageLink', 'addStageArea', 'addStageInput');">
                    <img src="images/actions/add_small.gif" border="0" alt="add" />&nbsp;Add interview stage
                </a>
            </div>

            <div id="addStageArea" style="display:none; margin-top:24px;">
                <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=evaluationCommand" style="display:inline;">
                    <input type="hidden" name="postback" value="postback" />
                    <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
                    <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
                    <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />
                    <?php echo $navJobOrderField; ?>
                    <input type="hidden" name="command" value="addStage" />
                    <input type="text" id="addStageInput" name="stageName" class="inputbox" style="width:220px;" />
                    <input type="submit" class="button" value="Add Stage" />
                    <input type="button" class="button" value="Cancel"
                           onclick="hideEdit('addStageLink', 'addStageArea');" />
                </form>
            </div>
        <?php endif; ?>

        <br clear="all" />

        <a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=candidates&a=show&candidateID=' . $this->candidateID); ?>">
            &laquo; Back to Candidate
        </a>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>