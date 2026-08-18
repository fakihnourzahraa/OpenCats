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
     * chart as an <img> pointing at the graphs module (piece 4), same
     * pattern the legacy Dashboard uses for miniJobOrderPipeline.
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

        $this->_template->assign('active', $this);
        $this->_template->assign('jobOrderID', $jobOrderID);
        $this->_template->assign('funnelGraphHTML', $funnelGraphHTML);

        if (!eval(Hooks::get('RECRUITMENTANALYTICS_FUNNEL'))) return;

        $this->_template->display('./modules/recruitmentanalytics/Funnel.tpl');
    }
}

?>