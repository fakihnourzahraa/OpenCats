<?php
/**
 * RecruitmentAnalytics.php
 * Added for IBC
 */

class RecruitmentAnalytics
{
    private $_db;
    private $_siteID;

    const INTERVIEW_STAGE_FIELD_NAME = 'Interview Stage';

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
}

?>