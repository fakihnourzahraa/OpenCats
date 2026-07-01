# University & Nationality — Implementation Notes

## Overview

Two new candidate fields were added to OpenCATS:

- **University** — stored as a foreign key (`university_id`) referencing a `university` reference table. Universities have both a canonical name ("Lebanese American University") and a short name ("LAU"). The dropdown displays both.
- **Nationality** — stored as a plain varchar (`nationality`) directly on the `candidate` table. The `nationality` table serves purely as a reference/dropdown source, not a relational key (same pattern as `source` on candidate). No join needed in queries.
- **Sources** 

Both fields appear on the Add, Edit, and Details pages, as well as the Candidates list filter and the Job Order pipeline filter.

The filter system uses a generic `filter.DropDownFilter` JS class driven by a `filterDropDownRegistry` object, making it easy to add further dropdown filters in the future without writing new JS classes.

Note: the `candidate` table uses the MyISAM engine, which does not enforce foreign keys. Referential integrity for `university_id` is enforced at the application layer only (the dropdown prevents invalid values from being entered).

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

INSERT INTO `university` (`canonical_name`, `short_name`) VALUES
('Académie Libanaise des Beaux-Arts', 'ALBA'),
('Al-Kafaàt University', 'AKU'),
('Al Maaref University', 'MU'),
('American University of Beirut', 'AUB'),
('American University of Culture & Education', 'AUCE'),
('American University of Science and Technology', 'AUST'),
('American University of Technology', 'AUT'),
('Antonine University', 'UA'),
('Arab Open University', 'AOU'),
('Arts, Sciences and Technology University in Lebanon', 'AUL'),
('Beirut Arab University', 'BAU'),
('Beirut Islamic University', 'BIU'),
('Conservatoire National des Arts et Métiers', 'Cnam'),
('East International University', 'EIU'),
('Ecole Superieure des Affaires', 'ESA'),
('Global University', 'GU'),
('Haigazian University', 'HU'),
('Islamic University of Lebanon', 'IUL'),
('Jinan University', 'JU'),
('Lebanese American University', 'LAU'),
('Lebanese Canadian University', 'LCU'),
('Lebanese German University', 'LGU'),
('Lebanese International University', 'LIU'),
('Lebanese National Higher Conservatory of Music', 'LNHCM'),
('Lebanese University', 'UL'),
('Makassed University of Beirut', 'MUB'),
('Middle East University', 'MEU'),
('Modern University for Business and Science', 'MUBS'),
('Notre Dame University - Louaize', 'NDU'),
('Phoenicia University', 'PU'),
('Rafik Hariri University', 'RHU'),
('Saint George University of Beirut', 'SGU'),
('Saint Joseph University of Beirut', 'USJ'),
('Tripoli University Institute for Islamic Studies', 'UT'),
('Université La Sagesse', 'ULS'),
('Université Libano-Française de Technologie et des Sciences Appliqués', 'ULF'),
('University of Balamand', 'UoB'),
('University of Sciences & Arts in Lebanon', 'USAL'),
('Université Saint-Esprit de Kaslik', 'USEK'),
('Université Sainte Famille', 'USF'),
('Joyaa University Institute of Technology', 'JUIT'),
('Ouzai University College', 'OUC'),
('Matn University College', 'MUC'),
('Sidoon University College', 'SUC'),
('Saint Paul Institute of Philosophy & Theology', 'NEST');

CREATE TABLE `nationality` (
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

ALTER TABLE `candidate`
  ADD COLUMN `nationality` varchar(255) DEFAULT NULL;

INSERT INTO `nationality` (`name`) VALUES
('Lebanese'),('Palestinian'),('Syrian'),('Armenian'),
('Afghan'),('Albanian'),('Algerian'),('American'),
('Andorran'),('Angolan'),('Anguillan'),('Citizen of Antigua and Barbuda'),
('Argentine'),('Australian'),('Austrian'),('Azerbaijani'),
('Bahamian'),('Bahraini'),('Bangladeshi'),('Barbadian'),
('Belarusian'),('Belgian'),('Belizean'),('Beninese'),
('Bermudian'),('Bhutanese'),('Bolivian'),('Citizen of Bosnia and Herzegovina'),
('Botswanan'),('Brazilian'),('British'),('British Virgin Islander'),
('Bruneian'),('Bulgarian'),('Burkinan'),('Burmese'),('Burundian'),
('Cambodian'),('Cameroonian'),('Canadian'),('Cape Verdean'),
('Cayman Islander'),('Central African'),('Chadian'),('Chilean'),
('Chinese'),('Colombian'),('Comoran'),('Congolese (Congo)'),
('Congolese (DRC)'),('Cook Islander'),('Costa Rican'),('Croatian'),
('Cuban'),('Cymraes'),('Cymro'),('Cypriot'),('Czech'),
('Danish'),('Djiboutian'),('Dominican'),('Citizen of the Dominican Republic'),('Dutch'),
('East Timorese'),('Ecuadorean'),('Egyptian'),('Emirati'),('English'),
('Equatorial Guinean'),('Eritrean'),('Estonian'),('Ethiopian'),
('Faroese'),('Fijian'),('Filipino'),('Finnish'),('French'),
('Gabonese'),('Gambian'),('Georgian'),('German'),('Ghanaian'),
('Gibraltarian'),('Greek'),('Greenlandic'),('Grenadian'),('Guamanian'),
('Guatemalan'),('Citizen of Guinea-Bissau'),('Guinean'),('Guyanese'),
('Haitian'),('Honduran'),('Hong Konger'),('Hungarian'),
('Icelandic'),('Indian'),('Indonesian'),('Iranian'),('Iraqi'),('Irish'),('Italian'),('Ivorian'),
('Jamaican'),('Japanese'),('Jordanian'),
('Kazakh'),('Kenyan'),('Kittitian'),('Citizen of Kiribati'),('Kosovan'),('Kuwaiti'),('Kyrgyz'),
('Lao'),('Latvian'),('Liberian'),('Libyan'),('Liechtenstein citizen'),('Lithuanian'),('Luxembourger'),
('Macanese'),('Macedonian'),('Malagasy'),('Malawian'),('Malaysian'),('Maldivian'),('Malian'),
('Maltese'),('Marshallese'),('Martiniquais'),('Mauritanian'),('Mauritian'),
('Mexican'),('Micronesian'),('Moldovan'),('Monegasque'),('Mongolian'),
('Montenegrin'),('Montserratian'),('Moroccan'),('Mosotho'),('Mozambican'),
('Namibian'),('Nauruan'),('Nepalese'),('New Zealander'),('Nicaraguan'),
('Nigerian'),('Nigerien'),('Niuean'),('North Korean'),('Northern Irish'),('Norwegian'),
('Omani'),
('Pakistani'),('Palauan'),('Panamanian'),('Papua New Guinean'),('Paraguayan'),
('Peruvian'),('Pitcairn Islander'),('Polish'),('Portuguese'),('Prydeinig'),('Puerto Rican'),
('Qatari'),
('Romanian'),('Russian'),('Rwandan'),
('Salvadorean'),('Sammarinese'),('Samoan'),('Sao Tomean'),('Saudi Arabian'),
('Scottish'),('Senegalese'),('Serbian'),('Citizen of Seychelles'),('Sierra Leonean'),
('Singaporean'),('Slovak'),('Slovenian'),('Solomon Islander'),('Somali'),
('South African'),('South Korean'),('South Sudanese'),('Spanish'),('Sri Lankan'),
('St Helenian'),('St Lucian'),('Stateless'),('Sudanese'),('Surinamese'),
('Swazi'),('Swedish'),('Swiss'),
('Taiwanese'),('Tajik'),('Tanzanian'),('Thai'),('Togolese'),('Tongan'),
('Trinidadian'),('Tristanian'),('Tunisian'),('Turkish'),('Turkmen'),
('Turks and Caicos Islander'),('Tuvaluan'),
('Ugandan'),('Ukrainian'),('Uruguayan'),('Uzbek'),
('Vatican citizen'),('Citizen of Vanuatu'),('Venezuelan'),('Vietnamese'),('Vincentian'),
('Wallisian'),('Welsh'),
('Yemeni'),
('Zambian'),('Zimbabwean');
```

Notes on nationality table design:
- `name` is the primary key — no separate ID column. Since nationality names don't change and are already unique, the name itself serves as both the stored value and the display label. No join is needed anywhere — the name is stored directly on `candidate.nationality`, matching how `source` works.
- Lebanese, Palestinian, Syrian, Armenian are inserted first so they appear at the top of the dropdown. MyISAM returns rows in insertion order with no `ORDER BY`, which is intentional here.

---

## 2. `lib/Candidates.php`

### `getPossibleDropDownOptions()` — new generic method

Replaces the old `getPossibleUniversities()`. Used for both university and nationality, and can be reused for any future reference-table dropdown by passing the table/column names as parameters.

```php
public function getPossibleDropDownOptions($table, $valueColumn, $labelColumn, $shortColumn = null, $orderBy = null)
{
    $orderBy = $orderBy ? $orderBy : $labelColumn;
    $shortSelect = $shortColumn ? ", $table.$shortColumn AS shortName" : ", $table.$labelColumn AS shortName";

    $sql = sprintf(
        "SELECT
            %s.%s AS optionValue,
            %s.%s AS optionLabel
            %s
        FROM
            %s
        ORDER BY
            %s.%s ASC",
        $table, $valueColumn,
        $table, $labelColumn,
        $shortSelect,
        $table,
        $table, $orderBy
    );

    return $this->_db->getAllAssoc($sql);
}
```

Returns rows with keys: `optionValue`, `optionLabel`, `shortName`.

Call signatures used:
```php
// University — value=university_id, label=canonical_name, short=short_name
$candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');

// Nationality — value=name, label=name, no short (name IS the value)
$candidates->getPossibleDropDownOptions('nationality', 'name', 'name');
```

Note: `$table` and column names are not user input, so no `makeQueryString` wrapping is needed for the identifiers.

### `add()` — updated signature and INSERT

Added to parameter list (before `$skipHistory`):
```php
$universityID = 0, $nationality = '',
```

Added to INSERT column list:
```sql
university_id,
nationality,
```

Added `%s` placeholders and bind values (in matching order):
```php
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality)
```

### `update()` — updated signature and SET clause

Added to parameter list:
```php
$universityID = 0, $nationality = '',
```

Added to SET clause (comma after `gpa = %s,`):
```sql
university_id         = %s,
nationality           = %s
```

Bind values (must appear before `$candidateID` and `$siteID` in the list):
```php
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality),
```

### `get()` — updated SELECT and JOIN

Added to SELECT list:
```sql
candidate.university_id AS universityID,
university.canonical_name AS universityCanonicalName,
university.short_name AS universityShortName,
candidate.nationality AS nationality,
```

Added join (in main JOIN block, alongside other LEFT JOINs):
```sql
LEFT JOIN university
    ON university.university_id = candidate.university_id
```

### `getForEditing()` — updated SELECT

```sql
candidate.university_id AS universityID,
candidate.nationality AS nationality,
```

---


Added alongside `'GPA'` and `'Tags'` in `_classColumns`. University filters on `university.short_name` (not the numeric ID) so the applied filter displays a human-readable value. Nationality filters directly on `candidate.nationality` (no join needed).

in Source add to the end
```php
    'filterTypes'    => '==',
```
```php
'University' => array(
    'select'         => 'university.canonical_name AS universityCanonicalName,
                         university.short_name AS universityShortName',
    'join'           => 'LEFT JOIN university ON university.university_id = candidate.university_id',
    'pagerRender'    => 'return !empty($rsData[\'universityShortName\']) ? htmlspecialchars($rsData[\'universityShortName\']) : \'\';',
    'exportRender'   => 'return !empty($rsData[\'universityShortName\']) ? $rsData[\'universityShortName\'] . \' — \' . $rsData[\'universityCanonicalName\'] : \'\';',
    'sortableColumn' => 'universityCanonicalName',
    'pagerWidth'     => 100,
    'pagerOptional'  => true,
    'filter'         => 'university.short_name',
    'filterTypes'    => '==',
),
'Nationality' => array(
    'select'         => 'candidate.nationality AS nationality',
    'pagerRender'    => 'return !empty($rsData[\'nationality\']) ? htmlspecialchars($rsData[\'nationality\']) : \'\';',
    'exportRender'   => 'return !empty($rsData[\'nationality\']) ? $rsData[\'nationality\'] : \'\';',
    'sortableColumn' => 'nationality',
    'pagerWidth'     => 100,
    'pagerOptional'  => true,
    'filter'         => 'candidate.nationality',
    'filterTypes'    => '==',
),
```

---

## 4. `modules/candidates/CandidatesUI.php`

### `listByView()`

After the template assign block (note: `$candidates` is already instantiated earlier in this method):
```php
$sourcesRS = $candidates->getPossibleSources();
$this->_template->assign('sourcesRS', $sourcesRS);
$universitiesRS = $candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');
$this->_template->assign('universitiesRS', $universitiesRS);
$nationalitiesRS = $candidates->getPossibleDropDownOptions('nationality', 'name', 'name');
$this->_template->assign('nationalitiesRS', $nationalitiesRS);
```

### `add()`

After `$sourcesRS`/`$sourcesString` block:
```php
$universitiesRS = $candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');
$nationalitiesRS = $candidates->getPossibleDropDownOptions('nationality', 'name', 'name');
$this->_template->assign('universitiesRS', $universitiesRS);
$this->_template->assign('nationalitiesRS', $nationalitiesRS);
```

### `edit()`

After `$sourcesString` line:
```php
$universitiesRS = $candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');
$nationalitiesRS = $candidates->getPossibleDropDownOptions('nationality', 'name', 'name');
$this->_template->assign('universitiesRS', $universitiesRS);
$this->_template->assign('nationalitiesRS', $nationalitiesRS);
```

### `onEdit()`

Read posted values alongside other field reads:
```php
$universityID = $this->getTrimmedInput('universityID', $_POST);
$universityID = ($universityID > 0) ? $universityID : null;
$nationality  = $this->getTrimmedInput('nationality', $_POST);
```

Pass as final arguments to `$candidates->update(...)`:
```php
$gpa,
$universityID,
$nationality
```

### `_addCandidate()`

Read posted values alongside other field reads:
```php
$universityID = $this->getTrimmedInput('universityID', $_POST);
$universityID = ($universityID > 0) ? $universityID : null;
$nationality  = $this->getTrimmedInput('nationality', $_POST);
```

Pass as final arguments to `$candidates->add(...)`:
```php
$gpa,
$universityID,
$nationality
```

### `show()`

After the `isHot`/`titleClass` if/else block:
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

---

## 5. `modules/candidates/Add.tpl`

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>
            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['optionValue']) ?>">
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['optionLabel']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>

<tr>
    <td class="tdVertical">
        <label id="nationalityLabel" for="nationality">Nationality:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="nationality" name="nationality" class="inputbox" style="width: 250px;">
            <option value="">-- Select Nationality --</option>
            <?php foreach ($this->nationalitiesRS as $nationalityData): ?>
                <option value="<?php $this->_($nationalityData['optionValue']) ?>">
                    <?php $this->_($nationalityData['optionLabel']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 6. `modules/candidates/Edit.tpl`

Same as Add, with `selected` checks for pre-selection:

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>
            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['optionValue']) ?>"
                    <?php if (isset($this->data['universityID']) && $this->data['universityID'] == $universityData['optionValue']) echo('selected'); ?>>
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['optionLabel']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>

<tr>
    <td class="tdVertical">
        <label id="nationalityLabel" for="nationality">Nationality:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="nationality" name="nationality" class="inputbox" style="width: 250px;">
            <option value="">-- Select Nationality --</option>
            <?php foreach ($this->nationalitiesRS as $nationalityData): ?>
                <option value="<?php $this->_($nationalityData['optionValue']) ?>"
                    <?php if (isset($this->data['nationality']) && $this->data['nationality'] == $nationalityData['optionValue']) echo('selected'); ?>>
                    <?php $this->_($nationalityData['optionLabel']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 7. `modules/candidates/Show.tpl`

Added after the GPA row:

```php
<tr>
    <td class="vertical">University:</td>
    <td class="data"><?php $this->_($this->data['university']); ?></td>
</tr>
<tr>
    <td class="vertical">Nationality:</td>
    <td class="data"><?php $this->_($this->data['nationality']); ?></td>
</tr>
```

---

## 8. `lib/Pipelines.php` — `getJobOrderPipeline()`

Added to the SELECT list:
```sql
candidate.nationality AS nationality,
university.short_name AS universityShortName,
```

Added to the main JOIN block (alongside the other LEFT JOINs, **not** inside the `lastActivity` subquery — putting it in the subquery was an earlier bug that caused it not to work):
```sql
LEFT JOIN university
    ON university.university_id = candidate.university_id
```

---

## 9. `ajax/getPipelineJobOrder.php`

Updated `$columnMap` to map the filter column names to the correct result set keys:

```php
'University'  => 'universityShortName',
'Nationality' => 'nationality'
```

---

## 10. `js/dataGridFilters.js`

### `filterDropDownRegistry` — new global registry

Defined at the top of the file (before any filter classes). Each page that needs dropdown filters populates this registry via a `<script>` block in its `.tpl` file. `filter.DropDownFilter` reads from it at render time — so the JS class itself is fully generic and never needs to change for new dropdown types.

```javascript
var filterDropDownRegistry = {};
```

### `filter.FilterFactory` — added fourth branch

Added before the final `else` (DefaultFilter) branch, after the `Created` check:

```javascript
} else if (filterDropDownRegistry && filterDropDownRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.DropDownFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else {
    return new filter.DefaultFilter(...);
}
```

This routes any column whose name appears as a key in `filterDropDownRegistry` to `filter.DropDownFilter` automatically — no factory change needed when adding future dropdown columns.

### `filter.DropDownFilter` — new generic class

```javascript
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
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    filterDiv.appendChild(operatorSelect);

    var valueSelect = this.createElement('select', {
        id: this.filterAreaID + this.filterCounter + 'value',
        className: 'inputbox',
        style: 'width: 220px;'
    });
    valueSelect.appendChild(this.createOption('', '-- Select --'));

    var options = filterDropDownRegistry[columnName] || [];
    for (var i = 0; i < options.length; i++) {
        valueSelect.appendChild(this.createOption(options[i].value, options[i].label));
    }
    filterDiv.appendChild(valueSelect);

    valueSelect.addEventListener('change', function() {
        applyDropDownFilter(me.filterAreaID, me.filterCounter, me.instanceName, columnName);
    });

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
```

---

## 11. `modules/candidates/Candidates.tpl`

Added near the top of the page, before the data grid renders, so `filterDropDownRegistry` is populated before any filter widget is shown:

```php
<script type="text/javascript">
    filterDropDownRegistry['University'] = [
        <?php foreach ($this->universitiesRS as $i => $u): ?>
            { value: '<?php echo addslashes($u['shortName']); ?>', label: '<?php echo addslashes($u['shortName'] . ' — ' . $u['optionLabel']); ?>' }<?php echo ($i < count($this->universitiesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    filterDropDownRegistry['Nationality'] = [
        <?php foreach ($this->nationalitiesRS as $i => $n): ?>
            { value: '<?php echo addslashes($n['optionValue']); ?>', label: '<?php echo addslashes($n['optionLabel']); ?>' }<?php echo ($i < count($this->nationalitiesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    filterDropDownRegistry['Source'] = [
    <?php foreach ($this->sourcesRS as $i => $s): ?>
        { value: '<?php echo addslashes($s['name']); ?>', label: '<?php echo addslashes($s['name']); ?>' }<?php echo ($i < count($this->sourcesRS) - 1) ? ',' : ''; ?>
    <?php endforeach; ?>
    ];
</script>
```

---

## 12. `modules/joborders/Show.tpl`

Same script block as `Candidates.tpl` — needed here because the Job Order pipeline page has its own filter UI using the same `filter.DropDownFilter` JS class. Without this, the dropdown renders but shows no options.

```php
<script type="text/javascript">
    filterDropDownRegistry['University'] = [
        <?php foreach ($this->universitiesRS as $i => $u): ?>
            { value: '<?php echo addslashes($u['shortName']); ?>', label: '<?php echo addslashes($u['shortName'] . ' — ' . $u['optionLabel']); ?>' }<?php echo ($i < count($this->universitiesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    filterDropDownRegistry['Nationality'] = [
        <?php foreach ($this->nationalitiesRS as $i => $n): ?>
            { value: '<?php echo addslashes($n['optionValue']); ?>', label: '<?php echo addslashes($n['optionLabel']); ?>' }<?php echo ($i < count($this->nationalitiesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
    filterDropDownRegistry['Source'] = [
        <?php foreach ($this->sourcesRS as $i => $s): ?>
            { value: '<?php echo addslashes($s['name']); ?>', label: '<?php echo addslashes($s['name']); ?>' }<?php echo ($i < count($this->sourcesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];
</script>
```

---

## 13. `modules/joborders/JobOrdersUI.php` — `show()`

Added after the template assign block. Note: `Candidates` must be instantiated here since this is the JobOrders controller — it doesn't have a `$candidates` object by default:

```php
$candidates = new Candidates($this->_siteID);
$sourcesRS = $candidates->getPossibleSources();
$this->_template->assign('sourcesRS', $sourcesRS);
$universitiesRS = $candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');
$nationalitiesRS = $candidates->getPossibleDropDownOptions('nationality', 'name', 'name');
$this->_template->assign('universitiesRS', $universitiesRS);
$this->_template->assign('nationalitiesRS', $nationalitiesRS);
```

---

## Adding a new dropdown filter in the future

To add another reference-table dropdown (e.g. "Major", "Language"), the steps are:

1. Create the reference table and add the column to `candidate`.
2. Add a `_classColumns` entry in `dataGrids.php` with `'filterTypes' => '=='`.
3. Call `getPossibleDropDownOptions()` in each relevant controller method and assign to template.
4. Add the `filterDropDownRegistry['ColumnName'] = [...]` block to each relevant `.tpl`.
5. Add the column to `getJobOrderPipeline()` SELECT + JOIN if it needs to work in the pipeline filter too.
6. Add the column name to `$columnMap` in `getPipelineJobOrder.php`.

No JS changes needed — `filter.FilterFactory` and `filter.DropDownFilter` handle it automatically once the registry entry exists.

---

## Status

- [x] `university` reference table — created, seeded (45 rows)
- [x] `nationality` reference table — created, seeded (224 rows, Lebanese/Palestinian/Syrian/Armenian priority order)
- [x] `candidate.university_id` and `candidate.nationality` columns added
- [x] Add Candidate page — both dropdowns, save
- [x] Edit Candidate page — both dropdowns (pre-selected), save
- [x] Candidate Details page — both fields displayed
- [x] Candidate list — University and Nationality columns, dropdown filters
- [x] Job Order pipeline — University and Nationality dropdown filters
- [ ] Migration of legacy free-text university data from `extra_field` (not in scope for this implementer — needs DB access to execute)

## Known bugs fixed during implementation

**`_addCandidate()` — `$universityID` read before assignment:**
The line `$universityID = ($universityID > 0) ? $universityID : null;` originally referenced `$universityID` before `getTrimmedInput()` was called, so it always evaluated to null. Fixed by reading from `$_POST` first:
```php
$universityID = $this->getTrimmedInput('universityID', $_POST);
$universityID = ($universityID > 0) ? $universityID : null;
```

**`update()` — `$candidateID` and `$nationality` bind values swapped:**
The bind value list had `makeQueryInteger($candidateID)` before `makeQueryString($nationality)`, but the SQL had `nationality = %s` before `WHERE candidate_id = %s`. This meant the nationality value was being written into the WHERE clause and the candidate ID was being written into the nationality column. Fixed by swapping the order:
```php
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality),
$this->_db->makeQueryInteger($candidateID),
$this->_siteID
```

**`getJobOrderPipeline()` — university JOIN placed inside subquery:**
The `LEFT JOIN university` was accidentally placed inside the `lastActivity` subquery instead of the main query's JOIN block, so `universityShortName` was always null in the pipeline result set. Fixed by moving the join to the correct location in the outer query.