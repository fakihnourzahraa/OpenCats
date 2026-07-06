# Ranges Notes

This document contains the exact code changes needed to implement three features:

1. **GPA** field on candidates (add/edit/display/filter)
2. **Created** date range filtering (candidates list and job order pipeline)


Each section below names the file, says where the change goes, and gives the code verbatim so it can be copied directly into the codebase.

---

## 1. Database Changes

Run these against the database before anything else:

```sql
ALTER TABLE candidate ADD COLUMN gpa DECIMAL(3,2) DEFAULT NULL;
```

---

## 2. GPA Feature
### `modules/candidates/Candidates.tpl`
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
    filterDateRangeRegistry['Desired Pay'] = true;
</script>
```

### `modules/candidates/Add.tpl`

Add this row to the form (inside the existing table of fields):

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

### `modules/candidates/Edit.tpl`

Add this row to the form:

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

### `modules/candidates/Show.tpl`

Add this row to the candidate details display:

```php
<tr>
    <td class="vertical">GPA:</td>
    <td class="data"><?php $this->_($this->data['gpa']); ?></td>
</tr>
```

### `modules/candidates/CandidatesUI.php`

**In the parsed-fields array** (used by `checkParsingFunctions`), add the `gpa` key:

```php
'isFromParser'    => true,
'gpa'             => $this->getTrimmedInput('gpa', $_POST),
```

**Before the call to `Candidates::add()`** (around line 2610), add:

```php
$gpa = $this->getTrimmedInput('gpa', $_POST);
```

**In the `Candidates::add()` call itself** (around line 2663), add `$gpa` as the final argument:

```php
,$gpa
```

**Before the call to `Candidates::update()`** (around line 1380), pass `$gpa` as the final argument in the same way.

### `lib/Candidates.php`

**`add()` function signature** add new parameters after `$disability`:

```php
$gender = '', $race = '', $veteran = '', $disability = '', $gpa = '', $universityID = 0, $nationality = '',
```

**`add()` INSERT statement**  add the parameters to the column list and corresponding `%s` placeholder to the VALUES list, then pass the value through using:

```php
$this->_db->makeQueryDouble($gpa),
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality)
```

(immediately after `$this->_db->makeQueryString($gender)`)

**`update()` function signature** (around line 259)  add new parameters:

```php
$gender = '', $race = '', $veteran = '', $disability = '', $gpa = '',, $universityID = 0, $nationality = '')
```

**`update()` SET clause** (around line 296)  add:

```php
gpa = %s,
university_id = %s,
nationality = %s
```

**`update()` value list** (around line 329)  add:

```php
$this->_db->makeQueryDouble($gpa),
$this->_db->makeQueryInteger($universityID),
$this->_db->makeQueryString($nationality),
```

**`get()` function** (around line 495)  add to the SELECT clause:

```php
candidate.gpa AS gpa,
candidate.university_id AS universityID,
university.canonical_name AS universityCanonicalName,
university.short_name AS universityShortName,
candidate.nationality AS nationality,
// [...]
// eeo_veteran_type.eeo_veteran_type_id = candidate.eeo_veteran_type_id
LEFT JOIN university
ON university.university_id = candidate.university_id

```

**`getForEditing()` function** (around line 636)  add to the SELECT clause:

```php
candidate.gpa AS gpa,
candidate.university_id AS universityID,
candidate.nationality AS nationality,
```


```
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


add 'filterTypes' ==> '=in' to all class COlumns vars

Created becoems:
            'Created' =>       array('select'   => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\') AS dateCreated',
                                    'pagerRender'      => 'return $rsData[\'dateCreated\'];',
                                    'sortableColumn'     => 'dateCreatedSort',
                                    'pagerWidth'    => 60,
                                    'filter'      => 'candidate.date_created',
                                    'filterHaving' => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\')',
                                    'filterTypes'  => '=d>=d<=='),
        modified becomes: 
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
 Added to list: =d>=d<

 add:
   'GPA'  =>           array(
                                    'select'         => 'candidate.gpa AS gpa',
                                    'sortableColumn' => 'gpa',
                                    'pagerWidth'     => 60,
                                    'pagerOptional'  => true,
                                    'filter'         => 'candidate.gpa',
                                    'filterTypes'    => '=>=<=><==', 
                                ),
            'University' =>     array(
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
            'Nationality' =>    array(
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
**`CandidatesDataGrid::_classColumns`**  add a new `GPA` entry to the array:

```php
'GPA'  =>          array(
                        'select'         => 'candidate.gpa AS gpa',
                        'sortableColumn' => 'gpa',
                        'pagerWidth'     => 60,
                        'pagerOptional'  => true,
                        'filter'         => 'candidate.gpa',
                        'filterTypes'    => '=><==',
                    ),
```

### `lib/Pipelines.php`

```php
//replace the following functions
 public function getJobOrderPipeline($jobOrderID, $orderBy = '')
    {
        /* FIXME: CONCAT() stuff is a very ugly hack, but I don't think there
         * is a way to return multiple values from a subquery.
         */
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

### `lib/JobOrders.php`
in created add
```php

'filterTypes'  => '=d>=d<=='),
```

### `modules/joborders/dataGrids.php`

In `JobOrdersListByViewDataGrid`'s `_defaultColumns` array, add:

```php
array('name' => 'gpa', 'width' => 55),

//end of file:

class PipelineCandidatesDataGrid extends CandidatesDataGrid
{
    public function __construct($siteID, $parameters, $misc)
    {
        /* Pager configuration. */
        $this->_tableWidth = new Width(100, '%');
        $this->_defaultAlphabeticalSortBy = 'lastName';
        $this->ajaxMode = false;
        $this->showExportCheckboxes = true; //BOXES WILL NOT APPEAR UNLESS SQL ROW exportID IS RETURNED!
        $this->showActionArea = true;
        $this->showChooseColumnsBox = true;
        $this->allowResizing = true;

        $this->defaultSortBy = 'dateModifiedSort';
        $this->defaultSortDirection = 'DESC';

        $this->_defaultColumns = array(
            array('name' => 'Attachments', 'width' => 31),
            array('name' => 'First Name', 'width' => 75),
            array('name' => 'Last Name', 'width' => 85),
            array('name' => 'City', 'width' => 75),
            array('name' => 'State', 'width' => 50),
            array('name' => 'Key Skills', 'width' => 215),
            array('name' => 'Owner', 'width' => 65),
            array('name' => 'Created', 'width' => 60),
            array('name' => 'Modified', 'width' => 60),
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
                continue; // match, addedByAbbrName, lastActivity, action have no DataGrid equivalent

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

?>
```
### `modules/setting/CustomizeExtraFields.php

to end of addRowToTable:
'+encodeURI(rowFilterType));

replace addRow:
    addRow<?php echo($index); ?>(
        document.getElementById('addFieldName<?php echo($index); ?>').value, 
        document.getElementById('addFieldSelect<?php echo($index); ?>').value, 
        document.getElementById('addFieldSelect<?php echo($index); ?>').options[document.getElementById('addFieldSelect<?php echo($index); ?>').selectedIndex].text,
        document.getElementById('addFieldFilterSelect<?php echo($index); ?>').value  // ← add this
    );

    add after Field Type:
        <th align="left">
        Filter Type
    </th>

    <!-- <?php $this->_($this->extraFieldTypes[$rsData['extraFieldType']]['name']); ?> -->
       </td>
        <td align="left">
            <?php echo htmlspecialchars($this->extraFieldFilters[$rsData['filterType']]['name'] ?? 'Default (Text)'); ?>

            //add after select for addFieldSelect
               <option value="<?php echo($extraFieldTypeIndex); ?>"><?php $this->_($extraFieldTypeData['name']); ?></option>
                                                    <option value="<?php echo($extraFieldTypeIndex); ?>"><?php $this->_($extraFieldTypeData['name']); ?></option>
                                                  <?php endforeach; ?>
                                                  <?php endforeach; ?>
                                               </select>
                                               </select>
                                            </td>



### `modules/settings/SettingsUI.php`

<!-- $extraFieldTypes = $candidates->extraFields->getValuesTypes(); -->

$this->extraFieldFilters = [
    'default'  => ['name' => 'Default (Text)'],
    'date'     => ['name' => 'Date Range'],
    'range'    => ['name' => 'Range'],
    'dropdown' => ['name' => 'Dropdown'],
];
<!--        $this->_template->assign('extraFieldSettingsCandidatesRS', $candidatesRS);
        $this->_template->assign('extraFieldSettingsContactsRS', $contactsRS);
        $this->_template->assign('extraFieldSettingsCompaniesRS', $companiesRS);
        $this->_template->assign('extraFieldSettingsJobOrdersRS', $jobOrdersRS);
        $this->_template->assign('extraFieldTypes', $extraFieldTypes); -->
$this->_template->assign('extraFieldFilters', $this->extraFieldFilters); 

replace:
 case 'ADDFIELD':
                    $args = explode(' ', $command, 5);
                    $extraFields = new ExtraFields($this->_siteID, intval(urldecode($args[1])));
                    $filterType = isset($args[4]) ? urldecode($args[4]) : 'default';
                    $extraFields->define(urldecode($args[3]), urldecode($args[2]), $filterType);
                    break;
### `modules/joborders/JobOrdersUI.php`


```php
include_once(LEGACY_ROOT . '/modules/joborders/dataGrids.php');

//after all the cases
  case 'exportPipeline':
                $this->exportPipeline();
                break;
        }
    }

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

    /* Build addedByAbbrName */
    foreach ($pipelinesRS as $i => $row)
    {
        $pipelinesRS[$i]['addedByAbbrName'] = StringUtility::makeInitialName(
            $row['addedByFirstName'], $row['addedByLastName'], LAST_NAME_MAXLEN
        );
    }

    /* Merge extra field values into rows */
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

    /* Filter to selected candidates only */
    $pipelinesRS = array_values(array_filter($pipelinesRS, function($row) use ($candidateIDs) {
        return in_array((int)$row['candidateID'], $candidateIDs);
    }));

    /* Base column map */
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

    /* Build export columns from visible session cols */
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


//at the end of the show () function


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

        if (!eval(Hooks::get('JO_SHOW'))) return;

    //     $dataGridProperties = DataGrid::getRecentParamaters('joborders:PipelineCandidatesDataGrid');
    //     if ($dataGridProperties == array())
    //     {
    //         $dataGridProperties = array(
    //             'rangeStart'    => 0,
    //             'maxResults'    => 15,
    //             'filterVisible' => true,
    //             'filter'        => 'First+Name=~',
    //         );
    //     }

    //     $dataGrid = new PipelineCandidatesDataGrid($this->_siteID, $dataGridProperties, 0);
    //     $this->_template->assign('dataGrid', $dataGrid);
    //     $this->_template->assign('userID', $_SESSION['CATS']->getUserID());
    //     $this->_template->display('./modules/joborders/Show.tpl');

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

## 3. Created Date Range Filter

### `lib/Candidates.php`

Replace the existing `Created` column definition in `CandidatesDataGrid::_classColumns` with:

```php
'Created' =>       array('select'   => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\') AS dateCreated',
                            'pagerRender'      => 'return $rsData[\'dateCreated\'];',
                            'sortableColumn'     => 'dateCreatedSort',
                            'pagerWidth'    => 60,
                            'filter'      => 'candidate.date_created',
                            'filterHaving' => 'DATE_FORMAT(candidate.date_created, \'%m-%d-%y\')',
                            'filterTypes'  => '=d>=d<=='),
```

### `lib/DataGrid.php`
```php


                //replace
                // if (isset($this->_classColumns[$value]['filterTypes']))
                // {
                //     $filterableColumns[$index] .= '!@!' . $this->_classColumns[$value]['filterTypes'];
                // }
                // else
                // {
                //     $filterableColumns[$index] .= '!@!' . '===~';
                // }
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


        //add right after: $template->assign('md5InstanceName', $md5InstanceName);
        // $template->assign('arrayKeysString', json_encode(array_values($filterableColumns)));
        // $template->assign('counterFilters', $counterFilters);

      
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
    // replace                 $argument = urldecode(substr($data, strpos($data, '=') + 2));
                $eqPos = strpos($data, '=');

                $operatorLength = 2;
                if (substr($data, $eqPos, 3) === '=d>' || substr($data, $eqPos, 3) === '=d<')
                {
                    $operatorLength = 3;
                }

                //  right after:               foreach ($arguments as $argument)
                // {
                //     $argument = trim($argument);

                    if (strpos($data, '=in') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' = ' . $db->makeQueryString($argument);
                        }
                    }

                    /* Is equal to (==) */

```

**Argument parsing fix.** Find the line in `_getData()` that extracts the column name and argument from the filter string:

```php
$columnName = urldecode(substr($data, 0, strpos($data, '=')));
$argument = urldecode(substr($data, strpos($data, '=') + 2));
```

Replace it with:

```php
$columnName = urldecode(substr($data, 0, strpos($data, '=')));

$eqPos = strpos($data, '=');

$operatorLength = 2;
if (substr($data, $eqPos, 3) === '=d>' || substr($data, $eqPos, 3) === '=d<')
{
    $operatorLength = 3;
}
$argument = urldecode(substr($data, $eqPos + $operatorLength));
```

**Numeric comparison fix.** In the existing `=<` (is less than) block, change `makeQueryInteger` to `makeQueryDouble`:

```php

if (strpos($data, '=<') !== false)
{
    if (isset($this->_classColumns[$columnName]['filter']))
    {
        $whereSQL_or[] = $this->_classColumns[$columnName]['filter'] . ' <= ' . $db->makeQueryDouble($argument) .' ';
    }

    if (isset($this->_classColumns[$columnName]['filterHaving']))
    {
        $havingSQL_or[] = $this->_classColumns[$columnName]['filterHaving'] . ' <= ' . $db->makeQueryDouble($argument)  .' ';
    }
}
```

Do the same for the `=>` (is greater than) block, change `makeQueryInteger` to `makeQueryDouble` in both the `filter` and `filterHaving` lines.

**New date operator blocks.** Add these new blocks (alongside the existing `=<`, `=>`, `=~`, `==`, `=#`, `=@` blocks in the same `foreach ($arguments as $argument)` loop):

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

**Human-readable operator labels.** In `drawFilterArea()`, find the `$filterOperatorHuman` switch statement:

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

(The `=d>` and `=d<` cases are the new addition)

### `js/dataGridFilters.js`

**`filter.getNames()`** replace with:

```javascript
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
```

**`filter.FilterFactory.createFromPossibleOperatorType`** replace the if else statements:

```javascript
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
```

```javascript
    // replace:
    // for (var i = 0; i < possibleTypes.length; i+=2)
    // {
    //     var possibleType = possibleTypes.substr(i,2);
    //     operatorSelect.appendChild(
    //         this.createOption(
    //             possibleType,
    //             filter.getNames()[possibleType]
    //         )
    //     );
    // }

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

```

**New code add at the end of the file:**

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
}

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
    operatorSelect.appendChild(this.createOption('==',     'is equal to'));
    operatorSelect.appendChild(this.createOption('=>',     'is after'));
    operatorSelect.appendChild(this.createOption('=<',     'is before'));
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

> **Note on `setTimeout(updateHandler, 0)`:** this was required because calling `updateHandler()` synchronously right after `operatorSelect.value = 'between'` did not always toggle the range inputs visible on first render (only one input box showed instead of two). Deferring the call with `setTimeout(..., 0)` lets the DOM settle first and fixed the issue.

---

## 4. Job Order Pipeline Filter (separate filtering system)

The job order pipeline ("Candidate in Job Order" section on the Job Order detail page) uses its own AJAX-based filtering system, completely separate from the DataGrid SQL filtering used by the Candidates list. This needed its own implementation for GPA and Created.

### `ajax/getPipelineJobOrder.php`

**`$columnMap`** add `GPA` and `Created`:

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

**`$operators` array** add the 3-character date operators (order matters they must be checked before the 2-character `=>`/`=<` so they match first):

```php
$operators = array('=d>', '=d<', '=~', '==', '=>', '=<');
```

**Filter comparison callback** find this line:

```php
$fieldValue = isset($row[$col]) ? $row[$col] : '';
```

Immediately after it, add the GPA and Created special cases (before falling through to the existing string comparison logic):

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

The rest of the function (string-based comparison for all other columns) stays as-is below these two blocks.

### `modules/joborders/Show.tpl`

The pipeline's filter pills are rendered entirely in inline JavaScript (the `submitFilter<md5>` function), not through `DataGrid::drawFilterArea()`. The same 2-vs-3-character operator parsing bug exists here and needs the same fix.
add this inside in the headers
```php
'js/dataGrid.js', 'js/dataGridFilters.js'
//<?php [...] ?>

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


then from
        //    <p class="note">Candidate in Job Order</p>
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
                <span id="ajaxPipelineNavigation">
                </span>&nbsp;
                <img src="images/indicator.gif" alt="" id="ajaxPipelineTableIndicator" />
            </p>

            <div id="ajaxPipelineTable"></div>
          
            <input type="checkbox" name="select_all" onclick="selectAll_candidates(this)" title="Select all candidates" /> <a href="javascript:void(0);" onclick="exportFromPipeline()" title="Export selected candidates">Export</a>&nbsp;&nbsp;&nbsp;&nbsp;
            
            <script type="text/javascript">
function exportFromPipeline() {
    var ids = getSelected_candidates();
    if (ids.length > 0) {
        window.location.href = '<?php echo(CATSUtility::getIndexName()); ?>?m=joborders&a=exportPipeline&jobOrderID=<?php echo($this->data['jobOrderID']); ?>&candidateIDs=' + urlEncode(serializeArray(ids));
    } else {
        alert('No data selected');
    }
}

till </script>
```

Find this section inside the `filters.forEach(function(f) {...})` block:

```javascript
var eqPos = f.indexOf('=');
if (eqPos === -1) return;
var col = decodeURIComponent(f.substring(0, eqPos));
var op = f.substring(eqPos, eqPos + 2);
var val = decodeURIComponent(f.substring(eqPos + 2));
var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than'};
```

Replace it with:

```javascript
var eqPos = f.indexOf('=');
if (eqPos === -1) return;
var col = decodeURIComponent(f.substring(0, eqPos));
var opLen = (f.substr(eqPos, 3) === '=d>' || f.substr(eqPos, 3) === '=d<') ? 3 : 2;
var op = f.substring(eqPos, eqPos + opLen);
var val = decodeURIComponent(f.substring(eqPos + opLen));
var opNames = {'==':'is equal to','=~':'contains','=>':'is greater than','=<':'is less than','=d>':'from','=d<':'to'};
```

---
