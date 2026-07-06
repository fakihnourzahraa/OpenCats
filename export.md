
in lib/datagrid.php

$exportableColumns = array();
foreach ($this->_currentColumns as $index => $colData)
{
    $exportableColumns[] = array('name' => $colData['name'], 'data' => $colData['data']);
}


in extraFields.php
```php
            // "SELECT
            //     extra_field_settings.field_name AS fieldName,
            //     extra_field_settings.extra_field_settings_id AS extraFieldSettingsID,
            //     extra_field_settings.extra_field_type as extraFieldType,
            //     extra_field_settings.extra_field_options as extraFieldOptions,
            //     extra_field_settings.filter_type AS filterType,
                extra_field_settings.site_id AS siteID

//replace define
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

    /* Force this new extra field to have a position. */
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

//replace 
  public function getDataGridDefinition($uniqueIndex, $data, $db)
    {
        switch ($this->_dataItemType)
        {
            case DATA_ITEM_JOBORDER:
                $column = 'joborder.joborder_id';
                break;
            case DATA_ITEM_CANDIDATE:
                $column = 'candidate.candidate_id';
                break;
            case DATA_ITEM_CONTACT:
                $column = 'contact.contact_id';
                break;
            case DATA_ITEM_COMPANY:
            default:
                $column = 'company.company_id';
                break;
        }

        $join = 'LEFT JOIN extra_field AS extra_field' . $uniqueIndex . ' '
            . 'ON ' . $column . ' = extra_field' . $uniqueIndex . '.data_item_id '
            . 'AND extra_field' . $uniqueIndex . '.field_name = ' . $db->makeQueryString($data['fieldName']) . ' '
            . 'AND extra_field' . $uniqueIndex . '.data_item_type = ' . $this->_dataItemType;

        switch ($data['extraFieldType'])
        {
            case EXTRA_FIELD_CHECKBOX:
                $definition = array(
                    'select'         => 'extra_field'.$uniqueIndex.'.value AS extra_field_value'.$uniqueIndex,
                    'join'           => $join,
                    'pagerRender'    => 'return ($rsData[\'extra_field_value'.$uniqueIndex.'\'] == \'Yes\' ? \'Yes\' : \'No\');',
                    'exportRender'   => 'return ($rsData[\'extra_field_value'.$uniqueIndex.'\'] == \'Yes\' ? \'Yes\' : \'No\');',
                    'sortableColumn' => 'extra_field_value'.$uniqueIndex,
                    'pagerWidth'     => 45,
                    'filter'         => 'IF (extra_field'.$uniqueIndex.'.value = "Yes", "Yes", "No")',
                );
                break;

            case EXTRA_FIELD_DATE:
                $pagerRender = 'if (isset($_SESSION[\'CATS\']) && $_SESSION[\'CATS\']->isLoggedIn() && $_SESSION[\'CATS\']->isDateDMY()) { $dateParts = explode(\'-\', $rsData[\'extra_field_value'.$uniqueIndex.'\']); if (count($dateParts) > 2) { $t = $dateParts[0]; $dateParts[0] = $dateParts[1]; $dateParts[1] = $t; } return implode(\'-\', $dateParts); } else { return $rsData[\'extra_field_value'.$uniqueIndex.'\']; }';
                $definition = array(
                    'select'         => 'extra_field'.$uniqueIndex.'.value AS extra_field_value'.$uniqueIndex,
                    'join'           => $join,
                    'pagerRender'    => $pagerRender,
                    'exportRender'   => $pagerRender,
                    'sortableColumn' => 'extra_field_value'.$uniqueIndex,
                    'pagerWidth'     => 110,
                    'filter'         => 'extra_field'.$uniqueIndex.'.value',
                );
                break;

            case EXTRA_FIELD_TEXT:
            default:
                $definition = array(
                    'select'         => 'extra_field'.$uniqueIndex.'.value AS extra_field_value'.$uniqueIndex,
                    'join'           => $join,
                    'pagerRender'    => 'return htmlspecialchars($rsData[\'extra_field_value'.$uniqueIndex.'\']);',
                    'sortableColumn' => 'extra_field_value'.$uniqueIndex,
                    'pagerWidth'     => 110,
                    'filter'         => 'extra_field'.$uniqueIndex.'.value',
                );
                break;
        }

        // Apply filter type from settings
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
}
```