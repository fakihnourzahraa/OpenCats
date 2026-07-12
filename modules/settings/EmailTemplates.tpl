<?php /* $Id: EmailTemplates.tpl 1929 2007-02-22 06:18:30Z will $ */ ?>
<?php TemplateUtility::printHeader('Settings', array()); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active, $this->subActive); ?>
    <div id="main">
        <?php TemplateUtility::printQuickSearch(); ?>

        <div id="contents">
            <table>
                <tr>
                    <td width="3%">
                        <img src="images/settings.gif" width="24" height="24" border="0" alt="Settings" style="margin-top: 3px;" />&nbsp;
                    </td>
                    <td><h2>Administration: E-Mail Templates</h2></td>
                </tr>
            </table>

            <p class="note">E-Mail Templates</p>

            <script type="text/javascript">
            <?php
                $statusChangeMainID=0;
                foreach ($this->emailTemplatesRS as $_tpl)
                {
                    if ($_tpl['emailTemplateTag'] == 'EMAIL_TEMPLATE_STATUSCHANGE')
                    {
                        $statusChangeMainID = (int) $_tpl['emailTemplateID'];
                        break;
                    }
                }
            ?>
            var STATUS_CHANGE_TEMPLATE_ID = <?php echo $statusChangeMainID; ?>;
            $(document).ready(function() { 
                $("select option:last").attr("selected", "selected");
                showTemplate(document.getElementById('titleSelect').value);
            });


            function hideAllStatusSubForms()
            {
                <?php foreach ($this->candidateStatusesRS as $status): ?>
                    var _el = document.getElementById('editTableStatus_<?php echo (int) $status['statusID']; ?>');
                    if (_el) _el.style.display = 'none';
                <?php endforeach; ?>
            }



            function showTemplate(templateID)
            {
                <?php foreach ($this->emailTemplatesRS as $data): ?>
                    document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                <?php endforeach; ?>
                hideAllStatusSubForms();
                document.getElementById('statusSubSelectorRow').style.display = 'none';
                document.getElementById('statusSubSelect').value = '';
                document.getElementById('editTable' + templateID).style.display = '';
                if (parseInt(templateID) === STATUS_CHANGE_TEMPLATE_ID)
                    document.getElementById('statusSubSelectorRow').style.display = '';
                }

                function showLastTemplate()
                {
                    <?php foreach ($this->emailTemplatesRS as $data): ?>
                        document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                    <?php endforeach; ?>
                    hideAllStatusSubForms();
                    document.getElementById('statusSubSelectorRow').style.display = 'none';

                    <?php $lastTemplateID = end($this->emailTemplatesRS)['emailTemplateID']; ?>
                    document.getElementById('editTable<?php echo $lastTemplateID; ?>').style.display = '';
                    if (<?php echo $lastTemplateID; ?> === STATUS_CHANGE_TEMPLATE_ID) {
                        document.getElementById('statusSubSelectorRow').style.display = '';
                    }
            }

            function showStatusSubTemplate(statusID)
            {
                /* Collapse the generic form and all per-status forms. */
                document.getElementById('editTable' + STATUS_CHANGE_TEMPLATE_ID).style.display = 'none';
                hideAllStatusSubForms();

            if (statusID === '') {
                    document.getElementById('editTable' + STATUS_CHANGE_TEMPLATE_ID).style.display = '';
                    return;
                }
                var target = document.getElementById('editTableStatus_' + statusID);
                if (target) target.style.display = '';
            }

                function insertAtCursor(myField, myValue)
                {
                    if (document.selection)
                    {
                        myField.focus();
                        sel = document.selection.createRange();
                        sel.text = myValue;
                    }
                    else if (myField.selectionStart || myField.selectionStart == 0)
                    {
                        var startPos = myField.selectionStart;
                        var endPos = myField.selectionEnd;
                        myField.value = myField.value.substring(0, startPos)
                            + myValue
                            + myField.value.substring(endPos, myField.value.length);
                    }
                    else
                    {
                        myField.value += myValue;
                    }
                }
                <?php function generateInsertAtCursorLink($data, $description, $value)
                {
                    echo('<input type="button" class="button" style="width:235px;" value="'.$description.'" onclick="insertAtCursor(document.getElementById(\'messageText'.$data['emailTemplateID'].'\'),  \''.$value.'\');"><br />');
                } ?>
                <?php function generateInsertAtCursorLinkConditional($data, $description, $value)
                {
                    if (strrpos($data['possibleVariables'], $value) !== false)
                    {
                        generateInsertAtCursorLink($data, $description, $value);
                    }
                } ?>
            </script>

            <table style="width:850px;" class="searchTable">
                <tr>
                    <td>
                        <input type="button" value="Add a Template" onclick="window.location='index.php?m=settings&a=addEmailTemplate'">
                    </td>
                </tr>
                <tr>
                    <td>
                        <table>
                            <tr>
                                <td style="width:210px;">
                                    <div style="font-weight:bold;">
                                        Template:
                                    </div>
                                </td>
                                <td>
                                    <span id="selectorSpan">
                                        <select id="titleSelect" style="width:550px;" onclick="showTemplate(this.value);">
                                            <?php foreach ($this->emailTemplatesRS as $data): ?>
                                                <option value="<?php echo($data['emailTemplateID']); ?>"><?php echo($data['emailTemplateTitle']); ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </span>
                                    <?php foreach ($this->emailTemplatesRS as $data): ?>
                                        <span id="templateTitleSpan<?php echo($data['emailTemplateID']); ?>" style="display:none; border:1px solid #000000; background-color:#ffffff; padding:5px;">
                                            Editing: <?php echo($data['emailTemplateTitle']); ?>
                                        </span>
                                    <?php endforeach; ?>
                                    <!--&nbsp;&nbsp;&nbsp;&nbsp;
                                    <input type="button" class="button" value="New">-->
                                </td>
                            </tr>
                              <tr id="statusSubSelectorRow" style="display:none;">
                                <td style="width:210px;">
                                    <div style="font-weight:bold;">
                                        Status:
                                    </div>
                                </td>
                                <td>
                                    <select id="statusSubSelect" style="width:550px;" onchange="showStatusSubTemplate(this.value);">
                                        <option value="">Generic </option>
                                        <?php foreach ($this->candidateStatusesRS as $status): ?>
                                            <option value="<?php echo((int) $status['statusID']);?>">
                                                <?php echo(htmlspecialchars($status['status'])); ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                    <span style="color:#666; font-size:0.85em;">
                                        &nbsp;<br>If no template is saved for a status, the generic template above is used.
                                    </span>
                                </td>
                                </tr>
                        </table>
                    </td>
                </tr>
                <tr>
                    <td>

                        <?php foreach ($this->emailTemplatesRS as $index => $data): ?>
                            <form action="<?php echo(CATSUtility::getIndexName()); ?>?m=settings&amp;a=emailTemplates" method="post">
                                <input type="hidden" name="postback" value="postback" />
                                <input type="hidden" name="templateID"  value="<?php echo($data['emailTemplateID']); ?>" />
                                <table id="editTable<?php echo($data['emailTemplateID']); ?>" class="editTable" width="850" <?php if ($index != 0): ?>style="display:none;"<?php endif; ?>>
                                    <tr>
                                        <!--<td class="tdVertical" style="width:150px;">
                                            Email Tag:
                                        </td>
                                        <td class="tdData">
                                            <?php echo($data['emailTemplateTag']); ?>
                                        </td>-->
                                    </tr>
                                    <tr>
                                        <td class="tdVertical" style="width:150px;">
                                            Message:
                                        </td>
                                        <td class="tdData">
                                            <table>
                                                <?php if(strpos($data['emailTemplateTag'], "CUSTOM") === 0): ?>
                                                <tr>
                                                    <td>
                                                        <input type="text" name="emailTemplateTitle" value="<?php echo($data['emailTemplateTitle']); ?>"/>
                                                        <input type="button" value="Delete Template" onclick="window.location='index.php?m=settings&a=deleteEmailTemplate&id=<?php echo $data['emailTemplateID']?>'">
                                                    </td>
                                                </tr>
                                                <?php endif; ?>
                                                
                                                <tr style="vertical-align:top;">
                                                    <td>
                                                        <textarea class="inputbox" name="messageText" <?php if ($data['disabled'] == 1) echo('disabled'); ?> id="messageText<?php echo($data['emailTemplateID']); ?>" style="width:450px; height:280px;" onclick="document.getElementById('selectorSpan').style.display='none'; document.getElementById('templateTitleSpan<?php echo($data['emailTemplateID']); ?>').style.display='';" ><?php echo($this->_($data['text'])); ?></textarea>
                                                        <input type="hidden" name="messageTextOrigional" id="messageTextOrigional<?php echo($data['emailTemplateID']); ?>" value="<?php echo($this->_($data['text'])); ?>">
                                                        <br /><br />
                                                        <input type="checkbox" name="useThisTemplate" id="useThisTemplate<?php echo($data['emailTemplateID']); ?>" <?php if ($data['disabled'] == 0) echo('checked'); ?> onclick="if (this.checked) {document.getElementById('messageText<?php echo($data['emailTemplateID']); ?>').disabled=false;} else {document.getElementById('messageText<?php echo($data['emailTemplateID']); ?>').disabled=true;} document.getElementById('selectorSpan').style.display='none'; document.getElementById('templateTitleSpan<?php echo($data['emailTemplateID']); ?>').style.display='';"> Use this Template / Feature<br />
                                                    </td>
                                                    <td style="text-align: center;">
                                                    <div style="font-weight:bold;">Insert Formatting:</div>
                                                        <?php generateInsertAtCursorLink($data, 'Bold', '<B></B>'); ?>
                                                        <?php generateInsertAtCursorLink($data, 'Italics', '<I></I>'); ?>
                                                        <?php generateInsertAtCursorLink($data, 'Underline', '<U></U>'); ?>
                                                        <br />
                                                        <div style="font-weight:bold;">Insert Mail Merge Fields:</div>
                                                        <?php /* Global vars */ ?>
                                                        <?php if(!isset($this->noGlobalTemplates)): ?>
                                                            <?php generateInsertAtCursorLink($data, 'Current Date/Time', '%DATETIME%'); ?>
                                                            <?php generateInsertAtCursorLink($data, 'Site Name', '%SITENAME%'); ?>
                                                            <?php generateInsertAtCursorLink($data, 'Recruiter/Current User Name', '%USERFULLNAME%'); ?>
                                                            <?php generateInsertAtCursorLink($data, 'Recruiter/Current User E-Mail Link', '%USERMAIL%'); ?>
                                                        <?php endif; ?>

                                                        <?php /* Template specific vars */ ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Previous Candidate Status', '%CANDPREVSTATUS%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Current Candidate Status', '%CANDSTATUS%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Candidate Owner', '%CANDOWNER%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Candidate First Name', '%CANDFIRSTNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Candidate Full Name', '%CANDFULLNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'CATS Candidate URL', '%CANDCATSURL%'); ?>

                                                        <?php generateInsertAtCursorLinkConditional($data, 'Company Owner', '%CLNTOWNER%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Company Name', '%CLNTNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'CATS Company URL', '%CLNTCATSURL%'); ?>

                                                        <?php generateInsertAtCursorLinkConditional($data, 'Contact Owner', '%CONTOWNER%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Contact First Name', '%CONTFIRSTNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Contact Full Name', '%CONTFULLNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Contacts Company Name', '%CONTCLIENTNAME%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'CATS Contact URL', '%CONTCATSURL%'); ?>

                                                        <?php generateInsertAtCursorLinkConditional($data, 'Job Order Owner', '%JBODOWNER%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Job Order Title', '%JBODTITLE%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Job Order Company', '%JBODCLIENT%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'Job Order ID', '%JBODID%'); ?>
                                                        <?php generateInsertAtCursorLinkConditional($data, 'CATS Job Order URL', '%JBODCATSURL%'); ?>
                                                    </td>
                                                 </tr>
                                             </table>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="tdVertical" style="width:150px;">
                                        </td>
                                        <td>
                                            <input type="submit" class="button" value="Save Template">
                                            <input type="reset" class="button" value="Reset Template" onclick="document.getElementById('selectorSpan').style.display=''; document.getElementById('templateTitleSpan<?php echo($data['emailTemplateID']); ?>').style.display='none'; document.getElementById('messageText<?php echo($data['emailTemplateID']); ?>').disabled=<?php if ($data['disabled'] == 0) {echo('false'); } else {echo('true'); } ?>;">
                                        </td>
                                    </tr>
                                </table>
                            </form>
                        <?php endforeach; ?>
                                                <?php foreach ($this->candidateStatusesRS as $status):
                            $statusID       = (int) $status['statusID'];
                            $statusLabel    = htmlspecialchars($status['status']);

                            /* Either the saved per-status row, or null if it hasn't been created yet. */
                            $statusTpl      = isset($this->statusChangeTemplatesRS[$statusID])
                                                ? $this->statusChangeTemplatesRS[$statusID]
                                                : null;

                            $tplDBID        = $statusTpl ? (int) $statusTpl['emailTemplateID'] : 0;
                            $tplText        = $statusTpl ? $statusTpl['text'] : $this->statusChangeFallbackText;
                            $tplDisabled    = $statusTpl ? (int) $statusTpl['disabled'] : 0;

                            /*
                             * The generateInsertAtCursor* functions key their JS element references on
                             * $data['emailTemplateID'], so we pass a synthetic string ID here.
                             * The string 'Status_N' is valid in an HTML id attribute and in
                             * getElementById(), and is guaranteed not to clash with numeric IDs.
                             */
                            $syntheticID    = 'Status_' . $statusID;
                            $subData        = array(
                                'emailTemplateID'   => $syntheticID,
                                'possibleVariables' => $this->statusChangePossibleVariables,
                            );
                        ?>
                        <form action="<?php echo(CATSUtility::getIndexName()); ?>?m=settings&amp;a=emailTemplates" method="post">
                            <input type="hidden" name="postback"            value="postback" />
                            <!-- templateID = 0 when the row doesn't exist yet; controller INSERTs in that case. -->
                            <input type="hidden" name="templateID"          value="<?php echo $tplDBID; ?>" />
                            <!-- statusID lets the controller build/look up the correct tag. -->
                            <input type="hidden" name="statusID"            value="<?php echo $statusID; ?>" />
                            <input type="hidden" name="isStatusSubTemplate" value="1" />

                            <table id="editTableStatus_<?php echo $statusID; ?>" class="editTable" width="850" style="display:none;">
                                <tr>
                                    <td colspan="2" style="padding:6px 0 2px 0;">
                                        <strong>Status-specific template: <?php echo $statusLabel; ?></strong>
                                        <?php if (!$statusTpl): ?>
                                            <span style="color:#888; font-size:0.85em; margin-left:8px;">
                                                (not yet saved — showing generic fallback as starting point)
                                            </span>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="tdVertical" style="width:150px;">
                                        Message:
                                    </td>
                                    <td class="tdData">
                                        <table>
                                            <tr style="vertical-align:top;">
                                                <td>
                                                    <textarea
                                                        class="inputbox"
                                                        name="messageText"
                                                        <?php if ($tplDisabled == 1) echo('disabled'); ?>
                                                        id="messageText<?php echo $syntheticID; ?>"
                                                        style="width:450px; height:280px;"
                                                    ><?php echo htmlspecialchars($tplText); ?></textarea>
                                                    <input type="hidden"
                                                        name="messageTextOrigional"
                                                        id="messageTextOrigional<?php echo $syntheticID; ?>"
                                                        value="<?php echo htmlspecialchars($tplText); ?>">
                                                    <br /><br />
                                                    <input
                                                        type="checkbox"
                                                        name="useThisTemplate"
                                                        id="useThisTemplate<?php echo $syntheticID; ?>"
                                                        <?php if ($tplDisabled == 0) echo('checked'); ?>
                                                        onclick="if (this.checked) {document.getElementById('messageText<?php echo $syntheticID; ?>').disabled=false;} else {document.getElementById('messageText<?php echo $syntheticID; ?>').disabled=true;}"
                                                    > Use this Template / Feature<br />
                                                </td>
                                                <td style="text-align:center;">
                                                    <div style="font-weight:bold;">Insert Formatting:</div>
                                                    <?php generateInsertAtCursorLink($subData, 'Bold',      '<B></B>'); ?>
                                                    <?php generateInsertAtCursorLink($subData, 'Italics',   '<I></I>'); ?>
                                                    <?php generateInsertAtCursorLink($subData, 'Underline', '<U></U>'); ?>
                                                    <br />
                                                    <div style="font-weight:bold;">Insert Mail Merge Fields:</div>
                                                    <?php generateInsertAtCursorLink($subData, 'Current Date/Time',                '%DATETIME%'); ?>
                                                    <?php generateInsertAtCursorLink($subData, 'Site Name',                        '%SITENAME%'); ?>
                                                    <?php generateInsertAtCursorLink($subData, 'Recruiter/Current User Name',      '%USERFULLNAME%'); ?>
                                                    <?php generateInsertAtCursorLink($subData, 'Recruiter/Current User E-Mail Link', '%USERMAIL%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Previous Candidate Status', '%CANDPREVSTATUS%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Current Candidate Status',  '%CANDSTATUS%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Candidate Owner',           '%CANDOWNER%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Candidate First Name',      '%CANDFIRSTNAME%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Candidate Full Name',       '%CANDFULLNAME%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Job Order Title',           '%JBODTITLE%'); ?>
                                                    <?php generateInsertAtCursorLinkConditional($subData, 'Job Order Company',         '%JBODCLIENT%'); ?>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="tdVertical" style="width:150px;"></td>
                                    <td>
                                        <input type="submit" class="button" value="Save Template">
                                        <input type="reset"  class="button" value="Reset Template"
                                            onclick="document.getElementById('messageText<?php echo $syntheticID; ?>').disabled=<?php echo ($tplDisabled == 0) ? 'false' : 'true'; ?>;">
                                    </td>
                                </tr>
                            </table>
                        </form>
                        <?php endforeach; ?>
                    </td>
                </tr>
            </table>
        </div>
    </div>
<?php TemplateUtility::printFooter(); ?>
