# Export Fix
## In lib/Datagrid.php drawCSV():
change this:
```php
        $exportableColumns = array();
        foreach ($this->_currentColumns as $index => $colData)
        {
            $exportableColumns[] = array('name' => $colData['name'], 'data' => $colData['data']);
        }
        $this->_currentColumns = $exportableColumns;
```
to this:
```php
        $exportableColumns = array();
        foreach ($this->_classColumns as $index => $data)
        {
            $exportableColumns[] = array('name' => $index, 'data' => $data);
        }
        $this->_currentColumns = $exportableColumns;
```
## In modules/jobOrders/JobOrderUI.php:
change this:
```php
    $visibleCols = isset($_SESSION['pipelineCols'][$siteID])
        ? $_SESSION['pipelineCols'][$siteID]
        : array('firstName', 'lastName', 'state', 'dateCreatedInt', 'addedByAbbrName', 'status', 'lastActivity');
    $exportCols = array();
    foreach ($visibleCols as $key)
    {
        if (isset($allCols[$key])) $exportCols[$key] = $allCols[$key];
    }
```
to this:
```php
    $exportCols = $allCols;
```
# Date Fix
## In lib/Pipelines.php in filterPipelineRows:
Change this:
```php
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
```
To this:
```php
                    if ($col === 'dateCreated' || $col === 'candidateDateCreated' || $col === 'dateModified')
                    {
                        $dateFormatFlag = $_SESSION['CATS']->isDateDMY() ? DATE_FORMAT_DDMMYY : DATE_FORMAT_MMDDYY;

                        $fieldValue = DateUtility::convert('-', $fieldValue, $dateFormatFlag, DATE_FORMAT_YYYYMMDD);
                        $valDate = DateUtility::convert('-', $valDate, $dateFormatFlag, DATE_FORMAT_YYYYMMDD);

                        switch ($op) {
                            case '==':  return $fieldValue == $valDate;
                            case '=d>': return $fieldValue >= $valDate;
                            case '=d<': return $fieldValue <= $valDate;
                            default:    return true;
                        }
                    }

```

## In js/dataGridFilters.js filter.DefaultFilter.prototype.render:
Change this:
```php
              if (filterDateRangeRegistry[col]) {
                fromInput.placeholder = "mm-dd-yy";
                toInput.placeholder   = "mm-dd-yy";
            }
```
To this:
```php
            if (filterDateRangeRegistry[col]) {
                var ph;
                if (typeof isDateDMY !== 'undefined' && isDateDMY)
                    ph = "dd-mm-yy";
                else
                    ph = "mm-dd-yy";
                fromInput.placeholder = ph;
                toInput.placeholder   = ph;
            }

```

Change this:
```php
    var singleInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "value",
        className: "inputbox", type: "text",
        placeholder: "mm-dd-yy", style: "width: 80px;"
    });
    filterDiv.appendChild(singleInput);

    var rangeSpan = this.createElement("span", {
        id: this.filterAreaID + this.filterCounter + "range",
        style: "display:none;"
    });
    var fromInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "from",
        className: "inputbox", type: "text",
        placeholder: "mm-dd-yy", style: "width: 80px;"
    });
    var toInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "to",
        className: "inputbox", type: "text",
        placeholder: "mm-dd-yy", style: "width: 80px;"
    });
```
To this:
```php
    var ph;
    if (typeof isDateDMY !== 'undefined' && isDateDMY)
        ph = "dd-mm-yy";
    else
        ph = "mm-dd-yy";

    var singleInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "value",
        className: "inputbox", type: "text",
        placeholder: ph, style: "width: 80px;"
    });
    filterDiv.appendChild(singleInput);

    var rangeSpan = this.createElement("span", {
        id: this.filterAreaID + this.filterCounter + "range",
        style: "display:none;"
    });
    var fromInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "from",
        className: "inputbox", type: "text",
        placeholder: ph, style: "width: 80px;"
    });
    var toInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "to",
        className: "inputbox", type: "text",
        placeholder: ph, style: "width: 80px;"
    });
```
## In joborders/Show.tpl:
After this:
```php

<?php if ($this->isPopup): ?>
    <?php TemplateUtility::printHeader('Job Order - ' . $this->data['title'], array('js/sorttable.js', 'js/match.js', 'js/pipeline.js', 'js/attachment.js','js/dataGrid.js','js/dataGridFilters.js')); ?>
<?php else: ?>
    <?php TemplateUtility::printHeader('Job Order - ' . $this->data['title'], array( 'js/sorttable.js', 'js/match.js', 'js/pipeline.js', 'js/attachment.js','js/dataGrid.js','js/dataGridFilters.js')); ?>
```
Add this:
```php
    <script>
    var isDateDMY = <?php echo $_SESSION['CATS']->isDateDMY() ? 'true' : 'false'; ?>;
    </script>
```

## In candidates/Show.tpl:
After this:
```php

    <?php TemplateUtility::printHeaderBlock(); ?>
    <?php TemplateUtility::printTabs($this->active); ?>
        <div id="main">
            <?php TemplateUtility::printQuickSearch(); ?>
<?php endif; ?>

```
Add this:
```php
    <script>
    var isDateDMY = <?php echo $_SESSION['CATS']->isDateDMY() ? 'true' : 'false'; ?>;
    </script>
```