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
 * data_type is what the ANSWER input looks like: text / date / number /
 * score. 'score' is the only type that also carries a GRADE - is_gradeable
 * is DERIVED from data_type (see _deriveGradeable()), never set directly, so
 * the two can never drift apart. A score criterion also carries its own
 * max_range (the grade runs 0..max_range, a double) - two score criteria in
 * the same stage can have different ranges (a /5 and a /10), which is why
 * scoring normalizes each grade against its own criterion's range before
 * weighting them together. See EvaluationScore.php for that arithmetic.
 *
 * The answer (`value`) and the grade (`grade`) are stored as two separate
 * columns on the same evaluation_criteria_value row, so changing a
 * criterion's type away from and back to 'score' never loses either one.
 *
 * Stages and score criteria carry a WEIGHT. Weights are raw user input, not
 * required to sum to anything; EvaluationScore turns them into shares.
 */

include_once(LEGACY_ROOT . '/lib/DatabaseConnection.php');
include_once(LEGACY_ROOT . '/lib/EvaluationScore.php');

class Evaluations
{
    /* What an answer can look like. 'score' is the one type that also grades
     * - see _deriveGradeable(). */
    public static $DATA_TYPES = array('text', 'date', 'number', 'score');

    /* Fallback max_range for a score criterion that predates this column, or
     * whose posted value didn't parse. */
    const DEFAULT_MAX_RANGE = 5;

    private $_db;
    private $_siteID;

    public function __construct($siteID)
    {
        $this->_siteID = (int) $siteID;
        $this->_db = DatabaseConnection::getInstance();
    }

    /* is_gradeable is a pure function of data_type now - 'score' criteria
     * grade, everything else doesn't. Centralised here so addCriteria(),
     * changeCriteriaType(), and seedFromStages() can't disagree with each
     * other about what a given type means. */
    private static function _deriveGradeable($dataType)
    {
        return ($dataType === 'score') ? 1 : 0;
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
    // Rating arrives as a 'score' criterion carrying the full weight, so a
    // brand new stage is immediately scoreable with no extra step - gradeable
    // follows automatically from the type, per _deriveGradeable(). Comments
    // stays plain text.
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

        $this->addCriteria($instanceStageID, 'Rating',   'score', 0,  100, 1, self::DEFAULT_MAX_RANGE);
        $this->addCriteria($instanceStageID, 'Comments', 'text',  99, 0,   0, self::DEFAULT_MAX_RANGE);

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
                    position, weight, max_range
             FROM evaluation_instance_criteria
             WHERE instance_stage_id = %s AND site_id = %s
             ORDER BY position ASC, instance_criteria_id ASC",
            (int) $instanceStageID,
            $this->_siteID
        ));
    }

    /* $isGradeable is accepted but IGNORED - kept only so existing call
     * sites (CandidatesUI::addCriteria command, seedFromStages() below)
     * don't break before they're patched to stop passing it. is_gradeable
     * is always derived from $dataType via _deriveGradeable(). */
    public function addCriteria($instanceStageID, $criteriaName, $dataType = 'text',
                                $position = null, $weight = 0, $isGradeable = 0,
                                $maxRange = self::DEFAULT_MAX_RANGE)
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
                (instance_stage_id, site_id, criteria_name, data_type, is_gradeable,
                 position, weight, max_range)
             VALUES (%s, %s, '%s', '%s', %s, %s, %s, %s)",
            (int) $instanceStageID,
            $this->_siteID,
            $this->_db->escapeString($criteriaName),
            $this->_db->escapeString($dataType),
            self::_deriveGradeable($dataType),
            (int) $position,
            $this->_sanitizeWeight($weight),
            $this->_sanitizeMaxRange($maxRange)
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

    /* Changing the type is the ONLY way is_gradeable moves - switching to
     * 'score' turns grading on, switching away turns it off. No separate
     * checkbox exists anymore. */
    public function changeCriteriaType($instanceCriteriaID, $dataType)
    {
        if (!in_array($dataType, self::$DATA_TYPES))
        {
            return;
        }

        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria
                SET data_type = '%s', is_gradeable = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            $this->_db->escapeString($dataType),
            self::_deriveGradeable($dataType),
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

    /* The ceiling a 'score' criterion's grade runs 0..max_range against.
     * Meaningless on a non-score criterion, but harmless to set - it just
     * sits unused until/unless the type is switched to 'score'. */
    public function setCriteriaMaxRange($instanceCriteriaID, $maxRange)
    {
        $this->_db->query(sprintf(
            "UPDATE evaluation_instance_criteria SET max_range = %s
             WHERE instance_criteria_id = %s AND site_id = %s",
            $this->_sanitizeMaxRange($maxRange),
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
    //
    // Returns the criterion's own data_type/max_range on success (saveCriteriaValue()
    // needs both to validate/store a grade correctly), or false if it doesn't
    // belong to this evaluator.
    private function _criteriaBelongsToEvaluator($evaluatorID, $instanceCriteriaID)
    {
        $rs = $this->_db->getAssoc(sprintf(
            "SELECT eic.instance_criteria_id, eic.data_type, eic.max_range
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
        return (!empty($rs) ? $rs : false);
    }

    /*
     * Update if a row for (evaluator, criterion) exists, insert otherwise.
     * $value and $grade are stored together in one row/one operation, since
     * they're always written for the same criterion at the same time.
     * Returns false if the criterion isn't this evaluator's to write.
     *
     * $grade is validated against THIS criterion's own data_type/max_range
     * (EvaluationScore::parseGrade() - 0..max_range, unanswered stays NULL
     * rather than becoming a 0) and stored regardless of whether the
     * criterion is currently 'score' - harmless if unused, and it means
     * switching the type back to 'score' later doesn't need the grade
     * re-entered.
     */
    public function saveCriteriaValue($evaluatorID, $instanceCriteriaID, $value, $grade = null)
    {
        $criterion = $this->_criteriaBelongsToEvaluator($evaluatorID, $instanceCriteriaID);
        if ($criterion === false)
        {
            return false;
        }

        $maxRange = isset($criterion['max_range']) && is_numeric($criterion['max_range'])
            ? (float) $criterion['max_range'] : self::DEFAULT_MAX_RANGE;

        $grade = EvaluationScore::parseGrade($grade, $maxRange);

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
                ($grade === null ? 'NULL' : sprintf('%.2f', $grade)),
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
                ($grade === null ? 'NULL' : sprintf('%.2f', $grade)),
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
                    data_type, is_gradeable, position, weight, max_range
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
                $stages[$i]['evaluators'][$j]['grades'][$criteriaID] = (float) $row['grade'];
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

                $dataType = isset($criterion['data_type']) ? $criterion['data_type'] : 'text';
                $weight   = isset($criterion['weight'])    ? $criterion['weight']    : 0;
                /* max_range rides across the same way weight does - miss it
                 * here and a seeded /10 criterion silently becomes a /5. */
                $maxRange = isset($criterion['max_range']) ? $criterion['max_range'] : self::DEFAULT_MAX_RANGE;

                /* is_gradeable is NOT copied from the template - it's
                 * re-derived from data_type on this side, same as everywhere
                 * else, so the two can never disagree even if a template row
                 * is somehow stale. */

                /* Keep the template's own ordering on a brand new stage;
                 * append to the end of an existing one. */
                $position = $isNewStage
                    ? (int) $criterion['position']
                    : $this->getNextCriteriaPosition($instanceStageID);

                $this->addCriteria(
                    $instanceStageID, $criterion['criteria_name'],
                    $dataType, $position, $weight, 0, $maxRange
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

    /* max_range must be strictly positive - a 0 or negative range would make
     * every grade on that criterion unparseable (nothing satisfies
     * 0 <= grade <= 0 except a real 0, and dividing by it in scoring blows
     * up). Falls back to DEFAULT_MAX_RANGE rather than silently clamping to
     * some arbitrary minimum. */
    private function _sanitizeMaxRange($maxRange)
    {
        $maxRange = is_numeric($maxRange) ? (float) $maxRange : self::DEFAULT_MAX_RANGE;

        if ($maxRange <= 0)       { $maxRange = self::DEFAULT_MAX_RANGE; }
        if ($maxRange > 9999.99)  { $maxRange = 9999.99; }

        return sprintf('%.2f', $maxRange);
    }
    /* Most recent evaluation for a candidate, regardless of job order.
   getInstancesForCandidateScored() is already newest-first, so this is
   just "give me element 0" with a name that says what it means at the
   call site. Returns null if the candidate has no evaluations. */
public function getMostRecentInstanceScored($candidateID)
{
    $instances = $this->getInstancesForCandidateScored($candidateID);
    return empty($instances) ? null : $instances[0];
}

/* Writes one candidate's full evaluation as CSV: title/candidate/score
   lines, then one block per stage (weight, score, criteria header, one
   row per evaluator). Shared by the single-evaluation export
   (CandidatesUI::onEvaluationExport) and the bulk pipeline export
   (JobOrdersUI::exportPipelineEvaluations) so the two formats can't
   drift apart the way $columnMap did between exportPipeline() and
   getPipelineJobOrder.php. Returns the raw score so callers building a
   summary table don't have to re-score the same instance. */
public function writeInstanceCSV($out, $instanceID, $candidateName)
{
    $instance = $this->getInstance($instanceID);
    $title    = $instance ? $instance['title'] : 'Evaluation';

    $stages  = $this->getFullEvaluation($instanceID);
    $scoring = EvaluationScore::scoreEvaluation($stages);
    $stages  = $scoring['stages'];
fputcsv($out, array('Name', $title));
    fputcsv($out, array('Candidate', $candidateName));
    fputcsv($out, array('Score', EvaluationScore::formatFull($scoring['score'])));
    foreach ($stages as $stage)
    {
        fputcsv($out, array());
        fputcsv($out, array('Stage', $stage['stage_name']));
        fputcsv($out, array('Stage Weight', $stage['weight']));
        fputcsv($out, array('Stage Score', EvaluationScore::format($stage['scoring']['score'])));
        fputcsv($out, array());

        $criteriaHeader = array('Criteria');
        foreach ($stage['criteria'] as $criterion)
        {
            $label = $criterion['is_gradeable'] ? 'score' : 'text';
            $criteriaHeader[] = $criterion['criteria_name'] . ' (' . $label . ')';
        }
        fputcsv($out, $criteriaHeader);

        if (empty($stage['evaluators']))
        {
            continue;
        }

        foreach ($stage['evaluators'] as $evaluator)
        {
            $row = array($evaluator['evaluator_name']);
            foreach ($stage['criteria'] as $criterion)
            {
                $criteriaID = $criterion['instance_criteria_id'];
                $row[] = $criterion['is_gradeable']
                    ? (isset($evaluator['grades'][$criteriaID]) ? $evaluator['grades'][$criteriaID] : '')
                    : (isset($evaluator['values'][$criteriaID]) ? $evaluator['values'][$criteriaID] : '');
            }
            fputcsv($out, $row);
        }
    }

    return $scoring['score'];
}
}
?>