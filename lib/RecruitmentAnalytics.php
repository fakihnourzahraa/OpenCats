<?php
/**
 * RecruitmentAnalytics.php
 * Added for IBC
 */

include_once(LEGACY_ROOT . '/lib/Pipelines.php');

class RecruitmentAnalytics
{
    private $_db;
    private $_siteID;

    const INTERVIEW_STAGE_FIELD_NAME = 'Interview Stage';
    const CAREER_LEVEL_FIELD_NAME = 'Career Level';

    /* candidate_joborder_status IDs, confirmed against this install's
     * live candidate_joborder_status table. Not defined as constants
     * anywhere else in the codebase, so defined here.
     */
    const PIPELINE_STATUS_PLACED = 800;
    const PIPELINE_STATUS_CLIENT_DECLINED = 700;

    /**
     * Column map for Pipelines::filterPipelineRows(). Keys are the filter
     * names the operational dashboard's filter UI is expected to emit;
     * values are the array keys used in the row sets built below.
     * ASSUMPTION: the filter UI will emit filter strings using these
     * exact key names (e.g. "owner=~john,jobOrder==482,..."). Confirm
     * against whatever generates the filter string before wiring the UI.
     * (Not a class const array — kept as a method for compatibility with
     * older PHP, matching the rest of this codebase's conventions.)
     */
    private function getOperationalColumnMap()
    {
        return array(
            'dateModified'  => 'dateModified',
            'owner'         => 'owner',
            'jobOrder'      => 'jobOrderID',
            'careerLevel'   => 'careerLevel',
            'source'        => 'source',
            'status'        => 'status',
            'dateAvailable' => 'dateAvailable'
        );
    }

    public function __construct($siteID)
    {
        $this->_siteID = $siteID;
        $this->_db = DatabaseConnection::getInstance();
    }

    /**
     * Given an extra field's name and the data item type
     * returns the field's options in admin-defined order
     */
    public function resolveExtraFieldOptions($fieldName, $dataItemType)
    {
        $sql = sprintf(
            "SELECT
                extra_field_options
             FROM
                extra_field_settings
             WHERE
                field_name = %s
             AND
                data_item_type = %s
             AND
                site_id = %s",
            $this->_db->makeQueryString($fieldName),
            $this->_db->makeQueryInteger($dataItemType),
            $this->_db->makeQueryInteger($this->_siteID)
        );

        $rs = $this->_db->getAssoc($sql);

        if (empty($rs['extra_field_options']))
        {
            return array();
        }

        $rawOptions = explode(',', $rs['extra_field_options']);
        $options = array();

        foreach ($rawOptions as $raw)
        {
            $decoded = urldecode(trim($raw));

            if ($decoded !== '')
            {
                $options[] = $decoded;
            }
        }

        return $options;
    }

    /**
     * [ 'stage' => string, 'count' => int, 'percentOfPrevious' => float|null ]
     */
    public function getRecruitmentFunnelData($filters = array())
    {
        $stages = $this->resolveExtraFieldOptions(
            self::INTERVIEW_STAGE_FIELD_NAME,
            DATA_ITEM_CANDIDATE
        );

        if (empty($stages))
        {
            return array();
        }

        $joins = array();
        $where = array();

        $where[] = sprintf(
            "extra_field.field_name = %s",
            $this->_db->makeQueryString(self::INTERVIEW_STAGE_FIELD_NAME)
        );
        $where[] = sprintf(
            "extra_field.data_item_type = %s",
            $this->_db->makeQueryInteger(DATA_ITEM_CANDIDATE)
        );
        $where[] = sprintf(
            "extra_field.site_id = %s",
            $this->_db->makeQueryInteger($this->_siteID)
        );
        $where[] = "extra_field.value != ''";

        if (!empty($filters['jobOrderID']))
        {
            $joins[] = "INNER JOIN candidate_joborder_status ON
                            candidate_joborder_status.candidate_id = candidate.candidate_id";
            $where[] = sprintf(
                "candidate_joborder_status.joborder_id = %s",
                $this->_db->makeQueryInteger($filters['jobOrderID'])
            );
        }

        if (!empty($filters['dateFrom']))
        {
            $where[] = sprintf(
                "candidate.date_modified >= %s",
                $this->_db->makeQueryString($filters['dateFrom'] . ' 00:00:00')
            );
        }

        if (!empty($filters['dateTo']))
        {
            $where[] = sprintf(
                "candidate.date_modified <= %s",
                $this->_db->makeQueryString($filters['dateTo'] . ' 23:59:59')
            );
        }

        $sql = sprintf(
            "SELECT
                extra_field.value AS stageValue,
                COUNT(DISTINCT candidate.candidate_id) AS candidateCount
             FROM
                candidate
             INNER JOIN
                extra_field ON extra_field.data_item_id = candidate.candidate_id
             %s
             WHERE
                %s
             GROUP BY
                extra_field.value",
            implode(' ', array_unique($joins)),
            implode(' AND ', $where)
        );

        $rs = $this->_db->getAllAssoc($sql);
        $countsByStage = array_fill_keys($stages, 0);

        foreach ($rs as $row)
        {
            $value = urldecode(trim($row['stageValue']));

            if (isset($countsByStage[$value]))
            {
                $countsByStage[$value] += (int) $row['candidateCount'];
            }
        }

        $cumulative = 0;
        $cumulativeByStage = array();

        foreach (array_reverse($stages) as $stage)
        {
            $cumulative += $countsByStage[$stage];
            $cumulativeByStage[$stage] = $cumulative;
        }

        $cumulativeByStage = array_reverse($cumulativeByStage, true);

        $result = array();
        $previousCount = null;

        foreach ($cumulativeByStage as $stage => $count)
        {
            $percentOfPrevious = null;

            if ($previousCount !== null && $previousCount > 0)
            {
                $percentOfPrevious = round(($count / $previousCount) * 100, 1);
            }

            $result[] = array(
                'stage'             => $stage,
                'count'             => $count,
                'percentOfPrevious' => $percentOfPrevious
            );

            $previousCount = $count;
        }

        return $result;
    }

    /**
     * Resolves a filterPipelineRows() DSL string to the distinct set of
     * candidate IDs whose pipeline entries survive it. Shared by
     * getTimeInStageData() so it can filter without duplicating
     * extra_field_history rows per job order (see getTimeInStageData()'s
     * docblock for why).
     *
     * @return array of int candidate IDs. Empty array + $filterString
     *         === '' means "no filtering, use all candidates" - callers
     *         must check $filterString, not just emptiness of the result.
     */
    private function getFilteredCandidateIDs($filterString)
    {
        if ($filterString === '')
        {
            return array();
        }

        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        $filteredRows = $pipelines->filterPipelineRows(
            $rows,
            $filterString,
            $this->getOperationalColumnMap()
        );

        $candidateIDs = array();

        foreach ($filteredRows as $row)
        {
            $candidateIDs[(int) $row['candidateID']] = true;
        }

        return array_keys($candidateIDs);
    }

    /**
     * Time-in-stage report, derived from extra_field_history (a diff log,
     * not an interval table). For each candidate's ordered transitions:
     *
     *   - Each row's new_value is the stage the candidate ENTERED at that
     *     row's set_date.
     *   - Duration in that stage = next row's set_date minus this row's
     *     set_date.
     *   - The candidate's most recent row is still "open": duration-so-far
     *     = NOW() minus its set_date, and it's excluded from the average
     *     (it hasn't finished) but reported separately as currentlyInStage.
     *   - A candidate's very first previous_value has no known entry date
     *     (we don't know when they entered that earlier stage), so it is
     *     never used to compute a duration — only new_value entries are.
     *
     * Returns:
     * [
     *   'aggregate' => [
     *     [ 'stage', 'averageDays', 'completedCount', 'currentlyInStage' ], ...
     *   ],
     *   'perCandidate' => [
     *     [ 'candidateID', 'stages' => [
     *         [ 'stage', 'enteredDate', 'exitedDate', 'days', 'isOpen' ], ...
     *     ] ], ...
     *   ]
     * ]
     *
     * @param string $filterString Pipelines::filterPipelineRows() DSL
     *        string, same 8 operational filters as getOperationalMetrics()
     *        (dateModified/owner/jobOrder/careerLevel/source/status/
     *        dateAvailable). Empty string = no filters (full dataset).
     *
     * Filtering is resolved in two steps rather than joining
     * extra_field_history directly to candidate_joborder: a candidate can
     * have multiple pipeline entries (multiple job orders), and joining
     * the history table straight to candidate_joborder would duplicate
     * each history row once per matching job order, inflating the
     * duration averages. Instead: (1) reuse getHireEventRows() - the same
     * per-pipeline-entry base rows getOperationalMetrics() uses - filter
     * those, and reduce to the distinct set of candidate IDs whose
     * pipeline entries survive the filter; (2) fetch each of those
     * candidates' full extra_field_history normally (unchanged from
     * before) and run the existing per-candidate delta logic untouched.
     */
    public function getTimeInStageData($filterString = '')
    {
        $stages = $this->resolveExtraFieldOptions(
            self::INTERVIEW_STAGE_FIELD_NAME,
            DATA_ITEM_CANDIDATE
        );

        $candidateIDs = $this->getFilteredCandidateIDs($filterString);

        if ($filterString !== '' && empty($candidateIDs))
        {
            /* Filters applied and nothing matched - don't fall through to
             * an unfiltered query below. */
            return array(
                'aggregate'    => array(),
                'perCandidate' => array()
            );
        }

        $joins = array();
        $where = array();

        $where[] = sprintf(
            "extra_field_history.the_field = %s",
            $this->_db->makeQueryString(self::INTERVIEW_STAGE_FIELD_NAME)
        );
        $where[] = sprintf(
            "extra_field_history.data_item_type = %s",
            $this->_db->makeQueryInteger(DATA_ITEM_CANDIDATE)
        );
        $where[] = sprintf(
            "extra_field_history.site_id = %s",
            $this->_db->makeQueryInteger($this->_siteID)
        );

        $sql = sprintf(
            "SELECT
                extra_field_history.data_item_id AS candidateID,
                extra_field_history.previous_value AS previousValue,
                extra_field_history.new_value AS newValue,
                extra_field_history.set_date AS setDate
             FROM
                extra_field_history
             %s
             WHERE
                %s
             ORDER BY
                extra_field_history.data_item_id ASC,
                extra_field_history.set_date ASC",
            implode(' ', array_unique($joins)),
            implode(' AND ', $where)
        );

        $rs = $this->_db->getAllAssoc($sql);

        // Group rows by candidate, preserving the oldest-first order
        // within each candidate (guaranteed by the ORDER BY above).
        $rowsByCandidate = array();

        foreach ($rs as $row)
        {
            $candidateID = (int) $row['candidateID'];

            if (!isset($rowsByCandidate[$candidateID]))
            {
                $rowsByCandidate[$candidateID] = array();
            }

            $rowsByCandidate[$candidateID][] = array(
                'previousValue' => urldecode(trim($row['previousValue'])),
                'newValue'      => urldecode(trim($row['newValue'])),
                'setDate'       => $row['setDate']
            );
        }

        $now = time();
        $perCandidate = array();
        $durationsByStage = array_fill_keys($stages, array());
        $openCountByStage = array_fill_keys($stages, 0);

        foreach ($rowsByCandidate as $candidateID => $rows)
        {
            $candidateStages = array();
            $rowCount = count($rows);

            for ($i = 0; $i < $rowCount; $i++)
            {
                $stage = $rows[$i]['newValue'];
                $enteredDate = $rows[$i]['setDate'];
                $isOpen = ($i === $rowCount - 1);

                if ($isOpen)
                {
                    $exitedDate = null;
                    $days = round((($now - strtotime($enteredDate)) / 86400), 1);
                }
                else
                {
                    $exitedDate = $rows[$i + 1]['setDate'];
                    $days = round(((strtotime($exitedDate) - strtotime($enteredDate)) / 86400), 1);
                }

                $candidateStages[] = array(
                    'stage'       => $stage,
                    'enteredDate' => $enteredDate,
                    'exitedDate'  => $exitedDate,
                    'days'        => $days,
                    'isOpen'      => $isOpen
                );

                if (isset($durationsByStage[$stage]))
                {
                    if ($isOpen)
                    {
                        $openCountByStage[$stage]++;
                    }
                    else
                    {
                        $durationsByStage[$stage][] = $days;
                    }
                }
            }

            $perCandidate[] = array(
                'candidateID' => $candidateID,
                'stages'      => $candidateStages
            );
        }

        $aggregate = array();

        foreach ($stages as $stage)
        {
            $completedDurations = $durationsByStage[$stage];
            $averageDays = null;

            if (!empty($completedDurations))
            {
                $averageDays = round(array_sum($completedDurations) / count($completedDurations), 1);
            }

            $aggregate[] = array(
                'stage'            => $stage,
                'averageDays'      => $averageDays,
                'completedCount'   => count($completedDurations),
                'currentlyInStage' => $openCountByStage[$stage]
            );
        }

        return array(
            'aggregate'    => $aggregate,
            'perCandidate' => $perCandidate
        );
    }

    /**
     * Fetches one row per candidate_joborder (pipeline entry), with every
     * column the 8 operational filters need, plus whichever of Placed
     * (800) / Client Declined (700) is that pipeline entry's MOST RECENT
     * hire-relevant status transition (or neither, if it hasn't reached
     * one yet).
     *
     * This is the single shared base dataset for getOperationalMetrics().
     * Unfiltered — filtering happens afterward via
     * Pipelines::filterPipelineRows() so all 3 derived metrics
     * (time to hire, offer acceptance rate, source of hire) share one
     * fetch instead of three separate filtered queries.
     *
     * Dates are formatted m-d-y to match what filterPipelineRows()
     * already expects for date-type columns (see its dateModified
     * handling), plus a parallel UNIX_TIMESTAMP column for each date so
     * duration math doesn't need to re-parse the formatted string.
     */
    private function getHireEventRows()
    {
        $sql = sprintf(
            "SELECT
                candidate_joborder.candidate_id AS candidateID,
                candidate_joborder.joborder_id AS jobOrderID,
                UNIX_TIMESTAMP(candidate_joborder.date_created) AS dateCreatedInt,
                DATE_FORMAT(
                    candidate.date_modified, '%%m-%%d-%%y'
                ) AS dateModified,
                CONCAT(
                    owner_user.first_name, ' ', owner_user.last_name
                ) AS owner,
                candidate.source AS source,
                candidate_joborder_status.short_description AS status,
                DATE_FORMAT(
                    candidate.date_available, '%%m-%%d-%%y'
                ) AS dateAvailable,
                career_level.value AS careerLevel,
                hire_history.statusToID AS hireStatusToID,
                UNIX_TIMESTAMP(hire_history.hireDate) AS hireDateInt
             FROM
                candidate_joborder
             INNER JOIN candidate
                ON candidate.candidate_id = candidate_joborder.candidate_id
             LEFT JOIN user AS owner_user
                ON candidate.owner = owner_user.user_id
             LEFT JOIN candidate_joborder_status
                ON candidate_joborder.status = candidate_joborder_status.candidate_joborder_status_id
             LEFT JOIN extra_field AS career_level
                ON career_level.data_item_id = candidate.candidate_id
                AND career_level.field_name = %s
                AND career_level.data_item_type = %s
                AND career_level.site_id = %s
             LEFT JOIN (
                SELECT
                    h1.candidate_id,
                    h1.joborder_id,
                    h1.status_to AS statusToID,
                    h1.date AS hireDate
                FROM
                    candidate_joborder_status_history h1
                INNER JOIN (
                    SELECT
                        candidate_id,
                        joborder_id,
                        MAX(date) AS maxDate
                    FROM
                        candidate_joborder_status_history
                    WHERE
                        status_to IN (%s, %s)
                    AND
                        site_id = %s
                    GROUP BY
                        candidate_id, joborder_id
                ) latest
                    ON latest.candidate_id = h1.candidate_id
                    AND latest.joborder_id = h1.joborder_id
                    AND latest.maxDate = h1.date
                WHERE
                    h1.status_to IN (%s, %s)
             ) AS hire_history
                ON hire_history.candidate_id = candidate_joborder.candidate_id
                AND hire_history.joborder_id = candidate_joborder.joborder_id
             WHERE
                candidate_joborder.site_id = %s
             AND
                candidate.site_id = %s",
            $this->_db->makeQueryString(self::CAREER_LEVEL_FIELD_NAME),
            $this->_db->makeQueryInteger(DATA_ITEM_CANDIDATE),
            $this->_db->makeQueryInteger($this->_siteID),
            $this->_db->makeQueryInteger(self::PIPELINE_STATUS_CLIENT_DECLINED),
            $this->_db->makeQueryInteger(self::PIPELINE_STATUS_PLACED),
            $this->_db->makeQueryInteger($this->_siteID),
            $this->_db->makeQueryInteger(self::PIPELINE_STATUS_CLIENT_DECLINED),
            $this->_db->makeQueryInteger(self::PIPELINE_STATUS_PLACED),
            $this->_db->makeQueryInteger($this->_siteID),
            $this->_db->makeQueryInteger($this->_siteID)
        );

        return $this->_db->getAllAssoc($sql);
    }

    /**
     * Candidates count (total pipeline entries), time to hire, offer
     * acceptance rate, and source of hire — all derived from one shared,
     * filtered base row set.
     *
     * @param string $filterString Pipelines::filterPipelineRows() DSL
     *        string, e.g. "owner=~jane,jobOrder==482". Empty string = no
     *        filters applied (full dataset).
     *
     * Returns:
     * [
     *   'candidatesCount'    => int,
     *   'timeToHire'         => [ 'averageDays' => float|null, 'hiredCount' => int ],
     *   'offerAcceptanceRate' => [ 'rate' => float|null, 'placedCount' => int, 'declinedCount' => int ],
     *   'sourceOfHire'       => [ [ 'source', 'hiredCount', 'percentOfHires' ], ... ]
     * ]
     */
    public function getOperationalMetrics($filterString = '')
    {
        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        $filteredRows = $pipelines->filterPipelineRows(
            $rows,
            $filterString,
            $this->getOperationalColumnMap()
        );

        $candidatesCount = count($filteredRows);

        $hiredDurations = array();
        $placedCount = 0;
        $declinedCount = 0;
        $hiresBySource = array();

        foreach ($filteredRows as $row)
        {
            if ((int) $row['hireStatusToID'] === self::PIPELINE_STATUS_PLACED)
            {
                $placedCount++;

                if (!empty($row['hireDateInt']) && !empty($row['dateCreatedInt']))
                {
                    $days = round(
                        (($row['hireDateInt'] - $row['dateCreatedInt']) / 86400),
                        1
                    );
                    $hiredDurations[] = $days;
                }

                $source = ($row['source'] !== null && $row['source'] !== '')
                    ? $row['source']
                    : 'Unknown';

                if (!isset($hiresBySource[$source]))
                {
                    $hiresBySource[$source] = 0;
                }

                $hiresBySource[$source]++;
            }
            else if ((int) $row['hireStatusToID'] === self::PIPELINE_STATUS_CLIENT_DECLINED)
            {
                $declinedCount++;
            }
        }

        $averageDaysToHire = null;

        if (!empty($hiredDurations))
        {
            $averageDaysToHire = round(
                array_sum($hiredDurations) / count($hiredDurations),
                1
            );
        }

        $offerAcceptanceRate = null;
        $offerTotal = $placedCount + $declinedCount;

        if ($offerTotal > 0)
        {
            $offerAcceptanceRate = round(($placedCount / $offerTotal) * 100, 1);
        }

        $sourceOfHire = array();

        foreach ($hiresBySource as $source => $hiredCount)
        {
            $percentOfHires = ($placedCount > 0)
                ? round(($hiredCount / $placedCount) * 100, 1)
                : null;

            $sourceOfHire[] = array(
                'source'         => $source,
                'hiredCount'     => $hiredCount,
                'percentOfHires' => $percentOfHires
            );
        }

        return array(
            'candidatesCount'     => $candidatesCount,
            'timeToHire'          => array(
                'averageDays' => $averageDaysToHire,
                'hiredCount'  => count($hiredDurations)
            ),
            'offerAcceptanceRate' => array(
                'rate'          => $offerAcceptanceRate,
                'placedCount'   => $placedCount,
                'declinedCount' => $declinedCount
            ),
            'sourceOfHire'        => $sourceOfHire
        );
    }

    /**
     * Recruitment funnel effectiveness — thin passthrough, not new logic.
     * getRecruitmentFunnelData() already computes stage-to-stage
     * conversion as 'percentOfPrevious'; this just reshapes that into
     * the 'stage' + 'conversionRate' pairing the operational dashboard
     * asked for, so callers don't need to know the funnel method's
     * internal field names.
     *
     * Uses the same $filters array as getRecruitmentFunnelData()
     * ('jobOrderID', 'dateFrom', 'dateTo') — NOT the filterPipelineRows()
     * DSL string used by getOperationalMetrics(), since this stays
     * Interview-Stage-scoped and was never moved onto the shared
     * candidate_joborder base set.
     */
    public function getFunnelEffectiveness($filters = array())
    {
        $funnel = $this->getRecruitmentFunnelData($filters);
        $effectiveness = array();

        foreach ($funnel as $stageRow)
        {
            $effectiveness[] = array(
                'stage'          => $stageRow['stage'],
                'count'          => $stageRow['count'],
                'conversionRate' => $stageRow['percentOfPrevious']
            );
        }

        return $effectiveness;
    }
}

?>