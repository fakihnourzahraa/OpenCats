# Ranges Notes

Changes covered by this document:
- Date range filtering (Created and Modified)
- Numeric range filtering (GPA, Desired Pay, etc.)
- Dropdown filtering (University, Nationality, Source, Interview Stage)
- Extra field filter types (date/range/dropdown for custom fields)

**Run the database migration first, then go file by file.**

---

## 1. Database

```sql
ALTER TABLE candidate ADD COLUMN gpa DECIMAL(3,2) DEFAULT NULL;

UPDATE candidate_joborder_status SET short_description = 'Applied'            WHERE candidate_joborder_status_id = 100;
UPDATE candidate_joborder_status SET short_description = '1st Screening'      WHERE candidate_joborder_status_id = 200;
UPDATE candidate_joborder_status SET short_description = 'Online Assignment'        WHERE candidate_joborder_status_id = 300;
UPDATE candidate_joborder_status SET short_description = 'Project Challenge'        WHERE candidate_joborder_status_id = 400;
UPDATE candidate_joborder_status SET short_description = 'Interview 1'        WHERE candidate_joborder_status_id = 500;
UPDATE candidate_joborder_status SET short_description = 'Interview 2'        WHERE candidate_joborder_status_id = 600;
UPDATE candidate_joborder_status SET short_description = 'Job offer rejected'  WHERE candidate_joborder_status_id = 700;
UPDATE candidate_joborder_status SET short_description = 'Job offer accepted' WHERE candidate_joborder_status_id = 800;

UPDATE candidate_joborder_status SET is_enabled = 0 WHERE candidate_joborder_status_id IN (250, 650);


ALTER TABLE extra_field_settings 
ADD COLUMN filter_type VARCHAR(20) NOT NULL DEFAULT 'default' 
AFTER extra_field_type;

CREATE TABLE `university` (
  `university_id` int(11) NOT NULL AUTO_INCREMENT,
  `canonical_name` varchar(255) NOT NULL DEFAULT '',
  `short_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`university_id`),
  UNIQUE KEY `uq_canonical_name` (`canonical_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

ALTER TABLE `candidate`
  ADD COLUMN `university_id` int(11) DEFAULT NULL;


CREATE TABLE `nationality` (
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

ALTER TABLE `candidate`
  ADD COLUMN `nationality` varchar(255) DEFAULT NULL;

```

---

## 2. lib/Candidates.php

### `add()` signature
Add parameters after `$disability`:

```php
$disability = '', $gpa = '', $universityID = 0, $nationality = '',
```

### `add()` INSERT statement
Add `gpa`, `university_id`, `nationality` to the column list and VALUES, using:

```php
$this->_db->makeQueryDouble($gpa),
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality)
```
(immediately after `$this->_db->makeQueryString($gender)`)

### `update()` signature (line 259)
Add parameters after `$disability`:

```php
$disability = '', $gpa = '', $universityID = 0, $nationality = ''
```

### `update()` SET clause (line 296)
Add:

```php
gpa = %s,
university_id = %s,
nationality = %s,
```

### `update()` value list (line 329)
Add:

```php
$this->_db->makeQueryDouble($gpa),
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality),
```

### `get()` SELECT (line 495)
Add to SELECT clause:

```php
candidate.gpa AS gpa,
candidate.university_id AS universityID,
university.canonical_name AS universityCanonicalName,
university.short_name AS universityShortName,
candidate.nationality AS nationality,
```

Add to JOINs (after the `eeo_veteran_type` join):

```php
LEFT JOIN university
    ON university.university_id = candidate.university_id
```

### `getForEditing()` SELECT (line 636)
Add to SELECT clause:

```php
candidate.gpa AS gpa,
candidate.university_id AS universityID,
candidate.nationality AS nationality,
```

### `getPossibleDropDownOptions()` add this new method

```php
public function getPossibleDropDownOptions($table, $valueColumn, $labelColumn, $shortColumn = null, $orderBy = null, $where = null)
{
    $shortSelect = $shortColumn ? ", $table.$shortColumn AS shortName" : ", $table.$labelColumn AS shortName";

    if ($orderBy === false) {
        $orderByClause = '';
    } elseif ($orderBy !== null && (strpos($orderBy, ' ') !== false || strpos($orderBy, ',') !== false)) {
        $orderByClause = "ORDER BY $orderBy";
    } else {
        $col = $orderBy ? $orderBy : $labelColumn;
        $orderByClause = "ORDER BY $table.$col ASC";
    }

    $whereClause = $where ? "WHERE $where" : '';

    $sql = sprintf(
        "SELECT
            %s.%s AS optionValue,
            %s.%s AS optionLabel
            %s
        FROM
            %s
        %s
        %s",
        $table, $valueColumn,
        $table, $labelColumn,
        $shortSelect,
        $table,
        $whereClause,
        $orderByClause
    );

    return $this->_db->getAllAssoc($sql);
}
```

### `CandidatesDataGrid::_classColumns` replace `Created`

```php
'Created' => array(
    'select'         => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\') AS dateCreated',
    'pagerRender'    => 'return $rsData[\'dateCreated\'];',
    'sortableColumn' => 'dateCreatedSort',
    'pagerWidth'     => 60,
    'filter'         => 'candidate.date_created',
    'filterHaving'   => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\')',
    'filterTypes'    => '=d>=d<=='),
```

### `CandidatesDataGrid::_classColumns` replace `Modified`

```php
'Modified' => array(
    'select'         => 'DATE_FORMAT(candidate.date_modified, \'%m-%d-%y\') AS dateModified,
                         candidate.date_modified AS dateModifiedSort',
    'sortableColumn' => 'dateModifiedSort',
    'pagerRender'    => 'return $rsData[\'dateModified\'];',
    'pagerWidth'     => 60,
    'pagerOptional'  => true,
    'filter'         => 'candidate.date_modified',
    'filterHaving'   => 'DATE_FORMAT(candidate.date_modified, \'%m-%d-%y\')',
    'filterTypes'    => '=d>=d<==',
),
```

### `CandidatesDataGrid::_classColumns` add new columns

```php
'GPA' => array(
    'select'         => 'candidate.gpa AS gpa',
    'sortableColumn' => 'gpa',
    'pagerWidth'     => 60,
    'pagerOptional'  => true,
    'filter'         => 'candidate.gpa',
    'filterTypes'    => '=>=<=><==',
),
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
'Interview Stage' => array(
    'select'         => '(
        SELECT candidate_joborder_status.short_description
        FROM candidate_joborder
        LEFT JOIN candidate_joborder_status
            ON candidate_joborder_status.candidate_joborder_status_id = candidate_joborder.status
        WHERE candidate_joborder.candidate_id = candidate.candidate_id
        ORDER BY candidate_joborder.date_modified DESC
        LIMIT 1
    ) AS statusDescription',
    'pagerRender'    => 'return !empty($rsData[\'statusDescription\']) ? htmlspecialchars($rsData[\'statusDescription\']) : \'\';',
    'exportRender'   => 'return !empty($rsData[\'statusDescription\']) ? $rsData[\'statusDescription\'] : \'\';',
    'sortableColumn' => 'statusDescription',
    'pagerWidth'     => 120,
    'pagerOptional'  => true,
    'filter'         => 'candidate_joborder_status.short_description',
    'filterTypes'    => '==',
),
```

---

## 3. lib/Pipelines.php

Replace `getJobOrderPipeline()` and add two new methods.

```php
public function getJobOrderPipeline($jobOrderID, $orderBy = '')
{
    $sql = sprintf(
        "SELECT
            IF(attachment_id, 1, 0) AS attachmentPresent,
            IF(old_candidate_id, 1, 0) AS isDuplicateCandidate,
            candidate.candidate_id AS candidateID,
            candidate.first_name AS firstName,
            candidate.last_name AS lastName,
            candidate.state AS state,
            candidate.city AS city,
            candidate.zip AS zip,
            candidate.address AS address,
            candidate.email1 AS candidateEmail,
            candidate.email2 AS candidateEmail2,
            candidate.phone_home AS phoneHome,
            candidate.phone_cell AS phoneCell,
            candidate.phone_work AS phoneWork,
            candidate.key_skills AS keySkills,
            candidate.current_employer AS currentEmployer,
            candidate.current_pay AS currentPay,
            candidate.desired_pay AS desiredPay,
            candidate.can_relocate AS canRelocate,
            candidate.source AS source,
            candidate.web_site AS webSite,
            candidate.notes AS notes,
            DATE_FORMAT(candidate.date_available, '%%m-%%d-%%y') AS dateAvailable,
            DATE_FORMAT(candidate.date_modified, '%%m-%%d-%%y') AS dateModified,
            DATE_FORMAT(candidate.date_created, '%%m-%%d-%%y') AS candidateDateCreated,
            candidate_joborder.status AS jobOrderStatus,
            candidate.is_hot AS isHotCandidate,
            candidate.gpa AS gpa,
            candidate.nationality AS nationality,
            university.short_name AS universityShortName,
            candidate_joborder_status.short_description AS statusDescription,
            DATE_FORMAT(
                candidate_joborder.date_created, '%%m-%%d-%%y'
            ) AS dateCreated,
            UNIX_TIMESTAMP(candidate_joborder.date_created) AS dateCreatedInt,
            candidate_joborder_status.short_description AS status,
            candidate_joborder.candidate_joborder_id AS candidateJobOrderID,
            candidate_joborder.rating_value AS ratingValue,
            owner_user.first_name AS ownerFirstName,
            owner_user.last_name AS ownerLastName,
            (
                SELECT
                    CONCAT(
                        '<strong>',
                        DATE_FORMAT(activity.date_created, '%%m-%%d-%%y'),
                        ' (',
                        entered_by_user.first_name,
                        ' ',
                        entered_by_user.last_name,
                        '):</strong> ',
                        IF(
                            ISNULL(activity.notes) OR activity.notes = '',
                            '(No Notes)',
                            activity.notes
                        )
                    )
                FROM
                    activity
                LEFT JOIN activity_type
                    ON activity.type = activity_type.activity_type_id
                LEFT JOIN user AS entered_by_user
                    ON activity.entered_by = entered_by_user.user_id
                WHERE
                    activity.data_item_id = candidate.candidate_id
                AND
                    activity.data_item_type = %s
                AND
                    activity.joborder_id = %s
                ORDER BY
                    activity.date_created DESC
                LIMIT 1
            ) AS lastActivity,
            IF((
                SELECT
                    COUNT(*)
                FROM
                    candidate_joborder_status_history
                WHERE
                    joborder_id = %s
                AND
                    candidate_id = candidate.candidate_id
                AND
                    status_to = %s
                AND
                    site_id = %s
            ) >= 1, 1, 0) AS submitted,
            added_user.first_name AS addedByFirstName,
            added_user.last_name AS addedByLastName
        FROM
            candidate_joborder
        LEFT JOIN candidate
            ON candidate_joborder.candidate_id = candidate.candidate_id
        LEFT JOIN user AS owner_user
            ON candidate.owner = owner_user.user_id
        LEFT JOIN user AS added_user
            ON candidate_joborder.added_by = added_user.user_id
        LEFT JOIN attachment
            ON candidate.candidate_id = attachment.data_item_id
        LEFT JOIN candidate_joborder_status
            ON candidate_joborder.status = candidate_joborder_status.candidate_joborder_status_id
        LEFT JOIN candidate_duplicates
            ON candidate_duplicates.new_candidate_id = candidate.candidate_id
        LEFT JOIN university
            ON university.university_id = candidate.university_id
        WHERE
            candidate_joborder.joborder_id = %s
        AND
            candidate_joborder.site_id = %s
        AND
            candidate.site_id = %s
        GROUP BY
            candidate_joborder.candidate_id
        %s",
        DATA_ITEM_CANDIDATE,
        $this->_db->makeQueryInteger($jobOrderID),
        $this->_db->makeQueryInteger($jobOrderID),
        PIPELINE_STATUS_SUBMITTED,
        $this->_siteID,
        $this->_db->makeQueryInteger($jobOrderID),
        $this->_siteID,
        $this->_siteID,
        $orderBy
    );

    return $this->_db->getAllAssoc($sql);
}

public function getExtraFieldsForPipelineCandidates(array $candidateIDs)
{
    if (empty($candidateIDs))
    {
        return array();
    }

    $safeIDs = implode(',', array_map('intval', $candidateIDs));

    $sql = sprintf(
        "SELECT
            data_item_id AS candidateID,
            field_name,
            value
        FROM
            extra_field
        WHERE
            data_item_type = %s
        AND
            site_id = %s
        AND
            data_item_id IN (%s)",
        DATA_ITEM_CANDIDATE,
        $this->_siteID,
        $safeIDs
    );

    $rs = $this->_db->getAllAssoc($sql);
    if (!$rs)
    {
        return array();
    }

    $indexed = array();
    foreach ($rs as $row)
    {
        $indexed[$row['candidateID']][$row['field_name']] = $row['value'];
    }

    return $indexed;
}

public function getExtraFieldDefinitions()
{
    $sql = sprintf(
        "SELECT field_name, extra_field_type, extra_field_options, filter_type
         FROM extra_field_settings
         WHERE data_item_type = %s
         AND site_id = %s",
        DATA_ITEM_CANDIDATE,
        $this->_siteID
    );

    $rs = $this->_db->getAllAssoc($sql);
    return $rs ? $rs : array();
}
```

---

## 4. lib/JobOrders.php

In the `Created` column definition, add `filterTypes`:

```php
'filterTypes'  => '=d>=d<=='),
```

---

## 5. lib/DataGrid.php

### filterTypes injection block replace

```php
// OLD:
if (isset($this->_classColumns[$value]['filterTypes']))
{
    $filterableColumns[$index] .= '!@!' . $this->_classColumns[$value]['filterTypes'];
}
else
{
    $filterableColumns[$index] .= '!@!' . '===~';
}

// NEW:
if (isset($this->_classColumns[$value]['filterTypes']))
{
    $types = $this->_classColumns[$value]['filterTypes'];
    if (strpos($types, '=e') === false) {
        $types .= '=e';
    }
    $filterableColumns[$index] .= '!@!' . $types;
}
else
{
    $filterableColumns[$index] .= '!@!' . '===~=e';
}
```

### JS registry emission, add after `$template->assign('md5InstanceName', $md5InstanceName)`

This block emits JS that auto-populates `filterDateRangeRegistry`, `filterRangeRegistry`, and `filterDropDownRegistry` based on each column's `filterTypes` and `filterDropDownOptions`.

```php
echo '<script type="text/javascript">';
foreach ($this->_classColumns as $columnName => $data) {
    if (!isset($data['filterTypes'])) continue;

    $types = $data['filterTypes'];

    if (strpos($types, '=d>') !== false || strpos($types, '=d<') !== false) {
        echo 'if (!filterDateRangeRegistry[' . json_encode($columnName) . ']) {
            filterDateRangeRegistry[' . json_encode($columnName) . '] = true; }';
    }

    if ((strpos($types, '=>') !== false || strpos($types, '=<') !== false)
        && strpos($types, '=d') === false) {
        echo 'if (!filterRangeRegistry[' . json_encode($columnName) . ']) {
            filterRangeRegistry[' . json_encode($columnName) . '] = true; }';
    }

    if (isset($data['filterDropDownOptions'])) {
        echo 'if (!filterDropDownRegistry[' . json_encode($columnName) . '] ||
              !filterDropDownRegistry[' . json_encode($columnName) . '].length) {
            filterDropDownRegistry[' . json_encode($columnName) . '] = ' .
            json_encode($data['filterDropDownOptions']) . '; }';
    }
}
echo '</script>';
```

### Argument parsing in `_getData()`, replace

```php
// OLD:
$columnName = urldecode(substr($data, 0, strpos($data, '=')));
$argument = urldecode(substr($data, strpos($data, '=') + 2));

// NEW:
$columnName = urldecode(substr($data, 0, strpos($data, '=')));

$eqPos = strpos($data, '=');
$operatorLength = 2;
if (substr($data, $eqPos, 3) === '=d>' || substr($data, $eqPos, 3) === '=d<')
{
    $operatorLength = 3;
}
$argument = urldecode(substr($data, $eqPos + $operatorLength));
```

### `=in` filter block — add inside `foreach ($arguments as $argument)` loop

```php
if (strpos($data, '=in') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' = ' . $db->makeQueryString($argument);
    }
}
```

### `=<` and `=>` blocks change `makeQueryInteger` to `makeQueryDouble`

```php
if (strpos($data, '=<') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' <= ' . $db->makeQueryDouble($argument) . ' ';
    }
    if (isset($this->_classColumns[$columnName]['filterHaving']))
    {
        $havingSQL_or[] = $this->_classColumns[$columnName]['filterHaving'] . ' <= ' . $db->makeQueryDouble($argument) . ' ';
    }
}

if (strpos($data, '=>') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' >= ' . $db->makeQueryDouble($argument) . ' ';
    }
    if (isset($this->_classColumns[$columnName]['filterHaving']))
    {
        $havingSQL_or[] = $this->_classColumns[$columnName]['filterHaving'] . ' >= ' . $db->makeQueryDouble($argument) . ' ';
    }
}
```

### New date operator blocks, add alongside the existing `=<`, `=>`, etc. blocks

```php
if (strpos($data, '=d<') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' <= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'%m-%d-%y\') ';
    }
}

if (strpos($data, '=d>') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' >= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'%m-%d-%y\') ';
    }
}
```

### `drawFilterArea()` replace `$filterOperatorHuman` 

```php
$filterOperatorHuman = '';
switch ($filterOperator)
{
    case '==':
        $filterOperatorHuman = ' is equal to';
        break;
    case '=~':
        $filterOperatorHuman = ' contains';
        break;
    case '=>':
        $filterOperatorHuman = ' is greater than';
        break;
    case '=<':
        $filterOperatorHuman = ' is less than';
        break;
    case '=#':
        $filterOperatorHuman = ' has element';
        break;
    case '=d>':
        $filterOperatorHuman = ' from';
        break;
    case '=d<':
        $filterOperatorHuman = ' to';
        break;
    case '=e':
        $filterOperatorHuman = ' is empty';
        break;
}
```

---

## 6. lib/ExtraFields.php

### `getSettings()` SELECT add `filter_type`

```php
"SELECT
    extra_field_settings.field_name AS fieldName,
    extra_field_settings.extra_field_settings_id AS extraFieldSettingsID,
    extra_field_settings.extra_field_type as extraFieldType,
    extra_field_settings.extra_field_options as extraFieldOptions,
    extra_field_settings.filter_type AS filterType,
    extra_field_settings.site_id AS siteID
```

### `define()`, replace to accept and save `filter_type`

```php
public function define($fieldName, $fieldType, $filterType = 'default')
{
    $sql = sprintf(
        "INSERT INTO extra_field_settings (
            field_name, site_id, date_created,
            data_item_type, extra_field_type, filter_type
         ) VALUES (%s, %s, NOW(), %s, %s, %s)",
         $this->_db->makeQueryString($fieldName),
         $this->_siteID,
         $this->_dataItemType,
         $this->_db->makeQueryInteger($fieldType),
         $this->_db->makeQueryString($filterType)
    );
    $this->_db->query($sql);

    $sql = sprintf(
        "UPDATE extra_field_settings
         SET position = %s
         WHERE extra_field_settings_id = %s
         AND site_id = %s",
         $this->_db->getLastInsertID(),
         $this->_db->getLastInsertID(),
         $this->_siteID
    );
    $this->_db->query($sql);
}
```

### `getDataGridDefinition()`, add filter type switch before `return $definition`

```php
$filterType = isset($data['filterType']) ? $data['filterType'] : 'default';
switch ($filterType)
{
    case 'date':
        $definition['filterTypes'] = '=d>=d<';
        $definition['filter'] = 'STR_TO_DATE(extra_field' . $uniqueIndex . '.value, \'%m-%d-%y\')';
        break;

    case 'range':
        $definition['filterTypes'] = '===>==<';
        break;

    case 'dropdown':
        $definition['filterTypes'] = '==';
        if (!empty($data['extraFieldOptions'])) {
            $rawOptions = explode(',', $data['extraFieldOptions']);
        } else {
            $distinctSQL = sprintf(
                "SELECT DISTINCT value FROM extra_field
                WHERE field_name = %s
                AND site_id = %s
                AND data_item_type = %s
                AND value != ''",
                $db->makeQueryString($data['fieldName']),
                $this->_siteID,
                $this->_dataItemType
            );
            $distinctRS = $db->getAllAssoc($distinctSQL);
            $rawOptions = array_column($distinctRS, 'value');
        }
        $definition['filterDropDownOptions'] = array_values(array_filter(array_map(function($opt) {
            $opt = urldecode(trim($opt));
            return $opt !== '' ? ['value' => $opt, 'label' => $opt] : null;
        }, $rawOptions)));
        break;

    default:
        $definition['filterTypes'] = '===~';
        break;
}

return $definition;
```

---

## 7. modules/candidates/Add.tpl

Add GPA, University, and Nationality rows inside the form table:

```php
<tr>
    <td class="tdVertical">
        <label id="gpaLabel" for="gpa">GPA:</label>
    </td>
    <td class="tdData">
        <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" step="0.01" style="width: 50px;" value="<?php if (isset($this->preassignedFields['gpa'])) $this->_($this->preassignedFields['gpa']); ?>" />
    </td>
</tr>

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

## 8. modules/candidates/Edit.tpl

Add GPA row:

```php
<tr>
    <td class="tdVertical">
        <label id="gpaLabel" for="gpa">GPA:</label>
    </td>
    <td class="tdData">
        <input type="number" class="inputbox" tabindex="<?php echo($tabIndex++); ?>" name="gpa" id="gpa" min="0" max="4" step="0.01" style="width: 60px;" value="<?php $this->_($this->data['gpa']); ?>" />
    </td>
</tr>
```

---

## 9. modules/candidates/Show.tpl

Add GPA display row:

```php
<tr>
    <td class="vertical">GPA:</td>
    <td class="data"><?php $this->_($this->data['gpa']); ?></td>
</tr>
```

---

## 10. modules/candidates/Candidates.tpl

Add this script block (registers dropdown options and date/range columns for the filter UI):

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
    filterDateRangeRegistry['Created'] = true;
    filterDateRangeRegistry['Modified'] = true;
    filterRangeRegistry['Desired Pay'] = true;
</script>
```

---

## 11. modules/candidates/CandidatesUI.php

### Parsed-fields array (used by `checkParsingFunctions`) — add `gpa`

```php
'isFromParser' => true,
'gpa'          => $this->getTrimmedInput('gpa', $_POST),
```

### Before `Candidates::add()` call (~line 2610)

```php
$gpa = $this->getTrimmedInput('gpa', $_POST);
```

### In the `Candidates::add()` call (~line 2663) — add as final argument

```php
,$gpa
```

### Before `Candidates::update()` call (~line 1380) — pass `$gpa` as final argument in the same way.

---

## 12. modules/joborders/dataGrids.php

### `JobOrdersListByViewDataGrid::_defaultColumns` — add GPA column

```php
array('name' => 'gpa', 'width' => 55),
```

### Add `PipelineCandidatesDataGrid` class at end of file

```php
class PipelineCandidatesDataGrid extends CandidatesDataGrid
{
    public function __construct($siteID, $parameters, $misc)
    {
        $this->_tableWidth = new Width(100, '%');
        $this->_defaultAlphabeticalSortBy = 'lastName';
        $this->ajaxMode = false;
        $this->showExportCheckboxes = true;
        $this->showActionArea = true;
        $this->showChooseColumnsBox = true;
        $this->allowResizing = true;

        $this->defaultSortBy = 'dateModifiedSort';
        $this->defaultSortDirection = 'DESC';

        $this->_defaultColumns = array(
            array('name' => 'Attachments', 'width' => 31),
            array('name' => 'First Name',  'width' => 75),
            array('name' => 'Last Name',   'width' => 85),
            array('name' => 'City',        'width' => 75),
            array('name' => 'State',       'width' => 50),
            array('name' => 'Key Skills',  'width' => 215),
            array('name' => 'Owner',       'width' => 65),
            array('name' => 'Created',     'width' => 60),
            array('name' => 'Modified',    'width' => 60),
        );

        parent::__construct(
            'joborders:PipelineCandidatesDataGrid',
            $siteID, $parameters, $misc
        );
        $this->_classColumns['Added'] = array(
            'pagerWidth'  => 60,
            'filterTypes' => '=d>=d<==',
        );
    }
}
```

### Add `PipelineExportDataGrid` class at end of file

This class maps pipeline column keys (session-stored) to DataGrid column names so the export respects visible columns.

```php
class PipelineExportDataGrid extends PipelineCandidatesDataGrid
{
    private static $_pipelineColMap = array(
        'firstName'           => 'First Name',
        'lastName'            => 'Last Name',
        'state'               => 'State',
        'city'                => 'City',
        'zip'                 => 'Zip',
        'address'             => 'Address',
        'dateCreatedInt'      => 'Created',
        'status'              => 'Interview Stage',
        'candidateEmail'      => 'E-Mail',
        'candidateEmail2'     => '2nd E-Mail',
        'phoneHome'           => 'Home Phone',
        'phoneCell'           => 'Cell Phone',
        'phoneWork'           => 'Work Phone',
        'keySkills'           => 'Key Skills',
        'currentEmployer'     => 'Current Employer',
        'currentPay'          => 'Current Pay',
        'desiredPay'          => 'Desired Pay',
        'canRelocate'         => 'Can Relocate',
        'source'              => 'Source',
        'webSite'             => 'Web Site',
        'notes'               => 'Misc Notes',
        'dateAvailable'       => 'Available',
        'dateModified'        => 'Modified',
        'gpa'                 => 'GPA',
        'nationality'         => 'Nationality',
        'universityShortName' => 'University',
    );

    protected function buildColumns()
    {
        parent::buildColumns();

        $siteID = $_SESSION['CATS']->getSiteID();
        $visibleCols = isset($_SESSION['pipelineCols'][$siteID])
            ? $_SESSION['pipelineCols'][$siteID]
            : array('firstName', 'lastName', 'state', 'dateCreatedInt', 'status');

        $newCurrentColumns = array();
        foreach ($visibleCols as $pipelineKey)
        {
            if (!isset(self::$_pipelineColMap[$pipelineKey]))
                continue;

            $dgColName = self::$_pipelineColMap[$pipelineKey];

            if (!isset($this->_classColumns[$dgColName]))
                continue;

            $newCurrentColumns[] = array(
                'name'  => $dgColName,
                'width' => isset($this->_classColumns[$dgColName]['pagerWidth'])
                               ? $this->_classColumns[$dgColName]['pagerWidth'] : 80,
                'data'  => $this->_classColumns[$dgColName],
            );
        }

        if (!empty($newCurrentColumns))
            $this->_currentColumns = $newCurrentColumns;
    }
}
```

---

## 13. modules/joborders/JobOrdersUI.php

### Add include at top

```php
include_once(LEGACY_ROOT . '/modules/joborders/dataGrids.php');
```

### Add `exportPipeline` case to action switch

```php
case 'exportPipeline':
    $this->exportPipeline();
    break;
```

### Add `exportPipeline()` private method

```php
private function exportPipeline()
{
    $siteID       = $this->_siteID;
    $jobOrderID   = $this->getTrimmedInput('jobOrderID', $_GET);
    $candidateIDs = isset($_GET['candidateIDs'])
        ? array_map('intval', unserialize(urldecode($_GET['candidateIDs'])))
        : array();

    if (!$jobOrderID || empty($candidateIDs)) die('Invalid input.');

    $pipelines   = new Pipelines($siteID);
    $pipelinesRS = $pipelines->getJobOrderPipeline($jobOrderID);

    foreach ($pipelinesRS as $i => $row)
    {
        $pipelinesRS[$i]['addedByAbbrName'] = StringUtility::makeInitialName(
            $row['addedByFirstName'], $row['addedByLastName'], LAST_NAME_MAXLEN
        );
    }

    $allCandidateIDs = array_map(function($r) { return $r['candidateID']; }, $pipelinesRS);
    $extraFieldsByCandidate = $pipelines->getExtraFieldsForPipelineCandidates($allCandidateIDs);
    foreach ($pipelinesRS as $idx => $row)
    {
        $cid = $row['candidateID'];
        if (isset($extraFieldsByCandidate[$cid]))
        {
            foreach ($extraFieldsByCandidate[$cid] as $fieldName => $value)
            {
                $pipelinesRS[$idx][$fieldName] = $value;
            }
        }
    }

    $pipelinesRS = array_values(array_filter($pipelinesRS, function($row) use ($candidateIDs) {
        return in_array((int)$row['candidateID'], $candidateIDs);
    }));

    $allCols = array(
        'firstName'           => array('First Name',       'firstName'),
        'lastName'            => array('Last Name',        'lastName'),
        'state'               => array('Loc',              'state'),
        'city'                => array('City',             'city'),
        'zip'                 => array('Zip',              'zip'),
        'address'             => array('Address',          'address'),
        'dateCreatedInt'      => array('Added',            'dateCreated'),
        'addedByAbbrName'     => array('Entered By',       'addedByAbbrName'),
        'status'              => array('Interview Stage',  'status'),
        'lastActivity'        => array('Last Activity',    'lastActivity'),
        'candidateEmail'      => array('E-Mail',           'candidateEmail'),
        'candidateEmail2'     => array('2nd E-Mail',       'candidateEmail2'),
        'phoneHome'           => array('Home Phone',       'phoneHome'),
        'phoneCell'           => array('Cell Phone',       'phoneCell'),
        'phoneWork'           => array('Work Phone',       'phoneWork'),
        'keySkills'           => array('Key Skills',       'keySkills'),
        'currentEmployer'     => array('Current Employer', 'currentEmployer'),
        'currentPay'          => array('Current Pay',      'currentPay'),
        'desiredPay'          => array('Desired Pay',      'desiredPay'),
        'canRelocate'         => array('Can Relocate',     'canRelocate'),
        'source'              => array('Source',           'source'),
        'webSite'             => array('Web Site',         'webSite'),
        'notes'               => array('Misc Notes',       'notes'),
        'dateAvailable'       => array('Available',        'dateAvailable'),
        'dateModified'        => array('Modified',         'dateModified'),
        'gpa'                 => array('GPA',              'gpa'),
        'nationality'         => array('Nationality',      'nationality'),
        'universityShortName' => array('University',       'universityShortName'),
    );

    /* Add extra field definitions to column map */
    $extraFieldDefs = $pipelines->getExtraFieldDefinitions();
    if ($extraFieldDefs)
    {
        foreach ($extraFieldDefs as $def)
        {
            $fn = $def['field_name'];
            $allCols[$fn] = array($fn, $fn);
        }
    }

    $visibleCols = isset($_SESSION['pipelineCols'][$siteID])
        ? $_SESSION['pipelineCols'][$siteID]
        : array('firstName', 'lastName', 'state', 'dateCreatedInt', 'addedByAbbrName', 'status', 'lastActivity');

    $exportCols = array();
    foreach ($visibleCols as $key)
    {
        if (isset($allCols[$key])) $exportCols[$key] = $allCols[$key];
    }

    header('Content-Disposition: attachment; filename="pipeline_export.csv"');
    header('Content-Type: text/x-csv; charset=utf-8');

    $out = fopen('php://output', 'w');
    fputcsv($out, array_column($exportCols, 0));

    foreach ($pipelinesRS as $row)
    {
        $cells = array();
        foreach ($exportCols as $key => $def)
        {
            $val = isset($row[$def[1]]) ? $row[$def[1]] : '';
            if ($key === 'canRelocate')  $val = ($val == 1 ? 'Yes' : 'No');
            if ($key === 'lastActivity') $val = strip_tags($val);
            $cells[] = $val;
        }
        fputcsv($out, $cells);
    }

    fclose($out);
    die();
}
```

### End of `show()`, add template assignments before `if (!eval(Hooks::get('JO_SHOW'))) return;`

```php
$candidates = new Candidates($this->_siteID);

$sourcesRS = $candidates->getPossibleSources();
$this->_template->assign('sourcesRS', $sourcesRS);

$db = DatabaseConnection::getInstance();

$pipelineUniversitiesIsIn = $db->getAllAssoc(sprintf(
    "SELECT DISTINCT university.short_name AS val
    FROM candidate
    INNER JOIN candidate_joborder ON candidate_joborder.candidate_id = candidate.candidate_id
    LEFT JOIN university ON university.university_id = candidate.university_id
    WHERE candidate_joborder.joborder_id = %d
    AND candidate_joborder.site_id = %d
    AND university.short_name IS NOT NULL AND university.short_name != ''
    ORDER BY university.short_name ASC",
    $jobOrderID, $this->_siteID
));
$this->_template->assign('pipelineUniversitiesIsIn', $pipelineUniversitiesIsIn);

$pipelineNationalitiesIsIn = $db->getAllAssoc(sprintf(
    "SELECT DISTINCT candidate.nationality AS val
    FROM candidate
    INNER JOIN candidate_joborder ON candidate_joborder.candidate_id = candidate.candidate_id
    WHERE candidate_joborder.joborder_id = %d
    AND candidate_joborder.site_id = %d
    AND candidate.nationality IS NOT NULL AND candidate.nationality != ''
    ORDER BY candidate.nationality ASC",
    $jobOrderID, $this->_siteID
));
$this->_template->assign('pipelineNationalitiesIsIn', $pipelineNationalitiesIsIn);

$pipelineSourcesIsIn = $db->getAllAssoc(sprintf(
    "SELECT DISTINCT candidate.source AS val
    FROM candidate
    INNER JOIN candidate_joborder ON candidate_joborder.candidate_id = candidate.candidate_id
    WHERE candidate_joborder.joborder_id = %d
    AND candidate_joborder.site_id = %d
    AND candidate.source IS NOT NULL AND candidate.source != ''
    ORDER BY candidate.source ASC",
    $jobOrderID, $this->_siteID
));
$this->_template->assign('pipelineSourcesIsIn', $pipelineSourcesIsIn);

$universitiesRS = $candidates->getPossibleDropDownOptions('university', 'university_id', 'canonical_name', 'short_name');
$nationalitiesRS = $candidates->getPossibleDropDownOptions('nationality', 'name', 'name', null, 'sort_order ASC, name ASC');
$this->_template->assign('universitiesRS', $universitiesRS);
$this->_template->assign('nationalitiesRS', $nationalitiesRS);

$statusesRS = $candidates->getPossibleDropDownOptions(
    'candidate_joborder_status',
    'short_description',
    'short_description',
    null,
    'candidate_joborder_status_id ASC',
    'is_enabled = 1 AND candidate_joborder_status_id != 0'
);
$this->_template->assign('statusesRS', $statusesRS);
```

Replace the dataGrid setup block at the very end of `show()`:

```php
$savedPipelineFilter = isset($_SESSION['pipelineFilter'][$jobOrderID])
    ? $_SESSION['pipelineFilter'][$jobOrderID]
    : '';

$dataGridProperties = DataGrid::getRecentParamaters('joborders:PipelineCandidatesDataGrid');
if ($dataGridProperties == array())
{
    $dataGridProperties = array(
        'rangeStart'    => 0,
        'maxResults'    => 15,
        'filterVisible' => true,
        'filter'        => $savedPipelineFilter !== '' ? $savedPipelineFilter : 'First+Name=~',
    );
}

$dataGrid = new PipelineCandidatesDataGrid($this->_siteID, $dataGridProperties, 0);
$this->_template->assign('dataGrid', $dataGrid);
$this->_template->assign('userID', $_SESSION['CATS']->getUserID());
$this->_template->assign('savedPipelineFilter', $savedPipelineFilter);
$this->_template->display('./modules/joborders/Show.tpl');
```

---

## 14. modules/joborders/Show.tpl

### Add JS includes in `<head>`

```php
'js/dataGrid.js', 'js/dataGridFilters.js'
```

### Add filter registry script block

This populates all the filter registries for the pipeline page. The `filterIsInRegistry` entries are scoped to candidates actually in this job order (used by the "is in" operator on dropdown filters).

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
    filterDropDownRegistry['Interview Stage'] = [
        <?php foreach ($this->statusesRS as $i => $s): ?>
            { value: '<?php echo addslashes($s['optionValue']); ?>', label: '<?php echo addslashes($s['optionLabel']); ?>' }<?php echo ($i < count($this->statusesRS) - 1) ? ',' : ''; ?>
        <?php endforeach; ?>
    ];

    filterIsInRegistry['University'] = [
        <?php if (!empty($this->pipelineUniversitiesIsIn)): foreach ($this->pipelineUniversitiesIsIn as $i => $u): ?>
            { value: '<?php echo addslashes($u['val']); ?>', label: '<?php echo addslashes($u['val']); ?>' }<?php echo ($i < count($this->pipelineUniversitiesIsIn) - 1) ? ',' : ''; ?>
        <?php endforeach; endif; ?>
    ];
    filterIsInRegistry['Nationality'] = [
        <?php if (!empty($this->pipelineNationalitiesIsIn)): foreach ($this->pipelineNationalitiesIsIn as $i => $n): ?>
            { value: '<?php echo addslashes($n['val']); ?>', label: '<?php echo addslashes($n['val']); ?>' }<?php echo ($i < count($this->pipelineNationalitiesIsIn) - 1) ? ',' : ''; ?>
        <?php endforeach; endif; ?>
    ];
    filterIsInRegistry['Source'] = [
        <?php if (!empty($this->pipelineSourcesIsIn)): foreach ($this->pipelineSourcesIsIn as $i => $s): ?>
            { value: '<?php echo addslashes($s['val']); ?>', label: '<?php echo addslashes($s['val']); ?>' }<?php echo ($i < count($this->pipelineSourcesIsIn) - 1) ? ',' : ''; ?>
        <?php endforeach; endif; ?>
    ];

    filterDateRangeRegistry['Created'] = true;
    filterDateRangeRegistry['Modified'] = true;
    filterRangeRegistry['GPA'] = true;
    filterRangeRegistry['Desired Pay'] = true;
</script>
```

### Add filter area, pipeline controls, and export

```php
<?php $this->dataGrid->drawFilterArea(); ?>

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
                var opLen = (f.substr(eqPos, 3) === '=d>' || f.substr(eqPos, 3) === '=d<' || f.substr(eqPos, 3) === '=in') ? 3 : 2;
                var op = f.substring(eqPos, eqPos + opLen);
                var val = decodeURIComponent(f.substring(eqPos + opLen));
                var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than','=d>':'from','=d<':'to','=e':'is empty'};
                var span = document.createElement('span');
                span.className = 'filterArea';
                span.innerHTML = '<a href="javascript:void(0);" onclick="this.parentNode.style.display=\'none\'; removeColumnFromFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\'); submitFilter' + md5 + '();">'
                    + '<img src="images/actions/delete_small.gif" style="padding:0px;margin:0px;" border="0" title="Remove this Filter" /></a>&nbsp;'
                    + '\'' + col + '\' ' + (opNames[op] || op) + ': '
                    + '<select id="filterResultsAreaTable' + md5 + (counter+1) + 'columnName" disabled="disabled" class="inputbox" style="display:none;"><option value="' + col + '!@!===~">' + col + '</option></select>'
                    + (op === '=e' ? '' : '<input class="inputbox" style="width:180px;" value="' + val + '" onchange="addColumnToFilter(\'' + pipelineDataGridFilterID + '\', \'' + col + '\', \'' + op + '\', this.value); submitFilter' + md5 + '();" />');
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

<script type="text/javascript">
document.addEventListener('DOMContentLoaded', function() {
    var filterArea = document.getElementById(
        'filterResultsArea<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>'
    );
    if (filterArea) filterArea.style.display = '';

    var originalShowNewFilter = showNewFilter;
    showNewFilter = function(counter, tableID, arrayKeys, md5) {
        originalShowNewFilter(counter, tableID, arrayKeys, md5);
        setTimeout(function() {
            var selects = document.querySelectorAll('[id^="filterResultsAreaTable' + md5 + '"][id$="columnOperator"]');
            selects.forEach(function(sel) {
                for (var i = 0; i < sel.options.length; i++) {
                    if (sel.options[i].value === '=e') return;
                }
                var opt = document.createElement('option');
                opt.value = '=e';
                opt.text = 'is empty';
                sel.appendChild(opt);
            });
        }, 0);
    };

    <?php if (!empty($this->savedPipelineFilter)): ?>
    submitFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>(true);
    <?php else: ?>
    showNewFilter<?php echo md5('joborders:PipelineCandidatesDataGrid'); ?>();
    <?php endif; ?>
});
</script>

<p id="ajaxPipelineControl">
    </select>&nbsp;
    <span id="ajaxPipelineNavigation"></span>&nbsp;
    <img src="images/indicator.gif" alt="" id="ajaxPipelineTableIndicator" />
</p>

<div id="ajaxPipelineTable"></div>

<input type="checkbox" name="select_all" onclick="selectAll_candidates(this)" title="Select all candidates" />
<a href="javascript:void(0);" onclick="exportFromPipeline()" title="Export selected candidates">Export</a>

<script type="text/javascript">
function exportFromPipeline() {
    var ids = getSelected_candidates();
    if (ids.length > 0) {
        window.location.href = '<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&a=exportPipeline&jobOrderID=<?php echo($this->data['jobOrderID']); ?>&candidateIDs=' + urlEncode(serializeArray(ids));
    } else {
        alert('No data selected');
    }
}
</script>
```

---

## 15. ajax/getPipelineJobOrder.php

### `$columnMap`, replace

```php
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
    'GPA'              => 'gpa',
    'Created'          => 'dateCreated'
);
```

### `$operators, replace

The 3-character operators must come before the 2 character.

```php
$operators = array('=d>', '=d<', '=~', '==', '=>', '=<');
```

### Filter comparison callback, add GPA and Created special cases

Find `$fieldValue = isset($row[$col]) ? $row[$col] : '';` and add immediately after:

```php
if ($col === 'gpa') {
    $fieldValue = (float) $fieldValue;
    $val = (float) $val;
    switch ($op) {
        case '==': return $fieldValue == $val;
        case '=>':  return $fieldValue >= $val;
        case '=<':  return $fieldValue <= $val;
        default:    return true;
    }
}

if ($col === 'dateCreated') {
    $fieldValue = DateTime::createFromFormat('m-d-y', $fieldValue);
    $valDate    = DateTime::createFromFormat('m-d-y', $val);
    if (!$fieldValue || !$valDate) return true;
    switch ($op) {
        case '==':  return $fieldValue == $valDate;
        case '=d>': return $fieldValue >= $valDate;
        case '=d<': return $fieldValue <= $valDate;
        default:    return true;
    }
}
```

---

## 16. modules/settings/CustomizeExtraFields.tpl

### Add "Filter Type" column header

Add after the "Field Type" `<th>`:

```html
<th align="left">Filter Type</th>
```

### Display filter type in the existing fields table

Add after the field type display cell:

```php
<td align="left">
    <?php echo htmlspecialchars($this->extraFieldFilters[$rsData['filterType']]['name'] ?? 'Default (Text)'); ?>
</td>
```

### Update `addRow` to accept and forward `rowFilterType`

```javascript
function addRow<?php echo($index); ?>(rowName, rowType, rowTypeName, rowFilterType)
{
    // ... existing body unchanged ...
    appendCommandList('ADDFIELD <?php echo(urlencode($data['type'])); ?> '+encodeURI(rowType)+' '+encodeURI(rowName)+' '+encodeURI(rowFilterType));
}
```

### Update `onAddField` caller to pass filter select value

```javascript
function onAddField<?php echo($index); ?>()
{
    if(document.getElementById('addFieldName<?php echo($index); ?>').value == '') return;
    addRow<?php echo($index); ?>(
        document.getElementById('addFieldName<?php echo($index); ?>').value,
        document.getElementById('addFieldSelect<?php echo($index); ?>').value,
        document.getElementById('addFieldSelect<?php echo($index); ?>').options[document.getElementById('addFieldSelect<?php echo($index); ?>').selectedIndex].text,
        document.getElementById('addFieldFilterSelect<?php echo($index); ?>').value
    );
    onHideAddArea<?php echo($index); ?>();
}
```

### Add filter type `<select>` to the add-new-field form (after the existing field type select)

```php
<select id="addFieldFilterSelect<?php echo($index); ?>">
    <?php foreach($this->extraFieldFilters as $filterKey => $filterData): ?>
        <option value="<?php echo($filterKey); ?>"><?php echo htmlspecialchars($filterData['name']); ?></option>
    <?php endforeach; ?>
</select>
```

---

## 17. modules/settings/SettingsUI.php

### Add `$extraFieldFilters` and assign to template in `customizeExtraFields()`

```php
$this->extraFieldFilters = [
    'default'  => ['name' => 'Default (Text)'],
    'date'     => ['name' => 'Date Range'],
    'range'    => ['name' => 'Range'],
    'dropdown' => ['name' => 'Dropdown'],
];
$this->_template->assign('extraFieldFilters', $this->extraFieldFilters);
```

### Replace the `ADDFIELD` case

```php
case 'ADDFIELD':
    $args = explode(' ', $command, 5);
    $extraFields = new ExtraFields($this->_siteID, intval(urldecode($args[1])));
    $filterType = isset($args[4]) ? urldecode($args[4]) : 'default';
    $extraFields->define(urldecode($args[3]), urldecode($args[2]), $filterType);
    break;
```

---

## 18. js/dataGridFilters.js

### Replace `filter.getNames()`

```javascript
getNames: function() {
    return {
        '==':  'is equal to',
        '=~':  'contains',
        '=<':  'is less than',
        '=>':  'is greater than',
        '=#':  'has element',
        '=@':  'Near',
        '=d>': 'is after',
        '=d<': 'is before',
        '=in': 'is in',
        '=e':  'is empty'
    };
},
```

### Replace `FilterFactory.createFromPossibleOperatorType` if/else block

```javascript
if (getFilterColumnTypesFromOptionValue(possibleOperatorType) == '=@') {
    return new filter.NearZipCodeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else if (filterDateRangeRegistry && filterDateRangeRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.DateRangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else if (filterRangeRegistry && filterRangeRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.RangeFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else if (filterDropDownRegistry && filterDropDownRegistry[getFilterColumnNameFromOptionValue(possibleOperatorType)]) {
    return new filter.DropDownFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
} else {
    return new filter.DefaultFilter(possibleOperatorType, filterCounter, filterAreaID, selectableColumns, instanceName);
}
```

### Replace the operator type loop in `createOperatorSelect`

Handles 3-character operators (`=d>`, `=d<`, `=in`) correctly

```javascript
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
```

### Add at end of file — registries and new filter classes

```javascript
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
    operatorSelect.appendChild(this.createOption('==', 'is equal to'));
    if (filterIsInRegistry[columnName] && filterIsInRegistry[columnName].length > 0)
        operatorSelect.appendChild(this.createOption('=in', 'is in'));
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
};

function applyDropDownFilter(filterAreaID, filterCounter, instanceName, columnName) {
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal = filterArea.value;
    var op = document.getElementById(filterAreaID + filterCounter + 'operator').value;

    var pattern = new RegExp(',?' + columnName + '(?:==|=in)[^,]*', 'g');
    filterVal = filterVal.replace(pattern, '');
    filterVal = filterVal.replace(/^,/, '');

    var val = document.getElementById(filterAreaID + filterCounter + 'value').value;
    if (val !== '') filterVal += (filterVal ? ',' : '') + columnName + op + val;

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
    operatorSelect.appendChild(this.createOption('==',      'is equal to'));
    operatorSelect.appendChild(this.createOption('=>',      'is after'));
    operatorSelect.appendChild(this.createOption('=<',      'is before'));
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

    var escapedColumn = columnName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=d>[^,]*', 'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '=d<[^,]*', 'g'), '');
    filterVal = filterVal.replace(new RegExp(',?' + escapedColumn + '==[^,]*',  'g'), '');
    filterVal = filterVal.replace(/^,/, '').replace(/,$/, '');

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
        className: 'inputbox', type: 'number', style: 'width: 80px;'
    });
    var toInput = this.createElement('input', {
        id: this.filterAreaID + this.filterCounter + 'to',
        className: 'inputbox', type: 'number', style: 'width: 80px;'
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
    var op         = document.getElementById(filterAreaID + filterCounter + 'operator').value;
    var filterArea = document.getElementById('filterArea' + instanceName);
    var filterVal  = filterArea.value;

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

    filterArea.value = filterVal;
}
```