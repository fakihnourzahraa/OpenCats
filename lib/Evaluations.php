<?php
/*
 * CATS
 * Evaluations Library
 *
 * The Original Code is "CATS Standard Edition".
 * This file was added for IBC
 *
 * An evaluation belongs to a CANDIDATE only. It owns its own stages and
 * criteria (evaluation_instance_stage / evaluation_instance_criteria), which
 * are COPIED from a job order's template once, at seed time, and are editable
 * afterwards with no effect on the template. Nothing here references
 * evaluation_template / evaluation_stage / evaluation_criteria.
 *
 * Every criterion has TWO independent things:
 *
 *   data_type      what the ANSWER input looks like (text / date / number)
 *   is_gradeable   whether this criterion ALSO carries a 1-5 GRADE
 *
 * They are unrelated - a date criterion can be graded, a text criterion can
 * be graded. The answer (`value`) and the grade (`grade`) are stored as two
 * separate columns on the same evaluation_criteria_value row, so switching
 * the gradeable checkbox off and back on never loses either one.
 *
 * Stages and gradeable criteria carry a WEIGHT. Weights are raw user input,
 * not required to sum to anything; EvaluationScore turns them into shares.
 * See EvaluationScore.php for the full scoring model.
 */

include_once(LEGACY_ROOT . '/lib/DatabaseConnection.php');
include_once(LEGACY_ROOT . '/lib/EvaluationScore.php');

class Evaluations
{
    /* What an answer can look like. Grading is a separate flag
     * (is_gradeable), not a type - see the class doc comment above. */
    public static $DATA_TYPES = array('text', 'date', 'number');

    private $_db;
    private $_siteID;

    public function __construct($siteID)
    {
        $this->_siteID = (int) $siteID;
        $this->_db = DatabaseConnection::getInstance();
    }


    /* ------------------------------------------------------------------ */
    /* Instances                                                          */
    /* ------------------------------------------------------------------ */

    public function getInstance($instanceID)
    {
        $rs = $this->_db->getAssoc(sprintf(
        "SELECT instance_id, candidate_id, title, date_created, date_modified,
                last_seed_job_order_id
         FROM evaluation_instance
         WHERE instance_id = %s AND site_id = %s",
            (int) $instanceID,
            $this->_siteID
        ));
        return (!empty($rs) ? $rs : false);
    }

    public function getInstancesForCandidate($candidateID)
    {
        return $this->_db->getAllAssoc(sprintf(
        "SELECT ei.instance_id, ei.title, ei.date_created, ei.date_modified,
                ei.is_locked, ei.final_opinion,
                (SELECT COUNT(*) FROM evaluation_instance_stage eis
                WHERE eis.instance_id = ei.instance_id) AS stage_count
        FROM evaluation_instance ei
        WHERE ei.candidate_id = %s AND ei.site_id = %s
        ORDER BY ei.instance_id DESC",
            (int) $candidateID,
            $this->_siteID
        ));
    }

    /*
     * Same list, with each row's computed score attached.
     *
     * The score is NOT stored - it is derived on read, every time. That means
     * changing a weight instantly reflows every existing evaluation with no
     * recalculation job and no possibility of a stale number sitting in a
     * column. The cost is one getFullEvaluation() per evaluation, which is
     * four queries each; fine for a candidate's handful of evaluations, and
     * the reason the export builds its own single joined query instead of
     * calling this in a loop.
     */
    public function getInstancesForCandidateScored($candidateID)
    {
        $rows = $this->getInstancesForCandidate($candidateID);

        foreach ($rows as $index => $row)
        {
            $scoring = $this->getScore((int) $row['instance_id']);

            $rows[$index]['score']        = $scoring['score'];
            $rows[$index]['scoreDisplay'] = EvaluationScore::format($scoring['score']);
            $rows[$index]['scorePercent'] = EvaluationScore::formatPercent($scoring['score']);
        }

        return $rows;
    }

    /* Convenience: full scoring result for one evaluation. */
    public function getScore($instanceID)
    {
        return EvaluationScore::scoreEvaluation($this->getFullEvaluation($instanceID));
    }

    public function createInstance($candidateID, $title = 'Evaluation')
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_instance
                (site_id, candidate_id, title, date_created, date_modified)
             VALUES (%s, %s, '%s', NOW(), NOW())",
            $this->_siteID,
            (int) $candidateID,
            $this->_db->escapeString($title)
        ));
        return ($this->_db->getLastInsertID());
    }

    public function renameInstance($instanceID, $title)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance SET title = '%s', date_modified = NOW()
             WHERE instance_id = %s AND site_id = %s",
            $this->_db->escapeString($title),
            (int) $instanceID,
            $this->_siteID
        ));
    }

    public function setFinalOpinion($instanceID, $finalOpinion)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance
                SET final_opinion = '%s', date_modified = NOW()
            WHERE instance_id = %s AND site_id = %s",
            $this->_db->escapeString($finalOpinion),
            (int) $instanceID,
            $this->_siteID
        ));
    }

    public function touchInstance($instanceID)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance SET date_modified = NOW()
             WHERE instance_id = %s AND site_id = %s",
            (int) $instanceID,
            $this->_siteID
        ));
    }

    /* Which job order this evaluation is filed under.
       NULL = unfiled (never seeded, unreachable from the nav dropdowns)
       0    = Generic
       >0   = that job order */
    public function setJobOrderID($instanceID, $jobOrderID)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance SET last_seed_job_order_id = %s
             WHERE instance_id = %s AND site_id = %s",
            ($jobOrderID === null ? 'NULL' : (int) $jobOrderID),
            (int) $instanceID,
            $this->_siteID
        ));
    }

    /* $jobOrderID 0 means "any evaluation, however it was filed" - the Generic
       view. Anything higher restricts to that job order's filing. */
    public function getLatestInstanceIDFor($candidateID, $jobOrderID)
    {
        $filter = ((int) $jobOrderID > 0)
            ? sprintf('AND last_seed_job_order_id = %s', (int) $jobOrderID)
            : '';

        $rs = $this->_db->getAssoc(sprintf(
            "SELECT instance_id FROM evaluation_instance
             WHERE candidate_id = %s AND site_id = %s %s
             ORDER BY instance_id DESC LIMIT 1",
            (int) $candidateID,
            $this->_siteID,
            $filter
        ));
        return (!empty($rs) ? (int) $rs['instance_id'] : false);
    }


    /* candidate_id => true, for the * marker in the navigation dropdown.
       Under Generic (0) that reads "has any evaluation". */
    public function getCandidatesWithEvaluations($jobOrderID)
    {
        $filter = ((int) $jobOrderID > 0)
            ? sprintf('AND last_seed_job_order_id = %s', (int) $jobOrderID)
            : '';

        $rows = $this->_db->getAllAssoc(sprintf(
            "SELECT DISTINCT candidate_id FROM evaluation_instance
             WHERE site_id = %s %s",
            $this->_siteID,
            $filter
        ));

        $map = array();
        foreach ($rows as $row)
        {
            $map[(int) $row['candidate_id']] = true;
        }
        return $map;
    }

    /*
     * FIXED: CandidatesUI::onEvaluationCandidateSearch() calls this name, but
     * only getCandidatesWithEvaluations() existed - so the Generic type-ahead
     * fataled on every keystroke. Same query, both names.
     */
    public function getCandidatesFiledUnder($jobOrderID)
    {
        return $this->getCandidatesWithEvaluations($jobOrderID);
    }

    public function isLocked($instanceID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT is_locked FROM evaluation_instance
             WHERE instance_id = %s AND site_id = %s",
            (int) $instanceID,
            $this->_siteID
        ));
        return (!empty($rs) && (int) $rs['is_locked'] === 1);
    }

    /* Deliberately does NOT touchInstance() - locking isn't a content change,
       and bumping date_modified would make the list misreport last edit. */
    public function setLocked($instanceID, $lockState, $userID)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance
                SET is_locked = %s, locked_by = %s, locked_date = %s
              WHERE instance_id = %s AND site_id = %s",
            ($lockState ? 1 : 0),
            ($lockState ? (int) $userID : 'NULL'),
            ($lockState ? 'NOW()' : 'NULL'),
            (int) $instanceID,
            $this->_siteID
        ));
    }

    // No foreign keys in this schema, so the cascade is done by hand,
    // deepest table first.
    public function deleteInstance($instanceID)
    {
        $stages = $this->getStages($instanceID);
        foreach ($stages as $stage)
        {
            $this->deleteStage($stage['instance_stage_id']);
        }

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_instance
             WHERE instance_id = %s AND site_id = %s",
            (int) $instanceID,
            $this->_siteID
        ));
    }


    /* ------------------------------------------------------------------ */
    /* Stages                                                             */
    /* ------------------------------------------------------------------ */

    public function getStages($instanceID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT instance_stage_id, stage_name, position, weight
             FROM evaluation_instance_stage
             WHERE instance_id = %s AND site_id = %s
             ORDER BY position ASC, instance_stage_id ASC",
            (int) $instanceID,
            $this->_siteID
        ));
    }

    public function getStage($instanceStageID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT instance_stage_id, instance_id, stage_name, position, weight
             FROM evaluation_instance_stage
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $instanceStageID,
            $this->_siteID
        ));
        return (!empty($rs) ? $rs : false);
    }

    // Mirrors EvaluationTemplate::addStage(): every new stage starts with
    // Rating and Comments, Comments pinned last by its high position.
    //
    // Rating arrives gradeable, carrying the full weight, so a brand new
    // stage is immediately scoreable without anyone having to tick a box
    // first. Comments stays plain text and ungradeable.
    public function addStage($instanceID, $stageName, $position = null, $weight = 100)
    {
        if ($position === null)
        {
            $position = $this->getNextStagePosition($instanceID);
        }

        $this->_db->query(sprintf(
            "INSERT INTO evaluation_instance_stage
                (instance_id, site_id, stage_name, position, weight)
             VALUES (%s, %s, '%s', %s, %s)",
            (int) $instanceID,
            $this->_siteID,
            $this->_db->escapeString($stageName),
            (int) $position,
            $this->_sanitizeWeight($weight)
        ));
        $instanceStageID = $this->_db->getLastInsertID();

        $this->addCriteria($instanceStageID, 'Rating',   'text', 0,  100, 1);
        $this->addCriteria($instanceStageID, 'Comments', 'text', 99, 0,   0);

        return ($instanceStageID);
    }

    public function renameStage($instanceStageID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_stage SET stage_name = '%s'
             WHERE instance_stage_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    public function setStageWeight($instanceStageID, $weight)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_stage SET weight = %s
             WHERE instance_stage_id = %s AND site_id = %s",
            $this->_sanitizeWeight($weight),
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    public function deleteStage($instanceStageID)
    {
        /* Values first: they hang off this stage's evaluators. */
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_criteria_value
             WHERE site_id = %s AND evaluator_id IN (
                SELECT evaluator_id FROM (
                    SELECT evaluator_id FROM evaluation_stage_evaluator
                    WHERE instance_stage_id = %s AND site_id = %s
                ) AS t
             )",
            $this->_siteID,
            (int) $instanceStageID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_stage_evaluator
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $instanceStageID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_instance_criteria
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $instanceStageID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_instance_stage
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    public function getNextStagePosition($instanceID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_instance_stage
             WHERE instance_id = %s AND site_id = %s",
            (int) $instanceID,
            $this->_siteID
        ));
        return (($rs && $rs['max_pos'] !== null) ? (int) $rs['max_pos'] + 1 : 0);
    }

    public function moveStage($instanceID, $instanceStageID, $direction)
    {
        $stages = $this->getStages($instanceID);

        $idx = -1;
        foreach ($stages as $i => $s)
        {
            if ((int) $s['instance_stage_id'] === (int) $instanceStageID)
            {
                $idx = $i;
                break;
            }
        }
        if ($idx === -1) return;

        $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapIdx < 0 || $swapIdx >= count($stages)) return;

        $posA = $stages[$idx]['position'];
        $posB = $stages[$swapIdx]['position'];

        /* Equal positions would make the swap a no-op; nudge one apart. */
        if ((int) $posA === (int) $posB)
        {
            $posB = ($direction === 'up') ? $posA - 1 : $posA + 1;
        }

        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_stage SET position = %s
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $posB, (int) $stages[$idx]['instance_stage_id'], $this->_siteID
        ));
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_stage SET position = %s
             WHERE instance_stage_id = %s AND site_id = %s",
            (int) $posA, (int) $stages[$swapIdx]['instance_stage_id'], $this->_siteID
        ));
    }


    /* ------------------------------------------------------------------ */
    /* Criteria                                                           */
    /* ------------------------------------------------------------------ */

    public function getCriteria($instanceStageID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT instance_criteria_id, criteria_name, data_type, is_gradeable,
                    position, weight
             FROM evaluation_instance_criteria
             WHERE instance_stage_id = %s AND site_id = %s
             ORDER BY position ASC, instance_criteria_id ASC",
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    public function addCriteria($instanceStageID, $criteriaName, $dataType = 'text',
                                $position = null, $weight = 0, $isGradeable = 0)
    {
        if (!in_array($dataType, self::$DATA_TYPES))
        {
            $dataType = 'text';
        }

        if ($position === null)
        {
            $position = $this->getNextCriteriaPosition($instanceStageID);
        }

        $this->_db->query(sprintf(
            "INSERT INTO evaluation_instance_criteria
                (instance_stage_id, site_id, criteria_name, data_type, is_gradeable, position, weight)
             VALUES (%s, %s, '%s', '%s', %s, %s, %s)",
            (int) $instanceStageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName),
            $this->_db->escapeString($dataType),
            ($isGradeable ? 1 : 0),
            (int) $position,
            $this->_sanitizeWeight($weight)
        ));
        return ($this->_db->getLastInsertID());
    }

    public function renameCriteria($instanceCriteriaID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET criteria_name = '%s'
             WHERE instance_criteria_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $instanceCriteriaID,
            $this->_siteID
        ));
    }

    public function changeCriteriaType($instanceCriteriaID, $dataType)
    {
        if (!in_array($dataType, self::$DATA_TYPES))
        {
            return;
        }

        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET data_type = '%s'
             WHERE instance_criteria_id = %s AND site_id = %s",
            $this->_db->escapeString($dataType),
            (int) $instanceCriteriaID,
            $this->_siteID
        ));
    }

    public function setCriteriaWeight($instanceCriteriaID, $weight)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET weight = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            $this->_sanitizeWeight($weight),
            (int) $instanceCriteriaID,
            $this->_siteID
        ));
    }

    // The checkbox that decides whether this criterion enters the scoring
    // arithmetic at all. Flipping it off does NOT clear the weight or any
    // grade already saved - only isScored() (EvaluationScore.php) stops
    // reading them, so re-ticking the box restores scoring with whatever was
    // there before.
    public function setCriteriaGradeable($instanceCriteriaID, $isGradeable)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET is_gradeable = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            ($isGradeable ? 1 : 0),
            (int) $instanceCriteriaID,
            $this->_siteID
        ));
    }

    // Deleting a criterion also discards every answer/grade already given for it.
    public function deleteCriteria($instanceCriteriaID)
    {
        $this->_db->query(sprintf(
            "DELETE FROM evaluation_criteria_value
             WHERE instance_criteria_id = %s AND site_id = %s",
            (int) $instanceCriteriaID,
            $this->_siteID
        ));

        $this->_db->query(sprintf(
            "DELETE FROM evaluation_instance_criteria
             WHERE instance_criteria_id = %s AND site_id = %s",
            (int) $instanceCriteriaID,
            $this->_siteID
        ));
    }

    // Comments is excluded so new criteria land before it, not after.
    public function getNextCriteriaPosition($instanceStageID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT MAX(position) AS max_pos FROM evaluation_instance_criteria
             WHERE instance_stage_id = %s AND site_id = %s
               AND criteria_name != 'Comments'",
            (int) $instanceStageID,
            $this->_siteID
        ));
        return (($rs && $rs['max_pos'] !== null) ? (int) $rs['max_pos'] + 1 : 0);
    }

    public function moveCriteria($instanceStageID, $instanceCriteriaID, $direction)
    {
        $criteria = $this->getCriteria($instanceStageID);

        $idx = -1;
        foreach ($criteria as $i => $c)
        {
            if ((int) $c['instance_criteria_id'] === (int) $instanceCriteriaID)
            {
                $idx = $i;
                break;
            }
        }
        if ($idx === -1) return;

        $swapIdx = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapIdx < 0 || $swapIdx >= count($criteria)) return;

        $posA = $criteria[$idx]['position'];
        $posB = $criteria[$swapIdx]['position'];

        if ((int) $posA === (int) $posB)
        {
            $posB = ($direction === 'up') ? $posA - 1 : $posA + 1;
        }

        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET position = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            (int) $posB, (int) $criteria[$idx]['instance_criteria_id'], $this->_siteID
        ));
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET position = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            (int) $posA, (int) $criteria[$swapIdx]['instance_criteria_id'], $this->_siteID
        ));
    }


    /* ------------------------------------------------------------------ */
    /* Evaluators                                                         */
    /* ------------------------------------------------------------------ */

    public function getEvaluatorsForStage($instanceStageID)
    {
        return $this->_db->getAllAssoc(sprintf(
            "SELECT evaluator_id, evaluator_name
             FROM evaluation_stage_evaluator
             WHERE instance_stage_id = %s AND site_id = %s
             ORDER BY evaluator_id ASC",
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    public function addEvaluator($instanceStageID, $evaluatorName)
    {
        $this->_db->query(sprintf(
            "INSERT INTO evaluation_stage_evaluator
                (instance_stage_id, site_id, evaluator_name)
             VALUES (%s, %s, '%s')",
            (int) $instanceStageID,
            $this->_siteID,
            $this->_db->escapeString($evaluatorName)
        ));
        return ($this->_db->getLastInsertID());
    }

    public function renameEvaluator($evaluatorID, $newName)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_stage_evaluator SET evaluator_name = '%s'
             WHERE evaluator_id = %s AND site_id = %s",
            $this->_db->escapeString($newName),
            (int) $evaluatorID,
            $this->_siteID
        ));
    }

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

    // Feeds the autocomplete datalist on the evaluate page.
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

    // Which instance an evaluator ultimately belongs to, or false. Used by the
    // controller to confirm a posted evaluator really belongs to the evaluation
    // named in the URL before writing anything.
    public function getInstanceIDForEvaluator($evaluatorID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT eis.instance_id
             FROM evaluation_stage_evaluator ese
             INNER JOIN evaluation_instance_stage eis
                     ON eis.instance_stage_id = ese.instance_stage_id
             WHERE ese.evaluator_id = %s AND ese.site_id = %s",
            (int) $evaluatorID,
            $this->_siteID
        ));
        return (!empty($rs) ? (int) $rs['instance_id'] : false);
    }


    /* ------------------------------------------------------------------ */
    /* Values / grades                                                    */
    /* ------------------------------------------------------------------ */

    // A criterion is only writable by an evaluator sitting on the SAME stage.
    // Without this check a posted criteria_id could write into another
    // evaluation's criteria, since the IDs are just integers off the form.
    private function _criteriaBelongsToEvaluator($evaluatorID, $instanceCriteriaID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT eic.instance_criteria_id
             FROM evaluation_instance_criteria eic
             INNER JOIN evaluation_stage_evaluator ese
                     ON ese.instance_stage_id = eic.instance_stage_id
             WHERE eic.instance_criteria_id = %s
               AND ese.evaluator_id = %s
               AND eic.site_id = %s",
            (int) $instanceCriteriaID,
            (int) $evaluatorID,
            $this->_siteID
        ));
        return (!empty($rs));
    }

    /* Same blank/non-numeric/out-of-range -> unanswered rule as
       EvaluationScore::parseGrade(), applied here so a garbage value never
       reaches the grade column in the first place. Kept as a private
       duplicate rather than calling parseGrade() directly, because that
       method returns a float for arithmetic and this one needs an int (or
       NULL) for storage - same rule, different return shape. */
    private function _sanitizeGradeForStorage($grade)
    {
        if ($grade === null || $grade === '' || !is_numeric($grade))
        {
            return null;
        }

        $grade = (int) $grade;

        if ($grade < 1 || $grade > 5)
        {
            return null;
        }

        return $grade;
    }

    /*
     * Update if a row for (evaluator, criterion) exists, insert otherwise.
     * $value and $grade are stored together in one row/one operation, since
     * they're always written for the same criterion at the same time.
     * Returns false if the criterion isn't this evaluator's to write.
     *
     * $grade is accepted (and stored) regardless of the criterion's current
     * is_gradeable flag - harmless if unused, and it means re-ticking the
     * checkbox later doesn't need the grade re-entered.
     */
    public function saveCriteriaValue($evaluatorID, $instanceCriteriaID, $value, $grade = null)
    {
        if (!$this->_criteriaBelongsToEvaluator($evaluatorID, $instanceCriteriaID))
        {
            return false;
        }

        $grade = $this->_sanitizeGradeForStorage($grade);

        $rs = $this->_db->getAssoc(sprintf(
            "SELECT value_id FROM evaluation_criteria_value
             WHERE evaluator_id = %s AND instance_criteria_id = %s AND site_id = %s",
            (int) $evaluatorID,
            (int) $instanceCriteriaID,
            $this->_siteID
        ));

        if (!empty($rs))
        {
            $this->_db->query(sprintf(
                "UPDATE evaluation_criteria_value SET value = '%s', grade = %s
                 WHERE value_id = %s AND site_id = %s",
                $this->_db->escapeString($value),
                ($grade === null ? 'NULL' : (int) $grade),
                (int) $rs['value_id'],
                $this->_siteID
            ));
        }
        else
        {
            $this->_db->query(sprintf(
                "INSERT INTO evaluation_criteria_value
                    (evaluator_id, instance_criteria_id, value, grade, site_id)
                 VALUES (%s, %s, '%s', %s, %s)",
                (int) $evaluatorID,
                (int) $instanceCriteriaID,
                $this->_db->escapeString($value),
                ($grade === null ? 'NULL' : (int) $grade),
                $this->_siteID
            ));
        }

        return true;
    }

public function getInstanceIDsFiledUnder($candidateID, $jobOrderID)
{
    $rows = $this->_db->getAllAssoc(sprintf(
        "SELECT instance_id FROM evaluation_instance
         WHERE candidate_id = %s AND site_id = %s AND last_seed_job_order_id = %s",
        (int) $candidateID,
        $this->_siteID,
        (int) $jobOrderID
    ));

    return array_map(function ($row) { return (int) $row['instance_id']; }, $rows);
}


    public function getFullEvaluation($instanceID)
    {
        $stages = $this->getStages($instanceID);
        if (empty($stages))
        {
            return array();
        }

        $stageIDs = array();
        $byStageID = array();
        foreach ($stages as $i => $stage)
        {
            $stages[$i]['criteria']   = array();
            $stages[$i]['evaluators'] = array();

            $stageIDs[] = (int) $stage['instance_stage_id'];
            $byStageID[(int) $stage['instance_stage_id']] = $i;
        }
        $stageIDList = implode(',', $stageIDs);

        /* Criteria for every stage at once. */
        $criteriaRows = $this->_db->getAllAssoc(sprintf(
            "SELECT instance_stage_id, instance_criteria_id, criteria_name,
                    data_type, is_gradeable, position, weight
             FROM evaluation_instance_criteria
             WHERE instance_stage_id IN (%s) AND site_id = %s
             ORDER BY position ASC, instance_criteria_id ASC",
            $stageIDList,
            $this->_siteID
        ));

        foreach ($criteriaRows as $row)
        {
            $i = $byStageID[(int) $row['instance_stage_id']];
            $stages[$i]['criteria'][] = $row;
        }

        /* Evaluators for every stage at once. */
        $evaluatorRows = $this->_db->getAllAssoc(sprintf(
            "SELECT instance_stage_id, evaluator_id, evaluator_name
             FROM evaluation_stage_evaluator
             WHERE instance_stage_id IN (%s) AND site_id = %s
             ORDER BY evaluator_id ASC",
            $stageIDList,
            $this->_siteID
        ));

        if (empty($evaluatorRows))
        {
            return $stages;
        }

        $evaluatorIDs   = array();
        $evaluatorIndex = array();
        foreach ($evaluatorRows as $row)
        {
            $i = $byStageID[(int) $row['instance_stage_id']];

            $stages[$i]['evaluators'][] = array(
                'evaluator_id'   => (int) $row['evaluator_id'],
                'evaluator_name' => $row['evaluator_name'],
                'values'         => array(),
                'grades'         => array()
            );

            $evaluatorIDs[] = (int) $row['evaluator_id'];
            $evaluatorIndex[(int) $row['evaluator_id']] = array(
                $i, count($stages[$i]['evaluators']) - 1
            );
        }

        /* Every saved answer/grade at once. */
        $valueRows = $this->_db->getAllAssoc(sprintf(
            "SELECT evaluator_id, instance_criteria_id, value, grade
             FROM evaluation_criteria_value
             WHERE evaluator_id IN (%s) AND site_id = %s",
            implode(',', $evaluatorIDs),
            $this->_siteID
        ));

        foreach ($valueRows as $row)
        {
            $evaluatorID = (int) $row['evaluator_id'];
            if (!isset($evaluatorIndex[$evaluatorID])) continue;

            list($i, $j) = $evaluatorIndex[$evaluatorID];
            $criteriaID = $row['instance_criteria_id'];

            $stages[$i]['evaluators'][$j]['values'][$criteriaID] = $row['value'];

            if ($row['grade'] !== null)
            {
                $stages[$i]['evaluators'][$j]['grades'][$criteriaID] = (int) $row['grade'];
            }
        }

        return $stages;
    }

    public function seedFromStages($instanceID, $templateStages)
    {
        $added = array('stages' => 0, 'criteria' => 0);

        if (empty($templateStages))
        {
            return $added;
        }

        /* Index the evaluation's existing stages by normalised name. */
        $existingStages = array();
        foreach ($this->getStages($instanceID) as $stage)
        {
            $key = $this->_nameKey($stage['stage_name']);
            $existingStages[$key] = (int) $stage['instance_stage_id'];
        }

        foreach ($templateStages as $templateStage)
        {
            $stageKey = $this->_nameKey($templateStage['stage_name']);

            if (isset($existingStages[$stageKey]))
            {
                $instanceStageID = $existingStages[$stageKey];
                $isNewStage = false;
            }
            else
            {
                /* Insert the stage directly rather than via addStage(), which
                 * would inject its own Rating/Comments and duplicate whatever
                 * the template already defines.
                 *
                 * weight rides across here exactly like stage_name. Omitting it
                 * is the failure mode worth guarding: the evaluation would seed
                 * cleanly, render fine, and score everything at equal weight
                 * with nothing to indicate the template's weights were lost. */
                $this->_db->query(sprintf(
                    "INSERT INTO evaluation_instance_stage
                        (instance_id, site_id, stage_name, position, weight)
                     VALUES (%s, %s, '%s', %s, %s)",
                    (int) $instanceID,
                    $this->_siteID,
                    $this->_db->escapeString($templateStage['stage_name']),
                    $this->getNextStagePosition($instanceID),
                    $this->_sanitizeWeight(
                        isset($templateStage['weight']) ? $templateStage['weight'] : 0
                    )
                ));
                $instanceStageID = $this->_db->getLastInsertID();
                $existingStages[$stageKey] = (int) $instanceStageID;

                $isNewStage = true;
                $added['stages']++;
            }

            if (empty($templateStage['criteria']))
            {
                continue;
            }

            /* Index this stage's existing criteria by normalised name. */
            $existingCriteria = array();
            if (!$isNewStage)
            {
                foreach ($this->getCriteria($instanceStageID) as $criterion)
                {
                    $existingCriteria[$this->_nameKey($criterion['criteria_name'])] = true;
                }
            }

            foreach ($templateStage['criteria'] as $criterion)
            {
                $criteriaKey = $this->_nameKey($criterion['criteria_name']);

                if (isset($existingCriteria[$criteriaKey]))
                {
                    continue;
                }

                $dataType    = isset($criterion['data_type'])    ? $criterion['data_type']    : 'text';
                $weight      = isset($criterion['weight'])       ? $criterion['weight']       : 0;
                $isGradeable = isset($criterion['is_gradeable']) ? $criterion['is_gradeable']  : 0;

                /* Keep the template's own ordering on a brand new stage;
                 * append to the end of an existing one. */
                $position = $isNewStage
                    ? (int) $criterion['position']
                    : $this->getNextCriteriaPosition($instanceStageID);

                $this->addCriteria(
                    $instanceStageID, $criterion['criteria_name'],
                    $dataType, $position, $weight, $isGradeable
                );

                $existingCriteria[$criteriaKey] = true;
                $added['criteria']++;
            }
        }

        $this->touchInstance($instanceID);

        return $added;
    }

    private function _nameKey($name)
    {
        return mb_strtolower(trim($name), 'UTF-8');
    }
    private function _sanitizeWeight($weight)
    {
        $weight = (float) $weight;

        if ($weight < 0)      { $weight = 0; }
        if ($weight > 9999.99) { $weight = 9999.99; }

        return sprintf('%.2f', $weight);
    }
}
?>