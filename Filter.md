# Candidate Filter in Job Order Details Page

A summary of every file worked on to implement the feature.

---

## What Was Built

Recruiters can now filter the candidates within each job using the same filters from the Candidates list page. Page reload and extra fields are also importantly handled here.

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

**What:** Instantiated `PipelineCandidatesDataGrid` inside the `show()` function, because we need jobOrderID, reads the saved filter from the session, and passes both the DataGrid and the saved filter string to the template.

**Dependencies added at top of file:**
```php
include_once(LEGACY_ROOT . '/modules/joborders/dataGrids.php');
```

**Added at the bottom of `show()`, replacing the old DataGrid block, just before `$this->_template->display()`:**
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

**Change 1 added JS files to both header calls:**
```php
'js/dataGrid.js', 'js/dataGridFilters.js'
```

**Change 2 added single hidden input near the top of the file** (before `<div id="contents">`), pre-populated with the saved filter value from PHP.
```php
<input type="hidden"
    id="filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>"
    value="<?php echo htmlspecialchars($this->savedPipelineFilter); ?>" />
```

**Change 3 inserted filter block** between `<p class="note">Candidate in Job Order</p>` and `<p id="ajaxPipelineControl">`:

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

---

### 4. `ajax/getPipelineJobOrder.php`

**What:** Merges extra field values into the pipeline row data, saves the active filter to the session, builds the column map (including dynamically discovered extra fields), and filters the result set in PHP before rendering.

**Why filtering happens in PHP:** The pipeline loads via AJAX and never goes through the DataGrid SQL layer, so filtering cannot happen at the query level. The full candidate list is fetched first, then extra field values are merged in, then PHP filters the combined array using the filter string sent from the browser.

**Change 1 merge extra field values into each row** after the formatting loop:
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

**Change 2 read filter string and save to session:**
```php
$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

$_SESSION['pipelineFilter'][$jobOrderID] = $filterString;
```

**Change 3 build column map then dynamically append extra field definitions:**

The static map only covers fields returned by `getJobOrderPipeline()`. Fields not in the SQL query (City, Source, Key Skills, Phone numbers, etc.) are intentionally excluded. 
```php
$columnMap = array(
    'First Name'  => 'firstName',
    'Last Name'   => 'lastName',
    'State'       => 'state',
    'E-Mail'      => 'candidateEmail',
    'GPA'         => 'gpa',
    'Created'     => 'dateCreated',
    'University'  => 'universityShortName',
    'Nationality' => 'nationality',
);

$extraFieldDefs = $pipelines->getExtraFieldDefinitions();
if ($extraFieldDefs)
{
    foreach ($extraFieldDefs as $def)
    {
        $columnMap[$def['field_name']] = $def['field_name'];
    }
}
```

**Change 4 filter logic** right after the column map:
```php
if ($filterString !== '')
{
    $pipelineFilters = array_filter(explode(',', $filterString));
    foreach ($pipelineFilters as $filterItem)
    {
        $operators = array('=d>', '=d<', '=~', '==', '=>', '=<');
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

                    $fieldValue = strtolower($fieldValue);
                    $val = strtolower($val);
                    switch ($op) {
                        case '==': return $fieldValue == $val;
                        case '=~': return strpos($fieldValue, $val) !== false;
                        case '=>':  return $fieldValue >= $val;
                        case '=<':  return $fieldValue <= $val;
                        default:    return true;
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

**Why two separate methods:** `getExtraFieldsForPipelineCandidates` fetches the actual stored values for a specific set of candidates in one query. `getExtraFieldDefinitions` fetches the field name definitions so the column map can be populated dynamically without hardcoding every possible extra field name.

**Database schema note:** This codebase uses two tables for extra fields. `extra_field_settings` stores the field definitions (name, type, options). `extra_field` stores the actual values per data item

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

---
