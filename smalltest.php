<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

include('./config.php');
include_once(LEGACY_ROOT . '/lib/DatabaseConnection.php');
include_once(LEGACY_ROOT . '/lib/Shortlist.php');

echo "Testing Shortlist class...<br>";

try {
    $shortlist = new Shortlist();
    echo "✓ Shortlist instantiated<br>";
    
    $userID = 1;
    $candidateID = 3;
    
    echo "Testing add($userID, $candidateID)...<br>";
    $result = $shortlist->add($userID, $candidateID);
    echo "Result: " . ($result ? 'SUCCESS' : 'FAILED') . "<br>";
    
    if (!$result) {
        $db = DatabaseConnection::getInstance();
        echo "Add failed. DB Error: " . $db->getError() . "<br>";
    }
    
    echo "Testing isShortlisted($userID, $candidateID)...<br>";
    $isShortlisted = $shortlist->isShortlisted($userID, $candidateID);
    echo "Result: " . ($isShortlisted ? 'YES' : 'NO') . "<br>";
    
} catch (Exception $e) {
    echo "EXCEPTION: " . $e->getMessage() . "<br>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}

echo "Done!";
?>