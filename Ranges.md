# OpenCATS Custom Feature Implementation Guide

This document contains the exact code changes needed to implement three features:

1. **GPA** field on candidates (add/edit/display/filter)
2. **Created** date range filtering (candidates list and job order pipeline)


Each section below names the file, says where the change goes, and gives the code verbatim so it can be copied directly into the codebase.

---

## 1. Database Changes

Run these against the database before anything else:

```sql
ALTER TABLE candidate ADD COLUMN gpa DECIMAL(3,2) DEFAULT NULL;
```

---

## 2. GPA Feature

### `modules/candidates/Add.tpl`

Add this row to the form (inside the existing table of fields):

```php
<tr>
    <td class="tdVertical">
        <label id="gpaLabel" for="gpa">GPA:</label>
    </td>
    <td class="tdData">
        <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" min="0" max="4" step="0.01" style="width: 50px;" value="<?php if (isset($this->preassignedFields['gpa'])) $this->_($this->preassignedFields['gpa']); ?>" />
    </td>
</tr>
```

### `modules/candidates/Edit.tpl`

Add this row to the form:

```php
<tr>
    <td class="tdVertical">
        <label id="gpaLabel" for="gpa">GPA:</label>
    </td>
    <td class="tdData">
        <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" min="0" max="4" step="0.01" style="width: 60px;" value="<?php $this->_($this->data['gpa']); ?>" />
    </td>
</tr>
```

### `modules/candidates/Show.tpl`

Add this row to the candidate details display:

```php
<tr>
    <td class="vertical">GPA:</td>
    <td class="data"><?php $this->_($this->data['gpa']); ?></td>
</tr>
```

### `modules/candidates/CandidatesUI.php`

**In the parsed-fields array** (used by `checkParsingFunctions`), add the `gpa` key:

```php
'isFromParser'    => true,
'gpa'             => $this->getTrimmedInput('gpa', $_POST),
```

**Before the call to `Candidates::add()`** (around line 2610), add:

```php
$gpa = $this->getTrimmedInput('gpa', $_POST);
```

**In the `Candidates::add()` call itself** (around line 2663), add `$gpa` as the final argument:

```php
,$gpa
```

**Before the call to `Candidates::update()`** (around line 1380), pass `$gpa` as the final argument in the same way.

### `lib/Candidates.php`

**`add()` function signature** add `$gpa = ''` as a new parameter after `$disability`:

```php
$gender = '', $race = '', $veteran = '', $disability = '', $gpa = '',
```

**`add()` INSERT statement**  add `gpa` to the column list and a corresponding `%s` placeholder to the VALUES list, then pass the value through using:

```php
$this->_db->makeQueryDouble($gpa)
```

(as the final value in the `sprintf()` argument list, immediately after `$this->_db->makeQueryString($gender)`)

**`update()` function signature** (around line 259)  add `$gpa = ''` as a new parameter:

```php
$gender = '', $race = '', $veteran = '', $disability = '', $gpa = '')
```

**`update()` SET clause** (around line 296)  add:

```php
gpa = %s
```

**`update()` value list** (around line 329)  add:

```php
$this->_db->makeQueryDouble($gpa),
```

**`get()` function** (around line 495)  add to the SELECT clause:

```php
candidate.gpa AS gpa,
```

**`getForEditing()` function** (around line 636)  add to the SELECT clause:

```php
candidate.gpa AS gpa,
```

**`CandidatesDataGrid::_classColumns`**  add a new `GPA` entry to the array:

```php
'GPA'  =>          array(
                        'select'         => 'candidate.gpa AS gpa',
                        'sortableColumn' => 'gpa',
                        'pagerWidth'     => 60,
                        'pagerOptional'  => true,
                        'filter'         => 'candidate.gpa',
                        'filterTypes'    => '=><==',
                    ),
```

### `lib/Pipelines.php`

In `getJobOrderPipeline()`, add to the SELECT clause:

```php
candidate.gpa AS gpa,
```

### `modules/joborders/dataGrids.php`

In `JobOrdersListByViewDataGrid`'s `_defaultColumns` array, add:

```php
array('name' => 'gpa', 'width' => 55),
```

---

## 3. Created Date Range Filter

### `lib/Candidates.php`

Replace the existing `Created` column definition in `CandidatesDataGrid::_classColumns` with:

```php
'Created' =>       array('select'   => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\') AS dateCreated',
                            'pagerRender'      => 'return $rsData[\'dateCreated\'];',
                            'sortableColumn'     => 'dateCreatedSort',
                            'pagerWidth'    => 60,
                            'filter'      => 'candidate.date_created',
                            'filterHaving' => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\')',
                            'filterTypes'  => '=d>=d<=='),
```

### `lib/DataGrid.php`

**Argument parsing fix.** Find the line in `_getData()` that extracts the column name and argument from the filter string:

```php
$columnName = urldecode(substr($data, 0, strpos($data, '=')));
$argument = urldecode(substr($data, strpos($data, '=') + 2));
```

Replace it with:

```php
$columnName = urldecode(substr($data, 0, strpos($data, '=')));

$eqPos = strpos($data, '=');
$operatorLength = 2;
if (substr($data, $eqPos, 3) === '=d>' || substr($data, $eqPos, 3) === '=d<')
{
    $operatorLength = 3;
}

$argument = urldecode(substr($data, $eqPos + $operatorLength));
```

**Numeric comparison fix.** In the existing `=<` (is less than) block, change `makeQueryInteger` to `makeQueryDouble`:

```php

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
```

Do the same for the `=>` (is greater than) block, change `makeQueryInteger` to `makeQueryDouble` in both the `filter` and `filterHaving` lines.

**New date operator blocks.** Add these new blocks (alongside the existing `=<`, `=>`, `=~`, `==`, `=#`, `=@` blocks in the same `foreach ($arguments as $argument)` loop):

```php
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
```

**Human-readable operator labels.** In `drawFilterArea()`, find the `$filterOperatorHuman` switch statement:

```php
$filterOperatorHuman = '';
switch ($filterOperator)
{
    case '==':
        $filterOperatorHuman = ' is equal to';
        break;

    case '=~':
        $filterOperatorHuman = ' contains';
        break;

    case '=>':
        $filterOperatorHuman = ' is greater than';
        break;

    case '=<':
        $filterOperatorHuman = ' is less than';
        break;

    case '=#':
        $filterOperatorHuman = ' has element';
        break;

    case '=d>':
        $filterOperatorHuman = ' from';
        break;

    case '=d<':
        $filterOperatorHuman = ' to';
        break;
}
```

(The `=d>` and `=d<` cases are the new addition)

### `js/dataGridFilters.js`

**`filter.getNames()`** replace with:

```javascript
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
```

**`filter.FilterFactory.createFromPossibleOperatorType`** add these two `else if` branches before the final `else`:

```javascript
} else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'GPA') {
    return new filter.GPAFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'Created') {
    return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
}
```

**New code add at the end of the file:**

```javascript
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


    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));


    filterDiv.appendChild(operatorSelect);

    
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
    rangeSpan.appendChild(minInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' and ' }));
    rangeSpan.appendChild(maxInput);
    filterDiv.appendChild(rangeSpan);

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

    operatorSelect.value = 'between';
    operatorSelect.addEventListener('change', updateHandler);
    setTimeout(updateHandler, 0);
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

    
    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    operatorSelect.appendChild(this.createOption('=>', 'is after'));
    operatorSelect.appendChild(this.createOption('=<', 'is before'));

    filterDiv.appendChild(operatorSelect);

    
    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        type: 'text',
        placeholder: 'mm-dd-yy',
        style: 'width: 80px;'
    });
    filterDiv.appendChild(singleInput);

    
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
    setTimeout(updateHandler, 0);
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
```

> **Note on `setTimeout(updateHandler, 0)`:** this was required because calling `updateHandler()` synchronously right after `operatorSelect.value = 'between'` did not always toggle the range inputs visible on first render (only one input box showed instead of two). Deferring the call with `setTimeout(..., 0)` lets the DOM settle first and fixed the issue.

---

## 4. Job Order Pipeline Filter (separate filtering system)

The job order pipeline ("Candidate in Job Order" section on the Job Order detail page) uses its own AJAX-based filtering system, completely separate from the DataGrid SQL filtering used by the Candidates list. This needed its own implementation for GPA and Created.

### `ajax/getPipelineJobOrder.php`

**`$columnMap`** add `GPA` and `Created`:

```php
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
```

**`$operators` array** add the 3-character date operators (order matters they must be checked before the 2-character `=>`/`=<` so they match first):

```php
$operators = array('=d>', '=d<', '=~', '==', '=>', '=<');
```

**Filter comparison callback** find this line:

```php
$fieldValue = isset($row[$col]) ? $row[$col] : '';
```

Immediately after it, add the GPA and Created special cases (before falling through to the existing string comparison logic):

```php
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
```

The rest of the function (string-based comparison for all other columns) stays as-is below these two blocks.

### `modules/joborders/Show.tpl`

The pipeline's filter pills are rendered entirely in inline JavaScript (the `submitFilter<md5>` function), not through `DataGrid::drawFilterArea()`. The same 2-vs-3-character operator parsing bug exists here and needs the same fix.

Find this section inside the `filters.forEach(function(f) {...})` block:

```javascript
var eqPos = f.indexOf('=');
if (eqPos === -1) return;
var col = decodeURIComponent(f.substring(0, eqPos));
var op = f.substring(eqPos, eqPos + 2);
var val = decodeURIComponent(f.substring(eqPos + 2));
var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than'};
```

Replace it with:

```javascript
var eqPos = f.indexOf('=');
if (eqPos === -1) return;
var col = decodeURIComponent(f.substring(0, eqPos));
var opLen = (f.substr(eqPos, 3) === '=d>' || f.substr(eqPos, 3) === '=d<') ? 3 : 2;
var op = f.substring(eqPos, eqPos + opLen);
var val = decodeURIComponent(f.substring(eqPos + opLen));
var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than','=d>':'from','=d<':'to'};
```

---
