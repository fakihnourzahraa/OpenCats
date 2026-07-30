<?php
/*
 * CATS
 * Evaluations Library
 * 
 * The Original Code is "CATS Standard Edition".
 * This file was added for IBC
 * 
 */
 
include_once(LEGACY_ROOT . '/lib/DatabaseConnection.php');

class Evaluations
{
    private $_db;
    private $_siteID;

    public function __construct($siteID)
    {
        $this->_siteID = $siteID;
        $this->_db = DatabaseConnection::getInstance();
    }


    // Finds the evaluation_instance and returns the instance_id, 
    // or false if nonexistent.
    public function getInstanceForPipeline($candidateID, $jobOrderID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT instance_id FROM evaluation_instance
             WHERE candidate_id = %s AND job_order_id = %s AND site_id = %s",
            (int) $candidateID,
            (int) $jobOrderID,
            $this->_siteID
        ));
        return !empty($rs) ? $rs['instance_id'] : false;
    }

    
    // Creates a new evaluation_instance and returns instance_id.
    // date_created is never touched other than here.
    public function createInstance($candidateID, $jobOrderID, $templateID)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_instance
                (site_id, candidate_id, job_order_id, template_id, date_created)
             VALUES (%s, %s, %s, %s, NOW())",
            $this->_siteID,
            (int) $candidateID,
            (int) $jobOrderID,
            (int) $templateID
        ));
        return $this->_db->getLastInsertID();
    }

    
    // Updates/refreshes an instance's template_id, in case the template changed
    public function updateInstanceTemplate($instanceID, $templateID)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance
             SET template_id = %s
             WHERE instance_id = %s AND site_id = %s",
            (int) $templateID,
            (int) $instanceID,
            $this->_siteID
        ));
    }

    // Returns all evaluators (evaluator_id, evaluator_name) recorded for a
    // given stage of a given instance, ordered by the evaluator_id
    public function getEvaluatorsForStage($instanceID, $stageID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT evaluator_id, evaluator_name
             FROM evaluation_stage_evaluator
             WHERE instance_id = %s AND stage_id = %s AND site_id = %s
             ORDER BY evaluator_id ASC",
            (int) $instanceID,
            (int) $stageID,
            $this->_siteID
        ));
    }

    
    // Adds a new evaluator and returns their id.
    public function addEvaluator($instanceID, $stageID, $evaluatorName)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_stage_evaluator
                (instance_id, stage_id, evaluator_name, site_id)
             VALUES (%s, %s, '%s', %s)",
            (int) $instanceID,
            (int) $stageID,
            $this->_db->escapeString($evaluatorName),
            $this->_siteID
        ));
        return $this->_db->getLastInsertID();
    }

    
    // Renames an existing evaluator
    public function renameEvaluator($evaluatorID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_stage_evaluator
             SET evaluator_name = '%s'
             WHERE evaluator_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $evaluatorID,
            $this->_siteID
        ));
    }

    
    // Returns criteria_id => value for everything a single evaluator has
    // filled in so far, for pre-filling their block on page load.    
    public function getValuesForEvaluator($evaluatorID)
    {
        $rows = $this->_db->getAllAssoc(sprintf(
            "SELECT criteria_id, value
             FROM evaluation_criteria_value
             WHERE evaluator_id = %s AND site_id = %s",
            (int) $evaluatorID,
            $this->_siteID
        ));

        $values = array();
        foreach ($rows as $row)
        {
            $values[$row['criteria_id']] = $row['value'];
        }
        return $values;
    }


    //Update if a row for (evaluator_id, criteria_id) already exists, insert otherwise.
    public function saveCriteriaValue($evaluatorID, $criteriaID, $value)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT value_id FROM evaluation_criteria_value
             WHERE evaluator_id = %s AND criteria_id = %s AND site_id = %s",
            (int) $evaluatorID,
            (int) $criteriaID,
            $this->_siteID
        ));

        if (!empty($rs))
        {
            $this->_db->query(sprintf(
                "UPDATE evaluation_criteria_value
                 SET value = '%s'
                 WHERE value_id = %s AND site_id = %s",
                $this->_db->escapeString($value),
                (int) $rs['value_id'],
                $this->_siteID
            ));
        }
        else
        {
            $this->_db->query(sprintf(
                "INSERT INTO evaluation_criteria_value
                    (evaluator_id, criteria_id, value, site_id)
                 VALUES (%s, %s, '%s', %s)",
                (int) $evaluatorID,
                (int) $criteriaID,
                $this->_db->escapeString($value),
                $this->_siteID
            ));
        }
    }

    // Returns every evaluator + value row for an entire instance in one
    // query(stage_id, evaluator_id, evaluator_name, criteria_id, value)
    // evaluate() folds this into each stage's 'evaluators' array.
    // LEFT JOIN is used on the value side so evaluators with no criterias show up

    public function getAllValuesForInstance($instanceID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT ese.stage_id, ese.evaluator_id, ese.evaluator_name,
                    ecv.criteria_id, ecv.value
             FROM evaluation_stage_evaluator ese
             LEFT JOIN evaluation_criteria_value ecv
                    ON ecv.evaluator_id = ese.evaluator_id
                   AND ecv.site_id = ese.site_id
             WHERE ese.instance_id = %s AND ese.site_id = %s
             ORDER BY ese.stage_id ASC, ese.evaluator_id ASC",
            (int) $instanceID,
            $this->_siteID
        ));
    }

    
    //Deletes an evaluator and all their criteria values for a stage.
    public function deleteEvaluator($evaluatorID)
    {
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_criteria_value
            WHERE evaluator_id = %s AND site_id = %s",
            (int) $evaluatorID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_stage_evaluator
            WHERE evaluator_id = %s AND site_id = %s",
            (int) $evaluatorID,
            $this->_siteID
        ));
    }

    public function getAllEvaluatorNames()
    {
        $rows = $this->_db->getAllAssoc(sprintf(
            "SELECT DISTINCT evaluator_name
            FROM evaluation_stage_evaluator
            WHERE site_id = %s AND evaluator_name != ''
            ORDER BY evaluator_name ASC",
            $this->_siteID
        ));

        return array_map(function ($row) { return $row['evaluator_name']; }, $rows);
    }
}
?>