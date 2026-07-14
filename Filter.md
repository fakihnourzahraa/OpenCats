# Pipeline Filter Infrastructure

The infrastructure that enables candidate filtering on the job order detail page. The pipeline loads via AJAX and never goes through the DataGrid SQL layer, so filtering happens entirely in PHP on the fetched result set.

---

## 1. js/pipeline.js

**What:** Passes the current filter string to the AJAX pipeline request so `getPipelineJobOrder.php` can apply it.

Inside `PipelineJobOrder_populate`, after the `/* Build HTTP POST data. */` comment, add:

```javascript
var filterAreaEl = document.getElementById(
    typeof pipelineDataGridFilterID !== 'undefined' ? pipelineDataGridFilterID : '');
POSTData += '&filterString=' + urlEncode(filterAreaEl ? filterAreaEl.value : '');
```

---

## 2. modules/joborders/dataGrids.php

**What:** Add the Candidates library as a dependency.

At the top of the file:

```php
include_once(LEGACY_ROOT . '/lib/Candidates.php');
```

---

## 3. modules/joborders/Show.tpl

**What:** A single hidden input near the top of the file (before `<div id="contents">`), pre-populated with the saved filter string from PHP. This is what gives the filter area element its initial value when the page loads.

```php
<input type="hidden"
    id="filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>"
    value="<?php echo htmlspecialchars($this->savedPipelineFilter); ?>" />
```

---

## 4. ajax/getPipelineJobOrder.php

The changes below are split into logical groups. For context on what this file does overall: it fetches the full pipeline result set, merges in extra field values, applies the filter string in PHP, then renders the HTML table.

---

### Read filter params

At the top of the file, read the incoming filter parameters:

```php
$filterValue    = isset($_REQUEST['filterValue'])    ? trim($_REQUEST['filterValue'])    : '';
$filterColumn   = isset($_REQUEST['filterColumn'])   ? trim($_REQUEST['filterColumn'])   : 'firstName';
$filterOperator = isset($_REQUEST['filterOperator']) ? trim($_REQUEST['filterOperator']) : '=~';
```

---

### Merge extra field values into each row


```php

    // $pipelinesRS[$rowIndex]['ratingLine'] = TemplateUtility::getRatingObject(
    //     $pipelinesRS[$rowIndex]['ratingValue'],
    //     $pipelinesRS[$rowIndex]['candidateJobOrderID'],
    //     $_SESSION['CATS']->getCookie()
    // );
}

$candidateIDs = array_map(function($row) {
    return $row['candidateID'];
}, $pipelinesRS);

$extraFieldsByCandidate = $pipelines->getExtraFieldsForPipelineCandidates($candidateIDs);

foreach ($pipelinesRS as $idx => $row)
{
    $cid = $row['candidateID'];
    if (isset($extraFieldsByCandidate[$cid]))
    {
        foreach ($extraFieldsByCandidate[$cid] as $fieldName => $value)
        {
            $pipelinesRS[$idx][$fieldName] = $value;
        }
    }
}

$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

$_SESSION['pipelineFilter'][$jobOrderID] = $filterString;

$columnMap = array(
    'First Name'       => 'firstName',
    'Last Name'        => 'lastName',
    'State'            => 'state',
    'City'             => 'city',
    'Zip'              => 'zip',
    'Address'          => 'address',
    'E-Mail'           => 'candidateEmail',
    '2nd E-Mail'       => 'candidateEmail2',
    'Home Phone'       => 'phoneHome',
    'Cell Phone'       => 'phoneCell',
    'Work Phone'       => 'phoneWork',
    'Key Skills'       => 'keySkills',
    'Current Employer' => 'currentEmployer',
    'Current Pay'      => 'currentPay',
    'Desired Pay'      => 'desiredPay',
    'Can Relocate'     => 'canRelocate',
    'Source'           => 'source',
    'Web Site'         => 'webSite',
    'Misc Notes'       => 'notes',
    'Available'        => 'dateAvailable',
    'Modified'         => 'dateModified',
    'Added'            => 'dateCreated',
    'GPA'              => 'gpa',
    'Created'          => 'candidateDateCreated',
    'University'       => 'universityShortName',
    'Nationality'      => 'nationality',
    'Interview Stage'  => 'interviewStage',
    'Status'  => 'statusDescription',
);

$allPipelineColumns = array(
    'match'               => 'Match',
    'firstName'           => 'First Name',
    'lastName'            => 'Last Name',
    'state'               => 'Loc',
    'city'                => 'City',
    'zip'                 => 'Zip',
    'address'             => 'Address',
    'dateCreatedInt'      => 'Added',
    'addedByAbbrName'     => 'Entered By',
    'status'              => 'Status',
    'lastActivity'        => 'Last Activity',
    'candidateEmail'      => 'E-Mail',
    'candidateEmail2'     => '2nd E-Mail',
    'phoneHome'           => 'Home Phone',
    'phoneCell'           => 'Cell Phone',
    'phoneWork'           => 'Work Phone',
    'keySkills'           => 'Key Skills',
    'currentEmployer'     => 'Current Employer',
    'currentPay'          => 'Current Pay',
    'desiredPay'          => 'Desired Pay',
    'canRelocate'         => 'Can Relocate',
    'source'              => 'Source',
    'webSite'             => 'Web Site',
    'notes'               => 'Misc Notes',
    'dateAvailable'       => 'Available',
    'dateModified'        => 'Modified',
    'candidateDateCreated'         => 'Created',
    'gpa'                 => 'GPA',
    'nationality'         => 'Nationality',
    'interviewStage'         => 'Interview Stage',
    'universityShortName' => 'University',
    'jobOrderStatus'      => 'Job Order Status',
    'action'              => 'Action',
);


$extraFieldDefs = $pipelines->getExtraFieldDefinitions();
if ($extraFieldDefs) {
    $actionLabel = $allPipelineColumns['action'];
    unset($allPipelineColumns['action']);
    foreach ($extraFieldDefs as $def) {
        $fn = $def['field_name'];
        $columnMap[$fn] = $fn;
        if (!isset($allPipelineColumns[$fn])) {
            $allPipelineColumns[$fn] = $def['field_name'];
        }
    }
    $allPipelineColumns['action'] = $actionLabel; // keep Action last
}
$defaultVisibleCols = array(
    'match',
    'firstName',
    'lastName',
    'state',
    'dateCreatedInt',
    'addedByAbbrName',
    'status',
    'lastActivity',
    'action',
);

/* Handle column toggle requests */
if (isset($_REQUEST['setColumn'])) {
    $toggleCol    = trim($_REQUEST['setColumn']);
    $toggleAction = isset($_REQUEST['colAction']) ? trim($_REQUEST['colAction']) : '';

    if (!isset($_SESSION['pipelineCols'][$siteID])) {
        $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
    }

    if ($toggleAction === 'reset') {
        $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
    } elseif ($toggleAction === 'remove' && array_key_exists($toggleCol, $allPipelineColumns)) {
        $_SESSION['pipelineCols'][$siteID] = array_values(
            array_diff($_SESSION['pipelineCols'][$siteID], array($toggleCol))
        );
    } elseif ($toggleAction === 'add' && array_key_exists($toggleCol, $allPipelineColumns)) {
        if (!in_array($toggleCol, $_SESSION['pipelineCols'][$siteID])) {
            $_SESSION['pipelineCols'][$siteID][] = $toggleCol;
        }
    }
}

if (!isset($_SESSION['pipelineCols'][$siteID])) {
    $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
}
$visibleCols = $_SESSION['pipelineCols'][$siteID];

$hardcodedCols = array(
    'match','firstName','lastName','state','city','zip','address',
    'dateCreatedInt','addedByAbbrName','status','lastActivity',
    'candidateEmail','candidateEmail2','phoneHome','phoneCell','phoneWork',
    'keySkills','currentEmployer','currentPay','desiredPay','canRelocate',
    'source','webSite','notes','dateAvailable','dateModified', 'candidateDateCreated',
    'gpa','nationality','interviewStage','universityShortName','jobOrderStatus','action',
);


$visibleColCount = 3;
foreach ($allPipelineColumns as $k => $v) {
    if ($k === 'action' && $isPopup) continue;
    if (in_array($k, $visibleCols)) $visibleColCount++;
}


if ($filterString !== '')
{
    $pipelineFilters = array_filter(explode(',', $filterString));
    foreach ($pipelineFilters as $filterItem)
    {
        $operators = array('=d>', '=d<','=in', '=~', '==', '=>', '=<', '=e');
        foreach ($operators as $op)
        {
            $pos = strpos($filterItem, $op);
            if ($pos !== false)
            {
                $col = urldecode(substr($filterItem, 0, $pos));
                
                $val = strtolower(urldecode(substr($filterItem, $pos + strlen($op))));
                $col = isset($columnMap[$col]) ? $columnMap[$col] : $col;

$pipelinesRS = array_filter($pipelinesRS, function($row) use ($col, $op, $val) {
    $fieldValue = isset($row[$col]) ? $row[$col] : '';

    if ($col === 'gpa') {
        if ($op === '=e') return $fieldValue === '' || $fieldValue === null;
        $fieldValue = (float) $fieldValue;
        $val = (float) $val;
        switch ($op) {
            case '==': return $fieldValue == $val;
            case '=>':  return $fieldValue >= $val;
            case '=<':  return $fieldValue <= $val;
            case '=e': return $fieldValue === '' || $fieldValue === null;
            default:    return true;
        }
    }

    if ($col === 'dateCreated' || $col === 'candidateDateCreated' || $col == 'dateModified') {
        if ($op === '=e') return $fieldValue === '' || $fieldValue === null;
        $fieldValue = DateTime::createFromFormat('m-d-y', $fieldValue);
        $valDate    = DateTime::createFromFormat('m-d-y', $val);
        if (!$fieldValue || !$valDate) return true;
        switch ($op) {
            case '==':  return $fieldValue == $valDate;
            case '=d>': return $fieldValue >= $valDate;
            case '=d<': return $fieldValue <= $valDate;
            case '=e':  return $fieldValue === '' || $fieldValue === null;
        }
    }
    if ($op === '=d>' || $op === '=d<')
    {
        if ($fieldValue === '' || $fieldValue === null) return false;
        $fieldDate = DateTime::createFromFormat('m-d-y', $fieldValue);
        $valDate   = DateTime::createFromFormat('m-d-y', $val);
        if (!$fieldDate || !$valDate) return true;
        return $op === '=d>' ? $fieldDate >= $valDate : $fieldDate <= $valDate;
    }
    $fieldValue = strtolower($fieldValue);
    $val = strtolower($val);
    switch ($op) {
        case '=in':
        case '==': return $fieldValue == $val;
        case '=~': return strpos($fieldValue, $val) !== false;
        case '=>':  return $fieldValue >= $val;
        case '=<':  return $fieldValue <= $val;
        case '=e': return $fieldValue === '' || $fieldValue === null;
        default:    return true;
    }
});
                $pipelinesRS = array_values($pipelinesRS);
                break;
            }
        }
    }
}


---

### JS copies

```php

// if (!eval(Hooks::get('JO_AJAX_GET_PIPELINE'))) return;

// ?>
$jsSortBy    = addslashes($sortBy);
$jsSortDir   = addslashes($sortDirection);
$jsIndexFile = addslashes($indexFile);
$jsFilter    = addslashes($filterString);
$jsCookie    = addslashes($_SESSION['CATS']->getCookie());
$jsIsPopup   = $isPopup ? 1 : 0;

//and delete the script after this
```

---

### Column picker UI

The gear icon toggles a dropdown that lists every column in `$allPipelineColumns` with a checkbox.

```php
        <th style="width:10px; border-right:1px solid gray;" align="center">
            <div style="width:10px; position:relative;">
                <a href="javascript:void(0);" id="pipelineColumnIcon" onclick="pipelineColumnBox_toggle(); return false;">
                    <img src="images/tab_add.gif" border="0" alt="" />
                </a>
                <div class="ajaxSearchResults" id="pipelineColumnBox" onclick="event.stopPropagation();"
                     style="display:none; position:absolute; left:0; top:16px; width:180px; z-index:10000; text-align:left;">
                    <span style="font-weight:bold; color:#000000;">Show Columns:</span><br/><br/>
                    <?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
                        <?php if ($colKey === 'action' && $isPopup) continue; ?>
                        <?php $isVis = in_array($colKey, $visibleCols); ?>
                        <span style="font-weight:normal;">
                            <a href="javascript:void(0);"
                               onclick="pipelineToggleColumn('<?php echo htmlspecialchars($colKey); ?>',
                                        '<?php echo $isVis ? 'remove' : 'add'; ?>');">
                                <img src="images/<?php echo $isVis ? 'checkbox' : 'checkbox_blank'; ?>.gif" border="0" alt="" />
                                &nbsp;&nbsp;&nbsp;&nbsp;<?php echo htmlspecialchars($colLabel); ?>
                            </a>
                        </span><br/>
                    <?php endforeach; ?>
                    <br/>
                    <span style="font-weight:bold;">
                        <a href="javascript:void(0);" onclick="pipelineToggleColumn('', 'reset');">
                            <img src="images/checkbox_blank.gif" border="0" alt="" />
                            &nbsp;&nbsp;&nbsp;&nbsp;Reset to Default Columns
                        </a>
                    </span><br/>
                </div>
            </div>
        //     </th>
        // <th></th>
        // <th align="left" width="32" nowrap="nowrap"></th>
            <?php if (in_array('match', $visibleCols)): ?>
```

---

### Checkboxes

Every previously-static `<th>` and `<td>` for the hardcoded columns is wrapped:

```php
<?php if (in_array('colKey', $visibleCols)): ?>
    <th ...>...</th>   <!-- or <td ...> in the row loop -->
<?php endif; ?>
```

Apply this pattern to every column!!

---

### Generic extra field column rendering

Header row:

```php
<?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
    <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
    <?php if (!in_array($colKey, $visibleCols)) continue; ?>
    <th align="left" nowrap="nowrap"><?php echo htmlspecialchars($colLabel); ?></th>
<?php endforeach; ?>
```

Data row:

```php
<?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
    <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
    <?php if (!in_array($colKey, $visibleCols)) continue; ?>
    <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars(isset($pipelinesData[$colKey]) ? $pipelinesData[$colKey] : ''); ?></td>
<?php endforeach; ?>
```

---

### Details row

Replace the hardcoded `colspan="11"` with the dynamic count:

```php
<td colspan="<?php echo $visibleColCount; ?>">
```