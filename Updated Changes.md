# Extra Field Date Filter Fix

## In lib/Datagrid.php _getData():
This is to handle the == when it comes to date.
After this:
```php
                  /* Is equal to (==) */
                    if (strpos($data, '==') !== false)
                    {
```
Insert this:
```php
                        $isDateColumn = isset($this->_classColumns[$columnName]['filterTypes']) &&
                            (strpos($this->_classColumns[$columnName]['filterTypes'], '=d>') !== false ||
                             strpos($this->_classColumns[$columnName]['filterTypes'], '=d<') !== false);

                        if ($isDateColumn)
                        {
                            $dateSQLFormat = $_SESSION['CATS']->isDateDMY() ? '%d-%m-%y' : '%m-%d-%y';

                            if (isset($this->_classColumns[$columnName]['filter']))
                            {
                                $whereSQL_or[] = 'DATE(' . $this->_classColumns[$columnName]['filter'] . ') = STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'' . $dateSQLFormat . '\') ';
                            }

                            if (isset($this->_classColumns[$columnName]['filterHaving']))
                            {
                                $havingSQL_or[] = 'DATE(' . $this->_classColumns[$columnName]['filterHaving'] . ') = STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'' . $dateSQLFormat . '\') ';
                            }
                        }
                        else
```

Change this:
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
To this:

```php

                   if (strpos($data, '=d<') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $dateSQLFormat = $_SESSION['CATS']->isDateDMY() ? '%d-%m-%y' : '%m-%d-%y';
                            $whereSQL_or[] = 'DATE(' . $this->_classColumns[$columnName]['filter'] . ') <= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'' . $dateSQLFormat . '\') ';
                        }
                    }
                    if (strpos($data, '=d>') !== false)
                    {
                        if (isset($this->_classColumns[$columnName]['filter']))
                        {
                            $dateSQLFormat = $_SESSION['CATS']->isDateDMY() ? '%d-%m-%y' : '%m-%d-%y';
                            $whereSQL_or[] = 'DATE(' . $this->_classColumns[$columnName]['filter'] . ') >= STR_TO_DATE(' . $db->makeQueryString($argument) . ', \'' . $dateSQLFormat . '\') ';
                        }
                    }
```

## In lib/ExtraFields.php getDataGridDefinition():

Format is built with CONCAT becuase any literal '%m-%d-%y' gets rewritten to '%d-%m-%y' in DMY mode
(Extra field values are always stored mm-dd-yy).
In `case 'date'` change this:
```php
                $definition['filter'] = 'STR_TO_DATE(extra_field' . $uniqueIndex . '.value, \'%m-%d-%y\')';
                break;
```
To this:
```php

                $definition['filter'] = 'STR_TO_DATE(extra_field' . $uniqueIndex . '.value, CONCAT(\'%\',\'m\',\'-\',\'%\',\'d\',\'-\',\'%\',\'y\'))';
                break;
```
