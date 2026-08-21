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

    private function funnel()
    {
        $jobOrderID = null;

        if ($this->isOptionalIDValid('jobOrderID', $_GET))
        {
            $jobOrderID = (int) $_GET['jobOrderID'];
        }

        $recruitmentAnalytics = new RecruitmentAnalytics($this->_siteID);

        $filterString = $this->buildFilterString();

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
        $this->_template->assign('overallAcceptanceRate', $operationalMetrics['overallAcceptanceRate']);
        $this->_template->assign('offerAcceptanceRate', $operationalMetrics['offerAcceptanceRate']);
        $this->_template->assign('sourceOfHire', $operationalMetrics['sourceOfHire']);
        $this->_template->assign('funnelEffectiveness', $funnelEffectiveness);
        $this->_template->assign('applicationsByRole', $applicationsByRole);
        $this->_template->assign('filterOptions', $filterOptions);
        $this->_template->assign('selectedFilters', $this->getSelectedFilterValues($jobOrderID));

        if (!eval(Hooks::get('RECRUITMENTANALYTICS_FUNNEL'))) return;

        $this->_template->display('./modules/recruitmentanalytics/Funnel.tpl');
    }

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

        $dateModifiedFrom = isset($_GET['dateModifiedFrom']) ? trim($_GET['dateModifiedFrom']) : '';

        if ($dateModifiedFrom !== '')
        {
            $filters[] = 'dateModified=d>' . rawurlencode($this->toMDY($dateModifiedFrom));
        }

        $dateModifiedTo = isset($_GET['dateModifiedTo']) ? trim($_GET['dateModifiedTo']) : '';

        if ($dateModifiedTo !== '')
        {
            $filters[] = 'dateModified=d<' . rawurlencode($this->toMDY($dateModifiedTo));
        }

        return implode(',', $filters);
    }

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

    private function toMDY($ymd)
    {
        $timestamp = strtotime($ymd);

        if ($timestamp === false)
        {
            return $ymd;
        }

        return date('m-d-y', $timestamp);
    }

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
            'dateAvailableTo'   => isset($_GET['dateAvailableTo']) ? $_GET['dateAvailableTo'] : '',
            'dateModifiedFrom'  => isset($_GET['dateModifiedFrom']) ? $_GET['dateModifiedFrom'] : '',
            'dateModifiedTo'    => isset($_GET['dateModifiedTo']) ? $_GET['dateModifiedTo'] : ''
        );
    }
}

?>