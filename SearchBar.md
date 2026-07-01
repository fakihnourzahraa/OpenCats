# Filter Searchbar — Implementation Notes

## Overview

Two searchable widgets were added to the DataGrid filter system in `js/dataGridFilters.js`:

- **Column selector** — the first dropdown ("First Name", "University", etc.) is replaced with a searchable custom widget on all filter types, so recruiters can type to find the column they want instead of scrolling through the full list.
- **Value selector** — for dropdown filters (University, Nationality, Source), the native `<select>` is replaced with a searchable custom widget so recruiters can type to find a specific value (e.g. type "LAU" to find the university).

Both widgets share the same pattern: a visible clickable `<div>` that opens a floating panel containing a text `<input>` for search and a scrollable list of options below it. The native `<select>` is kept hidden as the value holder so the rest of the filter system (change handlers, apply functions) works unchanged.

---

## Files Changed

### `js/dataGridFilters.js`

---

### 1. `var filterDropDownRegistry = {}`

Moved to the **top level of the file**, before any filter class definitions. Previously it was declared inside the `DropDownFilter` block, which caused `ReferenceError: filterDropDownRegistry is not defined` when `FilterFactory` tried to check it before `DropDownFilter` was parsed.

```javascript
var filterDropDownRegistry = {};
```

---

### 2. `filter.DropDownFilter` — constructor and prototype line uncommented

These were accidentally commented out during earlier edits, causing `Cannot read properties of undefined (reading 'prototype')` since `filter.DropDownFilter.prototype.render` was being assigned to an undefined constructor.

```javascript
filter.DropDownFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.DropDownFilter.prototype = Object.create(filter.Filter.prototype);
```

---

### 3. New method: `filter.Filter.prototype.createSearchableFieldSelect`

Added to the base `filter.Filter` prototype so every filter type can use it. Takes the same arguments as `createFieldSelect` and returns a `<div>` wrapper containing:

- A hidden native `<select>` (retains the `id` of `filterAreaID + filterCounter + 'columnName'` so `makePreviousSelectionBoxesUnselectable` still works)
- A visible clickable `<div>` showing the currently selected column name
- A floating panel (shown on click) containing a search `<input>` and a scrollable option list

Selecting an option sets the hidden `<select>`'s value and dispatches a real `change` event, so `createSelectAreaChangeHandler` fires exactly as before.

```javascript
filter.Filter.prototype.createSearchableFieldSelect = function(defaultValue, filterAreaID, filterCounter, selectableColumns) {
    var selectColumn = this.createFieldSelect(defaultValue, filterAreaID, filterCounter, selectableColumns);
    selectColumn.style.display = 'none';

    var colWrapper = document.createElement('div');
    colWrapper.style.cssText = 'display:inline-block; position:relative; vertical-align:middle;';

    var colDisplay = document.createElement('div');
    colDisplay.className = 'inputbox';
    colDisplay.style.cssText = 'width:160px; cursor:pointer; padding:2px 4px; background:#fff; border:1px solid #999; display:inline-block;';
    colDisplay.innerHTML = getFilterColumnNameFromOptionValue(defaultValue);

    var colPanel = document.createElement('div');
    colPanel.style.cssText = 'display:none; position:absolute; z-index:9999; background:#fff; border:1px solid #999; width:160px; box-shadow:2px 2px 4px rgba(0,0,0,0.2);';

    var colSearch = document.createElement('input');
    colSearch.type = 'text';
    colSearch.placeholder = 'Search...';
    colSearch.className = 'inputbox';
    colSearch.style.cssText = 'width:100%; box-sizing:border-box; padding:2px 4px;';

    var colOptionList = document.createElement('div');
    colOptionList.style.cssText = 'max-height:200px; overflow-y:auto;';

    var colOptions = [];
    for (var i = 0; i < selectableColumns.length; i++) {
        colOptions.push({
            value: selectableColumns[i],
            label: getFilterColumnNameFromOptionValue(selectableColumns[i])
        });
    }

    function buildColList(query) {
        colOptionList.innerHTML = '';
        for (var i = 0; i < colOptions.length; i++) {
            if (!query || colOptions[i].label.toLowerCase().indexOf(query.toLowerCase()) !== -1) {
                (function(opt) {
                    var item = document.createElement('div');
                    item.style.cssText = 'padding:3px 6px; cursor:pointer;';
                    item.innerHTML = opt.label;
                    item.addEventListener('mouseover', function() { item.style.background = '#3366cc'; item.style.color = '#fff'; });
                    item.addEventListener('mouseout', function() { item.style.background = ''; item.style.color = ''; });
                    item.addEventListener('mousedown', function(e) {
                        e.preventDefault();
                        colDisplay.innerHTML = opt.label;
                        colPanel.style.display = 'none';
                        selectColumn.value = opt.value;
                        var ev = document.createEvent('Event');
                        ev.initEvent('change', true, true);
                        selectColumn.dispatchEvent(ev);
                    });
                    colOptionList.appendChild(item);
                })(colOptions[i]);
            }
        }
    }

    buildColList('');
    colSearch.addEventListener('keyup', function() { buildColList(colSearch.value); });
    colPanel.appendChild(colSearch);
    colPanel.appendChild(colOptionList);

    colDisplay.addEventListener('click', function() {
        if (colPanel.style.display === 'none') {
            colPanel.style.display = 'block';
            colSearch.value = '';
            buildColList('');
            colSearch.focus();
        } else {
            colPanel.style.display = 'none';
        }
    });

    document.addEventListener('click', function(e) {
        if (!colWrapper.contains(e.target)) {
            colPanel.style.display = 'none';
        }
    });

    colWrapper.appendChild(colDisplay);
    colWrapper.appendChild(colPanel);
    colWrapper.appendChild(selectColumn);

    return colWrapper;
}
```

---

### 4. `filter.DefaultFilter.prototype.render` — updated

Replaced `this.createFieldSelect(...)` + `filterDiv.appendChild(selectColumn)` with `createSearchableFieldSelect`. Removed the duplicate `selectColumn.addEventListener('change', ...)` call — the change listener is already wired inside `createSearchableFieldSelect`.

```javascript
filter.DefaultFilter.prototype.render = function() {
    var filterDiv = document.createElement('div');
    var colWrapper = this.createSearchableFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    var selectColumn = colWrapper.querySelector('select');
    filterDiv.appendChild(colWrapper);
    var operatorSelectColumn = this.createOperatorSelect(selectColumn.value, this.filterAreaID, this.filterCounter);
    filterDiv.appendChild(operatorSelectColumn);
    var inputArea = this.createInputArea(this.filterAreaID, this.filterCounter, this.instanceName);
    filterDiv.appendChild(inputArea);
    filterDiv.style.float = 'left';
    return filterDiv;
}
```

---

### 5. `filter.DropDownFilter.prototype.render` — updated

Replaced the manual column selector block with `createSearchableFieldSelect`. The value selector (University / Nationality / Source) was replaced with a custom searchable widget — same panel pattern as the column selector. A hidden `<input>` holds the selected value so `applyDropDownFilter` can read it unchanged.

```javascript
filter.DropDownFilter.prototype.render = function() {
    var me = this;
    var columnName = getFilterColumnNameFromOptionValue(this.defaultValue);
    var filterDiv = document.createElement('div');

    var colWrapper = this.createSearchableFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    var selectColumn = colWrapper.querySelector('select');
    filterDiv.appendChild(colWrapper);

    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    filterDiv.appendChild(operatorSelect);

    var wrapper = document.createElement('div');
    wrapper.style.cssText = 'display:inline-block; position:relative; vertical-align:middle;';

    var display = document.createElement('div');
    display.className = 'inputbox';
    display.style.cssText = 'width:220px; cursor:pointer; padding:2px 4px; background:#fff; border:1px solid #999; display:inline-block;';
    display.innerHTML = '-- Select --';

    var panel = document.createElement('div');
    panel.style.cssText = 'display:none; position:absolute; z-index:9999; background:#fff; border:1px solid #999; width:220px; box-shadow:2px 2px 4px rgba(0,0,0,0.2);';

    var searchInput = document.createElement('input');
    searchInput.type = 'text';
    searchInput.placeholder = 'Search...';
    searchInput.className = 'inputbox';
    searchInput.style.cssText = 'width:100%; box-sizing:border-box; padding:2px 4px;';

    var optionList = document.createElement('div');
    optionList.style.cssText = 'max-height:200px; overflow-y:auto;';

    var allOptions = [{ value: '', label: '-- Select --' }];
    var options = filterDropDownRegistry[columnName] || [];
    for (var i = 0; i < options.length; i++) {
        allOptions.push({ value: options[i].value, label: options[i].label });
    }

    var hiddenValue = document.createElement('input');
    hiddenValue.type = 'hidden';
    hiddenValue.id = me.filterAreaID + me.filterCounter + 'value';
    wrapper.appendChild(hiddenValue);

    function buildList(query) {
        optionList.innerHTML = '';
        for (var i = 0; i < allOptions.length; i++) {
            if (!query || allOptions[i].label.toLowerCase().indexOf(query.toLowerCase()) !== -1) {
                (function(opt) {
                    var item = document.createElement('div');
                    item.style.cssText = 'padding:3px 6px; cursor:pointer;';
                    item.innerHTML = opt.label;
                    item.addEventListener('mouseover', function() { item.style.background = '#3366cc'; item.style.color = '#fff'; });
                    item.addEventListener('mouseout', function() { item.style.background = ''; item.style.color = ''; });
                    item.addEventListener('mousedown', function(e) {
                        e.preventDefault();
                        display.innerHTML = opt.label;
                        panel.style.display = 'none';
                        hiddenValue.value = opt.value;
                        applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
                    });
                    optionList.appendChild(item);
                })(allOptions[i]);
            }
        }
    }

    buildList('');
    searchInput.addEventListener('keyup', function() { buildList(searchInput.value); });
    panel.appendChild(searchInput);
    panel.appendChild(optionList);

    display.addEventListener('click', function() {
        if (panel.style.display === 'none') {
            panel.style.display = 'block';
            searchInput.value = '';
            buildList('');
            searchInput.focus();
        } else {
            panel.style.display = 'none';
        }
    });

    document.addEventListener('click', function(e) {
        if (!wrapper.contains(e.target)) {
            panel.style.display = 'none';
        }
    });

    wrapper.appendChild(display);
    wrapper.appendChild(panel);
    filterDiv.appendChild(wrapper);

    filterDiv.style.float = 'left';
    return filterDiv;
}
```

---

### 6. `applyDropDownFilter` — uncommented

Was accidentally left commented out from earlier edits. Required by `DropDownFilter.prototype.render` when a value is selected.

```javascript
function applyDropDownFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;

    var pattern = new RegExp(',?' + columnName + '==[^,]*', 'g');
    filterVal = filterVal.replace(pattern, '');
    filterVal = filterVal.replace(/^,/, '');

    var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
    if (val !== '') filterVal += (filterVal ? ',' : '') + columnName + '==' + val;

    filterArea.value = filterVal;
}
```

---

## Adding a new dropdown filter in the future

To add a new searchable dropdown filter (e.g. "Major", "Language"):

1. Add the column to `_classColumns` in `dataGrids.php` with `'filterTypes' => '=='`
2. Fetch the options in the relevant controller method and assign to template
3. Add `filterDropDownRegistry['ColumnName'] = [...]` to the relevant `.tpl` file
4. Add the column name to `$columnMap` in `getPipelineJobOrder.php` if it needs to work in the pipeline

No JS changes needed — `FilterFactory` and `DropDownFilter` handle it automatically.