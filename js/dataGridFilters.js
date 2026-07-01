var filter = {
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
    makePreviousSelectionBoxesUnselectable: function(
        filterCounter,
        filterAreaID,
        selectableColumns
    ) {
        var filterArea = document.getElementById(filterAreaID);
        if (filterCounter > 1)
        {
            filterBr = document.createElement('br');
            filterBr.clear = 'all';
        
            filterArea.appendChild(filterBr);

            for (var i = 1; i < filterCounter; i++)
            {
                var columnSelector = document.getElementById(filterAreaID+i+'columnName');
                columnSelector.disabled=true;

                //Take previously filtered columns out of the list of filterable columns.
                for (var i2 = 0; i2 < selectableColumns.length; i2++)
                {
                    if (selectableColumns[i2] == columnSelector.value)
                    {
                        selectableColumns.splice(i2, 1);
                        i2--;
                    }
                }
            }
        }
    }
};

filter.FilterFactory = {}
filter.FilterFactory.createFromPossibleOperatorType = function(
    possibleOperatorType,
    filterCounter,
    filterAreaID,
    selectableColumns,
    instanceName
) {
    if (getFilterColumnTypesFromOptionValue(possibleOperatorType) == '=@') {
        return new filter.NearZipCodeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    } else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'GPA') {
        return new filter.GPAFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    } else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'Created') {
        return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName); 
    } else if (filterDropDownRegistry && filterDropDownRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
        return new filter.DropDownFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    }
     else {
        return new filter.DefaultFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    }
}

filter.Filter = function() {
}

filter.Filter.prototype.createFieldSelect = function(defaultValue, filterAreaID, filterCounter, selectableColumns) {
    var selectColumn = document.createElement('select');
    for (var i = 0; i < selectableColumns.length; i++)
    {
        selectColumn.appendChild(this.createOption(
            selectableColumns[i],
            getFilterColumnNameFromOptionValue(selectableColumns[i]),
            defaultValue == selectableColumns[i]
        ));
    }
    selectColumn.id = filterAreaID+filterCounter+'columnName';
    selectColumn.className = 'inputbox';
    return selectColumn;
}


filter.Filter.prototype.createOption = function(value, innerHtml, isSelected) {
    var option = document.createElement('option');
    option.value = value;
    option.innerHTML = innerHtml;
    if (isSelected) {
        option.selected = 'selected';
    } 
    return option;
}

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

filter.Filter.prototype.createElement = function(tagName, properties, eventListeners) {
    var element = document.createElement(tagName);
    for (var property in properties) {
        element[property] = properties[property];
    }
    if (eventListeners) {
        for (var eventName in eventListeners) {
            element.addEventListener(eventName, eventListeners[eventName]);
        }
    }
    return element;
}

filter.DefaultFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.DefaultFilter.prototype = Object.create(filter.Filter.prototype);

filter.DefaultFilter.prototype.createOperatorSelect = function(currentValue, filterAreaID, filterCounter) {
    var operatorSelect = this.createElement('select', {
        id: filterAreaID + filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    var possibleTypes = getFilterColumnTypesFromOptionValue(currentValue);
    for (var i = 0; i < possibleTypes.length; i+=2)
    {
        var possibleType = possibleTypes.substr(i,2);
        operatorSelect.appendChild(
            this.createOption(
                possibleType,
                filter.getNames()[possibleType]
            )
        );
    }
    return operatorSelect;
}

filter.Filter.prototype.createSelectAreaChangeHandler = function(
        selectColumn,
        filterCounter,
        filterAreaID,
        selectableColumns,
        instanceName
) {
    var me = this;
    return function() {
        var newFilter = filter.FilterFactory.createFromPossibleOperatorType(
            selectColumn.value,
            filterCounter,
            filterAreaID,
            selectableColumns,
            instanceName
        );
        var currentFilter = selectColumn.parentNode;
        var filterArea = currentFilter.parentNode;
        filterArea.insertBefore(newFilter.render(), currentFilter);
        filterArea.removeChild(currentFilter);
    };
}

filter.DefaultFilter.prototype.createInputAreaChangeHandler = function(instanceName, filterAreaID, filterCounter) {
    return function() {
        addColumnToFilter(
            'filterArea' + instanceName, 
            getFilterColumnNameFromOptionValue(document.getElementById(filterAreaID+filterCounter+'columnName').value),
            document.getElementById(filterAreaID+filterCounter+'operator').value,
            document.getElementById(filterAreaID+filterCounter+'value').value
        ); 
    };
}

filter.DefaultFilter.prototype.createInputArea = function(filterAreaID, filterCounter, instanceName) {
    var inputArea = document.createElement('input');
    inputArea.id = filterAreaID+filterCounter+'value';
    inputArea.style.width='180px';
    var inputAreaChangeHandler = this.createInputAreaChangeHandler(instanceName, filterAreaID, filterCounter)
    if (inputArea.addEventListener) {
        inputArea.addEventListener('change', inputAreaChangeHandler, false);
     } else if (inputArea.attachEvent) {
        inputArea.attachEvent('onchange', inputAreaChangeHandler);
     }
     inputArea.className = 'inputbox';
    return inputArea;
}

// filter.DefaultFilter.prototype.render = function() {
//     var filterDiv = document.createElement('div');
//     var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
//     filterDiv.appendChild(selectColumn);
//     var operatorSelectColumn = this.createOperatorSelect(selectColumn.value, this.filterAreaID, this.filterCounter);
//     filterDiv.appendChild(operatorSelectColumn);
//     selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
//         selectColumn,
//         this.filterCounter,
//         this.filterAreaID,
//         this.selectableColumns,
//         this.instanceName
//     ));
//     var inputArea = this.createInputArea(this.filterAreaID, this.filterCounter, this.instanceName);
//     filterDiv.appendChild(inputArea);
//     filterDiv.style.float='left';
//     return filterDiv;
// }

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


filter.NearZipCodeFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.NearZipCodeFilter.prototype = Object.create(filter.Filter.prototype);

filter.NearZipCodeFilter.prototype.render = function() {
    var filterDiv = document.createElement('div');
    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn,
        this.filterCounter,
        this.filterAreaID,
        this.selectableColumns,
        this.instanceName
    ));
    filterDiv.appendChild(selectColumn);
    /* Zipcode input area */
    filterDiv.appendChild(this.createElement(
        'span',
        {
            id: this.filterAreaID + this.filterCounter + 'zip1',
            innerHTML: 'Zipcode:'
        }
    )); 
    var inputAreaChangeHandlerZip = function() {
        addColumnToFilter('filterArea' + this.instanceName, 
            getFilterColumnNameFromOptionValue(document.getElementById(this.filterAreaID+this.filterCounter+'columnName').value),
            document.getElementById(this.filterAreaID+this.filterCounter+'operator').value,
            document.getElementById(this.filterAreaID+this.filterCounter+'zipInput1').value + ',' + document.getElementById(this.filterAreaID+this.filterCounter+'zipInput2').value
        );
    };
    filterDiv.appendChild(this.createElement(
        'input',
        {
            id: this.filterAreaID + this.filterCounter + 'zipInput1',
            style: 'width: 80px',
            className: 'inputbox,',
            innerHTML: 'Zipcode:'
        },
        {
            change: inputAreaChangeHandlerZip
        }
    ));
    filterDiv.appendChild(this.createElement(
        'span',
        {
            id: this.filterAreaID + this.filterCounter + 'zip2',
            innerHTML: 'Distance to Zipcode (Miles):'
        }
    ));
    filterDiv.appendChild(this.createElement(
        'input',
        {
            id: this.filterAreaID+this.filterCounter+'zipInput2',
            style: 'width: 80px;',
            className: 'inputbox,',
            innerHTML: 'Zipcode:',
            value: '25'
        },
        {
            change: inputAreaChangeHandlerZip
        }
    ));
    return filterDiv;
}

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

    /* Operator dropdown: is equal to, is between */
    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    

    filterDiv.appendChild(operatorSelect);

    /* Single value input */
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

    /* Range inputs (hidden by default) */
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

    /* Toggle single/range inputs based on operator */
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

    /* Remove existing GPA filters */
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


/* Registry: column name → options array. Populated per-page in .tpl files. */
var filterDropDownRegistry = {};

filter.DropDownFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.DropDownFilter.prototype = Object.create(filter.Filter.prototype);


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

    /* Operator dropdown */
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

    /* Single date input */
    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        type: 'text',
        placeholder: 'mm-dd-yy',
        style: 'width: 80px;'
    });
    filterDiv.appendChild(singleInput);

    /* Range inputs (hidden by default) */
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
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' ' }));
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' and ' }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);

    /* Toggle inputs based on operator */
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

    /* Remove existing filters for this column */
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