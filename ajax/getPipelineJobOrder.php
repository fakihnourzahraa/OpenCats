<?php
/*
 * CATS
 * AJAX Job Order Pipeline HTML Interface
 *
 * Copyright (C) 2005 - 2007 Cognizo Technologies, Inc.
 *
 *
 * The contents of this file are subject to the CATS Public License
 * Version 1.1a (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.catsone.com/.
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "CATS Standard Edition".
 *
 * The Initial Developer of the Original Code is Cognizo Technologies, Inc.
 * Portions created by the Initial Developer are Copyright (C) 2005 - 2007
 * (or from the year in which this file was created to the year 2007) by
 * Cognizo Technologies, Inc. All Rights Reserved.
 *
 *
 * $Id: getPipelineJobOrder.php 3814 2007-12-06 17:54:28Z brian $
 */

include_once(LEGACY_ROOT . '/lib/Pipelines.php');
include_once(LEGACY_ROOT . '/lib/TemplateUtility.php');
include_once(LEGACY_ROOT . '/lib/StringUtility.php');
include_once(LEGACY_ROOT . '/lib/CATSUtility.php');
include_once(LEGACY_ROOT . '/lib/Hooks.php');
include_once(LEGACY_ROOT . '/lib/JobOrders.php');

$interface = new SecureAJAXInterface();

if (!isset($_REQUEST['joborderID']) ||
    !isset($_REQUEST['page']) ||
    !isset($_REQUEST['entriesPerPage']) ||
    !isset($_REQUEST['sortBy']) ||
    !isset($_REQUEST['sortDirection']))
{
    $interface->outputXMLErrorPage(-1, 'Invalid input.');
    die();
}

$siteID = $interface->getSiteID();

$jobOrderID     = $_REQUEST['joborderID'];
$page           = $_REQUEST['page'];
$entriesPerPage = $_REQUEST['entriesPerPage'];
$sortBy         = $_REQUEST['sortBy'];
$sortDirection  = $_REQUEST['sortDirection'];
$indexFile      = $_REQUEST['indexFile'];
$isPopup        = $_REQUEST['isPopup'] == 1 ? true : false;

$filterValue    = isset($_REQUEST['filterValue'])    ? trim($_REQUEST['filterValue'])    : '';
$filterColumn   = isset($_REQUEST['filterColumn'])   ? trim($_REQUEST['filterColumn'])   : 'firstName';
$filterOperator = isset($_REQUEST['filterOperator']) ? trim($_REQUEST['filterOperator']) : '=~';
$_SESSION['CATS']->setPipelineEntriesPerPage($entriesPerPage);

$jobOrders = new JobOrders($siteID);
$jobOrdersData = $jobOrders->get($jobOrderID);

/* Get an array of the pipeline data. */
$pipelines = new Pipelines($siteID);
$pipelinesRS = $pipelines->getJobOrderPipeline($jobOrderID);

/* Format pipeline data. */
foreach ($pipelinesRS as $rowIndex => $row)
{
    if ($row['submitted'] == '1')
    {
        $pipelinesRS[$rowIndex]['highlightStyle'] = 'jobLinkSubmitted';
    }
    else if($row['isHotCandidate'] == '1')
    {
        $pipelinesRS[$rowIndex]['highlightStyle'] = 'jobLinkHot';
    }
    else
    {
        $pipelinesRS[$rowIndex]['highlightStyle'] = 'jobLinkCold';
    }

    $pipelinesRS[$rowIndex]['addedByAbbrName'] = StringUtility::makeInitialName(
        $pipelinesRS[$rowIndex]['addedByFirstName'],
        $pipelinesRS[$rowIndex]['addedByLastName'],
        LAST_NAME_MAXLEN
    );

    if ($row['attachmentPresent'] == 1)
    {
        $pipelinesRS[$rowIndex]['iconTag'] = '<img src="images/paperclip.gif" alt="" width="16" height="16" />';
    }
    else
    {
        $pipelinesRS[$rowIndex]['iconTag'] = '<img src="images/mru/blank.gif" alt="" width="16" height="16" />';
    }

    if ($row['isDuplicateCandidate'] == 1)
    {
        $pipelinesRS[$rowIndex]['iconTag'] .= '<img src="images/wf_error.gif" alt="" width="16" height="16" title="Duplicate Candidate"/>';
    }

    if($pipelinesRS[$rowIndex]['iconTag'] == '')
    {
        $pipelinesRS[$rowIndex]['iconTag'] .= '&nbsp;';
    }

    $pipelinesRS[$rowIndex]['ratingLine'] = TemplateUtility::getRatingObject(
        $pipelinesRS[$rowIndex]['ratingValue'],
        $pipelinesRS[$rowIndex]['candidateJobOrderID'],
        $_SESSION['CATS']->getCookie()
    );
}

$candidateIDs = array_map(function($row) {
    return $row['candidateID'];
}, $pipelinesRS);

$extraFieldsByCandidate = $pipelines->getExtraFieldsForPipelineCandidates($candidateIDs);

foreach ($pipelinesRS as $idx => $row)
{
    $cid = $row['candidateID'];
    if (isset($extraFieldsByCandidate[$cid]))
    {
        foreach ($extraFieldsByCandidate[$cid] as $fieldName => $value)
        {
            $pipelinesRS[$idx][$fieldName] = $value;
        }
    }
}

$filterString = isset($_REQUEST['filterString']) ? trim($_REQUEST['filterString']) : '';

$_SESSION['pipelineFilter'][$jobOrderID] = $filterString;

$columnMap = array(
    'First Name'       => 'firstName',
    'Last Name'        => 'lastName',
    'State'            => 'state',
    'City'             => 'city',
    'Zip'              => 'zip',
    'Address'          => 'address',
    'E-Mail'           => 'candidateEmail',
    '2nd E-Mail'       => 'candidateEmail2',
    'Home Phone'       => 'phoneHome',
    'Cell Phone'       => 'phoneCell',
    'Work Phone'       => 'phoneWork',
    'Key Skills'       => 'keySkills',
    'Current Employer' => 'currentEmployer',
    'Current Pay'      => 'currentPay',
    'Desired Pay'      => 'desiredPay',
    'Can Relocate'     => 'canRelocate',
    'Source'           => 'source',
    'Web Site'         => 'webSite',
    'Misc Notes'       => 'notes',
    'Available'        => 'dateAvailable',
    'Modified'         => 'dateModified',
    'Added'            => 'dateCreated',
    'GPA'              => 'gpa',
    'Created'          => 'candidateDateCreated',
    'University'       => 'universityShortName',
    'Nationality'      => 'nationality',
    'Interview Stage'  => 'statusDescription',
);

$allPipelineColumns = array(
    'match'               => 'Match',
    'firstName'           => 'First Name',
    'lastName'            => 'Last Name',
    'state'               => 'Loc',
    'city'                => 'City',
    'zip'                 => 'Zip',
    'address'             => 'Address',
    'dateCreatedInt'      => 'Added',
    'addedByAbbrName'     => 'Entered By',
    'status'              => 'Interview Stage',
    'lastActivity'        => 'Last Activity',
    'candidateEmail'      => 'E-Mail',
    'candidateEmail2'     => '2nd E-Mail',
    'phoneHome'           => 'Home Phone',
    'phoneCell'           => 'Cell Phone',
    'phoneWork'           => 'Work Phone',
    'keySkills'           => 'Key Skills',
    'currentEmployer'     => 'Current Employer',
    'currentPay'          => 'Current Pay',
    'desiredPay'          => 'Desired Pay',
    'canRelocate'         => 'Can Relocate',
    'source'              => 'Source',
    'webSite'             => 'Web Site',
    'notes'               => 'Misc Notes',
    'dateAvailable'       => 'Available',
    'dateModified'        => 'Modified',
    'candidateDateCreated'         => 'Created',
    'gpa'                 => 'GPA',
    'nationality'         => 'Nationality',
    'universityShortName' => 'University',
    'jobOrderStatus'      => 'Job Order Status',
    'action'              => 'Action',
);


$extraFieldDefs = $pipelines->getExtraFieldDefinitions();
if ($extraFieldDefs) {
    $actionLabel = $allPipelineColumns['action'];
    unset($allPipelineColumns['action']);
    foreach ($extraFieldDefs as $def) {
        $fn = $def['field_name'];
        $columnMap[$fn] = $fn;
        if (!isset($allPipelineColumns[$fn])) {
            $allPipelineColumns[$fn] = $def['field_name'];
        }
    }
    $allPipelineColumns['action'] = $actionLabel; // keep Action last
}
$defaultVisibleCols = array(
    'match',
    'firstName',
    'lastName',
    'state',
    'dateCreatedInt',
    'addedByAbbrName',
    'status',
    'lastActivity',
    'action',
);

/* Handle column toggle requests */
if (isset($_REQUEST['setColumn'])) {
    $toggleCol    = trim($_REQUEST['setColumn']);
    $toggleAction = isset($_REQUEST['colAction']) ? trim($_REQUEST['colAction']) : '';

    if (!isset($_SESSION['pipelineCols'][$siteID])) {
        $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
    }

    if ($toggleAction === 'reset') {
        $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
    } elseif ($toggleAction === 'remove' && array_key_exists($toggleCol, $allPipelineColumns)) {
        $_SESSION['pipelineCols'][$siteID] = array_values(
            array_diff($_SESSION['pipelineCols'][$siteID], array($toggleCol))
        );
    } elseif ($toggleAction === 'add' && array_key_exists($toggleCol, $allPipelineColumns)) {
        if (!in_array($toggleCol, $_SESSION['pipelineCols'][$siteID])) {
            $_SESSION['pipelineCols'][$siteID][] = $toggleCol;
        }
    }
}

if (!isset($_SESSION['pipelineCols'][$siteID])) {
    $_SESSION['pipelineCols'][$siteID] = $defaultVisibleCols;
}
$visibleCols = $_SESSION['pipelineCols'][$siteID];

$hardcodedCols = array(
    'match','firstName','lastName','state','city','zip','address',
    'dateCreatedInt','addedByAbbrName','status','lastActivity',
    'candidateEmail','candidateEmail2','phoneHome','phoneCell','phoneWork',
    'keySkills','currentEmployer','currentPay','desiredPay','canRelocate',
    'source','webSite','notes','dateAvailable','dateModified', 'candidateDateCreated',
    'gpa','nationality','universityShortName','jobOrderStatus','action',
);


$visibleColCount = 3;
foreach ($allPipelineColumns as $k => $v) {
    if ($k === 'action' && $isPopup) continue;
    if (in_array($k, $visibleCols)) $visibleColCount++;
}


if ($filterString !== '')
{
    $pipelineFilters = array_filter(explode(',', $filterString));
    foreach ($pipelineFilters as $filterItem)
    {
        $operators = array('=d>', '=d<','=in', '=~', '==', '=>', '=<', '=e');
        foreach ($operators as $op)
        {
            $pos = strpos($filterItem, $op);
            if ($pos !== false)
            {
                $col = urldecode(substr($filterItem, 0, $pos));
                
                $val = strtolower(urldecode(substr($filterItem, $pos + strlen($op))));
                $col = isset($columnMap[$col]) ? $columnMap[$col] : $col;

$pipelinesRS = array_filter($pipelinesRS, function($row) use ($col, $op, $val) {
    $fieldValue = isset($row[$col]) ? $row[$col] : '';

    if ($col === 'gpa') {
        if ($op === '=e') return $fieldValue === '' || $fieldValue === null;
        $fieldValue = (float) $fieldValue;
        $val = (float) $val;
        switch ($op) {
            case '==': return $fieldValue == $val;
            case '=>':  return $fieldValue >= $val;
            case '=<':  return $fieldValue <= $val;
            case '=e': return $fieldValue === '' || $fieldValue === null;
            default:    return true;
        }
    }

    if ($col === 'dateCreated' || $col === 'candidateDateCreated' || $col == 'dateModified') {
        if ($op === '=e') return $fieldValue === '' || $fieldValue === null;
        $fieldValue = DateTime::createFromFormat('m-d-y', $fieldValue);
        $valDate    = DateTime::createFromFormat('m-d-y', $val);
        if (!$fieldValue || !$valDate) return true;
        switch ($op) {
            case '==':  return $fieldValue == $valDate;
            case '=d>': return $fieldValue >= $valDate;
            case '=d<': return $fieldValue <= $valDate;
            case '=e':  return $fieldValue === '' || $fieldValue === null;
        }
    }
    $fieldValue = strtolower($fieldValue);
    $val = strtolower($val);
    switch ($op) {
        case '=in':
        case '==': return $fieldValue == $val;
        case '=~': return strpos($fieldValue, $val) !== false;
        case '=>':  return $fieldValue >= $val;
        case '=<':  return $fieldValue <= $val;
        case '=e': return $fieldValue === '' || $fieldValue === null;
        default:    return true;
    }
});
                $pipelinesRS = array_values($pipelinesRS);
                break;
            }
        }
    }
}

/* Sort the data. */
if ($sortBy !== '' && $sortBy !== 'undefined')
{
    $sorting = array();
    foreach ($pipelinesRS as $p)
    {
        $sorting[] = $p[$sortBy];
    }
    if ($sortBy == 'ratingValue')
    {
        array_multisort($sorting, $sortDirection == 'desc' ? SORT_DESC : SORT_ASC , SORT_NUMERIC, $pipelinesRS);
    }
    else
    {
        array_multisort($sorting, $sortDirection == 'desc' ? SORT_DESC : SORT_ASC , SORT_STRING, $pipelinesRS);
    }
}

$minEntry = $entriesPerPage * $page;
$maxEntry = $minEntry + $entriesPerPage;

if ($maxEntry > count($pipelinesRS))
{
    $maxEntry = count($pipelinesRS);
}


function printSortLink($field, $delimiter = "'", $changeDirection = true)
{
    global $sortBy, $sortDirection;

    echo $delimiter, $field, $delimiter, ', ';

    if ($changeDirection)
    {
        if ($sortBy == $field)
        {
            if ($sortDirection == 'desc' || $sortDirection == '')
            {
                echo $delimiter, 'asc', $delimiter;
            }
            else
            {
                echo $delimiter, 'desc', $delimiter;
            }
        }
        else
        {
            echo $delimiter, 'asc', $delimiter;
        }
    }
    else
    {
        if ($sortDirection == 'desc' || $sortDirection == '')
        {
            echo $delimiter, 'desc', $delimiter;
        }
        else
        {
            echo $delimiter, 'asc', $delimiter;
        }
    }
}

if (!eval(Hooks::get('JO_AJAX_GET_PIPELINE'))) return;

?>

<?php
$jsSortBy    = addslashes($sortBy);
$jsSortDir   = addslashes($sortDirection);
$jsIndexFile = addslashes($indexFile);
$jsFilter    = addslashes($filterString);
$jsCookie    = addslashes($_SESSION['CATS']->getCookie());
$jsIsPopup   = $isPopup ? 1 : 0;
?>

<?php echo(TemplateUtility::getRatingsArrayJS()); ?>


<table class="notsortable" id="pipelineTable" width="100%">
    <tr>
        <th style="width:10px; border-right:1px solid gray;" align="center">
            <div style="width:10px; position:relative;">
                <a href="javascript:void(0);" id="pipelineColumnIcon" onclick="pipelineColumnBox_toggle(); return false;">
                    <img src="images/tab_add.gif" border="0" alt="" />
                </a>
                <div class="ajaxSearchResults" id="pipelineColumnBox" onclick="event.stopPropagation();"
                     style="display:none; position:absolute; left:0; top:16px; width:180px; z-index:10000; text-align:left;">
                    <span style="font-weight:bold; color:#000000;">Show Columns:</span><br/><br/>
                    <?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
                        <?php if ($colKey === 'action' && $isPopup) continue; ?>
                        <?php $isVis = in_array($colKey, $visibleCols); ?>
                        <span style="font-weight:normal;">
                            <a href="javascript:void(0);"
                               onclick="pipelineToggleColumn('<?php echo htmlspecialchars($colKey); ?>',
                                        '<?php echo $isVis ? 'remove' : 'add'; ?>');">
                                <img src="images/<?php echo $isVis ? 'checkbox' : 'checkbox_blank'; ?>.gif" border="0" alt="" />
                                &nbsp;&nbsp;&nbsp;&nbsp;<?php echo htmlspecialchars($colLabel); ?>
                            </a>
                        </span><br/>
                    <?php endforeach; ?>
                    <br/>
                    <span style="font-weight:bold;">
                        <a href="javascript:void(0);" onclick="pipelineToggleColumn('', 'reset');">
                            <img src="images/checkbox_blank.gif" border="0" alt="" />
                            &nbsp;&nbsp;&nbsp;&nbsp;Reset to Default Columns
                        </a>
                    </span><br/>
                </div>
            </div>
        </th>

        <th></th>
        <th align="left" width="32" nowrap="nowrap"></th>
        <?php if (in_array('match', $visibleCols)): ?>
        <th align="left" width="62" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('ratingValue'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Match</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('firstName', $visibleCols)): ?>
        <th align="left" width="80" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('firstName'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">First Name</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('lastName', $visibleCols)): ?>
        <th align="left" width="100" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('lastName'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Last Name</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('state', $visibleCols)): ?>
        <th align="left" width="40" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('state'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Loc</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('city', $visibleCols)): ?>
        <th align="left" width="75" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('city'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">City</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('zip', $visibleCols)): ?>
        <th align="left" width="50" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('zip'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Zip</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('address', $visibleCols)): ?>
        <th align="left" width="150" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('address'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Address</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('dateCreatedInt', $visibleCols)): ?>
        <th align="left" width="60" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('dateCreatedInt'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Added</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('addedByAbbrName', $visibleCols)): ?>
        <th align="left" width="70" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('addedByAbbrName'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Entered By</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('status', $visibleCols)): ?>
        <th align="left" width="65" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('status'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Interview Stage</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('lastActivity', $visibleCols)): ?>
        <th align="left" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('lastActivity'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Last Activity</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('candidateEmail', $visibleCols)): ?>
        <th align="left" width="120" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('candidateEmail'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">E-Mail</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('candidateEmail2', $visibleCols)): ?>
        <th align="left" width="120" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('candidateEmail2'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">2nd E-Mail</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('phoneHome', $visibleCols)): ?>
        <th align="left" width="90" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('phoneHome'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Home Phone</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('phoneCell', $visibleCols)): ?>
        <th align="left" width="90" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('phoneCell'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Cell Phone</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('phoneWork', $visibleCols)): ?>
        <th align="left" width="90" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('phoneWork'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Work Phone</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('keySkills', $visibleCols)): ?>
        <th align="left" width="150" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('keySkills'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Key Skills</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('currentEmployer', $visibleCols)): ?>
        <th align="left" width="120" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('currentEmployer'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Current Employer</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('currentPay', $visibleCols)): ?>
        <th align="left" width="90" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('currentPay'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Current Pay</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('desiredPay', $visibleCols)): ?>
        <th align="left" width="90" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('desiredPay'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Desired Pay</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('canRelocate', $visibleCols)): ?>
        <th align="left" width="80" nowrap="nowrap">Can Relocate</th>
        <?php endif; ?>
        <?php if (in_array('source', $visibleCols)): ?>
        <th align="left" width="100" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('source'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Source</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('webSite', $visibleCols)): ?>
        <th align="left" width="100" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('webSite'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Web Site</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('notes', $visibleCols)): ?>
        <th align="left" width="200" nowrap="nowrap">Misc Notes</th>
        <?php endif; ?>
        <?php if (in_array('dateAvailable', $visibleCols)): ?>
        <th align="left" width="70" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('dateAvailable'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Available</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('dateModified', $visibleCols)): ?>
        <th align="left" width="70" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('dateModified'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Modified</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('candidateDateCreated', $visibleCols)): ?>
        <th align="left" width="70" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('candidateDateCreated'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Created</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('gpa', $visibleCols)): ?>
        <th align="left" width="50" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('gpa'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">GPA</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('nationality', $visibleCols)): ?>
        <th align="left" width="80" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('nationality'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Nationality</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('universityShortName', $visibleCols)): ?>
        <th align="left" width="100" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('universityShortName'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">University</a>
        </th>
        <?php endif; ?>
        <?php if (in_array('jobOrderStatus', $visibleCols)): ?>
        <th align="left" width="80" nowrap="nowrap">
            <a href="javascript:void(0);" onclick="PipelineJobOrder_populate(<?php echo($jobOrderID); ?>, <?php echo($page); ?>, <?php echo($entriesPerPage); ?>, <?php printSortLink('jobOrderStatus'); ?>, <?php if ($isPopup) echo(1); else echo(0); ?>, 'ajaxPipelineTable', '<?php echo($_SESSION['CATS']->getCookie()); ?>', 'ajaxPipelineTableIndicator', '<?php echo($indexFile); ?>');">Job Order Status</a>
        </th>
        <?php endif; ?>
        <?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
                <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
                <?php if (!in_array($colKey, $visibleCols)) continue; ?>
                <th align="left" nowrap="nowrap"><?php echo htmlspecialchars($colLabel); ?></th>
            <?php endforeach; ?>
            <?php if (!$isPopup && in_array('action', $visibleCols)): ?>
            <th align="center">Action</th>
            <?php endif; ?>
        </tr>

    <?php for ($i = $minEntry; $i < $maxEntry; $i++): ?>
        <?php $pipelinesData = $pipelinesRS[$i]; $rowNumber = $i - $minEntry; ?>
        <tr class="<?php TemplateUtility::printAlternatingRowClass($rowNumber); ?>" id="pipelineRow<?php echo($rowNumber); ?>">

<td style="text-align:center;" valign="top">
    <input type="checkbox" name="checked"
           value="<?php echo($pipelinesData['candidateID']); ?>" />
</td>

            <td valign="top">
                <span id="pipelineEntryOpen<?php echo($rowNumber); ?>">
                    <a href="javascript:void(0);" onclick="document.getElementById('pipelineDetails<?php echo($rowNumber); ?>').style.display = ''; document.getElementById('pipelineEntryClose<?php echo($rowNumber); ?>').style.display = ''; document.getElementById('pipelineEntryOpen<?php echo($rowNumber); ?>').style.display = 'none'; PipelineDetails_populate(<?php echo($pipelinesData['candidateJobOrderID']); ?>, 'pipelineEntryInner<?php echo($rowNumber); ?>', '<?php echo($_SESSION['CATS']->getCookie()); ?>');">
                        <img src="images/arrow_next.png" alt="" border="0" title="Show History" />
                    </a>
                </span>
                <span id="pipelineEntryClose<?php echo($rowNumber); ?>" style="display: none;">
                    <a href="javascript:void(0);" onclick="document.getElementById('pipelineDetails<?php echo($rowNumber); ?>').style.display = 'none'; document.getElementById('pipelineEntryClose<?php echo($rowNumber); ?>').style.display = 'none'; document.getElementById('pipelineEntryOpen<?php echo($rowNumber); ?>').style.display = '';">
                        <img src="images/arrow_down.png" alt="" border="0" title="Hide History"/>
                    </a>
                </span>
            </td>
            <td valign="top"><?php echo($pipelinesData['iconTag']); ?></td>
            <?php if (in_array('match', $visibleCols)): ?>
            <td valign="top"><?php echo($pipelinesData['ratingLine']); ?></td>
            <?php endif; ?>
            <?php if (in_array('firstName', $visibleCols)): ?>
            <td valign="top">
                <a href="<?php echo($indexFile); ?>?m=candidates&amp;a=show&amp;candidateID=<?php echo($pipelinesData['candidateID']); ?>" class="<?php echo($pipelinesData['highlightStyle']); ?>">
                    <?php echo(htmlspecialchars($pipelinesData['firstName'])); ?>
                </a>
            </td>
            <?php endif; ?>
            <?php if (in_array('lastName', $visibleCols)): ?>
            <td valign="top">
                <a href="<?php echo($indexFile); ?>?m=candidates&amp;a=show&amp;candidateID=<?php echo($pipelinesData['candidateID']); ?>" class="<?php echo($pipelinesData['highlightStyle']); ?>">
                    <?php echo(htmlspecialchars($pipelinesData['lastName'])); ?>
                </a>
            </td>
            <?php endif; ?>
            <?php if (in_array('state', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo(htmlspecialchars($pipelinesData['state'])); ?></td>
            <?php endif; ?>
            <?php if (in_array('city', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['city']); ?></td>
            <?php endif; ?>
            <?php if (in_array('zip', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['zip']); ?></td>
            <?php endif; ?>
            <?php if (in_array('address', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['address']); ?></td>
            <?php endif; ?>
            <?php if (in_array('dateCreatedInt', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo(htmlspecialchars($pipelinesData['dateCreated'])); ?></td>
            <?php endif; ?>
            <?php if (in_array('addedByAbbrName', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo(htmlspecialchars($pipelinesData['addedByAbbrName'])); ?></td>
            <?php endif; ?>
            <?php if (in_array('status', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo(htmlspecialchars($pipelinesData['status'])); ?></td>
            <?php endif; ?>
            <?php if (in_array('lastActivity', $visibleCols)): ?>
            <td valign="top"><?php echo($pipelinesData['lastActivity']); ?></td>
            <?php endif; ?>
            <?php if (in_array('candidateEmail', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['candidateEmail']); ?></td>
            <?php endif; ?>
            <?php if (in_array('candidateEmail2', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['candidateEmail2']); ?></td>
            <?php endif; ?>
            <?php if (in_array('phoneHome', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['phoneHome']); ?></td>
            <?php endif; ?>
            <?php if (in_array('phoneCell', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['phoneCell']); ?></td>
            <?php endif; ?>
            <?php if (in_array('phoneWork', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['phoneWork']); ?></td>
            <?php endif; ?>
            <?php if (in_array('keySkills', $visibleCols)): ?>
            <td valign="top"><?php echo htmlspecialchars(substr(trim($pipelinesData['keySkills']), 0, 50)) . (strlen(trim($pipelinesData['keySkills'])) > 50 ? '...' : ''); ?></td>
            <?php endif; ?>
            <?php if (in_array('currentEmployer', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['currentEmployer']); ?></td>
            <?php endif; ?>
            <?php if (in_array('currentPay', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['currentPay']); ?></td>
            <?php endif; ?>
            <?php if (in_array('desiredPay', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['desiredPay']); ?></td>
            <?php endif; ?>
            <?php if (in_array('canRelocate', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo ($pipelinesData['canRelocate'] == 1 ? 'Yes' : 'No'); ?></td>
            <?php endif; ?>
            <?php if (in_array('source', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['source']); ?></td>
            <?php endif; ?>
            <?php if (in_array('webSite', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><a href="<?php echo htmlspecialchars($pipelinesData['webSite']); ?>"><?php echo htmlspecialchars($pipelinesData['webSite']); ?></a></td>
            <?php endif; ?>
            <?php if (in_array('notes', $visibleCols)): ?>
            <td valign="top"><?php echo htmlspecialchars(substr(trim($pipelinesData['notes']), 0, 100)) . (strlen(trim($pipelinesData['notes'])) > 100 ? '...' : ''); ?></td>
            <?php endif; ?>
            <?php if (in_array('dateAvailable', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['dateAvailable']); ?></td>
            <?php endif; ?>
            <?php if (in_array('dateModified', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['dateModified']); ?></td>
            <?php endif; ?>
            <?php if (in_array('candidateDateCreated', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['candidateDateCreated']); ?></td>
            <?php endif; ?>
            <?php if (in_array('gpa', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['gpa']); ?></td>
            <?php endif; ?>
            <?php if (in_array('nationality', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['nationality']); ?></td>
            <?php endif; ?>
            <?php if (in_array('universityShortName', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['universityShortName']); ?></td>
            <?php endif; ?>
            <?php if (in_array('jobOrderStatus', $visibleCols)): ?>
            <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars($pipelinesData['jobOrderStatus']); ?></td>
            <?php endif; ?>
            <?php foreach ($allPipelineColumns as $colKey => $colLabel): ?>
                <?php if (in_array($colKey, $hardcodedCols)) continue; ?>
                <?php if (!in_array($colKey, $visibleCols)) continue; ?>
                <td valign="top" nowrap="nowrap"><?php echo htmlspecialchars(isset($pipelinesData[$colKey]) ? $pipelinesData[$colKey] : ''); ?></td>
            <?php endforeach; ?>
            <?php if (!$isPopup && in_array('action', $visibleCols)): ?>
            <td align="center" nowrap="nowrap">
                <?php if ($_SESSION['CATS']->getAccessLevel('pipelines.screening') >= ACCESS_LEVEL_EDIT && !$_SESSION['CATS']->hasUserCategory('sourcer')): ?>
                    <?php if ($pipelinesData['ratingValue'] < 0): ?>
                        <a href="#" id="screenLink<?php echo($pipelinesData['candidateJobOrderID']); ?>" onclick="moImageValue<?php echo($pipelinesData['candidateJobOrderID']); ?> = 0; setRating(<?php echo($pipelinesData['candidateJobOrderID']); ?>, 0, 'moImage<?php echo($pipelinesData['candidateJobOrderID']); ?>', '<?php echo($_SESSION['CATS']->getCookie()); ?> '); return false;">
                            <img id="screenImage<?php echo($pipelinesData['candidateJobOrderID']); ?>" src="images/actions/screen.gif" width="16" height="16" class="absmiddle" alt="" border="0" title="Mark as Screened"/>
                        </a>
                    <?php else: ?>
                        <img src="images/actions/blank.gif" width="16" height="16" class="absmiddle" alt="" style="border: none;" />
                    <?php endif; ?>
                <?php endif; ?>
                <?php if (!isset($frozen)): ?>
                    <?php if ($_SESSION['CATS']->getAccessLevel('pipelines.addActivityChangeStatus') >= ACCESS_LEVEL_EDIT): ?>
                        <a href="#" onclick="showPopWin('<?php echo($indexFile); ?>?m=joborders&amp;a=addActivityChangeStatus&amp;jobOrderID=<?php echo($jobOrderID); ?>&amp;candidateID=<?php echo($pipelinesData['candidateID']); ?>', 600, 550, null); return false;">
                            <img src="images/actions/edit.gif" width="16" height="16" class="absmiddle" alt="" style="border: none;" title="Log an Activity / Change Interview Stage" />
                        </a>
                    <?php endif; ?>
                    <?php if ($_SESSION['CATS']->getAccessLevel('pipelines.removeFromPipeline') >= ACCESS_LEVEL_DELETE): ?>
                        <a href="<?php echo($indexFile); ?>?m=joborders&amp;a=removeFromPipeline&amp;jobOrderID=<?php echo($jobOrderID); ?>&amp;candidateID=<?php echo($pipelinesData['candidateID']); ?>" onclick="javascript:return confirm('Remove <?php echo(str_replace('\'', '\\\'', htmlspecialchars($pipelinesData['firstName']))); ?> <?php echo(str_replace('\'', '\\\'', htmlspecialchars($pipelinesData['lastName']))); ?> from the pipeline?')">
                            <img src="images/actions/delete.gif" width="16" height="16" class="absmiddle" alt="remove" style="border: none;" title="Remove from Job Order" />
                        </a>
                    <?php endif; ?>
                <?php endif; ?>
            </td>
            <?php endif; ?>
        </tr>
        <tr class="<?php TemplateUtility::printAlternatingRowClass($rowNumber); ?>" id="pipelineDetails<?php echo($rowNumber); ?>" style="display:none;">
            <td colspan="<?php echo $visibleColCount; ?>">
                <center>
                    <table width="98%" border=1 class="detailsOutside" style="margin:5px;">
                        <tr>
                            <td align="left" style="padding: 6px 6px 6px 6px; background-color: white; clear: both;">
                                <div style="overflow: auto; height: 200px;" id="pipelineEntryInner<?php echo($rowNumber); ?>">
                                    <img src="images/indicator.gif" alt="" />&nbsp;&nbsp;Loading pipeline details...
                                </div>
                            </td>
                        </tr>
                    </table>
                </center>
            </td>
        </tr>
    <?php endfor; ?>
</table>