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
            '=in': 'is in',
            '=e' : 'is empty'
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
} else if (filterDateRangeRegistry && filterDateRangeRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else if (filterRangeRegistry && filterRangeRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.RangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
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
    for (var i = 0; i < possibleTypes.length;)
    {
        var possibleType;
        if (possibleTypes.substr(i, 3) === '=d>' || possibleTypes.substr(i, 3) === '=d<' || possibleTypes.substr(i, 3) === '=in') {
            possibleType = possibleTypes.substr(i, 3);
            i += 3;
        } else {
            possibleType = possibleTypes.substr(i, 2);
            i += 2;
        }
        var names = filter.getNames();
        if (names[possibleType]) {
            operatorSelect.appendChild(
                this.createOption(possibleType, names[possibleType])
            );
        }
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

filter.DefaultFilter.prototype.render = function() {
    var filterDiv = document.createElement('div');
    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    filterDiv.appendChild(selectColumn);
    var operatorSelectColumn = this.createOperatorSelect(selectColumn.value, this.filterAreaID, this.filterCounter);
    filterDiv.appendChild(operatorSelectColumn);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn,
        this.filterCounter,
        this.filterAreaID,
        this.selectableColumns,
        this.instanceName
    ));
    var inputArea = this.createInputArea(this.filterAreaID, this.filterCounter, this.instanceName);
    filterDiv.appendChild(inputArea);
    filterDiv.style.float='left';
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

var filterDropDownRegistry = {};
var filterIsInRegistry = {};
var filterDateRangeRegistry = {};
var filterRangeRegistry = {};

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

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('==', 'is in'));
    operatorSelect.appendChild(this.createOption('=e', 'is empty'));


    filterDiv.appendChild(operatorSelect);

var valueArea = document.createElement('div');
    valueArea.style.cssText = 'display:inline-block; vertical-align:middle;';
    filterDiv.appendChild(valueArea);

    function buildValueWidget(options, onSelect) {
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
        searchInput.style.cssText = 'width:100%; box-sizing:border-box; padding:4px; border:none; border-bottom:1px solid #ccc;';

        var list = document.createElement('div');
        list.style.cssText = 'max-height:200px; overflow-y:auto;';

        var hiddenInput = document.createElement('input');
        hiddenInput.type = 'hidden';
        hiddenInput.id   = me.filterAreaID + me.filterCounter + 'value';

        function buildList(filterText) {
            list.innerHTML = '';
            for (var i = 0; i < options.length; i++) {
                var opt = options[i];
                if (filterText && opt.label.toLowerCase().indexOf(filterText.toLowerCase()) === -1) continue;
                (function(o) {
                    var item = document.createElement('div');
                    item.style.cssText = 'padding:4px 8px; cursor:pointer;';
                    item.textContent = o.label;
                    item.addEventListener('mouseenter', function() { this.style.background = '#eee'; });
                    item.addEventListener('mouseleave',  function() { this.style.background = '';    });
                    item.addEventListener('click', function() {
                        hiddenInput.value   = o.value;
                        display.textContent = o.label;
                        panel.style.display = 'none';
                        onSelect();
                    });
                    list.appendChild(item);
                })(opt);
            }
        }

        buildList('');
        searchInput.addEventListener('input', function() { buildList(this.value); });
        display.addEventListener('click', function(e) {
            e.stopPropagation();
            panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
            if (panel.style.display === 'block') {
                searchInput.value = '';
                buildList('');
                searchInput.focus();
            }
        });
        document.addEventListener('click', function() { panel.style.display = 'none'; });

        panel.appendChild(searchInput);
        panel.appendChild(list);
        wrapper.appendChild(display);
        wrapper.appendChild(hiddenInput);
        wrapper.appendChild(panel);
        return wrapper;
    }

    function updateValueArea() {
        valueArea.innerHTML = '';
        var op = operatorSelect.value;
        if (op === '=e') {
        applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
        return;
    }
        var options = op === '=in'
            ? (filterIsInRegistry[columnName] || [])
            : (filterDropDownRegistry[columnName] || []);
        valueArea.appendChild(buildValueWidget(options, function() {
            applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
        }));
    }

    operatorSelect.addEventListener('change', function() { updateValueArea(); });
    updateValueArea();

    filterDiv.style.float = 'left';
    return filterDiv;
}

function applyDropDownFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;
    var op = document.getElementById(filterAreaID + filterCounter + 'operator').value;

    var pattern = new RegExp(',?' + columnName + '(?:==|=in|=e)[^,]*', 'g');
    filterVal = filterVal.replace(pattern, '').replace(/^,/, '');

    if (op === '=e') {
        filterVal += (filterVal ? ',' : '') + columnName + '=e';
    } else {
        var valEl = document.getElementById(filterAreaID + filterCounter + 'value');
        var val = valEl ? valEl.value : '';
        if (val !== '') filterVal += (filterVal ? ',' : '') + columnName + op + val;
    }
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

    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    operatorSelect.appendChild(this.createOption('==',     'is equal to'));
    operatorSelect.appendChild(this.createOption('=>',     'is after'));
    operatorSelect.appendChild(this.createOption('=<',     'is before'));
operatorSelect.appendChild(this.createOption('=e', 'is empty'));
    filterDiv.appendChild(operatorSelect);

    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox', type: 'text',
        placeholder: 'mm-dd-yy', style: 'width: 80px;'
    });
    filterDiv.appendChild(singleInput);

    var rangeSpan = this.createElement('span', {
        id: this.filterAreaID + this.filterCounter + 'range',
        style: 'display:none;'
    });
    var fromInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'from',
        className: 'inputbox', type: 'text',
        placeholder: 'mm-dd-yy', style: 'width: 80px;'
    });
    var toInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'to',
        className: 'inputbox', type: 'text',
        placeholder: 'mm-dd-yy', style: 'width: 80px;'
    });
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' ' }));
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' and ' }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);


var getColumn = function() { return getFilterColumnNameFromOptionValue(selectColumn.value); };
    var applyFilter = function() {
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, getColumn());
    };

var updateHandler = function() {
    var op     = document.getElementById(me.filterAreaID + me.filterCounter + 'operator').value;
    var single = document.getElementById(me.filterAreaID + me.filterCounter + 'value');
    var range  = document.getElementById(me.filterAreaID + me.filterCounter + 'range');
    if (op === 'between') {
        single.style.display = 'none';
        range.style.display  = '';
    } else if (op === '=e') {
        single.style.display = 'none';
        range.style.display  = 'none';
    } else {
        single.style.display = '';
        range.style.display  = 'none';
    }
    applyFilter();
};

    var previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
selectColumn.addEventListener('change', function() {
    applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, previousColumn);
    previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
    applyFilter();
});

    operatorSelect.addEventListener('change', updateHandler);
    singleInput.addEventListener('change', applyFilter);
    fromInput.addEventListener('change',   applyFilter);
    toInput.addEventListener('change',     applyFilter);
    setTimeout(updateHandler, 0);

    filterDiv.style.float = 'left';
    return filterDiv;
};

function applyDateRangeFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var op         = document.getElementById(filterAreaID + filterCounter + 'operator').value;
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal  = filterArea.value;
filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=e[^,]*', 'g'), '');
    // Remove any existing filters for THIS column (using escapedColumn in the regex)
    var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=d>[^,]*', 'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=d<[^,]*', 'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '==[^,]*',  'g'), '');
    filterVal = filterVal.replace(/^,/, '').replace(/,$/, '');

    // Map the UI operator values to the filter string operators
    var opMap = { '=>': '=d>', '=<': '=d<', '==': '==' };

    if (op === 'between') {
        var from = document.getElementById(filterAreaID + filterCounter + 'from').value.trim();
        var to   = document.getElementById(filterAreaID + filterCounter + 'to').value.trim();
        if (from) filterVal += (filterVal ? ',' : '') + columnName + '=d>' + from;
        if (to)   filterVal += (filterVal ? ',' : '') + columnName + '=d<' + to;
    } else if (opMap[op]) {
        var val = document.getElementById(filterAreaID + filterCounter + 'value').value.trim();
        if (val) filterVal += (filterVal ? ',' : '') + columnName + opMap[op] + val;
    }
     else if (op === '=e') {
    filterVal += (filterVal ? ',' : '') + columnName + '=e';
}

    filterArea.value = filterVal;
}


filter.RangeFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.RangeFilter.prototype = Object.create(filter.Filter.prototype);

filter.RangeFilter.prototype.render = function() {
    var me = this;
    var filterDiv = document.createElement('div');

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('between', 'is between'));
    operatorSelect.appendChild(this.createOption('==',      'is equal to'));
    operatorSelect.appendChild(this.createOption('=>',      'is greater than'));
    operatorSelect.appendChild(this.createOption('=<',      'is less than'));
    operatorSelect.appendChild(this.createOption('=e', 'is empty'));
    filterDiv.appendChild(operatorSelect);

    var singleInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        type: 'number',
        style: 'width: 80px;'
    });
    filterDiv.appendChild(singleInput);

    var rangeSpan = this.createElement('span', {
        id: this.filterAreaID + this.filterCounter + 'range',
        style: 'display:none;'
    });
    var fromInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'from',
        className: 'inputbox',
        type: 'number',
        style: 'width: 80px;'
    });
    var toInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'to',
        className: 'inputbox',
        type: 'number',
        style: 'width: 80px;'
    });
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement('span', { innerHTML: ' and ' }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);

   var getColumn = function() { return getFilterColumnNameFromOptionValue(selectColumn.value); };
    var applyFilter = function() {
        applyRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, getColumn());
    };

    var updateHandler = function() {
        var op     = document.getElementById(me.filterAreaID + me.filterCounter + 'operator').value;
        var single = document.getElementById(me.filterAreaID + me.filterCounter + 'value');
        var range  = document.getElementById(me.filterAreaID + me.filterCounter + 'range');
        if (op === 'between') {
            single.style.display = 'none';
            range.style.display  = '';
        } else {
            single.style.display = '';
            range.style.display  = 'none';
        }
        applyFilter();
    };

var previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);

selectColumn.addEventListener('change', function() {
    applyRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, previousColumn);
    previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
    applyFilter();
});


    operatorSelect.addEventListener('change', updateHandler);
    singleInput.addEventListener('change', applyFilter);
    fromInput.addEventListener('change',   applyFilter);
    toInput.addEventListener('change',     applyFilter);
    setTimeout(updateHandler, 0);

    filterDiv.style.float = 'left';
    return filterDiv;
};

function applyRangeFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var op        = document.getElementById(filterAreaID + filterCounter + 'operator').value;
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal  = filterArea.value;
filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=e[^,]*', 'g'), '');

    var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=>[^,]*',  'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=<[^,]*',  'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '==[^,]*',  'g'), '');
    filterVal = filterVal.replace(/^,/, '').replace(/,$/, '');

    if (op === 'between') {
        var from = document.getElementById(filterAreaID + filterCounter + 'from').value;
        var to   = document.getElementById(filterAreaID + filterCounter + 'to').value;
        if (from !== '') filterVal += (filterVal ? ',' : '') + columnName + '=>' + from;
        if (to   !== '') filterVal += (filterVal ? ',' : '') + columnName + '=<' + to;
    } else if (op === '==' || op === '=>' || op === '=<') {
        var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
        if (val !== '') filterVal += (filterVal ? ',' : '') + columnName + op + val;
    }
    else if (op === '=e') {
    filterVal += (filterVal ? ',' : '') + columnName + '=e';
}

    filterArea.value = filterVal;
}
(function() {
    if (!filter.DefaultFilter || !filter.DefaultFilter.prototype.render) return;
    var _origRender = filter.DefaultFilter.prototype.render;
    filter.DefaultFilter.prototype.render = function() {
        var me = this;
        var div = _origRender.call(this);
        var operatorSel = div.querySelector('[id$="operator"]');
        var valueInput  = div.querySelector('[id$="value"]');
        if (operatorSel && valueInput) {
            operatorSel.addEventListener('change', function() {
                if (operatorSel.value === '=e') {
                    valueInput.style.display = 'none';
                    var colSel = div.querySelector('[id$="columnName"]');
                    var col = colSel ? getFilterColumnNameFromOptionValue(colSel.value) : '';
                    var filterArea = document.getElementById('filterArea' + me.instanceName);
                    if (filterArea && col) {
                        var fv = filterArea.value;
                        var esc = col.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
                        fv = fv.replace(new RegExp(',?' + esc + '=[^,]*', 'g'), '').replace(/^,/, '').replace(/,$/, '');
                        filterArea.value = (fv ? fv + ',' : '') + col + '=e';
                    }
                } else {
                    valueInput.style.display = '';
                }
            });
        }
        return div;
    };
})();