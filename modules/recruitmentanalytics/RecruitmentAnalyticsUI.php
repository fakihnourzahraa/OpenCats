<?php
/*
 * RecruitmentAnalyticsUI.php
 * Added for IBC
 */

include_once(LEGACY_ROOT . '/lib/RecruitmentAnalytics.php');
include_once(LEGACY_ROOT . '/lib/Graphs.php');


class RecruitmentAnalyticsUI extends UserInterface
{
    public function __construct()
    {
        parent::__construct();

        $this->_authenticationRequired = true;
        $this->_moduleDirectory = 'recruitmentanalytics';
        $this->_moduleName = 'recruitmentanalytics';
        $this->_moduleTabText = 'Analytics';
        $this->_subTabs = array(
            'Funnel' => CATSUtility::getIndexName() . '?m=recruitmentanalytics&a=funnel'
        );
    }


    public function handleRequest()
    {
        $action = $this->getAction();

        if (!eval(Hooks::get('RECRUITMENTANALYTICS_HANDLE_REQUEST'))) return;

        switch ($action)
        {
            case 'funnel':
            default:
                $this->funnel();
                break;
        }
    }

    /*
     * Called by handleRequest() to load the funnel page. Renders the
     * funnel chart, the time-in-stage chart, and the KPI overview
     * (candidates count, time to hire, offer acceptance rate, source of
     * hire, funnel effectiveness) all on one page. The two charts are
     * <img> tags pointing at the graphs module (piece 4), same pattern
     * the legacy Dashboard uses for miniJobOrderPipeline. The KPI
     * numbers aren't images - getOperationalMetrics() /
     * getFunnelEffectiveness() are called directly here and handed to
     * the template as plain PHP arrays, same as any other CATS page.
     */
    private function funnel()
    {
        $jobOrderID = null;

        if ($this->isOptionalIDValid('jobOrderID', $_GET))
        {
            $jobOrderID = (int) $_GET['jobOrderID'];
        }

        $recruitmentAnalytics = new RecruitmentAnalytics($this->_siteID);

        $filterString = $this->buildFilterString();

        /* Single filter string, used everywhere on the page now:
         * - the two graphs, passed through as this image URL's 'params'
         *   query string (Graphs::_getGraphHTML() encodes a one-element
         *   $params array as-is, so the whole DSL string round-trips
         *   through the <img> request intact - no comma-splitting
         *   collision, since implode() on a single-element array is a
         *   no-op)
         * - the KPI panel, Applications by Role, and Funnel
         *   Effectiveness, called directly in PHP below
         */
        $graphs = new Graphs();
        $funnelGraphHTML = $graphs->recruitmentFunnel(600, 300, array($filterString));
        $timeInStageGraphHTML = $graphs->timeInStage(600, 300, array($filterString));

        $operationalMetrics = $recruitmentAnalytics->getOperationalMetrics($filterString);
        $applicationsByRole = $recruitmentAnalytics->getApplicationsByRole($filterString);
        $filterOptions = $recruitmentAnalytics->getFilterOptions();
        $funnelEffectiveness = $recruitmentAnalytics->getFunnelEffectiveness($filterString);

        $this->_template->assign('active', $this);
        $this->_template->assign('jobOrderID', $jobOrderID);
        $this->_template->assign('funnelGraphHTML', $funnelGraphHTML);
        $this->_template->assign('timeInStageGraphHTML', $timeInStageGraphHTML);
        $this->_template->assign('candidatesCount', $operationalMetrics['candidatesCount']);
        $this->_template->assign('timeToHire', $operationalMetrics['timeToHire']);
        $this->_template->assign('offerAcceptanceRate', $operationalMetrics['offerAcceptanceRate']);
        $this->_template->assign('sourceOfHire', $operationalMetrics['sourceOfHire']);
        $this->_template->assign('funnelEffectiveness', $funnelEffectiveness);
        $this->_template->assign('applicationsByRole', $applicationsByRole);
        $this->_template->assign('filterOptions', $filterOptions);
        $this->_template->assign('selectedFilters', $this->getSelectedFilterValues($jobOrderID));

        if (!eval(Hooks::get('RECRUITMENTANALYTICS_FUNNEL'))) return;

        $this->_template->display('./modules/recruitmentanalytics/Funnel.tpl');
    }

    /*
     * Builds the Pipelines::filterPipelineRows() DSL string from $_GET,
     * for the operational filters (owner, jobOrder, careerLevel, source,
     * status, dateAvailable). Every value is rawurlencode()'d because
     * filterPipelineRows() splits the whole string on literal commas
     * before decoding each piece; an unencoded comma in a value (a
     * status description, say) would otherwise be misread as a filter
     * separator.
     */
    private function buildFilterString()
    {
        $filters = array();

        $owner = isset($_GET['owner']) ? trim($_GET['owner']) : '';

        if ($owner !== '')
        {
            $filters[] = 'owner==' . rawurlencode($owner);
        }

        if ($this->isOptionalIDValid('jobOrderID', $_GET))
        {
            $filters[] = 'jobOrder==' . rawurlencode((int) $_GET['jobOrderID']);
        }

        $careerLevel = isset($_GET['careerLevel']) ? trim($_GET['careerLevel']) : '';

        if ($careerLevel !== '')
        {
            $filters[] = 'careerLevel==' . rawurlencode($careerLevel);
        }

        $source = isset($_GET['source']) ? trim($_GET['source']) : '';

        if ($source !== '')
        {
            $filters[] = 'source==' . rawurlencode($source);
        }

        $status = isset($_GET['status']) ? trim($_GET['status']) : '';

        if ($status !== '')
        {
            $filters[] = 'status==' . rawurlencode($status);
        }

        $dateModifiedRange = $this->resolveDateModifiedRange();

        if ($dateModifiedRange !== null)
        {
            $filters[] = 'dateModified=d>' . rawurlencode($dateModifiedRange['start']);
            $filters[] = 'dateModified=d<' . rawurlencode($dateModifiedRange['end']);
        }

        $dateAvailableFrom = isset($_GET['dateAvailableFrom']) ? trim($_GET['dateAvailableFrom']) : '';

        if ($dateAvailableFrom !== '')
        {
            $filters[] = 'dateAvailable=d>' . rawurlencode($this->toMDY($dateAvailableFrom));
        }

        $dateAvailableTo = isset($_GET['dateAvailableTo']) ? trim($_GET['dateAvailableTo']) : '';

        if ($dateAvailableTo !== '')
        {
            $filters[] = 'dateAvailable=d<' . rawurlencode($this->toMDY($dateAvailableTo));
        }

        return implode(',', $filters);
    }

    /*
     * Resolves the Date Modified dropdown's single combined value
     * (from RecruitmentAnalytics::getFilterOptions()'s
     * dateModifiedPeriods - "year:2026", "quarter:2026-Q3", or
     * "month:2026-08") into a [start, end] m-d-y range for the
     * dateModified DSL filter. Returns null if no value is selected, or
     * if it doesn't match one of those three shapes.
     */
    private function resolveDateModifiedRange()
    {
        $value = isset($_GET['dateRangeValue']) ? trim($_GET['dateRangeValue']) : '';

        if ($value === '')
        {
            return null;
        }

        if (preg_match('/^year:(\d{4})$/', $value, $m))
        {
            $year = (int) $m[1];

            return array(
                'start' => date('m-d-y', mktime(0, 0, 0, 1, 1, $year)),
                'end'   => date('m-d-y', mktime(0, 0, 0, 12, 31, $year))
            );
        }

        if (preg_match('/^quarter:(\d{4})-Q([1-4])$/', $value, $m))
        {
            $year = (int) $m[1];
            $quarter = (int) $m[2];
            $startMonth = (($quarter - 1) * 3) + 1;
            $endMonth = $startMonth + 2;
            $lastDay = (int) date('t', mktime(0, 0, 0, $endMonth, 1, $year));

            return array(
                'start' => date('m-d-y', mktime(0, 0, 0, $startMonth, 1, $year)),
                'end'   => date('m-d-y', mktime(0, 0, 0, $endMonth, $lastDay, $year))
            );
        }

        if (preg_match('/^month:(\d{4})-(\d{2})$/', $value, $m))
        {
            $year = (int) $m[1];
            $month = (int) $m[2];
            $lastDay = (int) date('t', mktime(0, 0, 0, $month, 1, $year));

            return array(
                'start' => date('m-d-y', mktime(0, 0, 0, $month, 1, $year)),
                'end'   => date('m-d-y', mktime(0, 0, 0, $month, $lastDay, $year))
            );
        }

        return null;
    }

    /* Converts an HTML date input's Y-m-d value to the m-d-y format
     * getHireEventRows() formats dateAvailable in, so filterPipelineRows()'s
     * date comparison is comparing like-formatted strings. */
    private function toMDY($ymd)
    {
        $timestamp = strtotime($ymd);

        if ($timestamp === false)
        {
            return $ymd;
        }

        return date('m-d-y', $timestamp);
    }

    /* Raw (unencoded) selected filter values, for repopulating the
     * filter form - separate from buildFilterString()'s encoded DSL
     * output since the template needs these for value="" attributes,
     * not for splitting on commas. */
    private function getSelectedFilterValues($jobOrderID)
    {
        return array(
            'owner'             => isset($_GET['owner']) ? $_GET['owner'] : '',
            'jobOrderID'        => $jobOrderID,
            'careerLevel'       => isset($_GET['careerLevel']) ? $_GET['careerLevel'] : '',
            'source'            => isset($_GET['source']) ? $_GET['source'] : '',
            'status'            => isset($_GET['status']) ? $_GET['status'] : '',
            'dateRangeValue'    => isset($_GET['dateRangeValue']) ? $_GET['dateRangeValue'] : '',
            'dateAvailableFrom' => isset($_GET['dateAvailableFrom']) ? $_GET['dateAvailableFrom'] : '',
            'dateAvailableTo'   => isset($_GET['dateAvailableTo']) ? $_GET['dateAvailableTo'] : ''
        );
    }
}

?>