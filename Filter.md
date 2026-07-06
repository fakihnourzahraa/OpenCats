# Candidate Filter in Job Order Details Page

A summary of every file worked on to implement the feature.

---

## What Was Built

Recruiters can now filter the candidates within each job using the same filters from the Candidates list page. Page reload and saved filter state are also handled here.

---

## Files Changed

### 1. `modules/joborders/dataGrids.php`

**What:** Created a new `PipelineCandidatesDataGrid` class at the bottom of the file.

**Why:** The pipeline needed its own DataGrid instance to power the filter UI. It extends `CandidatesDataGrid` and inherits all its columns automatically, including any extra fields defined by the site admin.

**Dependencies added at top of file:**
```php
include_once(LEGACY_ROOT . '/lib/Candidates.php');
```

**Class added at bottom:**
```php
class PipelineCandidatesDataGrid extends CandidatesDataGrid
{
    public function __construct($siteID, $parameters, $misc)
    {
        $this->_tableWidth              = new Width(100, '%');
        $this->_defaultAlphabeticalSortBy = 'lastName';
        $this->ajaxMode                 = false;
        $this->showExportCheckboxes     = false;
        $this->showActionArea           = false;
        $this->showChooseColumnsBox     = true;
        $this->allowResizing            = true;
        $this->defaultSortBy            = 'dateCreatedSort';
        $this->defaultSortDirection     = 'DESC';

        $this->_defaultColumns = array(
            array('name' => 'First Name', 'width' => 75),
            array('name' => 'Last Name',  'width' => 85),
            array('name' => 'E-Mail',     'width' => 80),
            array('name' => 'Home Phone', 'width' => 80),
        );

        parent::__construct(
            'joborders:PipelineCandidatesDataGrid',
            $siteID, $parameters, $misc
        );
    }
}
```

---

### 2. `modules/joborders/JobOrdersUI.php`

**What:** Instantiated `PipelineCandidatesDataGrid` inside the `show()` function, reads the saved filter from the session, and passes both the DataGrid and the saved filter string to the template.

**Dependencies added at top of file:**
```php
include_once(LEGACY_ROOT . '/modules/joborders/dataGrids.php');
```

**Added at the bottom of `show()`, just before `$this->_template->display()`:**
```php
$savedPipelineFilter = isset($_SESSION['pipelineFilter'][$jobOrderID])
    ? $_SESSION['pipelineFilter'][$jobOrderID]
    : '';

$dataGridProperties = DataGrid::getRecentParamaters('joborders:PipelineCandidatesDataGrid');
if ($dataGridProperties == array())
{
    $dataGridProperties = array(
        'rangeStart'    => 0,
        'maxResults'    => 15,
        'filterVisible' => true,
        'filter'        => $savedPipelineFilter !== '' ? $savedPipelineFilter : 'First+Name=~',
    );
}

$dataGrid = new PipelineCandidatesDataGrid($this->_siteID, $dataGridProperties, 0);
$this->_template->assign('dataGrid', $dataGrid);
$this->_template->assign('userID', $_SESSION['CATS']->getUserID());
$this->_template->assign('savedPipelineFilter', $savedPipelineFilter);
$this->_template->display('./modules/joborders/Show.tpl');
```

---

### 3. `modules/joborders/Show.tpl`

**What:** Added the filter UI, wired it to the pipeline AJAX reload, and restored saved filter state on page load.

**Change 1 — added JS files to both header calls:**
```php
'js/dataGrid.js', 'js/dataGridFilters.js'
```

**Change 2 — added single hidden input near the top of the file** (before `<div id="contents">`), pre-populated with the saved filter value from PHP:
```php
<input type="hidden"
    id="filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>"
    value="<?php echo htmlspecialchars($this->savedPipelineFilter); ?>" />
```

**Change 3 — inserted filter block** between `<p class="note">Candidate in Job Order</p>` and `<p id="ajaxPipelineControl">`.

The block has two parts in this order:

**Part A — `drawFilterArea()` call and DOMContentLoaded handler** (runs on page load: shows the filter area, then either re-submits a saved filter or opens a blank new-filter row):
```php
<?php $this->dataGrid->drawFilterArea(); ?>

<script type="text/javascript">
document.addEventListener('DOMContentLoaded', function() {
    var filterArea = document.getElementById(
        'filterResultsArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>'
    );
    if (filterArea) filterArea.style.display = '';

    <?php if (!empty($this->savedPipelineFilter)): ?>
    submitFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>(true);
    <?php else: ?>
    showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
    <?php endif; ?>
});
</script>
```

**Part B — `submitFilter` override and `clearFilter` override:**
```php
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
                var opLen = (f.substr(eqPos, 3) === '=d>' || f.substr(eqPos, 3) === '=d<') ? 3 : 2;
                var op = f.substring(eqPos, eqPos + opLen);
                var val = decodeURIComponent(f.substring(eqPos + opLen));
                var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than','=d>':'from','=d<':'to'};

                var span = document.createElement('span');
                span.className = 'filterArea';
                span.innerHTML = '<a href="javascript:void(0);" onclick="this.parentNode.style.display=\'none\'; removeColumnFromFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\'); submitFilter' + md5 + '();">'
                    + '<img src="images/actions/delete_small.gif" style="padding:0px;margin:0px;" border="0" title="Remove this Filter" /></a>&nbsp;'
                    + '\'' + col + '\' ' + (opNames[op] || op) + ': '
                    + '<select id="filterResultsAreaTable' + md5 + (counter+1) + 'columnName" disabled="disabled" class="inputbox" style="display:none;"><option value="' + col + '!@!===~">' + col + '</option></select>'
                    + '<input class="inputbox" style="width:180px;" value="' + val + '" onchange="addColumnToFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\', \'' + op + '\', this.value); submitFilter' + md5 + '();" />';
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
</script>
```

**Notes on the filter pill rendering:**
- `opLen` is 3 for `=d>` / `=d<` and 2 for everything else, so date operators parse correctly.
- Every active filter always renders an editable input. There is no special case for any operator type.

---
### 4. `ajax/getPipelineJobOrder.php`

**What:** Merges extra field values into the pipeline row data, saves the active filter to the session, builds the column map (including dynamically discovered extra fields), adds a user-configurable column visibility picker, and filters the result set in PHP before rendering.

**Why filtering happens in PHP:** The pipeline loads via AJAX and never goes through the DataGrid SQL layer, so filtering cannot happen at the query level. The full candidate list is fetched first, extra field values are merged in, then PHP filters the combined array using the filter string sent from the browser.

**Note:** The old inline `<script>` block that built the "Showing entries X through Y of Z" pagination text (via `PipelineJobOrder_setLimitDefaultVars`, Previous/Next Page links, and the `ajaxPipelineControl` hide-when-small-list logic) is removed entirely. Confirm this is intentional before merging — it looks like it may have been dropped rather than replaced.

---

#### Change 1 — read filter params up front

```php
$filterValue    = isset($_REQUEST['filterValue'])    ? trim($_REQUEST['filterValue'])    : '';
$filterColumn   = isset($_REQUEST['filterColumn'])   ? trim($_REQUEST['filterColumn'])   : 'firstName';
$filterOperator = isset($_REQUEST['filterOperator']) ? trim($_REQUEST['filterOperator']) : '=~';
```

---

#### Change 2 — merge extra field values into each row

Added right after the row-formatting loop (highlight style, icon tags, rating line):

```php
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
```

---

#### Change 3 — read filter string and persist it to session

```php
$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

$_SESSION['pipelineFilter'][$jobOrderID] = $filterString;
```

---

#### Change 4 — column map and full column list

`$columnMap` translates the human-readable filter-column labels sent from the browser into the row's internal field keys. `$allPipelineColumns` is the full set of possible columns, in display order, used both by the column picker and by the header/row rendering below.

```php
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
    'Interview Stage'  => 'statusDescription',
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
    'status'              => 'Interview Stage',
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
    'gpa'                 => 'GPA',
    'nationality'         => 'Nationality',
    'universityShortName' => 'University',
    'jobOrderStatus'      => 'Job Order Status',
    'action'              => 'Action',
);
```

Extra field definitions are appended dynamically, with `Action` kept last:

```php
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
```

---

#### Change 5 — column visibility (picker state + session persistence)

```php
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
```

`$visibleCols` is the single source of truth read by every `<th>`/`<td>` conditional in the template below. It's scoped per site, stored in session, and mutated via AJAX calls to `pipelineToggleColumn()` from the "Show Columns" picker (Change 7).

---

#### Change 6 — `$hardcodedCols` and `$visibleColCount`

```php
$hardcodedCols = array(
    'match','firstName','lastName','state','city','zip','address',
    'dateCreatedInt','addedByAbbrName','status','lastActivity',
    'candidateEmail','candidateEmail2','phoneHome','phoneCell','phoneWork',
    'keySkills','currentEmployer','currentPay','desiredPay','canRelocate',
    'source','webSite','notes','dateAvailable','dateModified',
    'gpa','nationality','universityShortName','jobOrderStatus','action',
);

$visibleColCount = 3;
foreach ($allPipelineColumns as $k => $v) {
    if ($k === 'action' && $isPopup) continue;
    if (in_array($k, $visibleCols)) $visibleColCount++;
}
```

`$hardcodedCols` marks which columns already have hand-written markup in the template; anything in `$allPipelineColumns` not in this list is an extra field, rendered generically by a `foreach` loop appended to the header row and each data row. `$visibleColCount` drives the collapsible details row's `colspan` (replacing the old fixed `colspan="11"`), so it still spans correctly regardless of how many columns a user has toggled on.

---

#### Change 7 — the filter block

The `$operators` array lists longer operators (`=d>`, `=d<`, `=in`) before shorter ones (`=>`, `=<`, `==`) so `strpos` can't false-match a longer operator as a shorter substring.

```php
if ($filterString !== '')
{
    $pipelineFilters = array_filter(explode(',', $filterString));
    foreach ($pipelineFilters as $filterItem)
    {
        $operators = array('=d>', '=d<', '=in', '=~', '==', '=>', '=<', '=e');
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
                        $fieldValue = (float) $fieldValue;
                        $val = (float) $val;
                        switch ($op) {
                            case '==': return $fieldValue == $val;
                            case '=>': return $fieldValue >= $val;
                            case '=<': return $fieldValue <= $val;
                            case '=e': return $fieldValue === '' || $fieldValue === null;
                            default:   return true;
                        }
                    }

                    if ($col === 'dateCreated' || $col === 'candidateDateCreated' || $col == 'dateModified') {
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

                    $fieldValue = strtolower($fieldValue);
                    $val = strtolower($val);
                    switch ($op) {
                        case '=in':
                        case '==': return $fieldValue == $val;
                        case '=~': return strpos($fieldValue, $val) !== false;
                        case '=>': return $fieldValue >= $val;
                        case '=<': return $fieldValue <= $val;
                        case '=e': return $fieldValue === '' || $fieldValue === null;
                        default:   return true;
                    }
                });
                $pipelinesRS = array_values($pipelinesRS);
                break;
            }
        }
    }
}
```

---

#### Change 8 — JS-safe variable copies (right after the `JO_AJAX_GET_PIPELINE` hook)

```php
$jsSortBy    = addslashes($sortBy);
$jsSortDir   = addslashes($sortDirection);
$jsIndexFile = addslashes($indexFile);
$jsFilter    = addslashes($filterString);
$jsCookie    = addslashes($_SESSION['CATS']->getCookie());
$jsIsPopup   = $isPopup ? 1 : 0;
```

The old pagination `<script>` block that immediately followed this in the previous version (building "Showing entries X through Y of Z" and the Prev/Next links) is deleted — see the note at the top of this section.

---

#### Change 9 — column picker UI (replaces the bare leading `<th></th>` in the header row)

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
</th>
```

---

#### Change 10 — every header cell and data cell gated behind `in_array(..., $visibleCols)`

Each previously-static `<th>...</th>` / `<td>...</td>` pair for the hardcoded columns (Match, First Name, Last Name, State, City, Zip, Address, Added, Entered By, Interview Stage, Last Activity, E-Mail, 2nd E-Mail, Home/Cell/Work Phone, Key Skills, Current Employer, Current Pay, Desired Pay, Can Relocate, Source, Web Site, Misc Notes, Available, Modified, GPA, Nationality, University, Job Order Status, Action) is now wrapped:

```php
<?php if (in_array('<colKey>', $visibleCols)): ?>
    <th ...>...</th>   <!-- or <td ...>...</td> in the row loop -->
<?php endif; ?>
```

`canRelocate`'s header lost its sort link (it was never sortable) but kept the same guard pattern; the `action` column's header/cell is additionally gated on `!$isPopup`.

---

#### Change 11 — generic rendering of extra field columns

Appended after all the hardcoded column blocks, in both the header row and each data row:

```php
<?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
    <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
    <?php if (!in_array($colKey, $visibleCols)) continue; ?>
    <th align="left" nowrap="nowrap"><?php echo htmlspecialchars($colLabel); ?></th>
<?php endforeach; ?>
```

```php
<?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
    <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
    <?php if (!in_array($colKey, $visibleCols)) continue; ?>
    <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars(isset($pipelinesData[$colKey]) ? $pipelinesData[$colKey] : ''); ?></td>
<?php endforeach; ?>
```

This is what makes dynamically-defined extra fields (added via `getExtraFieldDefinitions()` in Change 4) show up as real, toggleable columns without any per-field template code.

---

#### Change 12 — details row `colspan`

```php
<td colspan="<?php echo $visibleColCount; ?>">
```

Replaces the previous hardcoded `colspan="11"`, so the collapsible "pipeline details" row still spans the full table width no matter how many columns are currently visible.

---

### 5. `js/pipeline.js`

**What:** Passes the current filter string to the AJAX pipeline request so `getPipelineJobOrder.php` can apply it.

**Added** inside `PipelineJobOrder_populate`, after the `/* Build HTTP POST data. */` comment:

```javascript
var filterAreaEl = document.getElementById(
    typeof pipelineDataGridFilterID !== 'undefined' ? pipelineDataGridFilterID : '');
POSTData += '&filterString=' + urlEncode(filterAreaEl ? filterAreaEl.value : '');
```

---

### 6. `lib/Pipelines.php`

**What:** Added two new public methods to support the filter feature.

**Why two separate methods:** `getExtraFieldsForPipelineCandidates` fetches the actual stored values for a specific set of candidates in one query. `getExtraFieldDefinitions` fetches just the field names so the column map in `getPipelineJobOrder.php` can be populated dynamically without hardcoding every possible extra field name.

**Database schema note:** This codebase uses two tables for extra fields. `extra_field_settings` stores the field definitions (name, type, options). `extra_field` stores the actual values per data item.

**Both methods added before the closing `}` of the class:**

```php
public function getExtraFieldsForPipelineCandidates(array $candidateIDs)
{
    if (empty($candidateIDs))
    {
        return array();
    }

    $safeIDs = implode(',', array_map('intval', $candidateIDs));

    $sql = sprintf(
        "SELECT
            data_item_id AS candidateID,
            field_name,
            value
         FROM
            extra_field
         WHERE
            data_item_type = %s
         AND
            site_id = %s
         AND
            data_item_id IN (%s)",
        DATA_ITEM_CANDIDATE,
        $this->_siteID,
        $safeIDs
    );

    $rs = $this->_db->getAllAssoc($sql);
    if (!$rs)
    {
        return array();
    }

    $indexed = array();
    foreach ($rs as $row)
    {
        $indexed[$row['candidateID']][$row['field_name']] = $row['value'];
    }

    return $indexed;
}

public function getExtraFieldDefinitions()
{
    $sql = sprintf(
        "SELECT field_name
         FROM extra_field_settings
         WHERE data_item_type = %s
         AND site_id = %s",
        DATA_ITEM_CANDIDATE,
        $this->_siteID
    );

    $rs = $this->_db->getAllAssoc($sql);
    return $rs ? $rs : array();
}
```