# Export Implementation Notes

Fix the candidates list export to respect visible columns instead of exporting every column.

---

## lib/DataGrid.php

In `drawCSV()`, find the block that builds `$exportableColumns`. It currently loops over `$this->_classColumns` (all columns that exist), which ignores the user's column selection and exports everything.

Replace it with a loop over `$this->_currentColumns` (only what's currently visible):

```php
$exportableColumns = array();
foreach ($this->_currentColumns as $index => $colData)
{
    $exportableColumns[] = array('name' => $colData['name'], 'data' => $colData['data']);
}
$this->_currentColumns = $exportableColumns;
```

Note the array shape difference: `_currentColumns` entries have `name` and `data` as sub-keys (set by `buildColumns()`), while `_classColumns` uses the column name as the array key directly — which is why the loop structure is slightly different from the original.