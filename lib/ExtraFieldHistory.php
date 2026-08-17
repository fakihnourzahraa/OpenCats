<?php
/**
 * CATS
 * Extra Field History Library
 *
 * Tracks changes to extra field values (currently: Interview Stage only).
 * extra_field itself has no built-in change tracking -- ExtraFields::setValue()
 * does a DELETE then INSERT on every save, so the previous value is destroyed
 * before anything could diff it. This class is called from setValue() with the
 * previous/new values already captured, and logs the transition to
 * extra_field_history, mirroring the shape and conventions of the core
 * History class (lib/History.php) which logs to the "history" table.
 *
 * @package    CATS
 * @subpackage Library
 */

class ExtraFieldHistory
{
    private $_db;
    private $_siteID;
    private $_userID;

    public function __construct($siteID)
    {
        $this->_siteID = $siteID;
        // FIXME: Remove dependency on Session here (mirrors History.php's own FIXME).
        $this->_userID = $_SESSION['CATS']->getUserID();
        $this->_db = DatabaseConnection::getInstance();
    }

    /**
     * Stores a single extra field value change.
     *
     * @param integer data item type
     * @param integer data item ID
     * @param string field name
     * @param string previous value (or null)
     * @param string new value
     * @return query response
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
     * oldest first (needed for time-in-stage delta calculations, unlike
     * History::getAll() which returns newest first for display purposes).
     *
     * @param integer data item type
     * @param integer data item ID
     * @param string field name
     * @return array history entries
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