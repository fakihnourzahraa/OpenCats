<?php /* modules/candidates/Evaluate.tpl  IBC */ ?>

<?php TemplateUtility::printHeader('Evaluate - ' . $this->candidateName, array('js/lib.js')); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>

<script type="text/javascript">
    var CSRF_Token = <?php echo json_encode($_SESSION['CATS']->getCSRFToken()); ?>;
    var CATS_IndexName = <?php echo json_encode(CATSUtility::getIndexName()); ?>;
    var CATS_CandidateID = <?php echo (int) $this->candidateID; ?>;
    var CATS_InstanceID = <?php echo (int) $this->instanceID; ?>;

    var CATS_IsLocked = <?php echo $this->isLocked ? 'true' : 'false'; ?>;

    var CATS_NavJobOrderID = <?php echo $this->navJobOrderID === null ? "''" : (int) $this->navJobOrderID; ?>;

    window.evalNavGo = function (candidateID, jobOrderID) {
        window.location = CATS_IndexName + '?m=candidates&a=evaluate'
            + '&candidateID=' + encodeURIComponent(candidateID)
            + '&navJobOrderID=' + encodeURIComponent(jobOrderID);
    };

    window.evalNavJobOrderChanged = function () {
        var jo = document.getElementById('navJobOrder').value;
        if (jo === '') { return; }
        evalNavGo(CATS_CandidateID, jo);
    };

    window.evalNavCandidateChanged = function () {
        var sel = document.getElementById('navCandidate');
        if (!sel || sel.value === '') { return; }
        evalNavGo(sel.value, document.getElementById('navJobOrder').value);
    };

    (function () {
        var timer = null;

        window.evalNavSearch = function (q) {
            var box = document.getElementById('navCandidateResults');
            if (!box) { return; }
            if (timer) { clearTimeout(timer); }

            if (q.trim().length < 2) {
                box.style.display = 'none';
                return;
            }

            timer = setTimeout(function () {
                fetch(CATS_IndexName + '?m=candidates&a=evaluationCandidateSearch'
                        + '&navJobOrderID=0&q=' + encodeURIComponent(q),
                      { credentials: 'same-origin' })
                    .then(function (r) { return r.json(); })
                    .then(function (data) {
                        box.innerHTML = '';
                        if (!data.results || !data.results.length) {
                            box.style.display = 'none';
                            return;
                        }
                        data.results.forEach(function (row) {
                            var a = document.createElement('a');
                            a.href = '#';
                            a.style.display = 'block';
                            a.style.padding = '2px 4px';
                            a.textContent = (row.filed ? '* ' : '') + row.name;
                            a.onclick = function (e) {
                                e.preventDefault();
                                evalNavGo(row.id, 0);
                            };
                            box.appendChild(a);
                        });
                        box.style.display = '';
                    })
                    .catch(function () { box.style.display = 'none'; });
            }, 250);
        };
    })();

    window.CATSStages = window.CATSStages || {};
    window.evaluatorBlocks = window.evaluatorBlocks || [];

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

    window.showStageEditor = function (instanceStageID) {
        var stage = window.CATSStages[instanceStageID];

        if (!stage.editorBound) {
            renderEvaluatorBlock(instanceStageID, 0, '', {}, {});
        }

        stage.labelDisplays.forEach(function (el) { el.style.display = 'none'; });
        stage.labelEdits.forEach(function (el) { el.style.display = ''; });

        document.getElementById('stageDisplay_' + instanceStageID).style.display = 'none';
        document.getElementById('stageNameEdit_' + instanceStageID).style.display = '';

        var wDisplay = document.getElementById('stageWeightDisplay_' + instanceStageID);
        var wEdit    = document.getElementById('stageWeightEdit_' + instanceStageID);
        if (wDisplay) { wDisplay.style.display = 'none'; }
        if (wEdit)    { wEdit.style.display    = '';     }

        document.getElementById('stageNameInput_' + instanceStageID).focus();
    };

    window.hideStageEditor = function (instanceStageID) {
        var stage = window.CATSStages[instanceStageID];

        stage.labelDisplays.forEach(function (el) { el.style.display = ''; });
        stage.labelEdits.forEach(function (el) { el.style.display = 'none'; });

        document.getElementById('stageNameEdit_' + instanceStageID).style.display = 'none';
        document.getElementById('stageDisplay_' + instanceStageID).style.display = '';

        var wDisplay = document.getElementById('stageWeightDisplay_' + instanceStageID);
        var wEdit    = document.getElementById('stageWeightEdit_' + instanceStageID);
        if (wEdit)    { wEdit.style.display    = 'none'; }
        if (wDisplay) { wDisplay.style.display = '';     }
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

            var lastGood = results.filter(function (r) { return r && r.success; }).pop();
            if (lastGood) { window.updateScoreDisplay(lastGood); }
        });
    };

    /* Percent renders first, raw score second - the HTML markup below
       already puts scorePercentDisplay before scoreDisplay, so this just
       needs to keep writing the same two elements by ID; no reordering
       logic needed here. */
    window.updateScoreDisplay = function (data) {
        var scoreEl = document.getElementById('scoreDisplay');
        var pctEl   = document.getElementById('scorePercentDisplay');
        if (pctEl && data && typeof data.scorePercent !== 'undefined') {
            pctEl.textContent = data.scorePercent;
        }
        if (scoreEl && data && typeof data.scoreDisplay !== 'undefined') {
            scoreEl.textContent = data.scoreDisplay;
        }
    };

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

    /* evaluatorID 0 means not saved yet */
    (function () {
        var uniqueCount = 0;

        window.renderEvaluatorBlock = function (instanceStageID, evaluatorID, evaluatorName, values, grades) {
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
            grades = grades || {};

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
            /* Maps instance_criteria_id -> the ANSWER field (not the grade
               input), so a post-save empty-field warning from the server can
               find and highlight the right element without re-walking the
               DOM. */
            var fieldByCriteriaID = {};

            stage.criteria.forEach(function (criterion) {
                var type = criterion.type || 'text';
                var field = null;
                var gradeInput = null;
                var fieldWrap;

                if (type === 'score') {
                    /* Score criteria carry ONLY the grade - there is no
                       separate free-text answer field anymore, since a
                       single numeric input is all this type needs. */
                    var maxRange = (criterion.maxRange !== undefined && criterion.maxRange !== null && criterion.maxRange > 0)
                        ? criterion.maxRange : 5;

                    gradeInput = document.createElement('input');
                    gradeInput.type = 'number';
                    gradeInput.name = 'grades[' + criterion.id + ']';
                    gradeInput.className = 'inputbox';
                    gradeInput.style.width = '80px';
                    gradeInput.min = '0';
                    gradeInput.max = String(maxRange);
                    gradeInput.step = '0.01';
                    gradeInput.placeholder = '0-' + maxRange;

                    var gv = grades[criterion.id];
                    gradeInput.value = (gv !== undefined && gv !== null && gv !== '') ? gv : '';

                    fieldWrap = gradeInput;
                    fieldByCriteriaID[criterion.id] = gradeInput;
                } else {
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

                    fieldByCriteriaID[criterion.id] = field;
                    fieldWrap = field;
                }

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

                    var typeLabelSpan = document.createElement('span');
                    typeLabelSpan.className = 'fieldLabelInline';
                    typeLabelSpan.style.marginLeft = '0';
                    typeLabelSpan.textContent = 'Type:';
                    labelEdit.appendChild(typeLabelSpan);

                    var critTypeSelect = document.createElement('select');
                    critTypeSelect.name = 'criteriaType[' + criterion.id + ']';
                    critTypeSelect.className = 'inputbox';
                    critTypeSelect.style.width = '75px';
                    critTypeSelect.setAttribute('form', criteriaFormID);

                    var typeLabels = { text: 'Text', date: 'Date', number: 'Number', score: 'Score' };
                    ['text', 'date', 'number', 'score'].forEach(function (t) {
                        var opt = document.createElement('option');
                        opt.value = t;
                        opt.textContent = typeLabels[t];
                        if ((criterion.type || 'text') === t) { opt.selected = true; }
                        critTypeSelect.appendChild(opt);
                    });
                    labelEdit.appendChild(critTypeSelect);

                    /* Weight and max range are both meaningless outside
                       'score' - wrapped together so they appear/disappear as
                       one unit with the type dropdown, instead of a bare
                       unlabeled weight box sitting there on every type. */
                    var critScoreWrap = document.createElement('span');
                    critScoreWrap.style.display = ((criterion.type || 'text') === 'score') ? '' : 'none';

                    var weightLabelSpan = document.createElement('span');
                    weightLabelSpan.className = 'fieldLabelInline';
                    weightLabelSpan.textContent = 'Weight:';
                    critScoreWrap.appendChild(weightLabelSpan);

                    var critWeightInput = document.createElement('input');
                    critWeightInput.type = 'text';
                    critWeightInput.name = 'criteriaWeight[' + criterion.id + ']';
                    critWeightInput.className = 'inputbox weightBox';
                    critWeightInput.title = 'Weight';
                    critWeightInput.value = String(criterion.weight || 0);
                    critWeightInput.setAttribute('form', criteriaFormID);
                    critScoreWrap.appendChild(critWeightInput);

                    var maxLabelSpan = document.createElement('span');
                    maxLabelSpan.className = 'fieldLabelInline';
                    maxLabelSpan.textContent = 'Max:';
                    critScoreWrap.appendChild(maxLabelSpan);

                    var critMaxRangeInput = document.createElement('input');
                    critMaxRangeInput.type = 'text';
                    critMaxRangeInput.name = 'criteriaMaxRange[' + criterion.id + ']';
                    critMaxRangeInput.className = 'inputbox weightBox';
                    critMaxRangeInput.title = 'Max range (grade runs 0..this)';
                    critMaxRangeInput.value = String(
                        (criterion.maxRange !== undefined && criterion.maxRange !== null) ? criterion.maxRange : 5
                    );
                    critMaxRangeInput.setAttribute('form', criteriaFormID);
                    critScoreWrap.appendChild(critMaxRangeInput);

                    labelEdit.appendChild(critScoreWrap);

                    critTypeSelect.onchange = function () {
                        critScoreWrap.style.display = (critTypeSelect.value === 'score') ? '' : 'none';
                    };

                    /* Share is computed once, server-side, the same way the
                       settings page computes it - not recalculated live here,
                       since weight editing on this page is occasional rather
                       than something worth live JS feedback for. */
                    var critShareSpan = document.createElement('span');
                    critShareSpan.className = 'shareNote';
                    critShareSpan.textContent = (criterion.type === 'score' && criterion.sharePercent !== null && criterion.sharePercent !== undefined)
                        ? (criterion.sharePercent + '%') : '';
                    labelEdit.appendChild(critShareSpan);

                    labelWrap.appendChild(labelEdit);

                    stage.labelDisplays.push(labelDisplay);
                    stage.labelEdits.push(labelEdit);
                }

                addFieldRow(labelWrap, fieldWrap);
                if (field) { fields.push(field); }
                if (gradeInput) { fields.push(gradeInput); }
            });

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
                /* readOnly has no effect on <select> - kept for any future
                   select-type field; every current field type honours
                   readOnly directly. */
                if (el.tagName === 'SELECT') {
                    el.disabled = !isEditable;
                } else {
                    el.readOnly = !isEditable;
                }
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

                        /* Simple, non-blocking warning: highlight whichever
                           answer fields the server saw as blank on this
                           save. Clears any stale marks first so a field that
                           got filled in stops being flagged. */
                        Object.keys(fieldByCriteriaID).forEach(function (cid) {
                            fieldByCriteriaID[cid].classList.remove('warningField');
                        });
                        if (data.emptyFields && data.emptyFields.length) {
                            console.warn(
                                'Evaluator "' + nameInput.value + '" saved with empty fields for criteria IDs:',
                                data.emptyFields
                            );
                            data.emptyFields.forEach(function (cid) {
                                var f = fieldByCriteriaID[cid];
                                if (f) {
                                    f.classList.add('warningField');
                                    f.title = 'This field is empty.';
                                }
                            });
                        }
                    } else if (data.locked) {
                        /* Locked after this page was opened. */
                        saveBtn.value = 'Locked';
                        alert('This evaluation has been locked and can no longer be edited.');
                        setEditable(false);
                    } else {
                        saveBtn.value = 'Save (failed, try again)';
                    }
                    if (data.success) {
                        window.updateScoreDisplay(data);

                        if (data.stageScores && data.stageScores[instanceStageID]) {
                            var stagePctEl   = document.getElementById('stageScorePercentDisplay_' + instanceStageID);
                            var stageScoreEl = document.getElementById('stageScoreDisplay_' + instanceStageID);
                            if (stagePctEl)   { stagePctEl.textContent   = data.stageScores[instanceStageID].scorePercent; }
                            if (stageScoreEl) { stageScoreEl.textContent = data.stageScores[instanceStageID].scoreDisplay; }
                        }
                    }
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
                isSaved: function () { return Number(evaluatorIDInput.value) > 0; }
            });

            container.appendChild(outer);
            container.appendChild(deleteForm);

            return outer;
        };
    })();
</script>

<?php

    $navJobOrderField = '<input type="hidden" name="navJobOrderID" value="'
        . ($this->navJobOrderID === null ? '' : (int) $this->navJobOrderID)
        . '" />';

    function evalWeight($value)
    {
        return rtrim(rtrim(number_format((float) $value, 2, '.', ''), '0'), '.') ?: '0';
    }
?>

<style type="text/css">
    .shareNote { color:#777; font-size:11px; margin-left:6px; white-space:nowrap; }
    .weightBox { width:46px; text-align:right; }
    /* "Stage:" / "Criteria" labels - quiet, small, sit above/beside the
       actual content rather than competing with it. */
    .sectionLabel { color:#555; font-weight:normal; font-size:13px; margin-right:4px; }
    .fieldLabelInline { color:#888; font-size:11px; margin:0 4px 0 8px; }
    .criteriaSectionHeader {
        margin-top:10px; margin-bottom:4px; font-weight:bold; font-size:11px;
        color:#666; text-transform:uppercase; letter-spacing:0.5px;
        border-bottom:1px solid #ddd; padding-bottom:2px;
    }
    /* Simple, non-blocking flag for a field the server saw as blank on the
       last save - not a hard validation error, just a visual nudge. */
    .warningField { border:1px solid #cc0000 !important; background:#fff5f5 !important; }
</style>

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
 <div class="sectionLabel" style="margin-bottom:2px;">Candidate View:</div>
        <!-- Navigation. Job order on top, its candidates below. This only MOVES
             between evaluations - it writes nothing, and is unrelated to the
             "Load stages from" line further down, which seeds structure. -->
        <?php
            $navJobOrderID = $this->navJobOrderID;              /* null = unfiled */
            $navSelected   = ($navJobOrderID === null) ? '' : (string) $navJobOrderID;
        ?>
        <div style="margin-bottom:14px;">
            <select id="navJobOrder" class="inputbox" style="width:340px;"
                    onchange="evalNavJobOrderChanged();">
                <option value="0"<?php echo $navSelected === '0' ? ' selected="selected"' : ''; ?>>Generic</option>
                <?php foreach ($this->jobOrdersRS as $jobOrderData): ?>
                    <?php $joID = (int) $jobOrderData['jobOrderID']; ?>
                    <option value="<?php echo $joID; ?>"<?php echo $navSelected === (string) $joID ? ' selected="selected"' : ''; ?>>
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
               
                <?php if ($navJobOrderID === null): ?>
                    <select class="inputbox" style="width:340px;" disabled="disabled">
                        <option><?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?></option>
                    </select>
                <?php elseif ($navJobOrderID > 0): ?>
                    <select id="navCandidate" class="inputbox" style="width:340px;"
                            onchange="evalNavCandidateChanged();">
                        <?php if (!$this->navCandidateHere): ?>
                            <option value="<?php echo (int) $this->candidateID; ?>" selected="selected">
                                <?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?> (not in joborder)
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
                <?php else: ?>
                    <input type="text" id="navCandidateSearch" class="inputbox" style="width:340px;"
                           autocomplete="off" placeholder="Type a candidate name"
                           value="<?php echo htmlspecialchars($this->candidateName, ENT_QUOTES, 'UTF-8'); ?>"
                           onkeyup="evalNavSearch(this.value);" />
                    <div id="navCandidateResults" class="ajaxSearchResults"
                         style="display:none; width:340px; max-height:220px; overflow:auto; text-align:left;"></div>
                <?php endif; ?>
            </div>
        </div>

        <?php if ($this->isLocked): ?>
            <div class="warning" style="margin-bottom:10px;">
                <img src="images/key.png" width="16" height="16" border="0" class="absmiddle" alt="" />&nbsp;This
                evaluation is locked. It is read-only and cannot be unlocked.
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
    <!-- Percent leads, raw score follows in parens - "78% (3.90/5)". The /5
         is a fixed display scale (see EvaluationScore::REPORT_SCALE), not
         any one criterion's own max_range, so it's safe to write literally
         here rather than pass another value through just for this. -->
    <br /><span id="scorePercentDisplay"><?php echo htmlspecialchars($this->scorePercent, ENT_QUOTES, 'UTF-8'); ?></span>
    <span style="color:#777;">(<span id="scoreDisplay"><?php echo htmlspecialchars($this->scoreDisplay, ENT_QUOTES, 'UTF-8'); ?></span>/5)</span>
    <?php if (!$this->isLocked): ?>
        <br /><input type="button" id="saveAllButton" value="Save All" class="button" style="margin-top:6px;"
                     onclick="saveAllEvaluators();" />
    <?php endif; ?>
    <br /><a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName()
        . '?m=candidates&a=evaluationExport&candidateID=' . $this->candidateID
        . '&instanceID=' . $this->instanceID); ?>"
       style="margin-top:6px; display:inline-block;">
        Export to CSV
    </a>
<?php endif; ?>
                </td>
            </tr>
        </table>

        <!-- Seed from a job order's template.
             COPIES stages/criteria in, merging by name: existing names are left
             alone and only what's missing gets added. It also FILES the
             evaluation under the job order picked here, replacing whatever it
             was filed under before - which is what the navigation dropdowns
             above read. On a draft page this is what creates the evaluation.

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
                 template editor. A small "Stage:" label sits before the name
                 so this section reads as a labelled block rather than a bare
                 heading, matching the template editor's layout. -->
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
                            </a>&nbsp;<?php endif; ?><span class="sectionLabel">Stage:</span> <span id="stageDisplay_<?php echo $instanceStageID; ?>"><?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?></span>

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

                        <?php $stageScoreVal = (isset($stage['scoring']) && array_key_exists('score', $stage['scoring'])) ? $stage['scoring']['score'] : null; ?>
                        <div style="margin-top:4px; font-weight:normal; font-size:11px; color:#666;">
                            Score:
                            <span id="stageScorePercentDisplay_<?php echo $instanceStageID; ?>"><?php echo htmlspecialchars(EvaluationScore::formatPercent($stageScoreVal), ENT_QUOTES, 'UTF-8'); ?></span>
                            <span style="color:#999;">(<span id="stageScoreDisplay_<?php echo $instanceStageID; ?>"><?php echo htmlspecialchars(EvaluationScore::format($stageScoreVal), ENT_QUOTES, 'UTF-8'); ?></span>/5)</span>
                        </div>

                        <div style="margin-top:2px; font-weight:normal; font-size:11px; color:#666;">
                            Weight:
                            <span id="stageWeightDisplay_<?php echo $instanceStageID; ?>"><?php echo evalWeight(isset($stage['weight']) ? $stage['weight'] : 0); ?></span>
                            <?php if (!$this->isLocked): ?>
                                <span id="stageWeightEdit_<?php echo $instanceStageID; ?>" style="display:none;">
                                    <input type="text" class="inputbox weightBox"
                                           id="stageWeightInput_<?php echo $instanceStageID; ?>"
                                           name="stageWeight"
                                           form="criteriaForm_<?php echo $instanceStageID; ?>"
                                           value="<?php echo evalWeight(isset($stage['weight']) ? $stage['weight'] : 0); ?>" />
                                </span>
                            <?php endif; ?>
                            <span class="shareNote"><?php echo isset($stage['sharePercent']) ? $stage['sharePercent'] . '%' : ''; ?></span>
                        </div>
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
                    weight: <?php echo json_encode(isset($stage['weight']) ? (float) $stage['weight'] : 0); ?>,
                    sharePercent: <?php echo json_encode(isset($stage['sharePercent']) ? $stage['sharePercent'] : null); ?>,
                    criteria: <?php echo json_encode(array_map(function ($c) {
                        return array(
                            'id'           => (int) $c['instance_criteria_id'],
                            'name'         => $c['criteria_name'],
                            'type'         => isset($c['data_type']) ? $c['data_type'] : 'text',
                            'weight'       => isset($c['weight']) ? (float) $c['weight'] : 0,
                            'maxRange'     => isset($c['max_range']) ? (float) $c['max_range'] : 5,
                            'sharePercent' => isset($c['sharePercent']) ? $c['sharePercent'] : null,
                        );
                    }, $stage['criteria'])); ?>
                };

                (function () {
                    var evaluators = <?php echo json_encode(array_map(function ($e) {
                        return array(
                            'id'     => (int) $e['evaluator_id'],
                            'name'   => $e['evaluator_name'],
                            'values' => (object) (isset($e['values']) ? $e['values'] : array()),
                            'grades' => (object) (isset($e['grades']) ? $e['grades'] : array()),
                        );
                    }, $stage['evaluators'])); ?>;

                    evaluators.forEach(function (ev) {
                        renderEvaluatorBlock(<?php echo $instanceStageID; ?>, ev.id, ev.name, ev.values, ev.grades);
                    });
                })();
            </script>

            <?php if (!$this->isLocked): ?>
                <div style="margin-top:12px;">
                    <input type="button" value="Add Evaluator" class="button"
                           onclick="renderEvaluatorBlock(<?php echo $instanceStageID; ?>, 0, '', {}, {});" />
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
                        <span class="fieldLabelInline">Type:</span>
                        <select name="dataType" id="addCriteriaType_<?php echo $instanceStageID; ?>" class="inputbox" style="width:90px;"
                                onchange="document.getElementById('addCriteriaScoreWrap_<?php echo $instanceStageID; ?>').style.display = (this.value === 'score') ? '' : 'none';">
                            <option value="text">Text</option>
                            <option value="date">Date</option>
                            <option value="number">Number</option>
                            <option value="score">Score</option>
                        </select>
                        <span id="addCriteriaScoreWrap_<?php echo $instanceStageID; ?>" style="display:none;">
                            <span class="fieldLabelInline">Weight:</span>
                            <input type="text" name="weight" class="inputbox weightBox" value="0" title="Weight" />
                            <span class="fieldLabelInline">Max:</span>
                            <input id="addCriteriaMaxRange_<?php echo $instanceStageID; ?>" type="text" name="maxRange"
                                   class="inputbox weightBox" value="5" title="Max range (grade runs 0..this)" />
                        </span>
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