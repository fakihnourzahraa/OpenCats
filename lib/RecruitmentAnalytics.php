<?php
/**
 * CATS
 * Recruitment Analytics Library
 *
 * New library, not part of the original CATS distribution.
 * Houses the recruitment funnel (and future analytics) query logic.
 * Meant to be called from a new dedicated module, reusing Pipelines.php's
 * filterPipelineRows() for combinable filters once that wiring is added.
 *
 * @package    CATS
 * @subpackage Library
 */

class RecruitmentAnalytics
{
    private $_db;
    private $_siteID;

    /**
     * The one and only hardcoded name in this file. Everything else about
     * the funnel (option list, order, bucket matching) is resolved live
     * from extra_field_settings / extra_field at query time.
     */
    const INTERVIEW_STAGE_FIELD_NAME = 'Interview Stage';

    public function __construct($siteID)
    {
        $this->_siteID = $siteID;
        $this->_db = DatabaseConnection::getInstance();
    }

    /**
     * Generic resolver: given an extra field's name and the data item type
     * it belongs to (DATA_ITEM_CANDIDATE = 100, or a job order type once
     * those fields exist), returns the field's options in admin-defined
     * order, decoded, with the leading blank/unassigned entry dropped.
     *
     * This is the one function every extra-field-based filter (Department,
     * Office, Country, Employment Type, Career Level, Interview Stage...)
     * should go through. Add/reorder an option in Settings and this
     * reflects it immediately, no code change required.
     *
     * @param string  $fieldName
     * @param integer $dataItemType
     * @return array ordered list of option strings (decoded, no blank entry)
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
            // extra_field_options is stored comma-separated, +-encoded
            // (urlencode style). The leading entry is the blank/unassigned
            // state ("-- Select --") and is intentionally dropped here,
            // not treated as a real stage.
            $decoded = urldecode(trim($raw));

            if ($decoded !== '')
            {
                $options[] = $decoded;
            }
        }

        return $options;
    }

    /**
     * Builds the cumulative recruitment funnel.
     *
     * Funnel definition (confirmed): count at stage N = candidates
     * currently at stage N + all candidates at any later stage in the
     * field's option order. Rejected/withdrawn candidates are included
     * at their last stage by default - this method does not filter on
     * candidate.status at all; that's left to the Status filter.
     *
     * @param array $filters {
     *     @type integer $jobOrderID  optional - restrict to one job order's pipeline
     *     @type string  $dateFrom    optional - candidate.date_modified >= this (Y-m-d)
     *     @type string  $dateTo      optional - candidate.date_modified <= this (Y-m-d)
     * }
     *     Additional filters (Recruiter, Department, Office, Country,
     *     Position, Employment Type, Source, Status, Availability,
     *     Career Level) are intentionally not wired in yet - they belong
     *     in Pipelines.php's filterPipelineRows() infrastructure once
     *     that's plugged in here, rather than being reimplemented ad hoc.
     *
     * @return array ordered list of:
     *     [ 'stage' => string, 'count' => int, 'percentOfPrevious' => float|null ]
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

        /* Bucket raw counts by stage. Values in extra_field.value are
         * compared urldecoded on both sides defensively, since we've
         * only confirmed the *settings* table stores +-encoded option
         * strings - not yet confirmed whether saved candidate values are
         * stored encoded or plain. This makes the match work either way. */
        $countsByStage = array_fill_keys($stages, 0);

        foreach ($rs as $row)
        {
            $value = urldecode(trim($row['stageValue']));

            if (isset($countsByStage[$value]))
            {
                $countsByStage[$value] += (int) $row['candidateCount'];
            }
        }

        /* Cumulative sum from the last stage backward, per the confirmed
         * example: 5 in A, 1 in B, 2 in C -> funnel shows 8, 3, 2. */
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
}

?>