<?php
include_once(LEGACY_ROOT . '/lib/Shortlist.php');
$interface = new SecureAJAXInterface();

if (!$interface->isRequiredIDValid('candidateId'))
{
    $interface->outputXMLErrorPage(-1, 'Invalid candidate ID.');
    die();
}

if (!isset($_REQUEST['action']) || empty($_REQUEST['action']))
{
    $interface->outputXMLErrorPage(-1, 'No action specified.');
    die();
}

$candidateID = $_REQUEST['candidateId'];
$action      = $_REQUEST['action'];
$recruiterID = $_SESSION['CATS']->getUserID();

session_write_close();

$shortlist = new Shortlist();

switch ($action)
{
    case 'add':
        $shortlist->add($recruiterID, $candidateID);

        $output =
            "<data>\n" .
            "    <errorcode>0</errorcode>\n" .
            "    <errormessage></errormessage>\n" .
            "</data>\n";
        break;

    case 'remove':
        $shortlist->remove($recruiterID, $candidateID);

        $output =
            "<data>\n" .
            "    <errorcode>0</errorcode>\n" .
            "    <errormessage></errormessage>\n" .
            "</data>\n";
        break;

    case 'isShortlisted':
        $isShortlisted = $shortlist->isShortlisted($recruiterID, $candidateID) ? '1' : '0';

        $output =
            "<data>\n" .
            "    <errorcode>0</errorcode>\n" .
            "    <errormessage></errormessage>\n" .
            "    <isShortlisted>" . $isShortlisted . "</isShortlisted>\n" .
            "</data>\n";
        break;

    default:
        $interface->outputXMLErrorPage(-1, 'Invalid action.');
        die();
}

$interface->outputXMLPage($output);

?>