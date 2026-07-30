<?php /* $Id: Show.tpl 3814 2007-12-06 17:54:28Z brian $ */
include_once('./vendor/autoload.php');
use OpenCATS\UI\QuickActionMenu;
?>
<?php if ($this->isPopup): ?>
    <?php TemplateUtility::printHeader('Job Order - ' . $this->data['title'], array('js/sorttable.js', 'js/match.js', 'js/pipeline.js', 'js/attachment.js','js/dataGrid.js','js/dataGridFilters.js')); ?>
<?php else: ?>
    <?php TemplateUtility::printHeader('Job Order - ' . $this->data['title'], array( 'js/sorttable.js', 'js/match.js', 'js/pipeline.js', 'js/attachment.js','js/dataGrid.js','js/dataGridFilters.js')); ?>
    <script>
    var isDateDMY = <?php echo $_SESSION['CATS']->isDateDMY() ? 'true' : 'false'; ?>;
    </script>
    <?php TemplateUtility::printHeaderBlock(); ?>
    <?php TemplateUtility::printTabs($this->active); ?>
        <div id="main">
            <?php TemplateUtility::printQuickSearch(); ?>
<?php endif; ?>

<script type="text/javascript">
  window.isPipelineFilterPage = true;
    filterDropDownRegistry['Source'] = [
        <?php foreach ($this->sourcesRS as $i => $s): ?>
            { value: '<?php echo addslashes($s['name']); ?>', label: '<?php echo addslashes($s['name']); ?>' }<?php echo ($i < count($this->sourcesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    filterDropDownRegistry['Recent Status'] = [
        <?php foreach ($this->statusesRS as $i => $s): ?>
            { value: '<?php echo addslashes($s['optionValue']); ?>', label: '<?php echo addslashes($s['optionLabel']); ?>' }<?php echo ($i < count($this->statusesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    
    filterIsInRegistry['Source'] = [
        <?php if (!empty($this->pipelineSourcesIsIn)): foreach ($this->pipelineSourcesIsIn as $i => $s): ?>
            { value: '<?php echo addslashes($s['val']); ?>', label: '<?php echo addslashes($s['val']); ?>' }<?php echo ($i < count($this->pipelineSourcesIsIn) - 1) ? ',' : ''; ?>
        <?php endforeach; endif; ?>
    ];
    filterIsInRegistry['Recent Status'] = [
        <?php if (!empty($this->pipelineStatusesIsIn)): foreach ($this->pipelineStatusesIsIn as $i => $s): ?>
            { value: '<?php echo addslashes($s['val']); ?>', label: '<?php echo addslashes($s['label']); ?>' }<?php echo ($i < count($this->pipelineStatusesIsIn) - 1) ? ',' : ''; ?>
        <?php endforeach; endif; ?>
    ];
    filterDateRangeRegistry['Created'] = true;
    filterDateRangeRegistry['Modified'] = true;
    filterDateRangeRegistry['Added'] = true;

</script>
<script type="text/javascript">
function pipelineColumnBox_toggle() {
    var box = document.getElementById('pipelineColumnBox');
    if (!box) return;
    box.style.display = (box.style.display === 'block') ? 'none' : 'block';
}
function pipelineColumnBox_close(e) {
    var box = document.getElementById('pipelineColumnBox');
    if (!box) return;
    var icon = document.getElementById('pipelineColumnIcon');
    if (icon && icon.contains(e.target)) return;
    if (box.contains(e.target)) return;
    box.style.display = 'none';
}
function pipelineToggleColumn(col, action) {
    var http = (window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject("Microsoft.XMLHTTP"));
    var filterString = document.getElementById('filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>')
                       ? document.getElementById('filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>').value
                       : '';
    var POSTData  = '&joborderID=<?php $this->_(isset($this->data['jobOrderID']) ? $this->data['jobOrderID'] : 0); ?>';
        POSTData += '&page=0';
        POSTData += '&entriesPerPage=<?php $this->_($this->pipelineEntriesPerPage); ?>';
        POSTData += '&sortBy=dateCreatedInt';
        POSTData += '&sortDirection=desc';
        POSTData += '&indexFile=<?php echo CATSUtility::getIndexName(); ?>';
        POSTData += '&isPopup=<?php echo $this->isPopup ? 1 : 0; ?>';
        POSTData += '&filterString=' + encodeURIComponent(filterString);
        POSTData += '&setColumn='  + encodeURIComponent(col);
        POSTData += '&colAction='  + encodeURIComponent(action);
    document.getElementById('ajaxPipelineTableIndicator').style.display = '';
    AJAX_callCATSFunction(
        http, 'getPipelineJobOrder', POSTData,
        function () {
            if (http.readyState != 4) return;
            document.getElementById('ajaxPipelineTableIndicator').style.display = 'none';
            document.getElementById('ajaxPipelineTable').innerHTML = http.responseText;
            execJS(http.responseText);
        },
        55000, '<?php echo $this->sessionCookie; ?>', false, false
    );
}
document.addEventListener('click', pipelineColumnBox_close);
</script>
<input type="hidden"
    id="filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>"
    value="<?php echo htmlspecialchars($this->savedPipelineFilter); ?>" />

        <div id="contents">
            <table>
                <tr>
                    <td width="3%">
                        <img src="images/job_orders.gif" width="24" height="24" border="0" alt="Job Orders" style="margin-top: 3px;" />&nbsp;
                    </td>
                    <td><h2>Job Orders: Job Order Details</h2></td>
                </tr>
            </table>

            <p class="note">Job Order Details</p>

            <?php if ($this->data['isAdminHidden'] == 1): ?>
                <div class="warning">
                    This Job Order is hidden.  Only Site Administrators can view it or search for it.  To make it visible by the site users, click
                    <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&amp;a=administrativeHideShow" style="display:inline;">
                        <input type="hidden" name="postback" value="postback" />
                        <input type="hidden" name="jobOrderID" value="<?php echo Template::escapeAttr($this->jobOrderID); ?>" />
                        <input type="hidden" name="state" value="0" />
                        <button type="submit" class="linkButton">Here.</button>
                    </form>
                </div>
            <?php endif; ?>

            <?php if (isset($this->frozen)): ?>
                <table style="font-weight:bold; border: 1px solid #000; background-color: #ffed1a; padding:5px; margin-bottom:7px;" width="100%" id="candidateAlreadyInSystemTable">
                    <tr>
                        <td class="tdVertical">
                            This Job Order is <?php $this->_($this->data['status']); ?> and can not be modified.
                           <?php if ($this->getUserAccessLevel('joborders.edit') >= ACCESS_LEVEL_EDIT): ?>
                               <a id="edit_link" href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=joborders&a=edit&jobOrderID=' . $this->jobOrderID); ?>">
                                   <img src="images/actions/edit.gif" width="16" height="16" class="absmiddle" alt="edit" border="0" />&nbsp;Edit
                               </a>
                               the Job Order to make it Active.&nbsp;&nbsp;
                           <?php endif; ?>
                        </td>
                    </tr>
                </table>
            <?php endif; ?>

            <table class="detailsOutside" width="100%" height="<?php echo((count($this->extraFieldRS)/2 + 12) * 22); ?>">
                <tr style="vertical-align:top;">
                    <td width="50%" height="100%">
                        <table class="detailsInside" height="100%">
                            <tr>
                                <td class="vertical">Title:</td>
                                <td class="data" width="300">
                                    <span class="<?php echo Template::escapeAttr($this->data['titleClass']); ?>"><?php $this->_($this->data['title']); ?></span>
                                    <?php echo($this->data['public']) ?>
                                    <?php TemplateUtility::printSingleQuickActionMenu(new QuickActionMenu(DATA_ITEM_JOBORDER, $this->data['jobOrderID'], $_SESSION['CATS']->getAccessLevel('joborders.edit'))); ?>
                                </td>
                            </tr>

                            <tr>
                                <td class="vertical">Company Name:</td>
                                <td class="data">
                                    <a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=companies&a=show&companyID=' . $this->data['companyID']); ?>">
                                        <?php $this->_($this->data['companyName']); ?>
                                    </a>
                                </td>
                            </tr>

                            <tr>
                                <td class="vertical">Department:</td>
                                <td class="data">
                                    <?php $this->_($this->data['department']); ?>
                                </td>
                            </tr>

                            <tr>
                                <td class="vertical">CATS Job ID:</td>
                                <td class="data" width="300"><?php $this->_($this->data['jobOrderID']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Company Job ID:</td>
                                <td class="data"><?php $this->_($this->data['companyJobID']); ?></td>
                            </tr>

                            <!-- CONTACT INFO -->
                            <tr>
                                <td class="vertical">Contact Name:</td>
                                <td class="data">
                                    <a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=contacts&a=show&contactID=' . $this->data['contactID']); ?>">
                                        <?php $this->_($this->data['contactFullName']); ?>
                                    </a>
                                </td>
                            </tr>

                            <tr>
                                <td class="vertical">Contact Phone:</td>
                                <td class="data"><?php $this->_($this->data['contactWorkPhone']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Contact Email:</td>
                                <td class="data">
                                    <a href="<?php echo Template::escapeUrl('mailto:' . $this->data['contactEmail']); ?>"><?php $this->_($this->data['contactEmail']); ?></a>
                                </td>
                            </tr>
                            <!-- /CONTACT INFO -->

                            <tr>
                                <td class="vertical">Location:</td>
                                <td class="data"><?php $this->_($this->data['cityAndState']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Max Rate:</td>
                                <td class="data"><?php $this->_($this->data['maxRate']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Salary:</td>
                                <td class="data"><?php $this->_($this->data['salary']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Start Date:</td>
                                <td class="data"><?php $this->_($this->data['startDate']); ?></td>
                            </tr>

                            <?php for ($i = 0; $i < intval(count($this->extraFieldRS)/2); $i++): ?>
                               <?php if(($this->extraFieldRS[$i]['extraFieldType']) != EXTRA_FIELD_TEXTAREA): ?>
                                   <tr>
                                        <td class="vertical"><?php $this->_($this->extraFieldRS[$i]['fieldName']); ?>:</td>
                                        <td class="data"><?php echo($this->extraFieldRS[$i]['display']); ?></td>
                                   </tr>
                                <?php endif; ?>
                            <?php endfor; ?>

                            <?php eval(Hooks::get('JO_TEMPLATE_SHOW_BOTTOM_OF_LEFT')); ?>

                        </table>
                    </td>

                    <td width="50%" height="100%" style="vertical-align:top;" >
                        <table class="detailsInside" height="100%">
                            <tr>
                                <td class="vertical">Duration:</td>
                                <td class="data"><?php $this->_($this->data['duration']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Openings:</td>
                                <td class="data"><?php $this->_($this->data['openings']); if ($this->data['openingsAvailable'] != $this->data['openings']): ?> (<?php $this->_($this->data['openingsAvailable']); ?> Available)<?php endif; ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Type:</td>
                                <td class="data"><?php $this->_($this->data['typeDescription']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Status:</td>
                                <td class="data"><?php $this->_($this->data['status']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Candidates:</td>
                                <td class="data"><?php $this->_($this->data['pipeline']) ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Submitted:</td>
                                <td class="data"><?php $this->_($this->data['submitted']) ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Days Old:</td>
                                <td class="data"><?php $this->_($this->data['daysOld']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Created:</td>
                                <td class="data"><?php $this->_($this->data['dateCreated']); ?> (<?php $this->_($this->data['enteredByFullName']); ?>)</td>
                            </tr>

                            <tr>
                                <td class="vertical">Recruiter:</td>
                                <td class="data"><?php $this->_($this->data['recruiterFullName']); ?></td>
                            </tr>

                            <tr>
                                <td class="vertical">Owner:</td>
                                <td class="data"><?php $this->_($this->data['ownerFullName']); ?></td>
                            </tr>

                            <?php for ($i = (intval(count($this->extraFieldRS))/2); $i < (count($this->extraFieldRS)); $i++): ?>
                                <?php if(($this->extraFieldRS[$i]['extraFieldType']) != EXTRA_FIELD_TEXTAREA): ?>
                                    <tr>
                                        <td class="vertical"><?php $this->_($this->extraFieldRS[$i]['fieldName']); ?>:</td>
                                        <td class="data"><?php echo($this->extraFieldRS[$i]['display']); ?></td>
                                    </tr>
                                <?php endif; ?>
                            <?php endfor; ?>

                            <?php eval(Hooks::get('JO_TEMPLATE_SHOW_BOTTOM_OF_RIGHT')); ?>
                        </table>
                    </td>
                </tr>
            </table>

            <?php if ($this->isPublic): ?>
            <div style="background-color: #E6EEFE; padding: 10px; margin: 5px 0 12px 0; border: 1px solid #728CC8;">
                <b>This job order is public<?php if ($this->careerPortalURL === false): ?>.</b><?php else: ?>
                    and will be shown on your
                    <?php if ($this->getUserAccessLevel('joborders.careerPortalUrl') >= ACCESS_LEVEL_SA): ?>
                        <a style="font-weight: bold;" href="<?php echo Template::escapeUrl($this->careerPortalURL); ?>">Careers Website</a>.
                    <?php else: ?>
                        Careers Website.
                    <?php endif; ?></b>
                <?php endif; ?>

                <?php if ($this->questionnaireID !== false): ?>
                    <br />Applicants must complete the "<i><?php $this->_($this->questionnaireData['title']); ?></i>" (<a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=settings&a=careerPortalQuestionnaire&questionnaireID=' . $this->questionnaireID); ?>">edit</a>) questionnaire when applying.
                <?php else: ?>
                    <br />You have not attached any
                    <?php if ($this->getUserAccessLevel('setting.carrerPortalSettings') >= ACCESS_LEVEL_SA): ?>
                        <a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=settings&a=careerPortalSettings'); ?>">Questionnaires</a>.
                    <?php else: ?>
                        Questionnaires.
                    <?php endif; ?>
                <?php endif; ?>
            </div>
            <?php endif; ?>

            <table class="detailsOutside">
                <tr>
                    <td>
                        <table class="detailsInside">
                            <tr>
                                <td valign="top" class="vertical">Attachments:</td>
                                <td valign="top" class="data">
                                    <table class="attachmentsTable">
                                        <?php foreach ($this->attachmentsRS as $rowNumber => $attachmentsData): ?>
                                            <tr>
                                                <td>
                                                    <?php echo $attachmentsData['retrievalLink']; ?>
                                                        <img src="<?php echo Template::escapeUrl($attachmentsData['attachmentIcon']); ?>" alt="" width="16" height="16" border="0" />
                                                        &nbsp;
                                                        <?php $this->_($attachmentsData['originalFilename']) ?>
                                                    </a>
                                                </td>
                                                <td><?php $this->_($attachmentsData['dateCreated']) ?></td>
                                                <td>
                                                    <?php if (!$this->isPopup): ?>
                                                        <?php if ($this->getUserAccessLevel('joborders.deleteAttachment') >= ACCESS_LEVEL_DELETE): ?>
                                                            <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&amp;a=deleteAttachment" style="display:inline;" onsubmit="return confirm('Delete this attachment?');">
                                                                <input type="hidden" name="postback" value="postback" />
                                                                <input type="hidden" name="jobOrderID" value="<?php echo Template::escapeAttr($this->jobOrderID); ?>" />
                                                                <input type="hidden" name="attachmentID" value="<?php echo Template::escapeAttr($attachmentsData['attachmentID']); ?>" />
                                                                <input type="image" src="images/actions/delete.gif" alt="" width="16" height="16" border="0" />
                                                            </form>
                                                        <?php endif; ?>
                                                    <?php endif; ?>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </table>
                                    <?php if (!$this->isPopup): ?>
                                        <?php if ($this->getUserAccessLevel('joborders.createAttachment') >= ACCESS_LEVEL_EDIT): ?>
                                            <?php if (isset($this->attachmentLinkHTML)): ?>
                                                <?php echo($this->attachmentLinkHTML); ?>
                                            <?php else: ?>
                                                <a href="#" onclick="showPopWin(<?php echo Template::escapeJsAttr(CATSUtility::getIndexName() . '?m=joborders&a=createAttachment&jobOrderID=' . $this->jobOrderID); ?>, 400, 125, null); return false;">
                                            <?php endif; ?>
                                                <img src="images/paperclip_add.gif" width="16" height="16" border="0" alt="add attachment" class="absmiddle" />&nbsp;Add Attachment
                                            </a>
                                        <?php endif; ?>
                                    <?php endif; ?>
                                </td>
                            </tr>

                            <tr>
                                <td valign="top" class="vertical">Description:</td>

                                <td class="data" colspan="2">
                                    <?php if($this->data['description'] != ''): ?>
                                    <div id="shortDescription" style="overflow: auto; height:170px; border: #AAA 1px solid; padding:5px;">
                                        <?php echo($this->data['description']); ?>
                                    </div>
                                    <?php endif; ?>
                                </td>

                            </tr>
                
                            <?php for ($i = (intval(count($this->extraFieldRS))/2); $i < (count($this->extraFieldRS)); $i++): ?>
                                <?php if(($this->extraFieldRS[$i]['extraFieldType']) == EXTRA_FIELD_TEXTAREA): ?>
                                    <tr>
                                        <td class="vertical"><?php $this->_($this->extraFieldRS[$i]['fieldName']); ?>:</td>
                                        <td class="data"><?php echo($this->extraFieldRS[$i]['display']); ?></td>
                                    </tr>
                                <?php endif; ?>
                            <?php endfor; ?>

                            <tr>
                                <td valign="top" class="vertical">Internal Notes:</td>

                                <td class="data" style="width:320px;">
                                    <?php if($this->data['notes'] != ''): ?>
                                        <div id="shortDescription" style="overflow: auto; height:240px; border: #AAA 1px solid; padding:5px;">
                                            <?php echo($this->data['notes']); ?>
                                        </div>
                                    <?php endif; ?>
                                </td>

                                <td style="vertical-align:top;">
                                    <?php echo($this->pipelineGraph);  ?>
                                </td>

                            </tr>
                            <tr>
                                <td valign="top" class="vertical">
                                    Evaluation Template:
                                    <?php if ($this->getUserAccessLevel('joborders.edit') >= ACCESS_LEVEL_EDIT): ?>
                                        <br /><a href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=settings&a=customizeEvaluationTemplate&jobOrderID=' . $this->jobOrderID); ?>">[Edit]</a>
                                    <?php endif; ?>
                                </td>
                                <td class="data" colspan="2">
                                    <?php if (empty($this->evaluationStages)): ?>
                                        <span style="color:#888;">No evaluation stages defined yet.</span>
                                    <?php else: ?>
                                        <ul style="margin:0 0 0 18px; padding:0;">
                                            <?php foreach ($this->evaluationStages as $stage): ?>
                                                <li>
                                                    <strong><?php echo htmlspecialchars($stage['stage_name'], ENT_QUOTES, 'UTF-8'); ?></strong>
                                                    <?php if (!empty($stage['criteria'])): ?>
                                                        <?php
                                                            $criteriaNames = array_map(function ($c) {
                                                                return htmlspecialchars($c['criteria_name'], ENT_QUOTES, 'UTF-8');
                                                            }, $stage['criteria']);
                                                        ?>
                                                    : <?php echo implode(', ', $criteriaNames); ?>
                                                    <?php else: ?>
                                                        <span style="color:#888;">(no criteria)</span>
                                                    <?php endif; ?>
                                                </li>
                                            <?php endforeach; ?>
                                        </ul>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
<?php if (!$this->isPopup): ?>
            <div id="actionbar">
                <span style="float:left;">
                    <?php if ($this->getUserAccessLevel('joborders.edit') >= ACCESS_LEVEL_EDIT): ?>
                        <a id="edit_link" href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=joborders&a=edit&jobOrderID=' . $this->jobOrderID); ?>">
                            <img src="images/actions/edit.gif" width="16" height="16" class="absmiddle" alt="edit" border="0" />&nbsp;Edit
                        </a>
                        &nbsp;&nbsp;&nbsp;&nbsp;
                    <?php endif; ?>
                    <?php if ($this->getUserAccessLevel('joborders.delete') >= ACCESS_LEVEL_DELETE): ?>
                        <form id="delete_link" method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&amp;a=delete" style="display:inline;" onsubmit="return confirm('Delete this job order?');">
                            <input type="hidden" name="postback" value="postback" />
                            <input type="hidden" name="jobOrderID" value="<?php echo Template::escapeAttr($this->jobOrderID); ?>" />
                            <button type="submit" class="linkButton">
                                <img src="images/actions/delete.gif" width="16" height="16" class="absmiddle" alt="delete" border="0" />&nbsp;Delete
                            </button>
                        </form>
                        &nbsp;&nbsp;&nbsp;&nbsp;
                    <?php endif; ?>
                    <?php if ($this->getUserAccessLevel('joborders.hidden') >= ACCESS_LEVEL_SA): ?>
                        <?php if ($this->data['isAdminHidden'] == 1): ?>
                            <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&amp;a=administrativeHideShow" style="display:inline;">
                                <input type="hidden" name="postback" value="postback" />
                                <input type="hidden" name="jobOrderID" value="<?php echo Template::escapeAttr($this->jobOrderID); ?>" />
                                <input type="hidden" name="state" value="0" />
                                <button type="submit" class="linkButton">
                                    <img src="images/resume_preview_inline.gif" width="16" height="16" class="absmiddle" alt="delete" border="0" />&nbsp;Administrative Show
                                </button>
                            </form>
                            <?php else: ?>
                            <form method="post" action="<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&amp;a=administrativeHideShow" style="display:inline;">
                                <input type="hidden" name="postback" value="postback" />
                                <input type="hidden" name="jobOrderID" value="<?php echo Template::escapeAttr($this->jobOrderID); ?>" />
                                <input type="hidden" name="state" value="1" />
                                <button type="submit" class="linkButton">
                                    <img src="images/resume_preview_inline.gif" width="16" height="16" class="absmiddle" alt="delete" border="0" />&nbsp;Administrative Hide
                                </button>
                            </form>
                        <?php endif; ?>
                        &nbsp;&nbsp;&nbsp;&nbsp;
                    <?php endif; ?>
                </span>
                <span style="float:right;">
                    <?php if (!empty($this->data['public']) && $this->careerPortalEnabled): ?>
                        <a id="public_link" href="<?php echo Template::escapeUrl(CATSUtility::getAbsoluteURI() . 'careers/' . CATSUtility::getIndexName() . '?p=showJob&ID=' . $this->jobOrderID); ?>">
                            <img src="images/public.gif" width="16" height="16" class="absmiddle" alt="Online Application" border="0" />&nbsp;Online Application
                        </a>
                        &nbsp;&nbsp;&nbsp;&nbsp;
                    <?php endif; ?>
                    <?php /* TODO: Make report available for every site. */ ?>
                    <a id="report_link" href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=reports&a=customizeJobOrderReport&jobOrderID=' . $this->jobOrderID); ?>">
                        <img src="images/reportsSmall.gif" width="16" height="16" class="absmiddle" alt="report" border="0" />&nbsp;Generate Report
                    </a>
                    <?php if ($this->privledgedUser): ?>
                        &nbsp;&nbsp;&nbsp;&nbsp;
                        <a id="history_link" href="<?php echo Template::escapeUrl(CATSUtility::getIndexName() . '?m=settings&a=viewItemHistory&dataItemType=400&dataItemID=' . $this->jobOrderID); ?>">
                            <img src="images/icon_clock.gif" width="16" height="16" class="absmiddle"  border="0" />&nbsp;View History
                        </a>
                    <?php endif; ?>
                </span>
            </div>
<?php endif; ?>
            <br clear="all" />
            <br />

            <p class="note">Candidate in Job Order</p>
            <span style="float:right;">
    <?php $this->dataGrid->drawShowFilterControl(); ?>
</span><br>
          <?php $this->dataGrid->drawFilterArea(); ?>
            <script type="text/javascript">
            var pipelineDataGridFilterID =
                'filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>';
            submitFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?> = function(retainFilterVisible) {
                var filterAreaEl = document.getElementById(pipelineDataGridFilterID);
                var filterString = filterAreaEl ? filterAreaEl.value : '';
                var md5 = '<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>';
                var tableID = 'filterResultsAreaTable' + md5;
                var table = document.getElementById(tableID);
                if (table) {
                    table.innerHTML = '';
                    if (filterString !== '') {
                        var filters = filterString.split(',');
                        var counter = 0;
                        filters.forEach(function(f) {
                            var eqPos = f.indexOf('=');
                            if (eqPos === -1) return;
                            var col = decodeURIComponent(f.substring(0, eqPos));
                         var opLen = (f.substr(eqPos, 3) === '=d>' || f.substr(eqPos, 3) === '=d<' || f.substr(eqPos, 3) === '=in') ? 3 : 2;
var op = f.substring(eqPos, eqPos + opLen);
var val = decodeURIComponent(f.substring(eqPos + opLen));
var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than','=d>':'from','=d<':'to','=in':'is in','=e':'is empty'};
                            var span = document.createElement('span');
                            span.className = 'filterArea';
                            span.innerHTML = '<a href="javascript:void(0);" onclick="this.parentNode.style.display=\'none\'; removeColumnFromFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\'); submitFilter' + md5 + '();">'
                                + '<img src="images/actions/delete_small.gif" style="padding:0px;margin:0px;" border="0" title="Remove this Filter" /></a>&nbsp;'
                                + '\'' + col + '\' ' + (opNames[op] || op) + ': '
                            + '<select id="filterResultsAreaTable' + md5 + (counter+1) + 'columnName" disabled="disabled" class="inputbox" style="display:none;"><option value="' + col + '!@!===~">' + col + '</option></select>'
                                + (op === '=e' ? '' : '<input class="inputbox" style="width:180px;" value="' + val + '" onchange="addColumnToFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\', \'' + op + '\', this.value); submitFilter' + md5 + '();" />');
                            table.appendChild(span);
                            counter++;
                        });
                        newFilterCounter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?> = counter;
                        } else {
                        newFilterCounter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?> = 0;
                        var filterArea = document.getElementById('filterResultsArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>');
                        if (filterArea) filterArea.style.display = '';
                        showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
                    }
                }
                PipelineJobOrder_populate(
                    <?php $this->_($this->data['jobOrderID']); ?>,
                    0,
                    <?php $this->_($this->pipelineEntriesPerPage); ?>,
                    'dateCreatedInt', 'desc',
                    <?php if ($this->isPopup) echo(1); else echo(0); ?>,
                    'ajaxPipelineTable',
                    '<?php echo($this->sessionCookie); ?>',
                    'ajaxPipelineTableIndicator',
                    '<?php echo(CATSUtility::getIndexName()); ?>'
                );
            };
            var originalClearFilter = clearFilter;
            clearFilter = function(filterElementID) {
                originalClearFilter(filterElementID);
                var tableID = 'filterResultsAreaTable<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>';
                var table = document.getElementById(tableID);
                if (table) table.innerHTML = '';
                newFilterCounter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?> = 0;
                showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
            };
            var originalShowNewFilter = showNewFilter;
            showNewFilter = function(counter, tableID, arrayKeys, md5) {
                originalShowNewFilter(counter, tableID, arrayKeys, md5);
                setTimeout(function() {
                    var selects = document.querySelectorAll('[id^="filterResultsAreaTable' + md5 + '"][id$="columnOperator"]');
                    selects.forEach(function(sel) {
                        for (var i = 0; i < sel.options.length; i++) {
                            if (sel.options[i].value === '=e') return;
                        }
                        var opt = document.createElement('option');
                        opt.value = '=e';
                        opt.text = 'is empty';
                        sel.appendChild(opt);
                    });
                }, 0);
            };
            <?php if (!empty($this->savedPipelineFilter)): ?>
            submitFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>(true);
            <?php else: ?>
            showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
            <?php endif; ?>
            </script>

            <p id="ajaxPipelineControl">
                Number of visible entries:&nbsp;&nbsp;
                <select id="numberOfEntriesSelect" onchange="PipelineJobOrder_changeLimit(<?php $this->_($this->data['jobOrderID']); ?>, this.value, <?php if ($this->isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', <?php echo Template::escapeJsAttr($this->sessionCookie); ?>, 'ajaxPipelineTableIndicator', <?php echo Template::escapeJsAttr(CATSUtility::getIndexName()); ?>);" class="selectBox">
                    <option value="15" <?php if ($this->pipelineEntriesPerPage == 15): ?>selected<?php endif; ?>>15 entries</option>
                    <option value="30" <?php if ($this->pipelineEntriesPerPage == 30): ?>selected<?php endif; ?>>30 entries</option>
                    <option value="50" <?php if ($this->pipelineEntriesPerPage == 50): ?>selected<?php endif; ?>>50 entries</option>
                    <option value="99999" <?php if ($this->pipelineEntriesPerPage == 99999): ?>selected<?php endif; ?>>All entries</option>
                </select>&nbsp;
                <span id="ajaxPipelineNavigation">
                </span>&nbsp;
                <img src="images/indicator.gif" alt="" id="ajaxPipelineTableIndicator" />
            </p>

            <div id="ajaxPipelineTable"></div>
            <input type="checkbox" name="select_all" onclick="selectAll_candidates(this)" title="Select all candidates" /> <a href="javascript:void(0);" onclick="exportFromPipeline()" title="Export selected candidates">Export</a>&nbsp;|&nbsp;<a href="javascript:void(0);" onclick="exportAllFromPipeline()" title="Export all candidates matching the current filter">All</a>&nbsp;&nbsp;&nbsp;&nbsp;
            <script type="text/javascript">

            function exportFromPipeline() {
                var ids = getSelected_candidates();
                if (ids.length > 0) {
                    window.location.href = '<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&a=exportPipeline&jobOrderID=<?php echo($this->data['jobOrderID']); ?>&candidateIDs=' + (serializeArray(ids));
                } else {
                    alert('No data selected');
                }
            }

            function exportAllFromPipeline() {
                var filterAreaEl = document.getElementById(pipelineDataGridFilterID);
                var filterString = filterAreaEl ? filterAreaEl.value : '';
                window.location.href = '<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&a=exportPipeline&jobOrderID=<?php echo($this->data['jobOrderID']); ?>&exportAll=1&filterString=' + encodeURIComponent(filterString);
            }

            PipelineJobOrder_populate(<?php $this->_($this->data['jobOrderID']); ?>, 0, <?php $this->_($this->pipelineEntriesPerPage); ?>, 'dateCreatedInt', 'desc', <?php if ($this->isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', <?php echo Template::escapeJs($this->sessionCookie); ?>, 'ajaxPipelineTableIndicator', <?php echo Template::escapeJs(CATSUtility::getIndexName()); ?>);
            </script>

            <?php if (!$this->isPopup): ?>
            <?php if ($this->getUserAccessLevel('joborders.considerCandidateSearch') >= ACCESS_LEVEL_EDIT && !isset($this->frozen)): ?>
                <a href="#" onclick="showPopWin(<?php echo Template::escapeJsAttr(CATSUtility::getIndexName() . '?m=joborders&a=considerCandidateSearch&jobOrderID=' . $this->jobOrderID); ?>, 820, 550, null); return false;">
                    <img src="images/consider.gif" width="16" height="16" class="absmiddle" alt="add candidate" border="0" />&nbsp;Add Candidate to This Job Order
                </a>
            <?php endif; ?>
        </div>
    </div>

<?php endif; ?>
<?php TemplateUtility::printFooter(); ?>
