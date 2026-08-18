<?php
/**
 * ExtraFieldHistory.php
 * Added for IBC
 */

class ExtraFieldHistory
{
    private $_db;
    private $_siteID;
    private $_userID;

    public function __construct($siteID)
    {
        $this->_siteID = $siteID;
        $this->_userID = $_SESSION['CATS']->getUserID();
        $this->_db = DatabaseConnection::getInstance();
    }

    /**
     * Stores a single extra field value change.
     */
    public function storeFieldChange($dataItemType, $dataItemID, $field,
        $previousValue, $newValue)
    {
        $description = sprintf(
            '(USER) changed field(s): %s.', $field
        );

        $sql = sprintf(
            "INSERT INTO extra_field_history (
                data_item_type,
                data_item_id,
                the_field,
                previous_value,
                new_value,
                description,
                set_date,
                entered_by,
                site_id
            ) VALUES (
                %s, %s, %s, %s, %s, %s, NOW(), %s, %s
            )",
            $dataItemType,
            $dataItemID,
            $this->_db->makeQueryStringOrNULL($field),
            $this->_db->makeQueryStringOrNULL($previousValue),
            $this->_db->makeQueryStringOrNULL($newValue),
            $this->_db->makeQueryStringOrNULL($description),
            $this->_userID,
            $this->_siteID
        );

        return $this->_db->query($sql);
    }

    /**
     * Get all extra field history entries for a given data item and field,
     * oldest first.
     */
    public function getAllForField($dataItemType, $dataItemID, $field)
    {
        $sql = sprintf(
            "SELECT
                extra_field_history_id AS historyID,
                the_field AS theField,
                previous_value AS previousValue,
                new_value AS newValue,
                description AS description,
                set_date AS setDate,
                entered_by AS enteredByID
            FROM
                extra_field_history
            WHERE
                site_id = %s
            AND
                data_item_type = %s
            AND
                data_item_id = %s
            AND
                the_field = %s
            ORDER BY
                extra_field_history_id ASC",
            $this->_siteID,
            $this->_db->makeQueryInteger($dataItemType),
            $this->_db->makeQueryInteger($dataItemID),
            $this->_db->makeQueryString($field)
        );

        return $this->_db->getAllAssoc($sql);
    }
}

?>