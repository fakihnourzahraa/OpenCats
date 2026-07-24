<?php
/*
 * CATS
 * Evaluation Template Library
 * Added for IBC
 * $Id: EvaluationTemplate.php 3810 2026-22-07 $
 */

class EvaluationTemplate
{
    private $_db;
    private $_siteID;

    public function __construct($siteID)
    {
        $this->_siteID = (int) $siteID;
        $this->_db     = DatabaseConnection::getInstance();
    }

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

        // if job order doesnt have a template, go for generic
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

        /* A job order's first own template inherits a copy of whatever the
           generic template currently has, so customizing it doesn't discard
           stages/criteria it was previously inheriting. */
        $genericTemplateID = $this->getOwnTemplateID(0);
        if ($genericTemplateID !== false)
        {
            $this->_copyStagesAndCriteria($genericTemplateID, $templateID);
        }

        return $templateID;
    }
    else
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_template (site_id, job_order_id)
             VALUES (%s, NULL)", //important to be null
            $this->_siteID
        ));
        return $this->_db->getLastInsertID();
    }
}

private function _copyStagesAndCriteria($sourceTemplateID, $destTemplateID)
{
    $stages = $this->getStages($sourceTemplateID);

    foreach ($stages as $stage)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_stage (template_id, site_id, stage_name, position)
             VALUES (%s, %s, '%s', %s)",
            (int) $destTemplateID,
            $this->_siteID,
            $this->_db->escapeString($stage['stage_name']),
            (int) $stage['position']
        ));
        $newStageID = $this->_db->getLastInsertID();

        $criteria = $this->getCriteria($stage['stage_id']);
        foreach ($criteria as $criterion)
        {
            $this->_db->query(sprintf(
                "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, position)
                 VALUES (%s, %s, '%s', %s)",
                (int) $newStageID,
                $this->_siteID,
                $this->_db->escapeString($criterion['criteria_name']),
                (int) $criterion['position']
            ));
        }
    }
}

    public function getStages($templateID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT stage_id, stage_name, position
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
            "SELECT criteria_id, criteria_name, position
             FROM evaluation_criteria
             WHERE stage_id = %s AND site_id = %s
             ORDER BY position ASC",
            (int) $stageID,
            $this->_siteID
        ));
    }


// returns false if job order doesnt have a template (only use to write)
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
    return !empty($rs) ? $rs['template_id'] : false;
}

public function addStage($templateID, $stageName, $position)
{
    $this->_db->query(sprintf(
        "INSERT INTO evaluation_stage (template_id, site_id, stage_name, position)
         VALUES (%s, %s, '%s', %s)",
        (int) $templateID, $this->_siteID,
        $this->_db->escapeString($stageName), (int) $position
    ));
    $stageID = $this->_db->getLastInsertID();

    $this->_db->query(sprintf(
        "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, position)
         VALUES (%s, %s, 'Rating', 0)",
        (int) $stageID, $this->_siteID
    ));
    $this->_db->query(sprintf(
        "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, position)
         VALUES (%s, %s, 'Comments', 1)",
        (int) $stageID, $this->_siteID
    ));

    return $stageID;
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
        return !empty($rs) ? $rs['stage_id'] : false;
    }

    public function addCriteria($stageID, $criteriaName, $position)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_criteria (stage_id, site_id, criteria_name, position)
             VALUES (%s, %s, '%s', %s)",
            (int) $stageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName),
            (int) $position
        ));
        return $this->_db->getLastInsertID();
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
    public function getCriteriaIDByName($stageID, $criteriaName)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT criteria_id FROM evaluation_criteria
             WHERE stage_id = %s AND site_id = %s AND criteria_name = '%s'",
            (int) $stageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName)
        ));
        return !empty($rs) ? $rs['criteria_id'] : false;
    }

    public function getNextStagePosition($templateID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_stage
             WHERE template_id = %s AND site_id = %s",
            (int) $templateID,
            $this->_siteID
        ));
        return ($rs && $rs['max_pos'] !== null) ? (int) $rs['max_pos'] + 1 : 0;
    }

    public function getNextCriteriaPosition($stageID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_criteria
             WHERE stage_id = %s AND site_id = %s",
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
    $stages = $this->getStages($templateID); // ordered by position ASC
    $idx = -1;
    foreach ($stages as $i => $s)
    {
        if ((int) $s['stage_id'] === (int) $stageID) { $idx = $i; break; }
    }
    if ($idx === -1) return;

    $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
    if ($swapIdx < 0 || $swapIdx >= count($stages)) return;

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
    $criteria = $this->getCriteria($stageID); // ordered by position ASC
    $idx = -1;
    foreach ($criteria as $i => $c)
    {
        if ((int) $c['criteria_id'] === (int) $criteriaID) { $idx = $i; break; }
    }
    if ($idx === -1) return;

    $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
    if ($swapIdx < 0 || $swapIdx >= count($criteria)) return;

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
}
?>