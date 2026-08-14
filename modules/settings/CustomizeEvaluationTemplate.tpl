<?php /* $Id: CustomizeEvaluationTemplate.tpl 1535 2007-01-22 17:55:29Z will $ */ ?>
<?php TemplateUtility::printHeader('Settings', array()); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active, $this->subActive); ?>
<div id="main">
<?php
$jobOrdersRS           = !empty($this->jobOrdersRS)           ? $this->jobOrdersRS           : array();
$evaluationTemplatesRS = !empty($this->evaluationTemplatesRS) ? $this->evaluationTemplatesRS : array();
$allTemplates = array_merge(
    array(array('jobOrderID' => 0, 'title' => 'Generic Template', 'companyName' => '')),
    $jobOrdersRS
);
$selectedJobOrderID = isset($_GET['jobOrderID']) ? (int) $_GET['jobOrderID'] : 0;

/* Weight is stored as DECIMAL(6,2). Trailing zeros in the editor read as
   noise, so 100.00 shows as 100 and 12.50 as 12.5. Score max uses the same
   DECIMAL(6,2) column and the same trimming. */
function evalTplWeight($value)
{
    return rtrim(rtrim(number_format((float) $value, 2, '.', ''), '0'), '.') ?: '0';
}

/* A criterion is only "gradeable" - only carries weight, only enters the
   stage's weight share - when its type is Score. There is no separate
   checkbox anymore; the type IS the switch. */
function evalTplIsScore($criterion)
{
    return isset($criterion['data_type']) && $criterion['data_type'] === 'score';
}

define('EVAL_TPL_DEFAULT_SCORE_MAX', 5);
?>
    <?php TemplateUtility::printQuickSearch(); ?>

    <div id="contents">

        <style type="text/css">
            .shareNote { color:#777; font-size:11px; margin-left:4px; white-space:nowrap; }
            .shareNote.inactive { color:#bbb; }
            .weightBox { width:46px; text-align:right; }
            .scoreMaxBox { width:46px; text-align:right; }
        </style>

        <table>
            <tr>
                <td width="3%">
                    <img src="images/settings.gif" width="24" height="24" border="0" alt="Settings" style="margin-top: 3px;" />&nbsp;
                </td>
                <td><h2>Settings: Evaluation Templates</h2></td>
            </tr>
        </table>

        <p class="note">Customize Evaluation Templates</p>

        <form name="evalTemplateForm" id="evalTemplateForm"
              action="<?php echo(CATSUtility::getIndexName()); ?>?m=settings&amp;a=customizeEvaluationTemplate"
              method="post">
            <input type="hidden" name="postback" value="postback" />
            <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
            <input type="hidden" name="jobOrderID" id="jobOrderID" value="0" />
            <input type="hidden" name="commandList" id="commandList" value="" />
            <input type="hidden" name="resetToGeneric" id="resetToGeneric" value="0" />

            <script type="text/javascript">
                var ALL_TEMPLATE_IDS = [0<?php foreach ($jobOrdersRS as $jo): ?>, <?php echo (int) $jo['jobOrderID']; ?><?php endforeach; ?>];

                var commandLists = {};
                ALL_TEMPLATE_IDS.forEach(function (id) { commandLists[id] = ''; });

                function appendCommand(joID, cmd) {
                    commandLists[joID] = commandLists[joID] + encodeURIComponent(cmd) + ',';
                }

                function showTemplate(jobOrderID) {
                    for (var i = 0; i < ALL_TEMPLATE_IDS.length; i++) {
                        var el = document.getElementById('templateArea_' + ALL_TEMPLATE_IDS[i]);
                        if (el) el.style.display = 'none';
                    }
                    var target = document.getElementById('templateArea_' + jobOrderID);
                    if (target) target.style.display = '';
                }

                function submitTemplate(joID) {
                    var commandList = commandLists[joID];
                    if (!commandList) {
                        alert('Nothing to save.');
                        return;
                    }
                    document.getElementById('jobOrderID').value  = joID;
                    document.getElementById('commandList').value = commandList;
                    document.getElementById('evalTemplateForm').submit();
                }

                function resetToGenericTemplate(joID) {
                    if (!confirm('Reset this job order\'s evaluation template to the generic template? All stage and criteria customizations for this job order will be permanently deleted.')) {
                        return;
                    }
                    document.getElementById('jobOrderID').value      = joID;
                    document.getElementById('commandList').value     = '';
                    document.getElementById('resetToGeneric').value  = '1';
                    document.getElementById('evalTemplateForm').submit();
                }

                /* ---------- Row-reorder helpers (skip hidden/deleted rows) ---------- */

                function getVisiblePrevRow(row) {
                    var prev = row.previousElementSibling;
                    while (prev && prev.style.display === 'none') { prev = prev.previousElementSibling; }
                    return prev;
                }
                function getVisibleNextRow(row) {
                    var next = row.nextElementSibling;
                    while (next && next.style.display === 'none') { next = next.nextElementSibling; }
                    return next;
                }

                /* ---------- Weights ----------
                   A weight is meaningless on its own; what the user needs to see
                   is its SHARE. These recompute that share live, so an
                   unbalanced set is visible while it's being typed rather than
                   after saving.

                   Only Score-type criteria carry weight. Typing a Score
                   criterion is what makes it gradeable now - there's no
                   separate flag - so a row only enters this arithmetic when
                   its type is 'score'.

                   Deleted rows are hidden, not removed, so anything hidden is
                   excluded here too - otherwise a deleted criterion would keep
                   diluting the shares of the ones that remain. */

                function parseWeight(raw) {
                    var w = parseFloat(raw);
                    if (isNaN(w) || w < 0) { return 0; }
                    return w;
                }

                function isRowVisible(id) {
                    var row = document.getElementById(id);
                    return !!row && row.style.display !== 'none';
                }

                function renderShare(spanID, weight, total) {
                    var span = document.getElementById(spanID);
                    if (!span) { return; }

                    if (total <= 0) {
                        /* Nothing weighted yet: the engine falls back to equal
                           shares rather than dividing by zero, so say so. */
                        span.className   = 'shareNote inactive';
                        span.textContent = '(equal)';
                        return;
                    }

                    span.className   = 'shareNote';
                    span.textContent = Math.round((weight / total) * 100) + '%';
                }

                window.onload = function () {
                    showTemplate(<?php echo $selectedJobOrderID; ?>);
                    if (window.recalcAllShares) { window.recalcAllShares(); }
                };
            </script>

            <table style="width:850px;" class="searchTable">

                <!-- Row 1: Job order selector -->
                <tr>
                    <td>
                        <table>
                            <tr>
                                <td style="width:210px;">
                                    <div style="font-weight:bold;">Job Order:</div>
                                </td>
                                <td>
                                    <select id="jobOrderSelect" style="width:550px;"
                                            onchange="showTemplate(this.value);">
                                        <?php foreach ($allTemplates as $joEntry): ?>
                                            <option value="<?php echo (int) $joEntry['jobOrderID']; ?>"
                                                <?php echo ((int) $joEntry['jobOrderID'] === $selectedJobOrderID) ? 'selected="selected"' : ''; ?>>
                                                <?php echo htmlspecialchars($joEntry['title'], ENT_QUOTES, 'UTF-8'); ?>

                                            </option>
                                        <?php endforeach; ?>
                                    </select>

                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- Row 2: template editing areas -->
                <tr>
                    <td>

                        <?php
                        $shareRecalcCalls = array();
                        foreach ($allTemplates as $joEntry):
                            $joID           = (int) $joEntry['jobOrderID'];
                            $isGeneric      = ($joID === 0);
                            $hasTpl         = isset($evaluationTemplatesRS[$joID]);
                            $existingStages = ($hasTpl && !empty($evaluationTemplatesRS[$joID]['stages']))
                                                ? $evaluationTemplatesRS[$joID]['stages']
                                                : array();
                            $stageStartCount = count($existingStages);
                            $shareRecalcCalls[] = 'recalcAllShares_' . $joID . '()';
                        ?>

                        <script type="text/javascript">
                            var stageCount_<?php echo $joID; ?> = <?php echo $stageStartCount; ?>;

                            <?php foreach ($existingStages as $stageIdx => $stage): ?>
                            window[<?php echo json_encode('stageName_' . $joID . '_' . $stageIdx); ?>] = <?php echo json_encode($stage['stage_name']); ?>;
                            window[<?php echo json_encode('stageWeight_' . $joID . '_' . $stageIdx); ?>] = <?php echo json_encode(evalTplWeight(isset($stage['weight']) ? $stage['weight'] : 0)); ?>;
                            window[<?php echo json_encode('criteriaCount_' . $joID . '_' . $stageIdx); ?>] = <?php echo count($stage['criteria']); ?>;
                            <?php foreach ($stage['criteria'] as $criteriaIdx => $criterion): ?>
                            window[<?php echo json_encode('criteriaName_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode($criterion['criteria_name']); ?>;
                            window[<?php echo json_encode('criteriaType_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode(isset($criterion['data_type']) ? $criterion['data_type'] : 'text'); ?>;
                            window[<?php echo json_encode('criteriaWeight_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode(evalTplWeight(isset($criterion['weight']) ? $criterion['weight'] : 0)); ?>;
                            window[<?php echo json_encode('criteriaScoreMax_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode(evalTplWeight(isset($criterion['score_max']) && $criterion['score_max'] !== null ? $criterion['score_max'] : EVAL_TPL_DEFAULT_SCORE_MAX)); ?>;
                            <?php endforeach; ?>
                            <?php endforeach; ?>

                            /* ---------- Share recalculation for this template ---------- */

                            function recalcCriteriaShares_<?php echo $joID; ?>(stageIdx) {
                                var count = window['criteriaCount_<?php echo $joID; ?>_' + stageIdx] || 0;
                                var total = 0;
                                var i;

                                /* Only Score-type criteria carry weight now - the
                                   type itself is what makes a row gradeable, so a
                                   text/date/number row is never part of this
                                   arithmetic even if it happens to have a weight
                                   value left over from before it was retyped. */
                                for (i = 0; i < count; i++) {
                                    var key = stageIdx + '_' + i;
                                    if (!isRowVisible('criteriaRow_<?php echo $joID; ?>_' + key)) { continue; }
                                    if (window['criteriaType_<?php echo $joID; ?>_' + key] !== 'score') { continue; }

                                    var box = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key);
                                    if (box) { total += parseWeight(box.value); }
                                }

                                for (i = 0; i < count; i++) {
                                    var key2 = stageIdx + '_' + i;
                                    var span = document.getElementById('criteriaShare_<?php echo $joID; ?>_' + key2);
                                    if (!span) { continue; }

                                    if (window['criteriaType_<?php echo $joID; ?>_' + key2] !== 'score') {
                                        /* Not part of the arithmetic - nothing to show. */
                                        span.className   = 'shareNote';
                                        span.textContent = '';
                                        continue;
                                    }

                                    var box2 = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key2);
                                    renderShare('criteriaShare_<?php echo $joID; ?>_' + key2,
                                                box2 ? parseWeight(box2.value) : 0, total);
                                }
                            }

                            function recalcStageShares_<?php echo $joID; ?>() {
                                var total = 0;
                                var i;

                                for (i = 0; i < stageCount_<?php echo $joID; ?>; i++) {
                                    if (!isRowVisible('stageRow_<?php echo $joID; ?>_' + i)) { continue; }
                                    var box = document.getElementById('stageWeightInput_<?php echo $joID; ?>_' + i);
                                    if (box) { total += parseWeight(box.value); }
                                }

                                for (i = 0; i < stageCount_<?php echo $joID; ?>; i++) {
                                    var box2 = document.getElementById('stageWeightInput_<?php echo $joID; ?>_' + i);
                                    renderShare('stageShare_<?php echo $joID; ?>_' + i,
                                                box2 ? parseWeight(box2.value) : 0, total);
                                }
                            }

                            function recalcAllShares_<?php echo $joID; ?>() {
                                recalcStageShares_<?php echo $joID; ?>();
                                for (var i = 0; i < stageCount_<?php echo $joID; ?>; i++) {
                                    recalcCriteriaShares_<?php echo $joID; ?>(i);
                                }
                            }

                            /* Weight/max boxes are hidden until the row's pencil is
                               clicked, but they stay in the DOM the whole time -
                               the share recalculation above reads their .value
                               whether or not they are visible. That is what lets
                               a cancel restore cleanly: put the stored value back
                               in the box and the shares snap back with it. */

                            function showWeightEditor(displayID, editID) {
                                var display = document.getElementById(displayID);
                                var edit    = document.getElementById(editID);
                                if (display) { display.style.display = 'none'; }
                                if (edit)    { edit.style.display    = '';     }
                            }

                            function hideWeightEditor(displayID, editID) {
                                var display = document.getElementById(displayID);
                                var edit    = document.getElementById(editID);
                                if (edit)    { edit.style.display    = 'none'; }
                                if (display) { display.style.display = '';     }
                            }

                            /* The criteria TYPE is what makes weight/max mean
                               anything now - only Score criteria use them.
                               Shared by every place a criteria row gets built
                               and by the edit/cancel/save handlers below, so
                               this rule lives in one place. */
                            function onCriteriaTypeChange_<?php echo $joID; ?>(select, key) {
                                var isScore = (select.value === 'score');

                                var wBox = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key);
                                if (wBox) { wBox.disabled = !isScore; }

                                var mBox = document.getElementById('criteriaScoreMaxInput_<?php echo $joID; ?>_' + key);
                                if (mBox) {
                                    mBox.disabled = !isScore;
                                    if (isScore && (!mBox.value || parseFloat(mBox.value) <= 0)) {
                                        mBox.value = '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>';
                                    }
                                }

                                var stageIdx = key.split('_')[0];
                                recalcCriteriaShares_<?php echo $joID; ?>(stageIdx);
                            }

                            /* Same toggle, for the "add criteria" row before it has
                               been committed - there's no key yet, just the
                               stage's add-form inputs. */
                            function onAddCriteriaTypeChange_<?php echo $joID; ?>(stageIdx) {
                                var typeSel = document.getElementById('addCriteriaType_<?php echo $joID; ?>_' + stageIdx);
                                var isScore = typeSel && typeSel.value === 'score';

                                var wBox = document.getElementById('addCriteriaWeight_<?php echo $joID; ?>_' + stageIdx);
                                if (wBox) { wBox.disabled = !isScore; }

                                var mBox = document.getElementById('addCriteriaScoreMax_<?php echo $joID; ?>_' + stageIdx);
                                if (mBox) {
                                    mBox.disabled = !isScore;
                                    if (isScore && (!mBox.value || parseFloat(mBox.value) <= 0)) {
                                        mBox.value = '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>';
                                    }
                                }
                            }

                            /* ---------- Stage: delete / edit / move ---------- */

                            function deleteStage_<?php echo $joID; ?>(idx) {
                                var el = document.getElementById('stageRow_<?php echo $joID; ?>_' + idx);
                                if (el) el.style.display = 'none';
                                var stageName = window['stageName_<?php echo $joID; ?>_' + idx];
                                appendCommand(<?php echo $joID; ?>, 'DELETESTAGE ' + encodeURIComponent(stageName));
                                recalcStageShares_<?php echo $joID; ?>();
                            }

                            function editStage_<?php echo $joID; ?>(idx) {
                                document.getElementById('stageNameInput_<?php echo $joID; ?>_' + idx).value = window['stageName_<?php echo $joID; ?>_' + idx];
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).style.display = 'none';
                                document.getElementById('stageNameEditArea_<?php echo $joID; ?>_' + idx).style.display = '';

                                var wBox = document.getElementById('stageWeightInput_<?php echo $joID; ?>_' + idx);
                                if (wBox) { wBox.value = window['stageWeight_<?php echo $joID; ?>_' + idx]; }
                                showWeightEditor('stageWeightDisplay_<?php echo $joID; ?>_' + idx,
                                                 'stageWeightEdit_<?php echo $joID; ?>_' + idx);

                                document.getElementById('stageNameInput_<?php echo $joID; ?>_' + idx).focus();
                            }

                            function cancelStageEdit_<?php echo $joID; ?>(idx) {
                                document.getElementById('stageNameEditArea_<?php echo $joID; ?>_' + idx).style.display = 'none';
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).style.display = '';

                                /* Put the stored value back before hiding, or an
                                   abandoned edit would leave the shares showing a
                                   number that was never committed. */
                                var wBox = document.getElementById('stageWeightInput_<?php echo $joID; ?>_' + idx);
                                if (wBox) { wBox.value = window['stageWeight_<?php echo $joID; ?>_' + idx]; }
                                hideWeightEditor('stageWeightDisplay_<?php echo $joID; ?>_' + idx,
                                                 'stageWeightEdit_<?php echo $joID; ?>_' + idx);
                                recalcStageShares_<?php echo $joID; ?>();
                            }

                            function saveStageEdit_<?php echo $joID; ?>(idx) {
                                var newName = document.getElementById('stageNameInput_<?php echo $joID; ?>_' + idx).value.replace(/^\s+|\s+$/g, '');
                                if (!newName) return;

                                var oldName = window['stageName_<?php echo $joID; ?>_' + idx];
                                if (newName !== oldName) {
                                    appendCommand(<?php echo $joID; ?>, 'RENAMESTAGE ' + encodeURIComponent(oldName) + ':' + encodeURIComponent(newName));
                                    window['stageName_<?php echo $joID; ?>_' + idx] = newName;
                                    document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).textContent = newName;
                                }

                                var wBox = document.getElementById('stageWeightInput_<?php echo $joID; ?>_' + idx);
                                if (wBox) {
                                    var newWeight = String(parseWeight(wBox.value));
                                    if (newWeight !== window['stageWeight_<?php echo $joID; ?>_' + idx]) {
                                        /* newName, not oldName: RENAMESTAGE above is
                                           processed first server-side, so by the time
                                           this runs the stage carries the new name. */
                                        appendCommand(<?php echo $joID; ?>, 'SETSTAGEWEIGHT ' + encodeURIComponent(newName) + ' ' + newWeight);
                                        window['stageWeight_<?php echo $joID; ?>_' + idx] = newWeight;
                                        document.getElementById('stageWeightDisplay_<?php echo $joID; ?>_' + idx).textContent = newWeight;
                                    }
                                }

                                /* Committed, so cancel's restore is a no-op here. */
                                cancelStageEdit_<?php echo $joID; ?>(idx);
                            }

                            function moveStageUp_<?php echo $joID; ?>(idx) {
                                var row = document.getElementById('stageRow_<?php echo $joID; ?>_' + idx);
                                var prevRow = getVisiblePrevRow(row);
                                if (!prevRow) return;
                                row.parentNode.insertBefore(row, prevRow);
                                var stageName = window['stageName_<?php echo $joID; ?>_' + idx];
                                appendCommand(<?php echo $joID; ?>, 'MOVESTAGEUP ' + encodeURIComponent(stageName));
                            }

                            function moveStageDown_<?php echo $joID; ?>(idx) {
                                var row = document.getElementById('stageRow_<?php echo $joID; ?>_' + idx);
                                var nextRow = getVisibleNextRow(row);
                                if (!nextRow) return;
                                row.parentNode.insertBefore(nextRow, row);
                                var stageName = window['stageName_<?php echo $joID; ?>_' + idx];
                                appendCommand(<?php echo $joID; ?>, 'MOVESTAGEDOWN ' + encodeURIComponent(stageName));
                            }

                            /* ---------- Criteria: delete / edit / move ---------- */

                            function deleteCriteria_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var el = document.getElementById('criteriaRow_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx);
                                if (el) el.style.display = 'none';
                                var stageName    = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                                var criteriaName = window['criteriaName_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx];
                                appendCommand(<?php echo $joID; ?>, 'DELETECRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(criteriaName));
                                recalcCriteriaShares_<?php echo $joID; ?>(stageIdx);
                            }

                            function editCriteria_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var key = stageIdx + '_' + criteriaIdx;
                                document.getElementById('criteriaNameInput_<?php echo $joID; ?>_' + key).value = window['criteriaName_<?php echo $joID; ?>_' + key];
                                document.getElementById('criteriaNameDisplay_<?php echo $joID; ?>_' + key).style.display = 'none';
                                document.getElementById('criteriaNameEditArea_<?php echo $joID; ?>_' + key).style.display = '';

                                var typeSel = document.getElementById('criteriaTypeInput_<?php echo $joID; ?>_' + key);
                                if (typeSel) {
                                    typeSel.value = window['criteriaType_<?php echo $joID; ?>_' + key] || 'text';
                                    typeSel.style.display = '';
                                    document.getElementById('criteriaTypeDisplay_<?php echo $joID; ?>_' + key).style.display = 'none';
                                }

                                var isScore = (window['criteriaType_<?php echo $joID; ?>_' + key] === 'score');

                                var wBox = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key);
                                if (wBox) { wBox.value = window['criteriaWeight_<?php echo $joID; ?>_' + key]; wBox.disabled = !isScore; }
                                showWeightEditor('criteriaWeightDisplay_<?php echo $joID; ?>_' + key,
                                                 'criteriaWeightEdit_<?php echo $joID; ?>_' + key);

                                var mBox = document.getElementById('criteriaScoreMaxInput_<?php echo $joID; ?>_' + key);
                                if (mBox) { mBox.value = window['criteriaScoreMax_<?php echo $joID; ?>_' + key] || '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>'; mBox.disabled = !isScore; }
                                showWeightEditor('criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + key,
                                                 'criteriaScoreMaxEdit_<?php echo $joID; ?>_' + key);

                                document.getElementById('criteriaNameInput_<?php echo $joID; ?>_' + key).focus();
                            }

                            function cancelCriteriaEdit_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var key = stageIdx + '_' + criteriaIdx;
                                document.getElementById('criteriaNameEditArea_<?php echo $joID; ?>_' + key).style.display = 'none';
                                document.getElementById('criteriaNameDisplay_<?php echo $joID; ?>_' + key).style.display = '';

                                var typeSel = document.getElementById('criteriaTypeInput_<?php echo $joID; ?>_' + key);
                                if (typeSel) {
                                    typeSel.style.display = 'none';
                                    document.getElementById('criteriaTypeDisplay_<?php echo $joID; ?>_' + key).style.display = '';
                                    /* Restore in case the select was changed but never saved. */
                                    typeSel.value = window['criteriaType_<?php echo $joID; ?>_' + key] || 'text';
                                }

                                var isScore = (window['criteriaType_<?php echo $joID; ?>_' + key] === 'score');

                                /* Restore before hiding: an abandoned edit must not
                                   leave the shares reflecting an uncommitted number. */
                                var wBox = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key);
                                if (wBox) { wBox.value = window['criteriaWeight_<?php echo $joID; ?>_' + key]; wBox.disabled = !isScore; }

                                var mBox = document.getElementById('criteriaScoreMaxInput_<?php echo $joID; ?>_' + key);
                                if (mBox) { mBox.value = window['criteriaScoreMax_<?php echo $joID; ?>_' + key] || '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>'; mBox.disabled = !isScore; }

                                hideWeightEditor('criteriaWeightDisplay_<?php echo $joID; ?>_' + key,
                                                 'criteriaWeightEdit_<?php echo $joID; ?>_' + key);
                                hideWeightEditor('criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + key,
                                                 'criteriaScoreMaxEdit_<?php echo $joID; ?>_' + key);
                                recalcCriteriaShares_<?php echo $joID; ?>(stageIdx);
                            }

                            function saveCriteriaEdit_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var key = stageIdx + '_' + criteriaIdx;
                                var newName = document.getElementById('criteriaNameInput_<?php echo $joID; ?>_' + key).value.replace(/^\s+|\s+$/g, '');
                                if (!newName) return;

                                var stageName = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                                var oldName   = window['criteriaName_<?php echo $joID; ?>_' + key];

                                if (newName !== oldName) {
                                    appendCommand(<?php echo $joID; ?>, 'RENAMECRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(oldName) + ':' + encodeURIComponent(newName));
                                    window['criteriaName_<?php echo $joID; ?>_' + key] = newName;
                                    document.getElementById('criteriaNameDisplay_<?php echo $joID; ?>_' + key).textContent = newName;
                                }

                                var typeSel = document.getElementById('criteriaTypeInput_<?php echo $joID; ?>_' + key);
                                var newType = typeSel ? typeSel.value : (window['criteriaType_<?php echo $joID; ?>_' + key] || 'text');
                                var oldType = window['criteriaType_<?php echo $joID; ?>_' + key] || 'text';

                                var wBox = document.getElementById('criteriaWeightInput_<?php echo $joID; ?>_' + key);
                                var mBox = document.getElementById('criteriaScoreMaxInput_<?php echo $joID; ?>_' + key);

                                var newWeight = wBox ? String(parseWeight(wBox.value)) : window['criteriaWeight_<?php echo $joID; ?>_' + key];
                                var newMax    = mBox ? String(parseWeight(mBox.value)) : (window['criteriaScoreMax_<?php echo $joID; ?>_' + key] || '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>');
                                if (newType === 'score' && parseFloat(newMax) <= 0) {
                                    newMax = '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>';
                                }

                                if (newType !== oldType) {
                                    /* Type change carries the current max along in one
                                       command - gradeable is derived server-side from
                                       the type itself, there's no separate flag to set.
                                       newName, not oldName: RENAMECRITERIA above is
                                       processed first server-side. */
                                    appendCommand(<?php echo $joID; ?>, 'CHANGECRITERIATYPE ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(newName) + ' ' + encodeURIComponent(newType) + ' ' + newMax);
                                    window['criteriaType_<?php echo $joID; ?>_' + key] = newType;
                                    document.getElementById('criteriaTypeDisplay_<?php echo $joID; ?>_' + key).textContent = newType;

                                    if (newType === 'score') {
                                        window['criteriaScoreMax_<?php echo $joID; ?>_' + key] = newMax;
                                        document.getElementById('criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + key).textContent = newMax;
                                    }

                                    /* This is what actually changes which rows share
                                       the stage's weight, so every share in the stage
                                       moves. */
                                    recalcCriteriaShares_<?php echo $joID; ?>(stageIdx);
                                }
                                else if (newType === 'score' && newMax !== window['criteriaScoreMax_<?php echo $joID; ?>_' + key]) {
                                    appendCommand(<?php echo $joID; ?>, 'SETSCORERANGE ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(newName) + ' ' + newMax);
                                    window['criteriaScoreMax_<?php echo $joID; ?>_' + key] = newMax;
                                    document.getElementById('criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + key).textContent = newMax;
                                }

                                if (newWeight !== window['criteriaWeight_<?php echo $joID; ?>_' + key]) {
                                    /* newName for the same reason as the type command
                                       above: the rename lands first. */
                                    appendCommand(<?php echo $joID; ?>, 'SETCRITERIAWEIGHT ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(newName) + ' ' + newWeight);
                                    window['criteriaWeight_<?php echo $joID; ?>_' + key] = newWeight;
                                    document.getElementById('criteriaWeightDisplay_<?php echo $joID; ?>_' + key).textContent = newWeight;
                                }

                                cancelCriteriaEdit_<?php echo $joID; ?>(stageIdx, criteriaIdx);
                            }

                            function moveCriteriaUp_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var row = document.getElementById('criteriaRow_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx);
                                var prevRow = getVisiblePrevRow(row);
                                if (!prevRow || prevRow.tagName !== 'TR') return;
                                row.parentNode.insertBefore(row, prevRow);
                                var stageName    = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                                var criteriaName = window['criteriaName_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx];
                                appendCommand(<?php echo $joID; ?>, 'MOVECRITERIAUP ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(criteriaName));
                            }

                            function moveCriteriaDown_<?php echo $joID; ?>(stageIdx, criteriaIdx) {
                                var row = document.getElementById('criteriaRow_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx);
                                var nextRow = getVisibleNextRow(row);
                                if (!nextRow || nextRow.tagName !== 'TR') return;
                                row.parentNode.insertBefore(nextRow, row);
                                var stageName    = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                                var criteriaName = window['criteriaName_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx];
                                appendCommand(<?php echo $joID; ?>, 'MOVECRITERIADOWN ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(criteriaName));
                            }

                            /* ---------- Add criteria / add stage ---------- */

                            function showAddCriteria_<?php echo $joID; ?>(stageIdx) {
                                document.getElementById('addCriteriaArea_<?php echo $joID; ?>_' + stageIdx).style.display = '';
                                document.getElementById('addCriteriaLink_<?php echo $joID; ?>_' + stageIdx).style.display = 'none';
                                document.getElementById('addCriteriaInput_<?php echo $joID; ?>_' + stageIdx).value = '';
                                var typeSel = document.getElementById('addCriteriaType_<?php echo $joID; ?>_' + stageIdx);
                                if (typeSel) typeSel.value = 'text';
                                var wBox = document.getElementById('addCriteriaWeight_<?php echo $joID; ?>_' + stageIdx);
                                if (wBox) { wBox.value = '0'; wBox.disabled = true; }
                                var mBox = document.getElementById('addCriteriaScoreMax_<?php echo $joID; ?>_' + stageIdx);
                                if (mBox) { mBox.value = '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>'; mBox.disabled = true; }
                                document.getElementById('addCriteriaInput_<?php echo $joID; ?>_' + stageIdx).focus();
                            }

                            function hideAddCriteria_<?php echo $joID; ?>(stageIdx) {
                                document.getElementById('addCriteriaArea_<?php echo $joID; ?>_' + stageIdx).style.display = 'none';
                                document.getElementById('addCriteriaLink_<?php echo $joID; ?>_' + stageIdx).style.display = '';
                            }

                            function doAddCriteria_<?php echo $joID; ?>(stageIdx) {
                                var input = document.getElementById('addCriteriaInput_<?php echo $joID; ?>_' + stageIdx);
                                var name  = input.value.replace(/^\s+|\s+$/g, '');
                                if (!name) return;
                                var typeSel = document.getElementById('addCriteriaType_<?php echo $joID; ?>_' + stageIdx);
                                var dataType = typeSel ? typeSel.value : 'text';
                                var isScore = (dataType === 'score');

                                var wBox = document.getElementById('addCriteriaWeight_<?php echo $joID; ?>_' + stageIdx);
                                var weight = wBox ? parseWeight(wBox.value) : 0;

                                var mBox = document.getElementById('addCriteriaScoreMax_<?php echo $joID; ?>_' + stageIdx);
                                var scoreMax = mBox ? parseWeight(mBox.value) : <?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>;
                                if (isScore && scoreMax <= 0) { scoreMax = <?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>; }

                                var criteriaIdx = window['criteriaCount_<?php echo $joID; ?>_' + stageIdx];
                                var key = stageIdx + '_' + criteriaIdx;
                                window['criteriaName_<?php echo $joID; ?>_' + key] = name;
                                window['criteriaType_<?php echo $joID; ?>_' + key] = dataType;
                                window['criteriaWeight_<?php echo $joID; ?>_' + key] = String(weight);
                                window['criteriaScoreMax_<?php echo $joID; ?>_' + key] = String(scoreMax);

                                var tbody = document.getElementById('criteriaBody_<?php echo $joID; ?>_' + stageIdx);
                                var row   = tbody.insertRow(tbody.rows.length);
                                row.id        = 'criteriaRow_<?php echo $joID; ?>_' + key;
                                row.className = (tbody.rows.length % 2 === 0) ? 'oddTableRow' : 'evenTableRow';

                                var cellDel = row.insertCell(0);
                                cellDel.style.whiteSpace = 'nowrap';

                                var delLink = document.createElement('a');
                                delLink.href = 'javascript:void(0);';
                                (function(si, ci) {
                                    delLink.onclick = function() { deleteCriteria_<?php echo $joID; ?>(si, ci); };
                                })(stageIdx, criteriaIdx);
                                var delImg = document.createElement('img');
                                delImg.src    = 'images/actions/delete.gif';
                                delImg.border = 0;
                                delLink.appendChild(delImg);
                                cellDel.appendChild(delLink);

                                var editLink = document.createElement('a');
                                editLink.href = 'javascript:void(0);';
                                editLink.style.marginLeft = '4px';
                                (function(si, ci) {
                                    editLink.onclick = function() { editCriteria_<?php echo $joID; ?>(si, ci); };
                                })(stageIdx, criteriaIdx);
                                var editImg = document.createElement('img');
                                editImg.src    = 'images/edit.gif';
                                editImg.border = 0;
                                editLink.appendChild(editImg);
                                cellDel.appendChild(editLink);

                                var upLink = document.createElement('a');
                                upLink.href = 'javascript:void(0);';
                                upLink.style.padding = '0px';
                                upLink.style.marginLeft = '4px';
                                (function(si, ci) {
                                    upLink.onclick = function() { moveCriteriaUp_<?php echo $joID; ?>(si, ci); };
                                })(stageIdx, criteriaIdx);
                                var upImg = document.createElement('img');
                                upImg.src    = 'images/scrollTop.jpg';
                                upImg.border = 0;
                                upImg.width  = 12;
                                upImg.height = 12;
                                upImg.style.padding = '0px';
                                upLink.appendChild(upImg);
                                cellDel.appendChild(upLink);

                                var downLink = document.createElement('a');
                                downLink.href = 'javascript:void(0);';
                                downLink.style.padding = '0px';
                                downLink.style.marginLeft = '2px';
                                (function(si, ci) {
                                    downLink.onclick = function() { moveCriteriaDown_<?php echo $joID; ?>(si, ci); };
                                })(stageIdx, criteriaIdx);
                                var downImg = document.createElement('img');
                                downImg.src    = 'images/scrollBottom.jpg';
                                downImg.border = 0;
                                downImg.width  = 12;
                                downImg.height = 12;
                                downImg.style.padding = '0px';
                                downLink.appendChild(downImg);
                                cellDel.appendChild(downLink);

                                var cellName = row.insertCell(1);
                                cellName.innerHTML =
                                    '<span id="criteriaNameDisplay_<?php echo $joID; ?>_' + key + '"></span>' +
                                    '<span id="criteriaNameEditArea_<?php echo $joID; ?>_' + key + '" style="display:none;">' +
                                        '<input type="text" id="criteriaNameInput_<?php echo $joID; ?>_' + key + '" class="inputbox" style="width:140px;" />' +
                                        '<input type="button" class="button" value="Save" onclick="saveCriteriaEdit_<?php echo $joID; ?>(' + stageIdx + ', ' + criteriaIdx + ');" />' +
                                        '<input type="button" class="button" value="Cancel" onclick="cancelCriteriaEdit_<?php echo $joID; ?>(' + stageIdx + ', ' + criteriaIdx + ');" />' +
                                    '</span>';
                                document.getElementById('criteriaNameDisplay_<?php echo $joID; ?>_' + key).textContent = name;

                                var cellType = row.insertCell(2);
                                cellType.innerHTML =
                                    '<span id="criteriaTypeDisplay_<?php echo $joID; ?>_' + key + '"></span>' +
                                    '<select id="criteriaTypeInput_<?php echo $joID; ?>_' + key + '" class="inputbox" style="display:none; width:90px;" onchange="onCriteriaTypeChange_<?php echo $joID; ?>(this, \'' + key + '\');">' +
                                        '<option value="text">text</option>' +
                                        '<option value="score">score</option>' +
                                        '<option value="date">date</option>' +
                                        '<option value="number">number</option>' +
                                    '</select>';
                                document.getElementById('criteriaTypeDisplay_<?php echo $joID; ?>_' + key).textContent = dataType;

                                var cellWeight = row.insertCell(3);
                                cellWeight.style.whiteSpace = 'nowrap';
                                cellWeight.innerHTML =
                                    '<span id="criteriaWeightDisplay_<?php echo $joID; ?>_' + key + '">' + weight + '</span>' +
                                    '<span id="criteriaWeightEdit_<?php echo $joID; ?>_' + key + '" style="display:none;">' +
                                        '<input type="text" class="inputbox weightBox" id="criteriaWeightInput_<?php echo $joID; ?>_' + key + '" ' +
                                            'value="' + weight + '" ' + (isScore ? '' : 'disabled="disabled" ') +
                                            'onkeyup="recalcCriteriaShares_<?php echo $joID; ?>(' + stageIdx + ');" />' +
                                    '</span>' +
                                    '<span class="shareNote" id="criteriaShare_<?php echo $joID; ?>_' + key + '"></span>';

                                var cellMax = row.insertCell(4);
                                cellMax.style.whiteSpace = 'nowrap';
                                cellMax.innerHTML =
                                    '<span id="criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + key + '">' + (isScore ? scoreMax : '') + '</span>' +
                                    '<span id="criteriaScoreMaxEdit_<?php echo $joID; ?>_' + key + '" style="display:none;">' +
                                        '<input type="text" class="inputbox scoreMaxBox" id="criteriaScoreMaxInput_<?php echo $joID; ?>_' + key + '" ' +
                                            'value="' + scoreMax + '" ' + (isScore ? '' : 'disabled="disabled" ') + '/>' +
                                    '</span>';

                                window['criteriaCount_<?php echo $joID; ?>_' + stageIdx]++;

                                var stageName = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                                appendCommand(<?php echo $joID; ?>, 'ADDCRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(name) + ' ' + encodeURIComponent(dataType) + ' ' + weight + ' ' + scoreMax);
                                hideAddCriteria_<?php echo $joID; ?>(stageIdx);
                                recalcCriteriaShares_<?php echo $joID; ?>(stageIdx);
                            }

                            function onAddStage_<?php echo $joID; ?>() {
                                var input     = document.getElementById('addStageInput_<?php echo $joID; ?>');
                                var stageName = input.value.replace(/^\s+|\s+$/g, '');
                                if (!stageName) return;

                                var wBoxNew   = document.getElementById('addStageWeight_<?php echo $joID; ?>');
                                var stageWeight = wBoxNew ? parseWeight(wBoxNew.value) : 100;

                                var idx = stageCount_<?php echo $joID; ?>++;
                                window['criteriaCount_<?php echo $joID; ?>_' + idx] = 1;
                                window['stageName_<?php echo $joID; ?>_' + idx]     = stageName;
                                /* Only Comments is seeded now. A Score criterion is
                                   no longer added automatically - the user adds one
                                   explicitly if this stage should be graded. */
                                window['criteriaName_<?php echo $joID; ?>_' + idx + '_0']     = 'Comments';
                                window['criteriaType_<?php echo $joID; ?>_' + idx + '_0']     = 'text';
                                window['criteriaWeight_<?php echo $joID; ?>_' + idx + '_0']   = '0';
                                window['criteriaScoreMax_<?php echo $joID; ?>_' + idx + '_0'] = '<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>';

                                var tbl = document.getElementById('stagesTable_<?php echo $joID; ?>');
                                var row = tbl.insertRow(tbl.rows.length);
                                row.id  = 'stageRow_<?php echo $joID; ?>_' + idx;

                                var tdLeft = row.insertCell(0);
                                tdLeft.style.verticalAlign = 'top';
                                tdLeft.style.paddingTop    = '6px';
                                tdLeft.innerHTML =
                                    '<a href="javascript:void(0);" onclick="deleteStage_<?php echo $joID; ?>(' + idx + ');">' +
                                        '<img src="images/actions/delete.gif" border="0" />' +
                                    '</a>' +
                                    '<a href="javascript:void(0);" style="margin-left:4px;" onclick="editStage_<?php echo $joID; ?>(' + idx + ');">' +
                                        '<img src="images/edit.gif" border="0" />' +
                                    '</a>' +
                                    '<a href="javascript:void(0);" style="padding:0px; margin-left:4px;" onclick="moveStageUp_<?php echo $joID; ?>(' + idx + ');">' +
                                        '<img src="images/scrollTop.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                    '</a>' +
                                    '<a href="javascript:void(0);" style="padding:0px; margin-left:2px;" onclick="moveStageDown_<?php echo $joID; ?>(' + idx + ');">' +
                                        '<img src="images/scrollBottom.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                    '</a>&nbsp;' +
                                    '<span id="stageNameDisplay_<?php echo $joID; ?>_' + idx + '"></span>' +
                                    '<span id="stageNameEditArea_<?php echo $joID; ?>_' + idx + '" style="display:none;">' +
                                        '<input type="text" id="stageNameInput_<?php echo $joID; ?>_' + idx + '" class="inputbox" style="width:140px;" />' +
                                        '<input type="button" class="button" value="Save" onclick="saveStageEdit_<?php echo $joID; ?>(' + idx + ');" />' +
                                        '<input type="button" class="button" value="Cancel" onclick="cancelStageEdit_<?php echo $joID; ?>(' + idx + ');" />' +
                                    '</span>' +
                                    '<div style="margin-top:4px; white-space:nowrap;">' +
                                        '<span style="font-size:11px; color:#666;">Weight</span> ' +
                                        '<span id="stageWeightDisplay_<?php echo $joID; ?>_' + idx + '">' + stageWeight + '</span>' +
                                        '<span id="stageWeightEdit_<?php echo $joID; ?>_' + idx + '" style="display:none;">' +
                                            '<input type="text" class="inputbox weightBox" id="stageWeightInput_<?php echo $joID; ?>_' + idx + '" ' +
                                                'value="' + stageWeight + '" ' +
                                                'onkeyup="recalcStageShares_<?php echo $joID; ?>();" />' +
                                        '</span>' +
                                        '<span class="shareNote" id="stageShare_<?php echo $joID; ?>_' + idx + '"></span>' +
                                    '</div>';
                                window['stageWeight_<?php echo $joID; ?>_' + idx] = String(stageWeight);
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).textContent = stageName;

                                var tdRight = row.insertCell(1);
                                tdRight.innerHTML =
                                    '<table id="criteriaTable_<?php echo $joID; ?>_' + idx + '" width="470" class="searchTable">' +
                                        '<thead><tr>' +
                                            '<th width="90"></th>' +
                                            '<th align="left">Criteria</th>' +
                                            '<th align="left" width="70">Type</th>' +
                                            '<th align="left" width="80">Weight</th>' +
                                            '<th align="left" width="70">Max</th>' +
                                        '</tr></thead>' +
                                        '<tr class="evenTableRow" id="criteriaRow_<?php echo $joID; ?>_' + idx + '_0">' +
                                            '<td style="white-space:nowrap;">' +
                                                '<a href="javascript:void(0);" onclick="deleteCriteria_<?php echo $joID; ?>(' + idx + ', 0);"><img src="images/actions/delete.gif" border="0"/></a>' +
                                                '<a href="javascript:void(0);" style="margin-left:4px;" onclick="editCriteria_<?php echo $joID; ?>(' + idx + ', 0);"><img src="images/edit.gif" border="0"/></a>' +
                                                '<a href="javascript:void(0);" style="padding:0px; margin-left:4px;" onclick="moveCriteriaUp_<?php echo $joID; ?>(' + idx + ', 0);">' +
                                                    '<img src="images/scrollTop.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                                '</a>' +
                                                '<a href="javascript:void(0);" style="padding:0px; margin-left:2px;" onclick="moveCriteriaDown_<?php echo $joID; ?>(' + idx + ', 0);">' +
                                                    '<img src="images/scrollBottom.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                                '</a>' +
                                            '</td>' +
                                            '<td>' +
                                                '<span id="criteriaNameDisplay_<?php echo $joID; ?>_' + idx + '_0">Comments</span>' +
                                                '<span id="criteriaNameEditArea_<?php echo $joID; ?>_' + idx + '_0" style="display:none;">' +
                                                    '<input type="text" id="criteriaNameInput_<?php echo $joID; ?>_' + idx + '_0" class="inputbox" style="width:140px;" />' +
                                                    '<input type="button" class="button" value="Save" onclick="saveCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 0);" />' +
                                                    '<input type="button" class="button" value="Cancel" onclick="cancelCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 0);" />' +
                                                '</span>' +
                                            '</td>' +
                                            '<td>' +
                                                '<span id="criteriaTypeDisplay_<?php echo $joID; ?>_' + idx + '_0">text</span>' +
                                                '<select id="criteriaTypeInput_<?php echo $joID; ?>_' + idx + '_0" class="inputbox" style="display:none; width:90px;" onchange="onCriteriaTypeChange_<?php echo $joID; ?>(this, \'' + idx + '_0\');">' +
                                                    '<option value="text">text</option>' +
                                                    '<option value="score">score</option>' +
                                                    '<option value="date">date</option>' +
                                                    '<option value="number">number</option>' +
                                                '</select>' +
                                            '</td>' +
                                            '<td style="white-space:nowrap;">' +
                                                '<span id="criteriaWeightDisplay_<?php echo $joID; ?>_' + idx + '_0">0</span>' +
                                                '<span id="criteriaWeightEdit_<?php echo $joID; ?>_' + idx + '_0" style="display:none;">' +
                                                    '<input type="text" class="inputbox weightBox" id="criteriaWeightInput_<?php echo $joID; ?>_' + idx + '_0" value="0" disabled="disabled" ' +
                                                        'onkeyup="recalcCriteriaShares_<?php echo $joID; ?>(' + idx + ');" />' +
                                                '</span>' +
                                                '<span class="shareNote" id="criteriaShare_<?php echo $joID; ?>_' + idx + '_0"></span>' +
                                            '</td>' +
                                            '<td style="white-space:nowrap;">' +
                                                '<span id="criteriaScoreMaxDisplay_<?php echo $joID; ?>_' + idx + '_0"></span>' +
                                                '<span id="criteriaScoreMaxEdit_<?php echo $joID; ?>_' + idx + '_0" style="display:none;">' +
                                                    '<input type="text" class="inputbox scoreMaxBox" id="criteriaScoreMaxInput_<?php echo $joID; ?>_' + idx + '_0" value="<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>" disabled="disabled" />' +
                                                '</span>' +
                                            '</td>' +
                                        '</tr>' +
                                        '<tbody id="criteriaBody_<?php echo $joID; ?>_' + idx + '"></tbody>' +
                                    '</table>' +
                                    '<div id="addCriteriaLink_<?php echo $joID; ?>_' + idx + '" style="margin-top:4px; margin-bottom:10px;">' +
                                        '<a href="javascript:void(0);" onclick="showAddCriteria_<?php echo $joID; ?>(' + idx + ');">' +
                                            '<img src="images/actions/add_small.gif" border="0"/>&nbsp;Add criteria to ' + stageName +
                                        '</a>' +
                                    '</div>' +
                                    '<div id="addCriteriaArea_<?php echo $joID; ?>_' + idx + '" style="display:none; margin-top:4px; margin-bottom:10px;">' +
                                        '<input id="addCriteriaInput_<?php echo $joID; ?>_' + idx + '" type="text" class="inputbox" style="width:160px;" ' +
                                            'onkeypress="if(event.keyCode==13){doAddCriteria_<?php echo $joID; ?>(' + idx + ');return false;}"/>' +
                                        '<select id="addCriteriaType_<?php echo $joID; ?>_' + idx + '" class="inputbox" style="width:90px;" onchange="onAddCriteriaTypeChange_<?php echo $joID; ?>(' + idx + ');">' +
                                            '<option value="text">Text</option>' +
                                            '<option value="score">Score</option>' +
                                            '<option value="date">Date</option>' +
                                            '<option value="number">Number</option>' +
                                        '</select>' +
                                        '<span style="font-size:11px; color:#666; margin-left:4px;">Weight</span>' +
                                        '<input id="addCriteriaWeight_<?php echo $joID; ?>_' + idx + '" type="text" class="inputbox weightBox" value="0" title="Weight" disabled="disabled" />' +
                                        '<span style="font-size:11px; color:#666; margin-left:4px;">Max</span>' +
                                        '<input id="addCriteriaScoreMax_<?php echo $joID; ?>_' + idx + '" type="text" class="inputbox scoreMaxBox" value="<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>" title="Max score" disabled="disabled" />' +
                                        '<input type="button" class="button" value="Add Criteria" onclick="doAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                        '<input type="button" class="button" value="Cancel" onclick="hideAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                    '</div>';

                                input.value = '';
                                document.getElementById('addStageArea_<?php echo $joID; ?>').style.display = 'none';
                                document.getElementById('addStageLink_<?php echo $joID; ?>').style.display  = '';

                                appendCommand(<?php echo $joID; ?>, 'ADDSTAGE ' + encodeURIComponent(stageName));

                                /* addStage() server-side inserts with a default
                                   weight, so an explicit SETSTAGEWEIGHT follows
                                   rather than being folded into ADDSTAGE - it
                                   keeps the command grammar backward compatible. */
                                appendCommand(<?php echo $joID; ?>, 'SETSTAGEWEIGHT ' + encodeURIComponent(stageName) + ' ' + stageWeight);

                                recalcAllShares_<?php echo $joID; ?>();
                            }
                        </script>

                        <table id="templateArea_<?php echo $joID; ?>" class="editTable" width="850"
                               <?php if ($joID !== 0): ?>style="display:none;"<?php endif; ?>>

                            <!-- Header -->
                            <tr>
                                <td colspan="2" style="padding: 8px 0 6px 0;">
                                    <?php if ($isGeneric): ?>
                                        <strong>Generic Evaluation Template</strong>
                                    <?php else: ?>
                                        <strong>
                                            Evaluation Template:
                                            <?php echo htmlspecialchars($joEntry['title'], ENT_QUOTES, 'UTF-8'); ?>
                                        </strong>
                                    <?php endif; ?>
                                </td>
                            </tr>

                            <!-- Stages & Criteria -->
                            <tr>
                                <td class="tdVertical" style="width:150px; vertical-align:top; padding-top:10px;">
                                    Interview Stage:
                                </td>
                                <td class="tdData" style="padding-top:10px;">

                                    <table id="stagesTable_<?php echo $joID; ?>" style="width:760px; table-layout:fixed;">
                                        <colgroup>
                                            <col style="width:220px;" />
                                            <col />
                                        </colgroup>

                                        <?php foreach ($existingStages as $stageIdx => $stage): ?>
                                        <tr id="stageRow_<?php echo $joID; ?>_<?php echo $stageIdx; ?>">
                                            <td style="vertical-align:top; padding-top:6px;">
                                                <a href="javascript:void(0);"
                                                   onclick="deleteStage_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                    <img src="images/actions/delete.gif" border="0" />
                                                </a>
                                                <a href="javascript:void(0);" style="margin-left:4px;"
                                                   onclick="editStage_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                    <img src="images/edit.gif" border="0" />
                                                </a>
                                                <a href="javascript:void(0);" style="padding:0px; margin-left:4px;"
                                                   onclick="moveStageUp_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                    <img src="images/scrollTop.jpg" width="12" height="12" border="0" style="padding:0px;" />
                                                </a>
                                                <a href="javascript:void(0);" style="padding:0px; margin-left:2px;"
                                                   onclick="moveStageDown_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                    <img src="images/scrollBottom.jpg" width="12" height="12" border="0" style="padding:0px;" />
                                                </a>&nbsp;<span id="stageNameDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"><?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?></span>
                                                <span id="stageNameEditArea_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="display:none;">
                                                    <input type="text" id="stageNameInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" class="inputbox" style="width:140px;" />
                                                    <input type="button" class="button" value="Save" onclick="saveStageEdit_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);" />
                                                    <input type="button" class="button" value="Cancel" onclick="cancelStageEdit_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);" />
                                                </span>

                                                <!-- Stage weight rides the same edit toggle as the
                                                     stage name: read-only text until the pencil is
                                                     clicked, then a box, committed by the same Save.
                                                     The share stays visible either way - it is the
                                                     number you actually compare stages on. -->
                                                <div style="margin-top:4px; white-space:nowrap;">
                                                    <span style="font-size:11px; color:#666;">Weight</span>
                                                    <span id="stageWeightDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"><?php echo evalTplWeight(isset($stage['weight']) ? $stage['weight'] : 0); ?></span>
                                                    <span id="stageWeightEdit_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="display:none;">
                                                        <input type="text" class="inputbox weightBox"
                                                               id="stageWeightInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"
                                                               value="<?php echo evalTplWeight(isset($stage['weight']) ? $stage['weight'] : 0); ?>"
                                                               onkeyup="recalcStageShares_<?php echo $joID; ?>();" />
                                                    </span>
                                                    <span class="shareNote" id="stageShare_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"></span>
                                                </div>
                                            </td>
                                            <td>
                                                <table id="criteriaTable_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" width="470" class="searchTable">
                                                    <thead>
                                                        <tr>
                                                            <th width="90"></th>
                                                            <th align="left">Criteria</th>
                                                            <th align="left" width="70">Type</th>
                                                            <th align="left" width="80">Weight</th>
                                                            <th align="left" width="70">Max</th>
                                                        </tr>
                                                    </thead>
                                                    <?php foreach ($stage['criteria'] as $criteriaIdx => $criterion): ?>
                                                    <?php
                                                        $criterionType   = isset($criterion['data_type']) ? $criterion['data_type'] : 'text';
                                                        $criterionIsScore = evalTplIsScore($criterion);
                                                        $criterionScoreMax = ($criterionIsScore)
                                                            ? evalTplWeight(isset($criterion['score_max']) && $criterion['score_max'] !== null ? $criterion['score_max'] : EVAL_TPL_DEFAULT_SCORE_MAX)
                                                            : evalTplWeight(EVAL_TPL_DEFAULT_SCORE_MAX);
                                                    ?>
                                                    <tr class="<?php echo ($criteriaIdx % 2 === 0) ? 'evenTableRow' : 'oddTableRow'; ?>"
                                                        id="criteriaRow_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>">
                                                        <td style="white-space:nowrap;">
                                                            <a href="javascript:void(0);"
                                                               onclick="deleteCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);">
                                                                <img src="images/actions/delete.gif" border="0" />
                                                            </a>
                                                            <a href="javascript:void(0);" style="margin-left:4px;"
                                                               onclick="editCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);">
                                                                <img src="images/edit.gif" border="0" />
                                                            </a>
                                                            <a href="javascript:void(0);" style="padding:0px; margin-left:4px;"
                                                               onclick="moveCriteriaUp_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);">
                                                                <img src="images/scrollTop.jpg" width="12" height="12" border="0" style="padding:0px;" />
                                                            </a>
                                                            <a href="javascript:void(0);" style="padding:0px; margin-left:2px;"
                                                               onclick="moveCriteriaDown_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);">
                                                                <img src="images/scrollBottom.jpg" width="12" height="12" border="0" style="padding:0px;" />
                                                            </a>
                                                        </td>
                                                        <td>
                                                            <span id="criteriaNameDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"><?php echo htmlspecialchars($criterion['criteria_name'], ENT_QUOTES, 'UTF-8'); ?></span>
                                                            <span id="criteriaNameEditArea_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" style="display:none;">
                                                                <input type="text" id="criteriaNameInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" class="inputbox" style="width:140px;" />
                                                                <input type="button" class="button" value="Save" onclick="saveCriteriaEdit_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);" />
                                                                <input type="button" class="button" value="Cancel" onclick="cancelCriteriaEdit_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>);" />
                                                            </span>
                                                        </td>
                                                        <td>
                                                            <span id="criteriaTypeDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"><?php echo htmlspecialchars($criterionType, ENT_QUOTES, 'UTF-8'); ?></span>
                                                            <select id="criteriaTypeInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" class="inputbox" style="display:none; width:90px;"
                                                                    onchange="onCriteriaTypeChange_<?php echo $joID; ?>(this, '<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>');">
                                                                <option value="text">text</option>
                                                                <option value="score">score</option>
                                                                <option value="date">date</option>
                                                                <option value="number">number</option>
                                                            </select>
                                                        </td>
                                                        <td style="white-space:nowrap;">
                                                            <span id="criteriaWeightDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"><?php echo evalTplWeight(isset($criterion['weight']) ? $criterion['weight'] : 0); ?></span>
                                                            <span id="criteriaWeightEdit_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" style="display:none;">
                                                                <input type="text" class="inputbox weightBox"
                                                                       id="criteriaWeightInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"
                                                                       value="<?php echo evalTplWeight(isset($criterion['weight']) ? $criterion['weight'] : 0); ?>"
                                                                       <?php echo !$criterionIsScore ? 'disabled="disabled"' : ''; ?>
                                                                       onkeyup="recalcCriteriaShares_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);" />
                                                            </span>
                                                            <span class="shareNote" id="criteriaShare_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"></span>
                                                        </td>
                                                        <td style="white-space:nowrap;">
                                                            <span id="criteriaScoreMaxDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"><?php echo $criterionIsScore ? $criterionScoreMax : ''; ?></span>
                                                            <span id="criteriaScoreMaxEdit_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" style="display:none;">
                                                                <input type="text" class="inputbox scoreMaxBox"
                                                                       id="criteriaScoreMaxInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"
                                                                       value="<?php echo $criterionScoreMax; ?>"
                                                                       <?php echo !$criterionIsScore ? 'disabled="disabled"' : ''; ?> />
                                                            </span>
                                                        </td>
                                                    </tr>
                                                    <?php endforeach; ?>
                                                    <tbody id="criteriaBody_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"></tbody>
                                                </table>

                                                <div id="addCriteriaLink_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="margin-top:4px; margin-bottom:10px;">
                                                    <a href="javascript:void(0);"
                                                       onclick="showAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                        <img src="images/actions/add_small.gif" border="0" />&nbsp;Add criteria
                                                    </a>
                                                </div>

                                                <div id="addCriteriaArea_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="display:none; margin-top:4px; margin-bottom:10px;">
                                                    <input id="addCriteriaInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"
                                                           type="text" class="inputbox" style="width:160px;"
                                                           onkeypress="if(event.keyCode==13){ doAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>); return false; }" />
                                                    <select id="addCriteriaType_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" class="inputbox" style="width:90px;"
                                                            onchange="onAddCriteriaTypeChange_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                        <option value="text">Text</option>
                                                        <option value="score">Score</option>
                                                        <option value="date">Date</option>
                                                        <option value="number">Number</option>
                                                    </select>
                                                    <span style="font-size:11px; color:#666; margin-left:4px;">Weight</span>
                                                    <input id="addCriteriaWeight_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"
                                                           type="text" class="inputbox weightBox" value="0" title="Weight" disabled="disabled" />
                                                    <span style="font-size:11px; color:#666; margin-left:4px;">Max</span>
                                                    <input id="addCriteriaScoreMax_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"
                                                           type="text" class="inputbox scoreMaxBox" value="<?php echo EVAL_TPL_DEFAULT_SCORE_MAX; ?>" title="Max score" disabled="disabled" />
                                                    <input type="button" class="button" value="Add Criteria"
                                                           onclick="doAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);" />
                                                    <input type="button" class="button" value="Cancel"
                                                           onclick="hideAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);" />
                                                </div>
                                            </td>
                                        </tr>
                                        <?php endforeach; ?>

                                    </table>

                                    <div id="addStageLink_<?php echo $joID; ?>" style="margin-top:6px;">
                                        <a href="javascript:void(0);"
                                           onclick="document.getElementById('addStageArea_<?php echo $joID; ?>').style.display='';
                                                    document.getElementById('addStageLink_<?php echo $joID; ?>').style.display='none';
                                                    document.getElementById('addStageInput_<?php echo $joID; ?>').value='';
                                                    document.getElementById('addStageInput_<?php echo $joID; ?>').focus();">
                                            <img src="images/actions/add_small.gif" border="0" />&nbsp;Add interview stage
                                        </a>
                                    </div>

                                    <div id="addStageArea_<?php echo $joID; ?>" style="display:none; margin-top:6px;">
                                        <input id="addStageInput_<?php echo $joID; ?>"
                                               type="text" class="inputbox" style="width:220px;"
                                               onkeypress="if(event.keyCode==13){ onAddStage_<?php echo $joID; ?>(); return false; }" />
                                        <span style="font-size:11px; color:#666; margin-left:4px;">Weight</span>
                                        <input id="addStageWeight_<?php echo $joID; ?>" type="text"
                                               class="inputbox weightBox" value="100" title="Stage weight" />
                                        <input type="button" class="button" value="Add Stage"
                                               onclick="onAddStage_<?php echo $joID; ?>();" />
                                        <input type="button" class="button" value="Cancel"
                                               onclick="document.getElementById('addStageArea_<?php echo $joID; ?>').style.display='none';
                                                        document.getElementById('addStageLink_<?php echo $joID; ?>').style.display='';" />
                                    </div>

                                </td>
                            </tr>

                            <!-- Save -->
                            <tr>
                                <td colspan="2" style="padding: 10px 0;">
                                    <input type="button" class="button" value="Save Template"
                                           onclick="submitTemplate(<?php echo $joID; ?>);" />
                                    <?php if (!$isGeneric): ?>
                                    <input type="button" class="button" value="Reset to Generic"
                                           style="margin-left:6px;"
                                           onclick="resetToGenericTemplate(<?php echo $joID; ?>);" />
                                    <?php endif; ?>
                                </td>
                            </tr>

                        </table>

                        <?php endforeach; ?>

                        <script type="text/javascript">
                            /* Every template area is in the DOM at once, only one
                               visible. Shares are computed for all of them on load
                               so switching job orders doesn't show blank percentages
                               until something is touched. */
                            window.recalcAllShares = function () {
                                <?php echo implode("; ", $shareRecalcCalls); ?>;
                            };
                        </script>

                    </td>
                </tr>

            </table>

        </form>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>