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

    /* getHireEventRows() is the shared unfiltered base row set for every
     * operational metric (KPIs, applications-by-role, filter dropdown
     * options, time-in-stage's candidate-ID resolution). All of those
     * can be called in the same request now that filters are wired up
     * page-wide, so the query is memoized here rather than re-run once
     * per caller. Filtering always happens afterward in PHP via
     * filterPipelineRows(), so caching the unfiltered set is safe
     * regardless of which filterString each caller applies. */
    private $_hireEventRowsCache = null;

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
     *
     * @param string $filterString Same Pipelines::filterPipelineRows()
     *        DSL string as getOperationalMetrics()/getTimeInStageData().
     *        Empty string = no filters (full dataset).
     *
     * Filtering is resolved the same way getTimeInStageData() resolves
     * it: reuse getFilteredCandidateIDs() (built from the shared
     * getHireEventRows() base set) to get the distinct candidate IDs
     * whose pipeline entries survive the filter, then scope this
     * method's own Interview-Stage query to just those candidates via
     * candidate_id IN (...). This replaces an earlier version that took
     * a separate 'jobOrderID'/'dateFrom'/'dateTo' array and built its
     * own ad-hoc joins/date range - that shape was never actually
     * DSL-compatible (GraphsUI.php's recruitmentFunnel() action already
     * passed a DSL string here, which would fail on array access), so
     * this brings the method in line with what every caller actually
     * sends.
     */
    public function getRecruitmentFunnelData($filterString = '')
    {
        $stages = $this->resolveExtraFieldOptions(
            self::INTERVIEW_STAGE_FIELD_NAME,
            DATA_ITEM_CANDIDATE
        );

        if (empty($stages))
        {
            return array();
        }

        $candidateIDs = $this->getFilteredCandidateIDs($filterString);

        if ($filterString !== '' && empty($candidateIDs))
        {
            /* Filters applied and nothing matched - don't fall through to
             * an unfiltered query below. */
            return array();
        }

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

        if ($filterString !== '')
        {
            $safeCandidateIDs = implode(',', array_map('intval', $candidateIDs));
            $where[] = sprintf("candidate.candidate_id IN (%s)", $safeCandidateIDs);
        }

        $sql = sprintf(
            "SELECT
                extra_field.value AS stageValue,
                COUNT(DISTINCT candidate.candidate_id) AS candidateCount
             FROM
                candidate
             INNER JOIN
                extra_field ON extra_field.data_item_id = candidate.candidate_id
             WHERE
                %s
             GROUP BY
                extra_field.value",
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
        if ($this->_hireEventRowsCache !== null)
        {
            return $this->_hireEventRowsCache;
        }

        $sql = sprintf(
            "SELECT
                candidate_joborder.candidate_id AS candidateID,
                candidate_joborder.joborder_id AS jobOrderID,
                joborder.title AS jobOrderTitle,
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
             LEFT JOIN joborder
                ON joborder.joborder_id = candidate_joborder.joborder_id
                AND joborder.site_id = %s
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
            $this->_db->makeQueryInteger($this->_siteID),
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

        $this->_hireEventRowsCache = $this->_db->getAllAssoc($sql);

        return $this->_hireEventRowsCache;
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
     *   'overallAcceptanceRate' => [ 'rate' => float|null, 'placedCount' => int, 'candidatesCount' => int ],
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

        /* Whole-process conversion: placed as a fraction of every
         * pipeline entry, not just of the ones that reached an offer
         * decision. Distinct from offerAcceptanceRate above, which only
         * looks at placed-vs-declined once an offer was actually made -
         * this one reflects the full funnel, including candidates who
         * never made it to an offer at all. */
        $overallAcceptanceRate = null;

        if ($candidatesCount > 0)
        {
            $overallAcceptanceRate = round(($placedCount / $candidatesCount) * 100, 1);
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
            'candidatesCount'        => $candidatesCount,
            'timeToHire'             => array(
                'averageDays' => $averageDaysToHire,
                'hiredCount'  => count($hiredDurations)
            ),
            'overallAcceptanceRate'  => array(
                'rate'            => $overallAcceptanceRate,
                'placedCount'     => $placedCount,
                'candidatesCount' => $candidatesCount
            ),
            'offerAcceptanceRate'    => array(
                'rate'          => $offerAcceptanceRate,
                'placedCount'   => $placedCount,
                'declinedCount' => $declinedCount
            ),
            'sourceOfHire'           => $sourceOfHire
        );
    }

    /**
     * Total applications (pipeline entries) broken down by role/job
     * order, sorted by count descending. Same base row set and filter
     * mechanism as getOperationalMetrics() (Option A - reuse
     * filterPipelineRows() rather than a separate GROUP BY query), just
     * bucketed differently: instead of computing hire/time/source
     * metrics from the filtered rows, this just counts rows per
     * jobOrderID.
     *
     * A pipeline entry whose job order row no longer exists (orphaned
     * candidate_joborder row) has a null jobOrderTitle - those are
     * bucketed under 'Unknown Role' rather than silently dropped, so the
     * per-role total still reconciles with candidatesCount.
     *
     * @param string $filterString Same filterPipelineRows() DSL string
     *        as getOperationalMetrics(). Empty string = no filters.
     *
     * @return array of [ 'jobOrderID' => int, 'role' => string, 'count' => int ]
     */
    public function getApplicationsByRole($filterString = '')
    {
        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        $filteredRows = $pipelines->filterPipelineRows(
            $rows,
            $filterString,
            $this->getOperationalColumnMap()
        );

        $countsByRole = array();

        foreach ($filteredRows as $row)
        {
            $jobOrderID = (int) $row['jobOrderID'];
            $role = ($row['jobOrderTitle'] !== null && $row['jobOrderTitle'] !== '')
                ? $row['jobOrderTitle']
                : 'Unknown Role';

            if (!isset($countsByRole[$jobOrderID]))
            {
                $countsByRole[$jobOrderID] = array(
                    'jobOrderID' => $jobOrderID,
                    'role'       => $role,
                    'count'      => 0
                );
            }

            $countsByRole[$jobOrderID]['count']++;
        }

        $result = array_values($countsByRole);

        usort($result, function($a, $b) {
            return $b['count'] - $a['count'];
        });

        return $result;
    }

    /**
     * Dropdown option lists for the 8 operational filters, so the filter
     * form only ever shows values that actually occur in the current
     * (unfiltered) dataset rather than a hardcoded/admin-wide list that
     * might not match reality.
     *
     * - owners/jobOrders/sources: derived from the same base row set as
     *   every other metric here, so there's no separate query and no
     *   risk of the dropdown drifting from what filterPipelineRows() can
     *   actually match against.
     * - careerLevels: reuses resolveExtraFieldOptions() for admin-defined
     *   order, same as the funnel's Interview Stage options.
     * - statuses: reuses Pipelines::getStatuses() rather than deriving
     *   from rows, so statuses with zero current candidates still show
     *   up as pickable (a recruiter filtering "show me Placed" should
     *   see that option even between placements).
     * - dateModifiedPeriods: Year/Quarter/Month options derived from the
     *   distinct dateModified values in the data (same "only show what
     *   actually occurs" principle), each newest-first. Each option's
     *   'value' is "type:value" (e.g. "quarter:2026-Q3", "year:2026",
     *   "month:2026-08") so the filter form's single dropdown can carry
     *   all three under one field name, and the controller can recover
     *   which type it is by splitting on the first colon.
     *
     * @return array [
     *   'owners'             => [ string, ... ],
     *   'jobOrders'          => [ jobOrderID => title, ... ],
     *   'sources'            => [ string, ... ],
     *   'careerLevels'       => [ string, ... ],
     *   'statuses'           => [ [ 'statusID', 'status', ... ], ... ],
     *   'dateModifiedPeriods' => [
     *     'years'    => [ [ 'value', 'label' ], ... ],
     *     'quarters' => [ [ 'value', 'label' ], ... ],
     *     'months'   => [ [ 'value', 'label' ], ... ]
     *   ]
     * ]
     */
    public function getFilterOptions()
    {
        $rows = $this->getHireEventRows();

        $owners = array();
        $jobOrders = array();
        $sources = array();
        $years = array();
        $quarters = array();
        $months = array();

        foreach ($rows as $row)
        {
            if (!empty($row['owner']) && trim($row['owner']) !== '')
            {
                $owners[$row['owner']] = true;
            }

            if (!empty($row['jobOrderID']))
            {
                $title = ($row['jobOrderTitle'] !== null && $row['jobOrderTitle'] !== '')
                    ? $row['jobOrderTitle']
                    : 'Unknown Role';
                $jobOrders[(int) $row['jobOrderID']] = $title;
            }

            if (!empty($row['source']))
            {
                $sources[$row['source']] = true;
            }

            if (!empty($row['dateModified']))
            {
                $date = DateTime::createFromFormat('m-d-y', $row['dateModified']);

                if ($date !== false)
                {
                    $year = (int) $date->format('Y');
                    $month = (int) $date->format('n');
                    $quarter = (int) ceil($month / 3);

                    $years[$year] = array(
                        'value' => 'year:' . $year,
                        'label' => (string) $year
                    );
                    $quarterKey = sprintf('%d-Q%d', $year, $quarter);
                    $quarters[$quarterKey] = array(
                        'value' => 'quarter:' . $quarterKey,
                        'label' => sprintf('Q%d %d', $quarter, $year)
                    );
                    $monthKey = sprintf('%d-%02d', $year, $month);
                    $months[$monthKey] = array(
                        'value' => 'month:' . $monthKey,
                        'label' => $date->format('F Y')
                    );
                }
            }
        }

        ksort($owners);
        asort($jobOrders);
        ksort($sources);

        /* Newest first - krsort on the numeric/zero-padded keys sorts
         * chronologically since every key is uniformly-widthed
         * (4-digit year, so "2026-Q3" > "2025-Q4" compares correctly
         * as a plain string). */
        krsort($years);
        krsort($quarters);
        krsort($months);

        $pipelines = new Pipelines($this->_siteID);
        $statuses = $pipelines->getStatuses();

        $careerLevels = $this->resolveExtraFieldOptions(
            self::CAREER_LEVEL_FIELD_NAME,
            DATA_ITEM_CANDIDATE
        );

        return array(
            'owners'              => array_keys($owners),
            'jobOrders'           => $jobOrders,
            'sources'             => array_keys($sources),
            'careerLevels'        => $careerLevels,
            'statuses'            => $statuses,
            'dateModifiedPeriods' => array(
                'years'    => array_values($years),
                'quarters' => array_values($quarters),
                'months'   => array_values($months)
            )
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
     * @param string $filterString Same Pipelines::filterPipelineRows()
     *        DSL string as every other operational method here. Empty
     *        string = no filters (full dataset).
     */
    public function getFunnelEffectiveness($filterString = '')
    {
        $funnel = $this->getRecruitmentFunnelData($filterString);
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