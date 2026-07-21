
var filterDropDownRegistry = {};
var filterIsInRegistry = {};
var filterDateRangeRegistry = {};

var filter = {
    getNames: function() {
        return {
            "==": "is equal to",
            "=~": "contains",
            "=<": "is less than",
            "=>": "is greater than",
            "=#": "has element",
            "=@": "Near",
            "=d>": "is after",
            "=d<": "is before",
            "=in": "is in",
            "=e" : "is empty",
            "=bt": "is between"
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
            filterBr = document.createElement("br");
            filterBr.clear = "all";
        
            filterArea.appendChild(filterBr);

            for (var i = 1; i < filterCounter; i++)
            {
                var columnSelector = document.getElementById(filterAreaID+i+"columnName");
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
    var col   = getFilterColumnNameFromOptionValue(possibleOperatorType);
    var types = getFilterColumnTypesFromOptionValue(possibleOperatorType) || "";

    if (types == "=@") {
        return new filter.NearZipCodeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    }
     var hasDate  = types.indexOf("=d>") !== -1 || types.indexOf("=d<") !== -1;
    var hasRange = !hasDate && (types.indexOf("=>") !== -1 || types.indexOf("=<") !== -1);
    var hasText  = types.indexOf("=~") !== -1;
    var hasDrop = !!filterDropDownRegistry[col];
    var families = (hasDate ? 1 : 0) + (hasRange ? 1 : 0) + (hasText ? 1 : 0) + (hasDrop ? 1 : 0);

    if (families > 1) {
        return new filter.DefaultFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    }

    if (hasDate)  return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    if (hasRange) return new filter.RangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
    if (hasDrop)  return new filter.DropDownFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);

        return new filter.DefaultFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);

}

filter.Filter = function() {
}

filter.Filter.prototype.createFieldSelect = function(defaultValue, filterAreaID, filterCounter, selectableColumns) {
    var selectColumn = document.createElement("select");
    for (var i = 0; i < selectableColumns.length; i++)
    {
        selectColumn.appendChild(this.createOption(
            selectableColumns[i],
            getFilterColumnNameFromOptionValue(selectableColumns[i]),
            defaultValue == selectableColumns[i]
        ));
    }
    selectColumn.id = filterAreaID+filterCounter+"columnName";
    selectColumn.className = "inputbox";
    return selectColumn;
}


filter.Filter.prototype.createOption = function(value, innerHtml, isSelected) {
    var option = document.createElement("option");
    option.value = value;
    option.innerHTML = innerHtml;
    if (isSelected) {
        option.selected = "selected";
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
    var operatorSelect = this.createElement("select", {
        id: filterAreaID + filterCounter + "operator",
        className: "inputbox",
        style: "width: 120px"
    });
    var possibleTypes = getFilterColumnTypesFromOptionValue(currentValue);
    for (var i = 0; i < possibleTypes.length;)
    {
        var possibleType;
        if (possibleTypes.substr(i, 3) === "=d>" || possibleTypes.substr(i, 3) === "=d<" || possibleTypes.substr(i, 3) === "=in" || possibleTypes.substr(i, 3) == "=bt") {
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
        selectColumn, filterCounter, filterAreaID, selectableColumns, instanceName
) {
    return function() {
        if (selectColumn._colPanel && selectColumn._colPanel.parentNode) {
            selectColumn._colPanel.parentNode.removeChild(selectColumn._colPanel);
        }

        var newFilter = filter.FilterFactory.createFromPossibleOperatorType(
            selectColumn.value, filterCounter, filterAreaID, selectableColumns, instanceName
        );

        var filterArea = document.getElementById(filterAreaID);
        var currentFilter = selectColumn;
        while (currentFilter.parentNode && currentFilter.parentNode !== filterArea) {
            currentFilter = currentFilter.parentNode;
        }
        if (!currentFilter.parentNode) return;

        filterArea.insertBefore(newFilter.render(), currentFilter);
        filterArea.removeChild(currentFilter);
    };
}


filter.DefaultFilter.prototype.createInputAreaChangeHandler = function(instanceName, filterAreaID, filterCounter) {
    return function() {
        addColumnToFilter(
            "filterArea" + instanceName, 
            getFilterColumnNameFromOptionValue(document.getElementById(filterAreaID+filterCounter+"columnName").value),
            document.getElementById(filterAreaID+filterCounter+"operator").value,
            document.getElementById(filterAreaID+filterCounter+"value").value
        ); 
    };
}

filter.DefaultFilter.prototype.createInputArea = function(filterAreaID, filterCounter, instanceName) {
    var inputArea = document.createElement("input");
    inputArea.id = filterAreaID+filterCounter+"value";
    inputArea.style.width="180px";
    var inputAreaChangeHandler = this.createInputAreaChangeHandler(instanceName, filterAreaID, filterCounter)
    if (inputArea.addEventListener) {
        inputArea.addEventListener("change", inputAreaChangeHandler, false);
     } else if (inputArea.attachEvent) {
        inputArea.attachEvent("onchange", inputAreaChangeHandler);
     }
     inputArea.className = "inputbox";
    return inputArea;
}

filter.DefaultFilter.prototype.buildDropDownValueWidget = function(options, onSelect) {
    var me = this;
    var select = document.createElement("select");
    select.id = me.filterAreaID + me.filterCounter + "value";
    select.className = "inputbox";
    select.style.width = "180px";

    var placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = "-- Select --";
    select.appendChild(placeholder);

    for (var i = 0; i < options.length; i++) {
        var opt = document.createElement("option");
        opt.value = options[i].value;
        opt.textContent = options[i].label;
        select.appendChild(opt);
    }

    select.addEventListener("change", onSelect);
    return select;
};

filter.DefaultFilter.prototype.render = function() {
    var me = this;
    var filterDiv = document.createElement("div");

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener("change", this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createOperatorSelect(selectColumn.value, this.filterAreaID, this.filterCounter);
    filterDiv.appendChild(operatorSelect);

    var valueArea = document.createElement("div");
    valueArea.style.cssText = "display:inline-block; vertical-align:middle;";
    filterDiv.appendChild(valueArea);

    var getColumn = function() { return getFilterColumnNameFromOptionValue(selectColumn.value); };

    var applyFilter = function() {
        var col = getColumn();
        var op  = operatorSelect.value;

        /* "=bt" is a UI-only operator: translate it into two real tokens. */
        if (op === "=bt") {
          var filterArea = document.getElementById("filterArea" + me.instanceName);
            var esc = col.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");
            var fv = filterArea.value;
            fv = fv.replace(new RegExp(",?" + esc + "=d>[^,]*", "g"), "");
            fv = fv.replace(new RegExp(",?" + esc + "=d<[^,]*", "g"), "");
            fv = fv.replace(new RegExp(",?" + esc + "=>[^,]*", "g"), "");
            fv = fv.replace(new RegExp(",?" + esc + "=<[^,]*", "g"), "");
            fv = fv.replace(new RegExp(",?" + esc + "==[^,]*", "g"), "");
            fv = fv.replace(new RegExp(",?" + esc + "=in[^,]*", "g"), "");
            fv = fv.replace(/^,/, "").replace(/,$/, "");

            var isDateCol = !!filterDateRangeRegistry[col];
            var gt = isDateCol ? "=d>" : "=>";
            var lt = isDateCol ? "=d<" : "=<";

            var fromEl = document.getElementById(me.filterAreaID + me.filterCounter + "from");
            var toEl   = document.getElementById(me.filterAreaID + me.filterCounter + "to");
            var from = fromEl ? fromEl.value : "";
            var to   = toEl   ? toEl.value   : "";
            if (from !== "") fv += (fv ? "," : "") + col + gt + from;
            if (to   !== "") fv += (fv ? "," : "") + col + lt + to;
            filterArea.value = fv;
            return;

        }

        var valEl = document.getElementById(me.filterAreaID + me.filterCounter + "value");
        addColumnToFilter("filterArea" + me.instanceName, col, op, valEl ? valEl.value : "");
    };

    var updateValueArea = function() {
        // valueArea.innerHTML = "";
        // var op  = operatorSelect.value;
        // var col = getColumn();
        if (valueArea._qsPanel && valueArea._qsPanel.parentNode) {
            valueArea._qsPanel.parentNode.removeChild(valueArea._qsPanel);
            valueArea._qsPanel = null;
        }
        valueArea.innerHTML = "";
        var op  = operatorSelect.value;
        var col = getColumn();

        if (op === "=e") {
            applyFilter();
            return;
        }

        /* Between: two inputs. */
        if (op === "=bt") {
            var fromInput = document.createElement("input");
            fromInput.id = me.filterAreaID + me.filterCounter + "from";
            fromInput.className = "inputbox";
            fromInput.style.width = "80px";
            fromInput.addEventListener("change", applyFilter);

            var andSpan = document.createElement("span");
            andSpan.innerHTML = " and ";

            var toInput = document.createElement("input");
            toInput.id = me.filterAreaID + me.filterCounter + "to";
            toInput.className = "inputbox";
            toInput.style.width = "80px";
            toInput.addEventListener("change", applyFilter);

            valueArea.appendChild(fromInput);
            valueArea.appendChild(andSpan);
            valueArea.appendChild(toInput);
              if (filterDateRangeRegistry[col]) {
                fromInput.placeholder = "mm-dd-yy";
                toInput.placeholder   = "mm-dd-yy";
            }
            return;
        }

        /* Is in: pick from the known values. */
        var dropOptions = filterDropDownRegistry[col] || null;
        if (dropOptions && dropOptions.length && op === "=in") {
            valueArea.appendChild(me.buildDropDownValueWidget(dropOptions, applyFilter));
            return;
        }

        // /* Everything else: a single typed value. */
        var input = document.createElement("input");
        input.id = me.filterAreaID + me.filterCounter + "value";
        input.className = "inputbox";
        input.style.width = "180px";
        input.addEventListener("change", applyFilter);
        valueArea.appendChild(input);
    };

    operatorSelect.addEventListener("change", updateValueArea);
    updateValueArea();

    filterDiv.style.float = "left";
    return filterDiv;
};


filter.NearZipCodeFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.NearZipCodeFilter.prototype = Object.create(filter.Filter.prototype);

filter.NearZipCodeFilter.prototype.render = function() {
    var filterDiv = document.createElement("div");
    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener("change", this.createSelectAreaChangeHandler(
        selectColumn,
        this.filterCounter,
        this.filterAreaID,
        this.selectableColumns,
        this.instanceName
    ));
    filterDiv.appendChild(selectColumn);
    /* Zipcode input area */
    filterDiv.appendChild(this.createElement(
        "span",
        {
            id: this.filterAreaID + this.filterCounter + "zip1",
            innerHTML: "Zipcode:"
        }
    )); 
    var inputAreaChangeHandlerZip = function() {
        addColumnToFilter("filterArea" + this.instanceName, 
            getFilterColumnNameFromOptionValue(document.getElementById(this.filterAreaID+this.filterCounter+"columnName").value),
            document.getElementById(this.filterAreaID+this.filterCounter+"operator").value,
            document.getElementById(this.filterAreaID+this.filterCounter+"zipInput1").value + "," + document.getElementById(this.filterAreaID+this.filterCounter+"zipInput2").value
        );
    };
    filterDiv.appendChild(this.createElement(
        "input",
        {
            id: this.filterAreaID + this.filterCounter + "zipInput1",
            style: "width: 80px",
            className: "inputbox,",
            innerHTML: "Zipcode:"
        },
        {
            change: inputAreaChangeHandlerZip
        }
    ));
    filterDiv.appendChild(this.createElement(
        "span",
        {
            id: this.filterAreaID + this.filterCounter + "zip2",
            innerHTML: "Distance to Zipcode (Miles):"
        }
    ));
    filterDiv.appendChild(this.createElement(
        "input",
        {
            id: this.filterAreaID+this.filterCounter+"zipInput2",
            style: "width: 80px;",
            className: "inputbox,",
            innerHTML: "Zipcode:",
            value: "25"
        },
        {
            change: inputAreaChangeHandlerZip
        }
    ));
    return filterDiv;
}


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
    var filterDiv = document.createElement("div");

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener("change", this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createElement("select", {
        id: this.filterAreaID + this.filterCounter + "operator",
        className: "inputbox",
        style: "width: 120px"
    });

    var isPipeline = (typeof window.isPipelineFilterPage !== 'undefined' && window.isPipelineFilterPage === true);
    if (isPipeline) {
        operatorSelect.appendChild(this.createOption("=in", "is in"));
    } else {
        operatorSelect.appendChild(this.createOption("==", "is in"));
    }
    operatorSelect.appendChild(this.createOption("=e", "is empty"));

    filterDiv.appendChild(operatorSelect);

    var valueArea = document.createElement("div");
    valueArea.style.cssText = "display:inline-block; vertical-align:middle;";
    filterDiv.appendChild(valueArea);

    function buildValueWidget(options, onSelect) {
        var select = document.createElement("select");
        select.id = me.filterAreaID + me.filterCounter + "value";
        select.className = "inputbox";
        select.style.width = "220px";

        var placeholder = document.createElement("option");
        placeholder.value = "";
        placeholder.textContent = "-- Select --";
        select.appendChild(placeholder);

        for (var i = 0; i < options.length; i++) {
            var opt = document.createElement("option");
            opt.value = options[i].value;
            opt.textContent = options[i].label;
            select.appendChild(opt);
        }

        select.addEventListener("change", onSelect);
        return select;
    }

    function updateValueArea() {
        valueArea.innerHTML = "";
        var op = operatorSelect.value;
        if (op === "=e") {
            applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
            return;
        }
        var options = op === "=in"
            ? (filterIsInRegistry[columnName] || [])
            : (filterDropDownRegistry[columnName] || []);
        valueArea.appendChild(buildValueWidget(options, function() {
            applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
        }));
    }

    operatorSelect.addEventListener("change", function() { updateValueArea(); });
    updateValueArea();

    filterDiv.style.float = "left";
    return filterDiv;
}


function applyDropDownFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var filterArea = document.getElementById("filterArea" + instanceName);
    var filterVal = filterArea.value;
    var op = document.getElementById(filterAreaID + filterCounter + "operator").value;

    var pattern = new RegExp(",?" + columnName + "(?:==|=in|=e)[^,]*", "g");
    filterVal = filterVal.replace(pattern, "").replace(/^,/, "");

    if (op === "=e") {
        filterVal += (filterVal ? "," : "") + columnName + "=e";
    } else {
        var valEl = document.getElementById(filterAreaID + filterCounter + "value");
        var val = valEl ? valEl.value : "";
        if (val !== "") filterVal += (filterVal ? "," : "") + columnName + op + val;
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
    var filterDiv = document.createElement("div");

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener("change", this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createElement("select", {
        id: this.filterAreaID + this.filterCounter + "operator",
        className: "inputbox",
        style: "width: 120px"
    });
    operatorSelect.appendChild(this.createOption("between", "is between"));
    operatorSelect.appendChild(this.createOption("==",     "is equal to"));
    operatorSelect.appendChild(this.createOption("=>",     "is after"));
    operatorSelect.appendChild(this.createOption("=<",     "is before"));
operatorSelect.appendChild(this.createOption("=e", "is empty"));
    filterDiv.appendChild(operatorSelect);

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
    rangeSpan.appendChild(this.createElement("span", { innerHTML: " " }));
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement("span", { innerHTML: " and " }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);


var getColumn = function() { return getFilterColumnNameFromOptionValue(selectColumn.value); };
    var applyFilter = function() {
        applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, getColumn());
    };

var updateHandler = function() {
    var op     = document.getElementById(me.filterAreaID + me.filterCounter + "operator").value;
    var single = document.getElementById(me.filterAreaID + me.filterCounter + "value");
    var range  = document.getElementById(me.filterAreaID + me.filterCounter + "range");
    if (op === "between") {
        single.style.display = "none";
        range.style.display  = "";
    } else if (op === "=e") {
        single.style.display = "none";
        range.style.display  = "none";
    } else {
        single.style.display = "";
        range.style.display  = "none";
    }
    applyFilter();
};

    var previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
selectColumn.addEventListener("change", function() {
    applyDateRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, previousColumn);
    previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
    applyFilter();
});

    operatorSelect.addEventListener("change", updateHandler);
    singleInput.addEventListener("change", applyFilter);
    fromInput.addEventListener("change",   applyFilter);
    toInput.addEventListener("change",     applyFilter);
    setTimeout(updateHandler, 0);

    filterDiv.style.float = "left";
    return filterDiv;
};

function applyDateRangeFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var op         = document.getElementById(filterAreaID + filterCounter + "operator").value;
    var filterArea = document.getElementById("filterArea" + instanceName);
    var filterVal  = filterArea.value;
      var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=e[^,]*", "g"), "");
    // Remove any existing filters for THIS column (using escapedColumn in the regex)
  
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=d>[^,]*", "g"), "");
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=d<[^,]*", "g"), "");
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "==[^,]*",  "g"), "");
    filterVal = filterVal.replace(/^,/, "").replace(/,$/, "");

    // Map the UI operator values to the filter string operators
    var opMap = { "=>": "=d>", "=<": "=d<", "==": "==" };

    if (op === "between") {
        var from = document.getElementById(filterAreaID + filterCounter + "from").value.trim();
        var to   = document.getElementById(filterAreaID + filterCounter + "to").value.trim();
        if (from) filterVal += (filterVal ? "," : "") + columnName + "=d>" + from;
        if (to)   filterVal += (filterVal ? "," : "") + columnName + "=d<" + to;
    } else if (opMap[op]) {
        var val = document.getElementById(filterAreaID + filterCounter + "value").value.trim();
        if (val) filterVal += (filterVal ? "," : "") + columnName + opMap[op] + val;
    }
     else if (op === "=e") {
    filterVal += (filterVal ? "," : "") + columnName + "=e";
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
    var filterDiv = document.createElement("div");

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener("change", this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    var operatorSelect = this.createElement("select", {
        id: this.filterAreaID + this.filterCounter + "operator",
        className: "inputbox",
        style: "width: 120px"
    });
    operatorSelect.appendChild(this.createOption("between", "is between"));
    operatorSelect.appendChild(this.createOption("==",      "is equal to"));
    operatorSelect.appendChild(this.createOption("=>",      "is greater than"));
    operatorSelect.appendChild(this.createOption("=<",      "is less than"));
    operatorSelect.appendChild(this.createOption("=e", "is empty"));
    filterDiv.appendChild(operatorSelect);

    var singleInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "value",
        className: "inputbox",
        type: "text",
        style: "width: 80px;"
    });
    filterDiv.appendChild(singleInput);

    var rangeSpan = this.createElement("span", {
        id: this.filterAreaID + this.filterCounter + "range",
        style: "display:none;"
    });
    var fromInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "from",
        className: "inputbox",
        type: "number",
        style: "width: 80px;"
    });
    var toInput = this.createElement("input", {
        id: this.filterAreaID + this.filterCounter + "to",
        className: "inputbox",
        type: "number",
        style: "width: 80px;"
    });
    rangeSpan.appendChild(fromInput);
    rangeSpan.appendChild(this.createElement("span", { innerHTML: " and " }));
    rangeSpan.appendChild(toInput);
    filterDiv.appendChild(rangeSpan);

   var getColumn = function() { return getFilterColumnNameFromOptionValue(selectColumn.value); };
    var applyFilter = function() {
        applyRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, getColumn());
    };

    var updateHandler = function() {
        var op     = document.getElementById(me.filterAreaID + me.filterCounter + "operator").value;
        var single = document.getElementById(me.filterAreaID + me.filterCounter + "value");
        var range  = document.getElementById(me.filterAreaID + me.filterCounter + "range");
        if (op === "between") {
            single.style.display = "none";
            range.style.display  = "";
        } else if (op === "=e") {
            single.style.display = "none";
            range.style.display  = "none";
        } else {
            single.style.display = "";
            range.style.display  = "none";
        }
        applyFilter();
    };

var previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);

selectColumn.addEventListener("change", function() {
    applyRangeFilter(me.filterAreaID, me.filterCounter, me.instanceName, previousColumn);
    previousColumn = getFilterColumnNameFromOptionValue(selectColumn.value);
    applyFilter();
});


    operatorSelect.addEventListener("change", updateHandler);
    singleInput.addEventListener("change", applyFilter);
    fromInput.addEventListener("change",   applyFilter);
    toInput.addEventListener("change",     applyFilter);
    setTimeout(updateHandler, 0);

    filterDiv.style.float = "left";
    return filterDiv;
};

function applyRangeFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var op        = document.getElementById(filterAreaID + filterCounter + "operator").value;
    var filterArea = document.getElementById("filterArea" + instanceName);
    var filterVal  = filterArea.value;
      var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");
filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=e[^,]*", "g"), "");
  
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=>[^,]*",  "g"), "");
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "=<[^,]*",  "g"), "");
    filterVal = filterVal.replace(new RegExp(",?" + escapedColumn + "==[^,]*",  "g"), "");
    filterVal = filterVal.replace(/^,/, "").replace(/,$/, "");

    if (op === "between") {
        var from = document.getElementById(filterAreaID + filterCounter + "from").value;
        var to   = document.getElementById(filterAreaID + filterCounter + "to").value;
        if (from !== "") filterVal += (filterVal ? "," : "") + columnName + "=>" + from;
        if (to   !== "") filterVal += (filterVal ? "," : "") + columnName + "=<" + to;
    } else if (op === "==" || op === "=>" || op === "=<") {
        var val = document.getElementById(filterAreaID + filterCounter + "value").value;
        if (val !== "") filterVal += (filterVal ? "," : "") + columnName + op + val;
    }
   else if (op === "=e") {
        filterVal += (filterVal ? "," : "") + columnName + "=e";
}

    filterArea.value = filterVal;
}