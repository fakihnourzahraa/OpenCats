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

    private $_hireEventRowsCache = null;

    const INTERVIEW_STAGE_FIELD_NAME = 'Interview Stage';
    const CAREER_LEVEL_FIELD_NAME = 'Career Level';


    const PIPELINE_STATUS_PLACED = 800;
    const PIPELINE_STATUS_CLIENT_DECLINED = 700;


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


    private function getFilteredCandidateIDs($filterString)
    {
        if ($filterString === '')
        {
            return array();
        }

        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        error_log('DEBUG filterString: ' . $filterString);
$filteredRows = $pipelines->filterPipelineRows(
    $rows,
    $filterString,
    $this->getOperationalColumnMap(),
    false
);

        $candidateIDs = array();

        foreach ($filteredRows as $row)
        {
            $candidateIDs[(int) $row['candidateID']] = true;
        }

        return array_keys($candidateIDs);
    }

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
        if ($filterString !== '')
{
    $safeCandidateIDs = implode(',', array_map('intval', $candidateIDs));
    $where[] = sprintf("extra_field_history.data_item_id IN (%s)", $safeCandidateIDs);
}

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

    public function getOperationalMetrics($filterString = '')
    {
        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        error_log('DEBUG filterString: ' . $filterString);
$filteredRows = $pipelines->filterPipelineRows(
    $rows,
    $filterString,
    $this->getOperationalColumnMap(),
    false
);

        $candidateIDs = array();
        foreach ($filteredRows as $row)
        {
            if (isset($row['candidateID']))
            {
                $candidateIDs[(int) $row['candidateID']] = true;
            }
        }
        $candidatesCount = count($candidateIDs);
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


    public function getApplicationsByRole($filterString = '')
    {
        $rows = $this->getHireEventRows();

        $pipelines = new Pipelines($this->_siteID);
        error_log('DEBUG filterString: ' . $filterString);
$filteredRows = $pipelines->filterPipelineRows(
    $rows,
    $filterString,
    $this->getOperationalColumnMap(),
    false
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
                    $dateFormat = $_SESSION['CATS']->isDateDMY() ? 'd-m-y' : 'm-d-y';
                $date = DateTime::createFromFormat($dateFormat, $row['dateModified']);

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