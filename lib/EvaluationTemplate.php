<?php
/*
 * Evaluation Template Library
 */

class EvaluationTemplate
{
    public static $DATA_TYPES = array('text', 'date', 'number');

    private $_db;
    private $_siteID;

    public function __construct($siteID)
    {
        $this->_siteID = (int) $siteID;
        $this->_db     = DatabaseConnection::getInstance();
    }

    //returns template id for a joborder, else the generic template
    public function getTemplateID($jobOrderID)
    {
        if ($jobOrderID > 0)
        {
            $rs = $this->_db->getAssoc(sprintf(
                "SELECT template_id FROM evaluation_template
                 WHERE site_id = %s AND job_order_id = %s",
                $this->_siteID,
                (int) $jobOrderID
            ));
            if (!empty($rs)) return $rs['template_id'];
        }

        $rs = $this->_db->getAssoc(sprintf(
            "SELECT template_id FROM evaluation_template
             WHERE site_id = %s AND job_order_id IS NULL",
            $this->_siteID
        ));
        return !empty($rs) ? $rs['template_id'] : false;
    }

    public function addTemplate($jobOrderID)
    {
        if ($jobOrderID > 0)
        {
            $this->_db->query(sprintf(
                "INSERT INTO evaluation_template (site_id, job_order_id)
                VALUES (%s, %s)",
                $this->_siteID,
                (int) $jobOrderID
            ));
            $templateID = $this->_db->getLastInsertID();

            //inherit generic
            $genericTemplateID = $this->getOwnTemplateID(0);
            if ($genericTemplateID !== false)
                $this->_copyStagesAndCriteria($genericTemplateID, $templateID);
            return ($templateID);
        }
        else
        {
            $this->_db->query(sprintf(
                "INSERT INTO evaluation_template (site_id, job_order_id)
                VALUES (%s, NULL)",
                $this->_siteID
            ));
            return ($this->_db->getLastInsertID());
        }
    }

    //Just used for copying generic for a new template
    private function _copyStagesAndCriteria($sourceTemplateID, $destTemplateID)
    {
        $stages = $this->getStages($sourceTemplateID);

        foreach ($stages as $stage)
        {

            $this->_db->query(sprintf(
                "INSERT INTO evaluation_stage (template_id, site_id, stage_name, position, weight)
                VALUES (%s, %s, '%s', %s, %s)",
                (int) $destTemplateID,
                $this->_siteID,
                $this->_db->escapeString($stage['stage_name']),
                (int) $stage['position'],
                $this->_sanitizeWeight(isset($stage['weight']) ? $stage['weight'] : 0)
            ));
            $newStageID = $this->_db->getLastInsertID();

            $criteria = $this->getCriteria($stage['stage_id']);
            foreach ($criteria as $criterion)
            {

                $this->_db->query(sprintf(
                    "INSERT INTO evaluation_criteria
                        (stage_id, site_id, criteria_name, data_type, is_gradeable, position, weight)
                    VALUES (%s, %s, '%s', '%s', %s, %s, %s)",
                    (int) $newStageID,
                    $this->_siteID,
                    $this->_db->escapeString($criterion['criteria_name']),
                    $this->_db->escapeString($criterion['data_type']),
                    (!empty($criterion['is_gradeable']) ? 1 : 0),
                    (int) $criterion['position'],
                    $this->_sanitizeWeight(isset($criterion['weight']) ? $criterion['weight'] : 0)
                ));
            }
        }
    }

    public function getStages($templateID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT stage_id, stage_name, position, weight
             FROM evaluation_stage
             WHERE template_id = %s AND site_id = %s
             ORDER BY position ASC",
            (int) $templateID,
            $this->_siteID
        ));
    }

    public function getCriteria($stageID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT criteria_id, criteria_name, data_type, is_gradeable, position, weight
             FROM evaluation_criteria
             WHERE stage_id = %s AND site_id = %s
             ORDER BY position ASC",
            (int) $stageID,
            $this->_siteID
        ));
    }

    public function getOwnTemplateID($jobOrderID)
    {
        if ($jobOrderID > 0)
        {
            $rs = $this->_db->getAssoc(sprintf(
                "SELECT template_id FROM evaluation_template
                WHERE site_id = %s AND job_order_id = %s",
                $this->_siteID, (int) $jobOrderID
            ));
        }
        else
        {
            $rs = $this->_db->getAssoc(sprintf(
                "SELECT template_id FROM evaluation_template
                WHERE site_id = %s AND job_order_id IS NULL",
                $this->_siteID
            ));
        }
        return (!empty($rs) ? $rs['template_id'] : false);
    }

    public function getJobOrdersWithTemplates()
    {
        $rows = $this->_db->getAllAssoc(sprintf(
            "SELECT job_order_id FROM evaluation_template
             WHERE site_id = %s AND job_order_id IS NOT NULL",
            $this->_siteID
        ));

        $map = array();
        foreach ($rows as $row)
        {
            $map[(int) $row['job_order_id']] = true;
        }
        return $map;
    }

    /* A new stage arrives with Rating already gradeable and carrying the
     * whole weight, so it scores immediately instead of needing the
     * checkbox ticked by hand first. Comments stays plain text and
     * ungradeable. */
    public function addStage($templateID, $stageName, $position, $weight = 100)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_stage (template_id, site_id, stage_name, position, weight)
            VALUES (%s, %s, '%s', %s, %s)",
            (int) $templateID, $this->_siteID,
            $this->_db->escapeString($stageName), (int) $position,
            $this->_sanitizeWeight($weight)
        ));
        $stageID = $this->_db->getLastInsertID();

        $this->_db->query(sprintf(
            "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, data_type, is_gradeable, position, weight)
            VALUES (%s, %s, 'Rating', 'text', 1, 0, 100)",
            (int) $stageID, $this->_siteID
        ));
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, data_type, is_gradeable, position, weight)
            VALUES (%s, %s, 'Comments', 'text', 0, 99, 0)",
            (int) $stageID, $this->_siteID
        ));
        return ($stageID);
    }

    public function deleteStage($stageID)
    {
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_criteria WHERE stage_id = %s AND site_id = %s",
            (int) $stageID,
            $this->_siteID
        ));
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_stage WHERE stage_id = %s AND site_id = %s",
            (int) $stageID,
            $this->_siteID
        ));
    }

    public function getStageIDByName($templateID, $stageName)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT stage_id FROM evaluation_stage
             WHERE template_id = %s AND site_id = %s AND stage_name = '%s'",
            (int) $templateID,
            $this->_siteID,
            $this->_db->escapeString($stageName)
        ));
        return (!empty($rs) ? $rs['stage_id'] : false);
    }

    public function addCriteria($stageID, $criteriaName, $position, $dataType = 'text',
                                 $weight = 0, $isGradeable = 0)
    {
        if (!in_array($dataType, self::$DATA_TYPES))
        {
            $dataType = 'text';
        }

        $this->_db->query(sprintf(
            "INSERT INTO evaluation_criteria
                (stage_id, site_id, criteria_name, data_type, is_gradeable, position, weight)
             VALUES (%s, %s, '%s', '%s', %s, %s, %s)",
            (int) $stageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName),
            $this->_db->escapeString($dataType),
            ($isGradeable ? 1 : 0),
            (int) $position,
            $this->_sanitizeWeight($weight)
        ));
        return ($this->_db->getLastInsertID());
    }

    public function deleteCriteria($criteriaID)
    {
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_criteria WHERE criteria_id = %s AND site_id = %s",
            (int) $criteriaID,
            $this->_siteID
        ));
    }

    public function renameStage($stageID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_stage SET stage_name = '%s'
            WHERE stage_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $stageID,
            $this->_siteID
        ));
    }

    public function setStageWeight($stageID, $weight)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_stage SET weight = %s
            WHERE stage_id = %s AND site_id = %s",
            $this->_sanitizeWeight($weight),
            (int) $stageID,
            $this->_siteID
        ));
    }

    public function renameCriteria($criteriaID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET criteria_name = '%s'
            WHERE criteria_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $criteriaID,
            $this->_siteID
        ));
    }

    public function setCriteriaWeight($criteriaID, $weight)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET weight = %s
            WHERE criteria_id = %s AND site_id = %s",
            $this->_sanitizeWeight($weight),
            (int) $criteriaID,
            $this->_siteID
        ));
    }

    // Whether this criterion enters the template's weight shares at all.
    // Does not touch weight itself - unticking and re-ticking restores
    // whatever number was already there.
    public function setCriteriaGradeable($criteriaID, $isGradeable)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET is_gradeable = %s
            WHERE criteria_id = %s AND site_id = %s",
            ($isGradeable ? 1 : 0),
            (int) $criteriaID,
            $this->_siteID
        ));
    }

    public function getCriteriaIDByName($stageID, $criteriaName)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT criteria_id FROM evaluation_criteria
             WHERE stage_id = %s AND site_id = %s AND criteria_name = '%s'",
            (int) $stageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName)
        ));
        return (!empty($rs) ? $rs['criteria_id'] : false);
    }

    public function getNextStagePosition($templateID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_stage
             WHERE template_id = %s AND site_id = %s",
            (int) $templateID,
            $this->_siteID
        ));
        return (($rs && $rs['max_pos'] !== null) ? (int) $rs['max_pos'] + 1 : 0);
    }

    public function getNextCriteriaPosition($stageID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_criteria
            WHERE stage_id = %s AND site_id = %s AND criteria_name != 'Comments'",
            (int) $stageID,
            $this->_siteID
        ));
        return ($rs && $rs['max_pos'] !== null) ? (int) $rs['max_pos'] + 1 : 0;
    }

    public function getFullTemplate($jobOrderID)
    {
        $templateID = $this->getTemplateID($jobOrderID);
        if (!$templateID) return array();

        $stages = $this->getStages($templateID);
        if (empty($stages)) return array();

        foreach ($stages as $i => $stage)
        {
            $stages[$i]['criteria'] = $this->getCriteria($stage['stage_id']);
        }
        return $stages;
    }

    public function deleteTemplate($templateID)
    {
        $stages = $this->getStages($templateID);
        foreach ($stages as $stage)
        {
            $this->_db->query(sprintf(
                "DELETE FROM evaluation_criteria WHERE stage_id = %s AND site_id = %s",
                (int) $stage['stage_id'],
                $this->_siteID
            ));
        }

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_stage WHERE template_id = %s AND site_id = %s",
            (int) $templateID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_template WHERE template_id = %s AND site_id = %s",
            (int) $templateID,
            $this->_siteID
        ));
    }

    public function moveStage($templateID, $stageID, $direction)
    {
        $stages = $this->getStages($templateID); //ordered by position asc
        $idx = -1;
        foreach ($stages as $i => $s)
        {
            if ((int) $s['stage_id'] === (int) $stageID)
            {
                $idx = $i;
                break;
            }
        }
        if ($idx === -1)
            return;

        $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapIdx < 0 || $swapIdx >= count($stages))
            return;

        $posA = $stages[$idx]['position'];
        $posB = $stages[$swapIdx]['position'];

        $this->_db->query(sprintf(
            "UPDATE evaluation_stage SET position = %s WHERE stage_id = %s AND site_id = %s",
            (int) $posB, (int) $stages[$idx]['stage_id'], $this->_siteID
        ));
        $this->_db->query(sprintf(
            "UPDATE evaluation_stage SET position = %s WHERE stage_id = %s AND site_id = %s",
            (int) $posA, (int) $stages[$swapIdx]['stage_id'], $this->_siteID
        ));
    }

    public function moveCriteria($stageID, $criteriaID, $direction)
    {
        $criteria = $this->getCriteria($stageID); //ordered by position asc
        $idx = -1;
        foreach ($criteria as $i => $c)
        {
            if ((int) $c['criteria_id'] === (int) $criteriaID)
            {
                $idx = $i;
                break;
            }
        }
        if ($idx === -1)
            return;

        $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapIdx < 0 || $swapIdx >= count($criteria))
            return;

        $posA = $criteria[$idx]['position'];
        $posB = $criteria[$swapIdx]['position'];

        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET position = %s WHERE criteria_id = %s AND site_id = %s",
            (int) $posB, (int) $criteria[$idx]['criteria_id'], $this->_siteID
        ));
        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET position = %s WHERE criteria_id = %s AND site_id = %s",
            (int) $posA, (int) $criteria[$swapIdx]['criteria_id'], $this->_siteID
        ));
    }

    public function changeCriteriaType($criteriaID, $dataType)
    {
        if (!in_array($dataType, self::$DATA_TYPES))
        {
            return;
        }

        $this->_db->query(sprintf(
            "UPDATE evaluation_criteria SET data_type = '%s'
            WHERE criteria_id = %s AND site_id = %s",
            $this->_db->escapeString($dataType),
            (int) $criteriaID,
            $this->_siteID
        ));
    }

    private function _sanitizeWeight($weight)
    {
        $weight = (float) $weight;

        if ($weight < 0)       { $weight = 0; }
        if ($weight > 9999.99) { $weight = 9999.99; }

        return sprintf('%.2f', $weight);
    }
}
?>