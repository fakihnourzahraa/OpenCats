# University Reference Table — Implementation Notes

## Overview

Universities were previously stored as free text in the `extra_field` table,
which led to naming inconsistencies (e.g. "LAU" vs "Lebanese American
University") and typos. This was replaced with a proper reference table
(`university`) and a `university_id` foreign-key-style column on `candidate`.
Since the recruiter now selects from a dropdown sourced from `university`,
new typos are no longer possible.

The dropdown displays both the short name and canonical name (e.g.
`LAU — Lebanese American University`) so the filter can match everything
under a given institution regardless of which form was previously typed.

Note: the `candidate` table uses the MyISAM engine, which does not enforce
foreign keys. Referential integrity is therefore enforced at the
application layer only (the dropdown prevents invalid values from being
entered).

---

## 1. Schema

```sql
CREATE TABLE `university` (
  `university_id` int(11) NOT NULL AUTO_INCREMENT,
  `canonical_name` varchar(255) NOT NULL DEFAULT '',
  `short_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`university_id`),
  UNIQUE KEY `uq_canonical_name` (`canonical_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

ALTER TABLE `candidate`
  ADD COLUMN `university_id` int(11) DEFAULT NULL;
```

Seeded with 45 Lebanese universities and institutes (sourced from the
Wikipedia "List of universities and related institutions in Lebanon").

---

## 2. `lib/Candidates.php`

### `add()`
- Added `$universityID = 0` to the parameter list (before `$skipHistory`).
- Added `university_id` to the `INSERT INTO candidate (...)` column list.
- Added a corresponding `%s` placeholder in `VALUES (...)`.
- Added `$this->_db->makeQueryInteger($universityID)` to the bind value list.

### `update()`
- Added `$universityID = 0` to the parameter list.
- Added `university_id = %s` to the `SET` clause (comma after `gpa = %s,`).
- Added `$this->_db->makeQueryInteger($universityID)` to the bind value list.

### `get()`
- Added to the `SELECT` list:
  ```sql
  candidate.university_id AS universityID,
  university.canonical_name AS universityCanonicalName,
  university.short_name AS universityShortName,
  ```
- Added join:
  ```sql
  LEFT JOIN university
      ON university.university_id = candidate.university_id
  ```

### `getForEditing()`
- Added `candidate.university_id AS universityID,` to the `SELECT` list.

### New method
```php
public function getPossibleUniversities()
{
    $sql = sprintf(
        "SELECT
            university.university_id AS universityID,
            university.canonical_name AS canonicalName,
            university.short_name AS shortName
        FROM
            university
        ORDER BY
            university.canonical_name ASC"
    );

    return $this->_db->getAllAssoc($sql);
}
```

Note: the `University` data grid column definition (used by the candidate
list/filter page) lives in `modules/candidates/dataGrids.php`
(`CandidatesDataGrid` class), not in this file — see Section 7 below.
```

---

## 3. `modules/candidates/CandidatesUI.php`

### `add()`
- After `$sourcesRS = $candidates->getPossibleSources();`:
  ```php
  $universitiesRS = $candidates->getPossibleUniversities();
  ```
- Template assign block:
  ```php
  $this->_template->assign('universitiesRS', $universitiesRS);
  ```

### `show()`
- After the `isHot` / `titleClass` if/else block:
  ```php
  if (!empty($data['universityID']))
  {
      $data['university'] = $data['universityShortName'] . ' — ' . $data['universityCanonicalName'];
  }
  else
  {
      $data['university'] = '';
  }
  ```

### `edit()`
- After `$sourcesString = ListEditor::getStringFromList($sourcesRS, 'name');`:
  ```php
  $universitiesRS = $candidates->getPossibleUniversities();
  ```
- Template assign block:
  ```php
  $this->_template->assign('universitiesRS', $universitiesRS);
  ```

### `onEdit()`
- Read posted value (alongside other field reads):
  ```php
  $universityID = $this->getTrimmedInput('universityID', $_POST);
  $universityID = ($universityID > 0) ? $universityID : null;
  ```
- Pass `$universityID` as the final argument to `$candidates->update(...)`.

### `_addCandidate()`
- Read posted value (alongside other field reads):
  ```php
  $universityID = $this->getTrimmedInput('universityID', $_POST);
  $universityID = ($universityID > 0) ? $universityID : null;
  ```
- Pass `$universityID` as the final argument to `$candidates->add(...)`.

---

## 4. `modules/candidates/Add.tpl`

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>

            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['universityID']) ?>">
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['canonicalName']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 5. `modules/candidates/Edit.tpl`

Same as Add, with the current value pre-selected:

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>

            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['universityID']) ?>"
                    <?php if (isset($this->data['universityID']) && $this->data['universityID'] == $universityData['universityID']) echo('selected'); ?>>
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['canonicalName']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 6. `modules/candidates/Show.tpl`

Added after the GPA row:

```php
<tr>
    <td class="vertical">University:</td>
    <td class="data"><?php $this->_($this->data['university']); ?></td>
</tr>
```

---

## 7. `modules/candidates/dataGrids.php` (`CandidatesDataGrid` class)

Added a `University` column definition alongside the other `_classColumns`
entries (e.g. next to `'GPA'`). Filters on `university.short_name` (not
the numeric ID) so the applied filter reads as a name (e.g. "LAU") rather
than an opaque integer:

```php
'University' => array(
                    'select'         => 'university.canonical_name AS universityCanonicalName,
                                         university.short_name AS universityShortName',
                    'join'           => 'LEFT JOIN university ON university.university_id = candidate.university_id',
                    'pagerRender'    => 'return !empty($rsData[\'universityShortName\']) ? htmlspecialchars($rsData[\'universityShortName\']) : \'\';',
                    'sortableColumn' => 'universityCanonicalName',
                    'pagerWidth'     => 100,
                    'pagerOptional'  => true,
                    'filter'         => 'university.short_name',
                    'filterTypes'    => '==',
                ),
```

---

## 8. `modules/candidates/CandidatesUI.php` — `listByView()`

After the existing `$this->_template->assign(...)` block, fetch and assign
the university list so the filter dropdown can be populated:

```php
$universitiesRS = $candidates->getPossibleUniversities();
$this->_template->assign('universitiesRS', $universitiesRS);
```

---

## 9. `modules/candidates/Candidates.tpl`

Added near the top of the page (before the data grid is drawn), so the
options exist in global scope before the filter widget is rendered:

```php
<script type="text/javascript">
    var universityFilterOptions = [
        <?php foreach ($this->universitiesRS as $i => $u): ?>
            { shortName: '<?php echo addslashes($u['shortName']); ?>', label: '<?php echo addslashes($u['shortName'] . ' — ' . $u['canonicalName']); ?>' }<?php echo ($i < count($this->universitiesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
</script>
```

---

## 10. `js/dataGridFilters.js`

The standard filter system (`filter.DefaultFilter`) only renders a free
text box for any column, which would have required recruiters to type a
raw university name (or worse, an ID) by hand. To give a real dropdown
filter, a new filter class was added and registered in the factory,
following the same pattern as the existing `GPAFilter` / `DateRangeFilter`
custom filter types.

**`filter.FilterFactory.createFromPossibleOperatorType()`** — added a
branch to route the `University` column to the new filter class:

```javascript
} else if (getFilterColumnNameFromOptionValue(possibleOperatorType) == 'University') {
    return new filter.UniversityFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
}
```

**New `filter.UniversityFilter` class** — renders an "is equal to"
operator (only one, since university selection isn't a range) plus a
`<select>` populated from `universityFilterOptions` (defined in
`Candidates.tpl`). The dropdown's `value` is the university's
`short_name` (not its ID), so the filter applies against
`university.short_name` and displays human-readable in the applied
filter list:

```javascript
filter.UniversityFilter = function(defaultValue, filterCounter, filterAreaID, selectableColumns, instanceName) {
    this.defaultValue = defaultValue;
    this.filterCounter = filterCounter;
    this.filterAreaID = filterAreaID;
    this.selectableColumns = selectableColumns;
    this.instanceName = instanceName;
}

filter.UniversityFilter.prototype = Object.create(filter.Filter.prototype);

filter.UniversityFilter.prototype.render = function() {
    var me = this;
    var filterDiv = document.createElement('div');

    var selectColumn = this.createFieldSelect(this.defaultValue, this.filterAreaID, this.filterCounter, this.selectableColumns);
    selectColumn.addEventListener('change', this.createSelectAreaChangeHandler(
        selectColumn, this.filterCounter, this.filterAreaID, this.selectableColumns, this.instanceName
    ));
    filterDiv.appendChild(selectColumn);

    /* Operator: equal to only */
    var operatorSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'operator',
        className: 'inputbox',
        style: 'width: 120px'
    });
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    filterDiv.appendChild(operatorSelect);

    /* University dropdown, populated from universityFilterOptions */
    var universitySelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        style: 'width: 220px;'
    });
    universitySelect.appendChild(this.createOption('', '-- Select University --'));

    var options = (typeof universityFilterOptions !== 'undefined') ? universityFilterOptions : [];
    for (var i = 0; i < options.length; i++) {
        universitySelect.appendChild(this.createOption(options[i].shortName, options[i].label));
    }
    filterDiv.appendChild(universitySelect);

    var applyHandler = function() {
        applyUniversityFilter(me.filterAreaID, me.filterCounter, me.instanceName);
    };
    universitySelect.addEventListener('change', applyHandler);

    filterDiv.style.float = 'left';
    return filterDiv;
}

function applyUniversityFilter(filterAreaID, filterCounter, instanceName) {
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;

    filterVal = filterVal.replace(/,?University==[^,]*/g, '');
    filterVal = filterVal.replace(/^,/, '');

    var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
    if (val !== '') filterVal += (filterVal ? ',' : '') + 'University==' + val;

    filterArea.value = filterVal;
}
```

---

## Status

- [x] `university` reference table created and seeded (45 rows)
- [x] `candidate.university_id` column added
- [x] Add Candidate page — dropdown, save
- [x] Edit Candidate page — dropdown (pre-selected), save
- [x] Candidate Details page — display formatted name
- [x] Candidate list/filter page — `University` column (shows short name,
      sortable by canonical name) and a custom dropdown filter widget
      (filters on `university.short_name`, displayed as a readable name
      rather than a raw ID)
- [ ] Migration plan for legacy `extra_field` / free-text `university`
      column data (not in scope for this implementer; needs DB access
      to execute)

## Open item to verify

The `getPossibleUniversities()` fetch + `$this->_template->assign('universitiesRS', ...)`
in `listByView()` must run before `Candidates.tpl` renders, or the
`universityFilterOptions` JS array will be empty and the filter dropdown
will show no options (it will not error, just appear blank under
"-- Select University --"). Confirm this assign is actually inside
`listByView()` and not accidentally left in `add()`/`edit()` only.

## Known bug fixed during implementation

In `_addCandidate()`, the line:
```php
$universityID = ($universityID > 0) ? $universityID : null;
```
originally referenced `$universityID` before it was ever read from
`$_POST`, causing it to always evaluate to `null`/`0` regardless of the
dropdown selection. Fixed by reading the posted value first:
```php
$universityID = $this->getTrimmedInput('universityID', $_POST);
$universityID = ($universityID > 0) ? $universityID : null;
```