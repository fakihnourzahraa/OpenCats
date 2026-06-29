

ALTER TABLE candidate_joborder ADD COLUMN interview_stage text COLLATE utf8_unicode_ci;

edit.tpl
                    <tr>
                        <td class="tdVertical">
                            <label id="interviewStageLabel" for="interviewStage">Interview Stage:</label>
                        </td>
                        <td class="tdData">
                            <select id="interviewStage" name="interviewStage" class="inputbox" style="width: 150px;">
                            <option value="Applied"     <?php if ($this->data['interviewStage'] == 'Applied'):     ?>selected<?php endif; ?>>Applied</option>
                            <option value="1st Screening"     <?php if ($this->data['interviewStage'] == '1st Screening'):     ?>selected<?php endif; ?>>1st Screening</option>
                            <option value="Interview 1"  <?php if ($this->data['interviewStage'] == 'Interview 1'):  ?>selected<?php endif; ?>>Interview 1</option>
                            <option value="Interview 2" <?php if ($this->data['interviewStage'] == 'Interview 2'): ?>selected<?php endif; ?>>Interview 2</option>
                            <option value="Job Offered" <?php if ($this->data['interviewStage'] == 'Job Offered'):?>selected<?php endif; ?>>Job Offered</option>
                            <option value="Job Offer Refused" <?php if ($this->data['interviewStage'] == 'Job Offer Refused'):?>selected<?php endif; ?>>Job Offer Refused</option>
                            <option value="Job Offer Accepted" <?php if ($this->data['interviewStage'] == 'Job Offer Accepted'):?>selected<?php endif; ?>>Job Offer Accepted</option>
                        </select>

                            <input type="hidden" id="interviewStageCSV" name="interviewStageCSV" value="<?php $this->_($this->interviewStagesString); ?>" />
                        </td>
                    </tr>



ALTER TABLE candidate ADD COLUMN gpa DECIMAL(3,2) DEFAULT NULL;


in lib datagrid change

                if (array_search($index, $filterableColumns) !== false)
                {
                    unset ($filterableColumns[array_search($index, $filterableColumns)]);
                }
to 
if (array_search($index, $filterableColumns) !== false && $index !== 'GPA')
{
    unset ($filterableColumns[array_search($index, $filterableColumns)]);
}

	modified:   lib/Candidates.php
                'GPA Min' => array(
                'select'         => 'candidate.gpa AS gpa',
                'sortableColumn' => 'gpa',
                'pagerWidth'     => 60,
                'pagerOptional'  => true,
                'filter'         => 'candidate.gpa',
                'filterTypes'    => '=>==',
            ),

            'GPA Max' => array(
                'select'         => '',
                'pagerWidth'     => 60,
                'pagerOptional'  => true,
                'filter'         => 'candidate.gpa',
                'filterTypes'    => '=<==',
            ),
	modified:   modules/candidates/Add.tpl


                    <tr>
                        <td class="tdVertical">
                            <label id="gpaLabel" for="gpa">GPA:</label>
                        </td>
                        <td class="tdData">
                            <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" min="0" max="4" step="0.01" style="width: 50px;" value="<?php if (isset($this->preassignedFields['gpa'])) $this->_($this->preassignedFields['gpa']); ?>" />
                        </td>
                    </tr>

	modified:   modules/candidates/CandidatesUI.php
	modified:   modules/candidates/Edit.tpl

                        <tr>
                    <td class="tdVertical">
                        <label id="gpaLabel" for="gpa">GPA:</label>
                    </td>
                    <td class="tdData">
                        <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" min="0" max="4" step="0.01" style="width: 60px;" value="<?php $this->_($this->data['gpa']); ?>" />
                    </td>
                </tr>

	modified:   modules/candidates/Show.tpl

                                                        <tr>
                                <td class="vertical">GPA:</td>
                                <td class="data"><?php $this->_($this->data['gpa']); ?></td>
                            </tr>