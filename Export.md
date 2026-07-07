# Export Notes

Fix the export so that the columns and candidates stay the same while exporting.
---

## lib/DataGrid.php

In `drawCSV()`, `$exportableColumns`. Replace `$this->_classColumns` with `$this->_currentColumns`:

```php
$exportableColumns = array();
foreach ($this->_currentColumns as $index => $colData)
{
    $exportableColumns[] = array('name' => $colData['name'], 'data' => $colData['data']);
}
$this->_currentColumns = $exportableColumns;
```
