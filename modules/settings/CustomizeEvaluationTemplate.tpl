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
?>
    <?php TemplateUtility::printQuickSearch(); ?>

    <div id="contents">

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

                window.onload = function () { showTemplate(<?php echo $selectedJobOrderID; ?>); };
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

                        <?php foreach ($allTemplates as $joEntry):
                            $joID           = (int) $joEntry['jobOrderID'];
                            $isGeneric      = ($joID === 0);
                            $hasTpl         = isset($evaluationTemplatesRS[$joID]);
                            $existingStages = ($hasTpl && !empty($evaluationTemplatesRS[$joID]['stages']))
                                                ? $evaluationTemplatesRS[$joID]['stages']
                                                : array();
                            $stageStartCount = count($existingStages);
                        ?>

                        <script type="text/javascript">
                            var stageCount_<?php echo $joID; ?> = <?php echo $stageStartCount; ?>;

                            <?php foreach ($existingStages as $stageIdx => $stage): ?>
                            window[<?php echo json_encode('stageName_' . $joID . '_' . $stageIdx); ?>] = <?php echo json_encode($stage['stage_name']); ?>;
                            window[<?php echo json_encode('criteriaCount_' . $joID . '_' . $stageIdx); ?>] = <?php echo count($stage['criteria']); ?>;
                            <?php foreach ($stage['criteria'] as $criteriaIdx => $criterion): ?>
                            window[<?php echo json_encode('criteriaName_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode($criterion['criteria_name']); ?>;
                            window[<?php echo json_encode('criteriaType_' . $joID . '_' . $stageIdx . '_' . $criteriaIdx); ?>] = <?php echo json_encode(isset($criterion['data_type']) ? $criterion['data_type'] : 'text'); ?>;
                            <?php endforeach; ?>
                            <?php endforeach; ?>

                            /* ---------- Stage: delete / edit / move ---------- */

                            function deleteStage_<?php echo $joID; ?>(idx) {
                                var el = document.getElementById('stageRow_<?php echo $joID; ?>_' + idx);
                                if (el) el.style.display = 'none';
                                var stageName = window['stageName_<?php echo $joID; ?>_' + idx];
                                appendCommand(<?php echo $joID; ?>, 'DELETESTAGE ' + encodeURIComponent(stageName));
                            }

                            function editStage_<?php echo $joID; ?>(idx) {
                                document.getElementById('stageNameInput_<?php echo $joID; ?>_' + idx).value = window['stageName_<?php echo $joID; ?>_' + idx];
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).style.display = 'none';
                                document.getElementById('stageNameEditArea_<?php echo $joID; ?>_' + idx).style.display = '';
                                document.getElementById('stageNameInput_<?php echo $joID; ?>_' + idx).focus();
                            }

                            function cancelStageEdit_<?php echo $joID; ?>(idx) {
                                document.getElementById('stageNameEditArea_<?php echo $joID; ?>_' + idx).style.display = 'none';
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).style.display = '';
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
                                }
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
                                if (typeSel) {
                                    var newType = typeSel.value;
                                    var oldType = window['criteriaType_<?php echo $joID; ?>_' + key] || 'text';
                                    if (newType !== oldType) {
                                        /* newName, not oldName: the RENAMECRITERIA above is
                                           processed first server-side, so by the time this
                                           command runs the criterion has the new name. */
                                        appendCommand(<?php echo $joID; ?>, 'CHANGECRITERIATYPE ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(newName) + ' ' + encodeURIComponent(newType));
                                        window['criteriaType_<?php echo $joID; ?>_' + key] = newType;
                                        document.getElementById('criteriaTypeDisplay_<?php echo $joID; ?>_' + key).textContent = newType;
                                    }
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

                                var criteriaIdx = window['criteriaCount_<?php echo $joID; ?>_' + stageIdx];
                                var key = stageIdx + '_' + criteriaIdx;
                                window['criteriaName_<?php echo $joID; ?>_' + key] = name;

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
                                cellType.textContent = dataType;
                                window['criteriaCount_<?php echo $joID; ?>_' + stageIdx]++;

                                var stageName = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                               appendCommand(<?php echo $joID; ?>, 'ADDCRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(name) + ' ' + encodeURIComponent(dataType));
                                hideAddCriteria_<?php echo $joID; ?>(stageIdx);
                            }

                            function onAddStage_<?php echo $joID; ?>() {
                                var input     = document.getElementById('addStageInput_<?php echo $joID; ?>');
                                var stageName = input.value.replace(/^\s+|\s+$/g, '');
                                if (!stageName) return;

                                var idx = stageCount_<?php echo $joID; ?>++;
                                window['criteriaCount_<?php echo $joID; ?>_' + idx] = 2;
                                window['stageName_<?php echo $joID; ?>_' + idx]     = stageName;
                                window['criteriaName_<?php echo $joID; ?>_' + idx + '_0'] = 'Rating';
                                window['criteriaName_<?php echo $joID; ?>_' + idx + '_1'] = 'Comments';

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
                                    '</span>';
                                document.getElementById('stageNameDisplay_<?php echo $joID; ?>_' + idx).textContent = stageName;

                                var tdRight = row.insertCell(1);
                                tdRight.innerHTML =
                                    '<table id="criteriaTable_<?php echo $joID; ?>_' + idx + '" width="380" class="searchTable">' +
                                        '<thead><tr>' +
                                            '<th width="90"></th>' +
                                            '<th align="left">Criteria</th>' +
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
                                                '<span id="criteriaNameDisplay_<?php echo $joID; ?>_' + idx + '_0">Rating</span>' +
                                                '<span id="criteriaNameEditArea_<?php echo $joID; ?>_' + idx + '_0" style="display:none;">' +
                                                    '<input type="text" id="criteriaNameInput_<?php echo $joID; ?>_' + idx + '_0" class="inputbox" style="width:140px;" />' +
                                                    '<input type="button" class="button" value="Save" onclick="saveCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 0);" />' +
                                                    '<input type="button" class="button" value="Cancel" onclick="cancelCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 0);" />' +
                                                '</span>' +
                                            '</td>' +
                                        '</tr>' +
                                        '<tr class="oddTableRow" id="criteriaRow_<?php echo $joID; ?>_' + idx + '_1">' +
                                            '<td style="white-space:nowrap;">' +
                                                '<a href="javascript:void(0);" onclick="deleteCriteria_<?php echo $joID; ?>(' + idx + ', 1);"><img src="images/actions/delete.gif" border="0"/></a>' +
                                                '<a href="javascript:void(0);" style="margin-left:4px;" onclick="editCriteria_<?php echo $joID; ?>(' + idx + ', 1);"><img src="images/edit.gif" border="0"/></a>' +
                                                '<a href="javascript:void(0);" style="padding:0px; margin-left:4px;" onclick="moveCriteriaUp_<?php echo $joID; ?>(' + idx + ', 1);">' +
                                                    '<img src="images/scrollTop.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                                '</a>' +
                                                '<a href="javascript:void(0);" style="padding:0px; margin-left:2px;" onclick="moveCriteriaDown_<?php echo $joID; ?>(' + idx + ', 1);">' +
                                                    '<img src="images/scrollBottom.jpg" width="12" height="12" border="0" style="padding:0px;" />' +
                                                '</a>' +
                                            '</td>' +
                                            '<td>' +
                                                '<span id="criteriaNameDisplay_<?php echo $joID; ?>_' + idx + '_1">Comments</span>' +
                                                '<span id="criteriaNameEditArea_<?php echo $joID; ?>_' + idx + '_1" style="display:none;">' +
                                                    '<input type="text" id="criteriaNameInput_<?php echo $joID; ?>_' + idx + '_1" class="inputbox" style="width:140px;" />' +
                                                    '<input type="button" class="button" value="Save" onclick="saveCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 1);" />' +
                                                    '<input type="button" class="button" value="Cancel" onclick="cancelCriteriaEdit_<?php echo $joID; ?>(' + idx + ', 1);" />' +
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
                                        '<select id="addCriteriaType_<?php echo $joID; ?>_' + idx + '" class="inputbox" style="width:90px;">' +
                                            '<option value="text">Text</option>' +
                                            '<option value="date">Date</option>' +
                                            '<option value="number">Number</option>' +
                                        '</select>' +
                                        '<input type="button" class="button" value="Add Criteria" onclick="doAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                        '<input type="button" class="button" value="Cancel" onclick="hideAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                    '</div>';

                                input.value = '';
                                document.getElementById('addStageArea_<?php echo $joID; ?>').style.display = 'none';
                                document.getElementById('addStageLink_<?php echo $joID; ?>').style.display  = '';
                                appendCommand(<?php echo $joID; ?>, 'ADDSTAGE ' + encodeURIComponent(stageName));
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

                                    <table id="stagesTable_<?php echo $joID; ?>" style="width:700px; table-layout:fixed;">
                                        <colgroup>
                                            <col style="width:180px;" />
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
                                            </td>
                                            <td>
                                                <table id="criteriaTable_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" width="380" class="searchTable">
                                                    <thead>
                                                        <tr>
                                                            <th width="90"></th>
                                                            <th align="left">Criteria</th>
                                                            <th align="left" width="70">Type</th>
                                                        </tr>
                                                    </thead>
                                                    <?php foreach ($stage['criteria'] as $criteriaIdx => $criterion): ?>
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
                                                            <span id="criteriaTypeDisplay_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>"><?php echo htmlspecialchars(isset($criterion['data_type']) ? $criterion['data_type'] : 'text', ENT_QUOTES, 'UTF-8'); ?></span>
                                                            <select id="criteriaTypeInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>" class="inputbox" style="display:none; width:90px;">
                                                                <option value="text">text</option>
                                                                <option value="date">date</option>
                                                                <option value="number">number</option>
                                                            </select>
                                                        </td>
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
                                                    <select id="addCriteriaType_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" class="inputbox" style="width:90px;">
                                                        <option value="text">Text</option>
                                                        <option value="date">Date</option>
                                                        <option value="number">Number</option>
                                                    </select>
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

                    </td>
                </tr>

            </table>

        </form>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>