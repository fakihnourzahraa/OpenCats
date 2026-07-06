# Pipeline Filter Infrastructure

The infrastructure that enables candidate filtering on the job order detail page. The pipeline loads via AJAX and never goes through the DataGrid SQL layer, so filtering happens entirely in PHP on the fetched result set.

**This doc covers only what is not already in ranges.md.** The following are intentionally omitted here because ranges.md is the master for them:
- `PipelineCandidatesDataGrid` class and `PipelineExportDataGrid` class (`dataGrids.php`)
- `show()` setup, template assignments, and `exportPipeline` method (`JobOrdersUI.php`)
- Filter registries, `drawFilterArea()`, `submitFilter`, `clearFilter`, export UI (`Show.tpl`)
- `getExtraFieldsForPipelineCandidates()` and `getExtraFieldDefinitions()` (`Pipelines.php`)
- `$columnMap`, `$operators`, and GPA/Created filter callbacks (`getPipelineJobOrder.php`)

---

## 1. js/pipeline.js

**What:** Passes the current filter string to the AJAX pipeline request so `getPipelineJobOrder.php` can apply it server-side.

Inside `PipelineJobOrder_populate`, after the `/* Build HTTP POST data. */` comment, add:

```javascript
var filterAreaEl = document.getElementById(
    typeof pipelineDataGridFilterID !== 'undefined' ? pipelineDataGridFilterID : '');
POSTData += '&filterString=' + urlEncode(filterAreaEl ? filterAreaEl.value : '');
```

---

## 2. modules/joborders/dataGrids.php

**What:** Add the Candidates library as a dependency so `PipelineCandidatesDataGrid` (defined in ranges.md) can extend `CandidatesDataGrid`.

At the top of the file:

```php
include_once(LEGACY_ROOT . '/lib/Candidates.php');
```

---

## 3. modules/joborders/Show.tpl

**What:** A single hidden input near the top of the file (before `<div id="contents">`), pre-populated with the saved filter string from PHP. This is what gives the filter area element its initial value when the page loads — without it, `drawFilterArea()` renders an empty filter area even when a saved filter exists.

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

Added right after the row-formatting loop (highlight style, icon tags, rating line). Fetches all extra field values for the current candidates in one query and merges them into each row so the filter block and column renderer can access them by field name.

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

### Read filter string and persist to session

```php
$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

$_SESSION['pipelineFilter'][$jobOrderID] = $filterString;
```

---

### Column visibility — picker state and session persistence

`$defaultVisibleCols` is the out-of-the-box set. The picker sends `setColumn` + `colAction` (add/remove/reset) via AJAX; this block updates `$_SESSION['pipelineCols'][$siteID]` and then reads it back as `$visibleCols`, which is the single source of truth for every `<th>`/`<td>` conditional below.

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

---

### `$hardcodedCols` and `$visibleColCount`

`$hardcodedCols` marks which columns have hand-written markup in the template — anything in `$allPipelineColumns` not in this list is an extra field rendered generically. `$visibleColCount` drives the details row `colspan` so it still spans the full table regardless of how many columns are toggled on.

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

---

### JS-safe variable copies

Right after the `JO_AJAX_GET_PIPELINE` hook. The old pagination `<script>` block that followed this in the original file (building "Showing entries X through Y of Z" and Prev/Next links via `PipelineJobOrder_setLimitDefaultVars`) is deleted here.

```php
$jsSortBy    = addslashes($sortBy);
$jsSortDir   = addslashes($sortDirection);
$jsIndexFile = addslashes($indexFile);
$jsFilter    = addslashes($filterString);
$jsCookie    = addslashes($_SESSION['CATS']->getCookie());
$jsIsPopup   = $isPopup ? 1 : 0;
```

---

### Column picker UI

Replaces the bare leading `<th></th>` in the header row. The gear icon toggles a dropdown that lists every column in `$allPipelineColumns` with a checkbox next to each, wired to `pipelineToggleColumn()`.

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

### Per-column visibility gates

Every previously-static `<th>` and `<td>` for the hardcoded columns is wrapped:

```php
<?php if (in_array('colKey', $visibleCols)): ?>
    <th ...>...</th>   <!-- or <td ...> in the row loop -->
<?php endif; ?>
```

The `action` column is additionally gated on `!$isPopup`. Apply this pattern to every column: Match, First Name, Last Name, State, City, Zip, Address, Added, Entered By, Interview Stage, Last Activity, E-Mail, 2nd E-Mail, Home/Cell/Work Phone, Key Skills, Current Employer, Current Pay, Desired Pay, Can Relocate, Source, Web Site, Misc Notes, Available, Modified, GPA, Nationality, University, Job Order Status, Action.

---

### Generic extra field column rendering

Appended after all hardcoded column blocks, in both the header row and each data row. This is what makes dynamically-defined extra fields show up as real toggleable columns without any per-field template code.

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

### Details row `colspan`

Replace the hardcoded `colspan="11"` with the dynamic count:

```php
<td colspan="<?php echo $visibleColCount; ?>">
```