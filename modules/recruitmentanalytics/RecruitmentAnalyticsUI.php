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

        $graphs = new Graphs();
        $graphParams = ($jobOrderID !== null) ? array($jobOrderID) : array();
        $funnelGraphHTML = $graphs->recruitmentFunnel(600, 300, $graphParams);

        /* No filters wired up yet for either graph or the KPIs - same
         * "not yet available" state as before. Once the filters UI
         * exists, this needs to build the filterPipelineRows() DSL
         * string from $_GET and pass it here and into
         * getOperationalMetrics(). */
        $timeInStageGraphHTML = $graphs->timeInStage(600, 300, array());

        $recruitmentAnalytics = new RecruitmentAnalytics($this->_siteID);
        $operationalMetrics = $recruitmentAnalytics->getOperationalMetrics('');
        $funnelEffectiveness = $recruitmentAnalytics->getFunnelEffectiveness();

        $this->_template->assign('active', $this);
        $this->_template->assign('jobOrderID', $jobOrderID);
        $this->_template->assign('funnelGraphHTML', $funnelGraphHTML);
        $this->_template->assign('timeInStageGraphHTML', $timeInStageGraphHTML);
        $this->_template->assign('candidatesCount', $operationalMetrics['candidatesCount']);
        $this->_template->assign('timeToHire', $operationalMetrics['timeToHire']);
        $this->_template->assign('offerAcceptanceRate', $operationalMetrics['offerAcceptanceRate']);
        $this->_template->assign('sourceOfHire', $operationalMetrics['sourceOfHire']);
        $this->_template->assign('funnelEffectiveness', $funnelEffectiveness);

        if (!eval(Hooks::get('RECRUITMENTANALYTICS_FUNNEL'))) return;

        $this->_template->display('./modules/recruitmentanalytics/Funnel.tpl');
    }
}

?>