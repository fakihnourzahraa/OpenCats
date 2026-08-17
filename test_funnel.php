<?php
/**
 * test_funnel.php
 *
 * Standalone CLI test for RecruitmentAnalytics - no session, no routing,
 * no auth. Place at the OpenCATS root (next to index.php) and run:
 *
 *     php test_funnel.php
 *
 * Bootstraps only what RecruitmentAnalytics actually touches:
 * DatabaseConnection (for the query) and constants.php (for
 * DATA_ITEM_CANDIDATE). Everything else index.php loads - Session,
 * UserInterface, ModuleUtility, Hooks, etc. - is routing/auth machinery
 * this script has no use for.
 */

include_once('./config.php');
include_once(LEGACY_ROOT . '/constants.php');
include_once(LEGACY_ROOT . '/lib/CommonErrors.php');
include_once(LEGACY_ROOT . '/lib/CATSUtility.php');
include_once(LEGACY_ROOT . '/lib/DatabaseConnection.php');

include_once('./lib/RecruitmentAnalytics.php');

/* Confirm your real site_id first if unsure:
 *   SELECT site_id, name FROM site;
 * Most single-site installs are 1, but worth checking rather than
 * assuming. */
$siteID = 1;

$ra = new RecruitmentAnalytics($siteID);

echo "--- Resolved stage options (order matters) ---\n";
$stages = $ra->resolveExtraFieldOptions('Interview Stage', DATA_ITEM_CANDIDATE);
var_dump($stages);

echo "\n--- Funnel data (cumulative, no filters) ---\n";
$funnel = $ra->getRecruitmentFunnelData();
var_dump($funnel);

?>