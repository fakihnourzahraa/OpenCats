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
<script type="text/javascript">
    var CATS_SESSION_ID = '<?php echo session_id(); ?>';
</script>
        <script type="text/javascript">
            var ALL_TEMPLATE_IDS = [0<?php foreach ($jobOrdersRS as $jo): ?>, <?php echo (int) $jo['jobOrderID']; ?><?php endforeach; ?>];

            function showTemplate(jobOrderID) {
                for (var i = 0; i < ALL_TEMPLATE_IDS.length; i++) {
                    var el = document.getElementById('templateArea_' + ALL_TEMPLATE_IDS[i]);
                    if (el) el.style.display = 'none';
                }
                var target = document.getElementById('templateArea_' + jobOrderID);
                if (target) target.style.display = '';
            }

            window.onload = function() { showTemplate(0); };
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
                                        <option value="<?php echo (int) $joEntry['jobOrderID']; ?>">
                                            <?php echo htmlspecialchars($joEntry['title'], ENT_QUOTES, 'UTF-8'); ?>
                                            <?php if (!empty($joEntry['companyName'])): ?>
                                                &mdash; <?php echo htmlspecialchars($joEntry['companyName'], ENT_QUOTES, 'UTF-8'); ?>
                                            <?php endif; ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                                <span style="color:#888; font-size:0.85em;">
                                    <br />If no template is saved for a job order, the Generic Template is used.
                                </span>
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

                    <!-- commandList hidden input lives outside the table so the browser keeps it -->
                    <input type="hidden" id="commandList_<?php echo $joID; ?>" value="" />

                    <script type="text/javascript">
                        var stageCount_<?php echo $joID; ?> = <?php echo $stageStartCount; ?>;

                        <?php foreach ($existingStages as $stageIdx => $stage): ?>
                        window[<?php echo json_encode('stageName_' . $joID . '_' . $stageIdx); ?>] = <?php echo json_encode($stage['stage_name']); ?>;
                        window[<?php echo json_encode('criteriaCount_' . $joID . '_' . $stageIdx); ?>] = <?php echo count($stage['criteria']); ?>;
                        <?php endforeach; ?>

                        function appendCommand_<?php echo $joID; ?>(cmd) {
                            var el = document.getElementById('commandList_<?php echo $joID; ?>');
                            el.value = el.value + encodeURIComponent(cmd) + ',';
                        }

                        /* Builds a real form in JS, appends to body, and submits.
                           This bypasses the browser's table foster-parenting rules
                           which discard <form> elements parsed inside <table>. */
function submitTemplate_<?php echo $joID; ?>() {
    var commandList = document.getElementById('commandList_<?php echo $joID; ?>').value;
    console.log('commandList value:', commandList);
    if (!commandList) {
        alert('Nothing to save.');
        return;
    }
    var xhr = new XMLHttpRequest();
xhr.open('POST', '<?php echo CATSUtility::getIndexName(); ?>?m=settings&a=customizeEvaluationTemplate', true);
xhr.withCredentials = true;
xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = function() {
        console.log('XHR status:', xhr.status);
        console.log('XHR response:', xhr.responseText.substring(0, 500));
        window.location.href = '<?php echo CATSUtility::getIndexName(); ?>?m=settings&a=customizeEvaluationTemplate';
    };
    xhr.onerror = function() {
        alert('Save failed.');
    };
    var body = 'postback=postback&jobOrderID=<?php echo $joID; ?>&commandList=' + encodeURIComponent(commandList);
    console.log('XHR sending body:', body);
xhr.send(
    'postback=postback' +
    '&jobOrderID=<?php echo $joID; ?>' +
    '&commandList=' + encodeURIComponent(commandList) +
    '&cats_session_id=' + encodeURIComponent(CATS_SESSION_ID)
);
}

                        function deleteStage_<?php echo $joID; ?>(idx, stageName) {
                            var el = document.getElementById('stageRow_<?php echo $joID; ?>_' + idx);
                            if (el) el.style.display = 'none';
                            appendCommand_<?php echo $joID; ?>('DELETESTAGE ' + encodeURIComponent(stageName));
                        }

                        function deleteCriteria_<?php echo $joID; ?>(stageIdx, criteriaIdx, criteriaName) {
                            var el = document.getElementById('criteriaRow_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx);
                            if (el) el.style.display = 'none';
                            var stageName = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                            appendCommand_<?php echo $joID; ?>('DELETECRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(criteriaName));
                        }

                        function showAddCriteria_<?php echo $joID; ?>(stageIdx) {
                            document.getElementById('addCriteriaArea_<?php echo $joID; ?>_' + stageIdx).style.display = '';
                            document.getElementById('addCriteriaLink_<?php echo $joID; ?>_' + stageIdx).style.display = 'none';
                            document.getElementById('addCriteriaInput_<?php echo $joID; ?>_' + stageIdx).value = '';
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

                            var criteriaIdx = window['criteriaCount_<?php echo $joID; ?>_' + stageIdx];
                            var tbody = document.getElementById('criteriaBody_<?php echo $joID; ?>_' + stageIdx);
                            var row   = tbody.insertRow(tbody.rows.length);
                            row.id        = 'criteriaRow_<?php echo $joID; ?>_' + stageIdx + '_' + criteriaIdx;
                            row.className = (tbody.rows.length % 2 === 0) ? 'oddTableRow' : 'evenTableRow';

                            var cellDel = row.insertCell(0);
                            var a = document.createElement('a');
                            a.href = 'javascript:void(0);';
                            (function(si, ci, cn) {
                                a.onclick = function() { deleteCriteria_<?php echo $joID; ?>(si, ci, cn); };
                            })(stageIdx, criteriaIdx, name);
                            var img = document.createElement('img');
                            img.src    = 'images/actions/delete.gif';
                            img.border = 0;
                            a.appendChild(img);
                            cellDel.appendChild(a);

                            var cellName = row.insertCell(1);
                            cellName.appendChild(document.createTextNode(name));

                            window['criteriaCount_<?php echo $joID; ?>_' + stageIdx]++;

                            var stageName = window['stageName_<?php echo $joID; ?>_' + stageIdx];
                            appendCommand_<?php echo $joID; ?>('ADDCRITERIA ' + encodeURIComponent(stageName) + ' ' + encodeURIComponent(name));
                            hideAddCriteria_<?php echo $joID; ?>(stageIdx);
                        }

                        function onAddStage_<?php echo $joID; ?>() {
                            var input     = document.getElementById('addStageInput_<?php echo $joID; ?>');
                            var stageName = input.value.replace(/^\s+|\s+$/g, '');
                            if (!stageName) return;

                            var idx = stageCount_<?php echo $joID; ?>++;
                            window['criteriaCount_<?php echo $joID; ?>_' + idx] = 2;
                            window['stageName_<?php echo $joID; ?>_' + idx]     = stageName;

                            var tbl = document.getElementById('stagesTable_<?php echo $joID; ?>');
                            var row = tbl.insertRow(tbl.rows.length);
                            row.id  = 'stageRow_<?php echo $joID; ?>_' + idx;

                            var tdLeft = row.insertCell(0);
                            tdLeft.style.verticalAlign = 'top';
                            tdLeft.style.paddingTop    = '6px';
                            tdLeft.innerHTML =
                                '<a href="javascript:void(0);" onclick="deleteStage_<?php echo $joID; ?>(' + idx + ', \'' + stageName.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + '\');">' +
                                    '<img src="images/actions/delete.gif" border="0" />' +
                                '</a>&nbsp;' + stageName;

                            var tdRight = row.insertCell(1);
                            tdRight.innerHTML =
                                '<table id="criteriaTable_<?php echo $joID; ?>_' + idx + '" width="380" class="searchTable">' +
                                    '<thead><tr>' +
                                        '<th width="30"></th>' +
                                        '<th align="left">Criteria</th>' +
                                    '</tr></thead>' +
                                    '<tr class="evenTableRow" id="criteriaRow_<?php echo $joID; ?>_' + idx + '_0">' +
                                        '<td><a href="javascript:void(0);" onclick="deleteCriteria_<?php echo $joID; ?>(' + idx + ', 0, \'Rating\');"><img src="images/actions/delete.gif" border="0"/></a></td>' +
                                        '<td>Rating</td>' +
                                    '</tr>' +
                                    '<tr class="oddTableRow" id="criteriaRow_<?php echo $joID; ?>_' + idx + '_1">' +
                                        '<td><a href="javascript:void(0);" onclick="deleteCriteria_<?php echo $joID; ?>(' + idx + ', 1, \'Comments\');"><img src="images/actions/delete.gif" border="0"/></a></td>' +
                                        '<td>Comments</td>' +
                                    '</tr>' +
                                    '<tbody id="criteriaBody_<?php echo $joID; ?>_' + idx + '"></tbody>' +
                                '</table>' +
                                '<div id="addCriteriaLink_<?php echo $joID; ?>_' + idx + '" style="margin-top:4px; margin-bottom:10px;">' +
                                    '<a href="javascript:void(0);" onclick="showAddCriteria_<?php echo $joID; ?>(' + idx + ');">' +
                                        '<img src="images/actions/add_small.gif" border="0"/>&nbsp;Add criteria to ' + stageName +
                                    '</a>' +
                                '</div>' +
                                '<div id="addCriteriaArea_<?php echo $joID; ?>_' + idx + '" style="display:none; margin-top:4px; margin-bottom:10px;">' +
                                    '<input id="addCriteriaInput_<?php echo $joID; ?>_' + idx + '" type="text" class="inputbox" style="width:220px;" ' +
                                        'onkeypress="if(event.keyCode==13){doAddCriteria_<?php echo $joID; ?>(' + idx + ');return false;}"/>' +
                                    '<input type="button" class="button" value="Add Criteria" onclick="doAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                    '<input type="button" class="button" value="Cancel" onclick="hideAddCriteria_<?php echo $joID; ?>(' + idx + ');"/>' +
                                '</div>';

                            input.value = '';
                            document.getElementById('addStageArea_<?php echo $joID; ?>').style.display = 'none';
                            document.getElementById('addStageLink_<?php echo $joID; ?>').style.display  = '';
                            appendCommand_<?php echo $joID; ?>('ADDSTAGE ' + encodeURIComponent(stageName));
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
                                    <?php if (!$hasTpl): ?>
                                        <span style="color:#888; font-size:0.85em; margin-left:8px;">
                                            (no saved template yet — Generic Template used at runtime)
                                        </span>
                                    <?php endif; ?>
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
                                               onclick="deleteStage_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo json_encode($stage['stage_name']); ?>);">
                                                <img src="images/actions/delete.gif" border="0" />
                                            </a>&nbsp;<?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?>
                                        </td>
                                        <td>
                                            <table id="criteriaTable_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" width="380" class="searchTable">
                                                <thead>
                                                    <tr>
                                                        <th width="30"></th>
                                                        <th align="left">Criteria</th>
                                                    </tr>
                                                </thead>
                                                <?php foreach ($stage['criteria'] as $criteriaIdx => $criterion): ?>
                                                <tr class="<?php echo ($criteriaIdx % 2 === 0) ? 'evenTableRow' : 'oddTableRow'; ?>"
                                                    id="criteriaRow_<?php echo $joID; ?>_<?php echo $stageIdx; ?>_<?php echo $criteriaIdx; ?>">
                                                    <td>
                                                        <a href="javascript:void(0);"
                                                           onclick="deleteCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>, <?php echo $criteriaIdx; ?>, <?php echo json_encode($criterion['criteria_name']); ?>);">
                                                            <img src="images/actions/delete.gif" border="0" />
                                                        </a>
                                                    </td>
                                                    <td><?php echo htmlspecialchars($criterion['criteria_name'], ENT_QUOTES, 'UTF-8'); ?></td>
                                                </tr>
                                                <?php endforeach; ?>
                                                <tbody id="criteriaBody_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"></tbody>
                                            </table>

                                            <div id="addCriteriaLink_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="margin-top:4px; margin-bottom:10px;">
                                                <a href="javascript:void(0);"
                                                   onclick="showAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>);">
                                                    <img src="images/actions/add_small.gif" border="0" />&nbsp;Add criteria to <?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?>
                                                </a>
                                            </div>

                                            <div id="addCriteriaArea_<?php echo $joID; ?>_<?php echo $stageIdx; ?>" style="display:none; margin-top:4px; margin-bottom:10px;">
                                                <input id="addCriteriaInput_<?php echo $joID; ?>_<?php echo $stageIdx; ?>"
                                                       type="text" class="inputbox" style="width:220px;"
                                                       onkeypress="if(event.keyCode==13){ doAddCriteria_<?php echo $joID; ?>(<?php echo $stageIdx; ?>); return false; }" />
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
                                        <img src="images/actions/add_small.gif" border="0" />&nbsp;Add an interview stage
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
                                       onclick="submitTemplate_<?php echo $joID; ?>();" />
                            </td>
                        </tr>

                    </table>

                    <?php endforeach; ?>

                </td>
            </tr>

        </table>

    </div>
</div>

<?php TemplateUtility::printFooter(); ?>