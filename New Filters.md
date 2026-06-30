

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


gpa filter:

ALTER TABLE candidate ADD COLUMN gpa DECIMAL(3,2) DEFAULT NULL;


getPipelineJobOrder.php:

$columnMap = array(
    'First Name'       => 'firstName',
    'Last Name'        => 'lastName',
    'City'             => 'city',
    'State'            => 'state',
    'Source'           => 'source',
    'Key Skills'       => 'keySkills',
    'E-Mail'           => 'email1',
    'Home Phone'       => 'phoneHome',
    'Cell Phone'       => 'phoneCell',
    'Work Phone'       => 'phoneWork',
    'Current Employer' => 'currentEmployer',
    'Misc Notes'       => 'notes',
    'GPA'              => 'gpa',
    'Created'          => 'dateCreated'
);

        $operators = array('=d>', '=d<', '=~', '==', '=>', '=<');

        replace:     $fieldValue = isset($row[$col]) ? $row[$col] : '';

   if ($col === 'gpa') {
        $fieldValue = (float) $fieldValue;
        $val = (float) $val;
        switch ($op) {
            case '==': return $fieldValue == $val;
            case '=>':  return $fieldValue >= $val;
            case '=<':  return $fieldValue <= $val;
            default:    return true;
        }
    }

    if ($col === 'dateCreated') {
    $fieldValue = DateTime::createFromFormat('m-d-y', $fieldValue);
    $valDate    = DateTime::createFromFormat('m-d-y', $val);
    if (!$fieldValue || !$valDate) return true;
    switch ($op) {
        case '==':  return $fieldValue == $valDate;
        case '=d>': return $fieldValue >= $valDate;
        case '=d<': return $fieldValue <= $valDate;
        default:    return true;
    }
}

in lib/datagrid change

for  >=, <=, == change makeQueryInteger to makeQueryDouble, e.g

                    /* Is less than (=<) */
                    if (strpos($data, '=<') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' <= ' . $db->makeQueryDouble($argument) .' ';
                        }

                        if (isset($this->_classColumns[$columnName]['filterHaving']))
                        {
                            $havingSQL_or[] = $this->_classColumns[$columnName]['filterHaving'] . ' <= ' . $db->makeQueryDouble($argument)  .' ';
                        }
                    }
                    

                $eqPos = strpos($data, '=');
                $operatorLength = 2;
                if (substr($data, $eqPos, 3) === '=d>' || substr($data, $eqPos, 3) === '=d<')
                {
                    $operatorLength = 3;
                }

                $argument = urldecode(substr($data, $eqPos + $operatorLength));

                    if (strpos($data, '=d<') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' <= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'%m-%d-%y\') ';
                        }
                    }


                    if (strpos($data, '=d>') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' >= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'%m-%d-%y\') ';
                        }
                    }
lib/Pipelines.php
candidate.gpa AS gpa,

dataGridFilter.js
    getNames: function() {
        return {
            '==': 'is equal to',
            '=~': 'contains',
            '=<': 'is less than',
            '=>': 'is greater than',
            '=#': 'has element',
            '=@': 'Near',
            '=d>': 'is after',
            '=d<': 'is before',
        };
    },

in createFromPossibleOperatorType: 

        } else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'GPA') {
        return new filter.GPAFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    } else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'Created') {
        return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName); 

at the end:

filter.GPAFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.GPAFilter.prototype = Object.create(filter.Filter.prototype);

filter.GPAFilter.prototype.render = function() {
    var me = this;
    var filterDiv = document.createElement('div');

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    /* Operator dropdown: is equal to, is between */
    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    filterDiv.appendChild(operatorSelect);

    /* Single value input */
    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        type: 'number',
        min: '0',
        max: '4',
        step: '0.01',
        style: 'width: 60px;'
    });
    filterDiv.appendChild(singleInput);

    /* Range inputs (hidden by default) */
    var rangeSpan = this.createElement('span', {
        id: this.filterAreaID + this.filterCounter + 'range',
        style: 'display:none;'
    });
    var minInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'min',
        className: 'inputbox',
        type: 'number',
        min: '0',
        max: '4',
        step: '0.01',
        style: 'width: 60px;'
    });
    var maxInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'max',
        className: 'inputbox',
        type: 'number',
        min: '0',
        max: '4',
        step: '0.01',
        style: 'width: 60px;'
    });
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' and ' }));
    rangeSpan.appendChild(minInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' to ' }));
    rangeSpan.appendChild(maxInput);
    filterDiv.appendChild(rangeSpan);

    /* Toggle single/range inputs based on operator */
    var updateHandler = function() {
        var op = document.getElementById(me.filterAreaID + me.filterCounter + 'operator').value;
        var single = document.getElementById(me.filterAreaID + me.filterCounter + 'value');
        var range = document.getElementById(me.filterAreaID + me.filterCounter + 'range');
        if (op === 'between') {
            single.style.display = 'none';
            range.style.display = '';
        } else {
            single.style.display = '';
            range.style.display = 'none';
        }
        applyGPAFilter(me.filterAreaID, me.filterCounter, me.instanceName);
    };

    operatorSelect.addEventListener('change', updateHandler);
    singleInput.addEventListener('change', function() {
        applyGPAFilter(me.filterAreaID, me.filterCounter, me.instanceName);
    });
    minInput.addEventListener('change', function() {
        applyGPAFilter(me.filterAreaID, me.filterCounter, me.instanceName);
    });
    maxInput.addEventListener('change', function() {
        applyGPAFilter(me.filterAreaID, me.filterCounter, me.instanceName);
    });

    filterDiv.style.float = 'left';
    return filterDiv;
}

function applyGPAFilter(filterAreaID, filterCounter, instanceName) {
    var op = document.getElementById(filterAreaID + filterCounter + 'operator').value;
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;

    /* Remove existing GPA filters */
    filterVal = filterVal.replace(/,?GPA==[^,]*/g, '');
    filterVal = filterVal.replace(/,?GPA=>[^,]*/g, '');
    filterVal = filterVal.replace(/,?GPA=<[^,]*/g, '');
    filterVal = filterVal.replace(/^,/, '');

    if (op === '==') {
        var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
        if (val !== '') filterVal += (filterVal ? ',' : '') + 'GPA==' + val;
    } else if (op === 'between') {
        var min = document.getElementById(filterAreaID + filterCounter + 'min').value;
        var max = document.getElementById(filterAreaID + filterCounter + 'max').value;
        if (min !== '') filterVal += (filterVal ? ',' : '') + 'GPA=>' + min;
        if (max !== '') filterVal += (filterVal ? ',' : '') + 'GPA=<' + max;
    }

    filterArea.value = filterVal;
}

filter.DateRangeFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.DateRangeFilter.prototype = Object.create(filter.Filter.prototype);

filter.DateRangeFilter.prototype.render = function() {
    var me = this;
    var filterDiv = document.createElement('div');

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    /* Operator dropdown */
    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    operatorSelect.appendChild(this.createOption('=>', 'is after'));
    operatorSelect.appendChild(this.createOption('=<', 'is before'));
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    filterDiv.appendChild(operatorSelect);

    /* Single date input */
    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        type: 'text',
        placeholder: 'mm-dd-yy',
        style: 'width: 80px;'
    });
    filterDiv.appendChild(singleInput);

    /* Range inputs (hidden by default) */
    var rangeSpan = this.createElement('span', {
        id: this.filterAreaID + this.filterCounter + 'range',
        style: 'display:none;'
    });
    var fromInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'from',
        className: 'inputbox',
        type: 'text',
        placeholder: 'mm-dd-yy',
        style: 'width: 80px;'
    });
    var toInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'to',
        className: 'inputbox',
        type: 'text',
        placeholder: 'mm-dd-yy',
        style: 'width: 80px;'
    });
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' from ' }));
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' to ' }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);

    /* Toggle inputs based on operator */
    var updateHandler = function() {
        var op = document.getElementById(me.filterAreaID + me.filterCounter + 'operator').value;
        var single = document.getElementById(me.filterAreaID + me.filterCounter + 'value');
        var range = document.getElementById(me.filterAreaID + me.filterCounter + 'range');
        if (op === 'between') {
            single.style.display = 'none';
            range.style.display = '';
        } else {
            single.style.display = '';
            range.style.display = 'none';
        }
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, 'Created');
    };

    operatorSelect.addEventListener('change', updateHandler);
    singleInput.addEventListener('change', function() {
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, 'Created');
    });
    fromInput.addEventListener('change', function() {
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, 'Created');
    });
    toInput.addEventListener('change', function() {
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, 'Created');
    });

    filterDiv.style.float = 'left';
    return filterDiv;
}

function applyDateRangeFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var op = document.getElementById(filterAreaID + filterCounter + 'operator').value;
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;

    /* Remove existing filters for this column */
    var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
        filterVal = filterVal.replace(/,?Created=d>[^,]*/g, '');
        filterVal = filterVal.replace(/,?Created=d<[^,]*/g, '');
        filterVal = filterVal.replace(/,?Created==[^,]*/g, '');
        filterVal = filterVal.replace(/^,/, '');
        filterVal = filterVal.replace(/,$/, '');

    if (op === '=d>' || op === '=d<' || op === '==') {
        var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
        if (val !== '') filterVal += (filterVal ? ',' : '') + columnName + op + val;
    } else if (op === 'between') {
        var from = document.getElementById(filterAreaID + filterCounter + 'from').value;
        var to = document.getElementById(filterAreaID + filterCounter + 'to').value;
       if (from !== '') filterVal += (filterVal ? ',' : '') + columnName + '=d>' + from;
       if (to !== '') filterVal += (filterVal ? ',' : '') + columnName + '=d<' + to;
    }

    filterArea.value = filterVal;
}

modified:   lib/Candidates.php


            'Created' =>       array('select'   => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\') AS dateCreated',
                                    'pagerRender'      => 'return $rsData[\'dateCreated\'];',
                                    'sortableColumn'     => 'dateCreatedSort',
                                    'pagerWidth'    => 60,
                                    'filter'      => 'candidate.date_created',
                                    'filterHaving' => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\')',
                                    'filterTypes'  => '=d>=d<=='),
            
            'GPA'  =>          array(
                                    'select'         => 'candidate.gpa AS gpa',
                                    'sortableColumn' => 'gpa',
                                    'pagerWidth'     => 60,
                                    'pagerOptional'  => true,
                                    'filter'         => 'candidate.gpa',
                                    'filterTypes'    => '=><==',
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

modules/joborder/dataGrids.php

in default columns:
            array('name' => 'gpa', 'width' => 55),
