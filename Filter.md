# Candidate Filter in Job Order Details Page

A summary of every file worked on to implement the feature.

---

## What Was Built

Recruiters can now filter the candidate pipeline inside a Job Order using the same filter that exists on the Candidates list page.
---

## Files Changed

### 1. `modules/joborders/dataGrids.php`

**What:** Created a new `PipelineCandidatesDataGrid` class at the bottom of the file.

**Why:** The pipeline needed its own DataGrid instance to power the filter UI. Rather than duplicating column definitions, it extends `CandidatesDataGrid` and inherits all its columns automatically.

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

**What:** Instantiated `PipelineCandidatesDataGrid` and assigned it to the template inside the show function before:

**Dependencies added at top of file:**
```php
include_once(LEGACY_ROOT . '/modules/joborders/dataGrids.php');
```

**Inside the show function, after:**
```php
$this->_template->display('./modules/joborders/Show.tpl');
```

**Add:**
```php
$dataGridProperties = DataGrid::getRecentParamaters('joborders:PipelineCandidatesDataGrid');
if ($dataGridProperties == array())
{
    $dataGridProperties = array(
        'rangeStart'    => 0,
        'maxResults'    => 15,
        'filterVisible' => true,
        'filter'        => 'First+Name=~',
    );
}

$dataGrid = new PipelineCandidatesDataGrid($this->_siteID, $dataGridProperties, 0);
$this->_template->assign('dataGrid', $dataGrid);
$this->_template->assign('userID', $_SESSION['CATS']->getUserID());
```

---

### 3. `modules/joborders/Show.tpl`

**What:** Added the filter UI and wired it to the pipeline AJAX reload.

**Change 1 — added JS files to both header calls:**
```php
'js/dataGrid.js', 'js/dataGridFilters.js'
```

**Change 2 — inserted filter block** between `<p class="note">Candidate in Job Order</p>` and `<p id="ajaxPipelineControl">`:

```php
 <?php $this->dataGrid->drawFilterArea(); ?>

            <script type="text/javascript">
            document.addEventListener('DOMContentLoaded', function() {
                var filterArea = document.getElementById(
                    'filterResultsArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>'
                );
                if (filterArea) filterArea.style.display = '';
                showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
            });
            </script>

            <input type="hidden"
                id="filterArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>"
                value="" />

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
                            var op = f.substring(eqPos, eqPos + 2);
                            var val = decodeURIComponent(f.substring(eqPos + 2));
                            var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than'};
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

**What:** Added PHP-side filtering of the pipeline result set before it renders. The pipeline is loaded via AJAX and doesn't go through the DataGrid SQL system, so filtering happens in PHP after the data is fetched.

**Change 1 — added filter params** after `$isPopup` declaration:
```php
$filterValue    = isset($_REQUEST['filterValue'])    ? trim($_REQUEST['filterValue'])    : '';
$filterColumn   = isset($_REQUEST['filterColumn'])   ? trim($_REQUEST['filterColumn'])   : 'firstName';
$filterOperator = isset($_REQUEST['filterOperator']) ? trim($_REQUEST['filterOperator']) : '=~';
```

**Change 2 — added filter logic** right before the sort block:
```php
/* Filter the data. */ nope?
if ($filterValue !== '')
{
    $pipelinesRS = array_filter($pipelinesRS, function($row) use ($filterColumn, $filterOperator, $filterValue) {
        $fieldValue = strtolower(isset($row[$filterColumn]) ? $row[$filterColumn] : '');
        $search     = strtolower($filterValue);
        switch ($filterOperator) {
            case '==': return $fieldValue == $search;
            case '=~': return strpos($fieldValue, $search) !== false;
            case '=>':  return $fieldValue >= $search;
            case '=<':  return $fieldValue <= $search;
            default:    return true;
        }
    });
    $pipelinesRS = array_values($pipelinesRS);
}

$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

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
);

if ($filterString !== '')
{
    $pipelineFilters = array_filter(explode(',', $filterString));
    foreach ($pipelineFilters as $filterItem)
    {
        $operators = array('=~', '==', '=>', '=<');
        foreach ($operators as $op)
        {
            $pos = strpos($filterItem, $op);
            if ($pos !== false)
            {
                $col = urldecode(substr($filterItem, 0, $pos));
                $val = strtolower(urldecode(substr($filterItem, $pos + strlen($op))));
                $col = isset($columnMap[$col]) ? $columnMap[$col] : $col;

                $pipelinesRS = array_filter($pipelinesRS, function($row) use ($col, $op, $val) {
                    $fieldValue = strtolower(isset($row[$col]) ? $row[$col] : '');
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

**Added** inside `PipelineJobOrder_populate`, after the `/* Build HTTP POST data. */` comment and before the indicator line:

```javascript
    var filterAreaEl = document.getElementById(
    typeof pipelineDataGridFilterID !== 'undefined' ? pipelineDataGridFilterID : '');
    POSTData += '&filterString=' + urlEncode(filterAreaEl ? filterAreaEl.value : '');
    
```

---
