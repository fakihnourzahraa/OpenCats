
<?php
include_once(LEGACY_ROOT . '/lib/Shortlist.php');
$interface = new SecureAJAXInterface();

if ($_SESSION['CATS']->getAccessLevel('candidates') < ACCESS_LEVEL_EDIT)
{
    $interface->outputXMLErrorPage(-1, ERROR_NO_PERMISSION);
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

        $output ="<errorcode>0</errorcode>";
        break;

    case 'remove':
        $shortlist->remove($recruiterID, $candidateID);

        $output ="<errorcode>0</errorcode>";
        break;

    case 'isShortlisted':
        $isShortlisted = $shortlist->isShortlisted($recruiterID, $candidateID) ? '1' : '0';

        $output ="<isShortlisted>" . $isShortlisted . "</isShortlisted>";
        break;

    default:
        $interface->outputXMLErrorPage(-1, 'Invalid action.');
        die();
}

$interface->outputXMLPage($output);

?>