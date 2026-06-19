TO DO:
add logic to duplicates.tpl and only hot candidates
Changed code:

for star option in candidates list

database:
db/cats_schema.sql
CREATE TABLE 'shortlist' (
  'shortlist_id' int(11) AUTO_INCREMENT PRIMARY KEY,
  'recruiter_id' int(11), /*recruiter who shorlisted, I want this to be private to them*/
  'candidate_id' int(11),
  KEY 'idx_recruiter' ('recruiter_id'),
  KEY 'idx_candidate' ('candidate_id'),
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
ajax/shortlist.php
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

js:
js/shortlist.js

function checkStatus(candidateId, callback) {
    $.ajax({
        url: 'ajax.php?f=shortlist&action=isShortlisted&candidateId=' + candidateId,
        type: 'GET',
        dataType: 'xml',
        success: function(response) {
            if (!response) {
                if (callback) callback(false);
                return;
            }
            var isShortlisted = $(response).find('isShortlisted').text() === '1';
            if (callback) callback(isShortlisted);
        },
        error: function(xhr, status, error) {
            console.error('checkStatus AJAX failed:', status, error, xhr.responseText);
            if (callback) callback(false);
        }
    });
}

function toggleShortlist(candidateId, starIcon) {
    var isStarred = starIcon.classList.contains('shortlist-starred');
    var action = isStarred ? 'remove' : 'add';

    $.ajax({
        url: 'ajax.php?f=shortlist&action=' + action + '&candidateId=' + candidateId,
        type: 'GET',
        dataType: 'xml',
        success: function(response) {
            var errorcode = $(response).find('errorcode').text();
            if (errorcode === '0' || errorcode === '') {
                if (action === 'add') {
                    starIcon.classList.add('shortlist-starred');
                } else {
                    starIcon.classList.remove('shortlist-starred');
                }
            }
        }
    });
}

function initShortlist(candidateId, containerId)
{
    var container = document.getElementById(containerId);
    var starIcon = container.querySelector('.shortlist-star');
    checkStatus(candidateId, function(isShortlisted)
    {
        if (isShortlisted)
            starIcon.classList.add('shortlist-starred');
        else
            starIcon.classList.remove('shortlist-starred')
    });
    starIcon.addEventListener('click', function(e)
    {
        e.preventDefault();
        e.stopPropagation();
        toggleShortlist(candidateId, starIcon);
    });
}


function addToShortlist(candidateId, callback)
{
    $.ajax({
        url: 'ajax.php',
        type: 'POST',
        data: {
            m: 'ajax',
            a: 'shortlist',
            action: 'add',
            candidateId: candidateId
        },
        dataType: 'json',
        success: function (response)
        {
            if (callback)
                callback(response.success);
        }
    });
}
function removeFromShortlist(candidateId, callback)
{
    $.ajax({
        url: 'ajax.php',
        type: 'POST',
        data: {
            m: 'ajax',
            a: 'shortlist',
            action: 'remove',
            candidateId: candidateId
        },
        dataType: 'json',
        success: function (response)
        {
            if (callback)
                callback(response.success);
        }
    });
}
function initAllSL(stars)
{
    stars.forEach(function(star){
        initShortlist(star.candidateId, star.containerId);
    });
}

lib/Shortlist.php
<?php

class Shortlist{
    private $_db;

    public function __construct() {
        $this->_db = DatabaseConnection::getInstance();
    }

    public function add($rID, $cID)
    {
        $query = "INSERT INTO shortlist (recruiter_id, candidate_id) 
                  VALUES ({$this->_db->makeQueryInteger($rID)}, {$this->_db->makeQueryInteger($cID)})";
        return $this->_db->query($query);
    }

    public function remove($rID, $cID)
    {
        $query = "DELETE FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}
                  AND candidate_id = {$this->_db->makeQueryInteger($cID)}";
        return $this->_db->query($query);
    }

    public function isShortlisted($rID, $cID)
    {
        $query = "SELECT COUNT(*) as count FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}
                  AND candidate_id = {$this->_db->makeQueryInteger($cID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return false;
        $row = $this->_db->getAssoc();  //using the results of the last query
        return isset($row['count']) && $row['count'] > 0;
    }

    public function getSL($rID)
    {
        $query = "SELECT candidate_id FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return array();
        
        $candidates = [];
        while (($row = $this->_db->getAssoc())) {
            $candidates[] = $row['candidate_id'];
        }
        return $candidates;
    }
    
    public function getCount($rID)
    {
        $query = "SELECT COUNT(*) as count FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return 0;
        
        $row = $this->_db->getAssoc();
        return isset($row['count']) ? intval($row['count']) : 0;
    }
}
?>

modules/candidates/Candidates.tpl

<?php TemplateUtility::printHeader('Candidates', array('js/highlightrows.js', 'js/export.js', 'js/dataGrid.js', 'js/dataGridFilters.js', 'js/shortlist.js')); ?>
[...]
<script>
            //MY CODE
            document.addEventListener('DOMContentLoaded', function() {
                var rows = document.querySelectorAll('table tr');
                
                rows.forEach(function(row, index) {
                    if (index === 0) return;
                    
                    var link = row.querySelector('a');
                    if (!link) return;
                    
                    var href = link.getAttribute('href');
                    var match = href.match(/candidateID=(\d+)/);
                    if (!match) return;
                    
                    var candidateId = match[1];
                    var containerId = 'star-' + candidateId;
                    
                    if (document.getElementById(containerId)) return;
                    
                    var td = document.createElement('td');
                    td.style.textAlign = 'center';
                    td.style.width = '40px';
                    td.innerHTML = '<div id="' + containerId + '" class="shortlist-container" data-candidate-id="' + candidateId + '"><i class="shortlist-star">★</i></div>';
                    
                    row.querySelector('td').parentNode.insertBefore(td, row.querySelector('td'));
                    
                    initShortlist(candidateId, containerId);
                });
            });
            </script>

modules/candidates/CandidatesUI.php
include_once(LEGACY_ROOT . '/lib/Shortlist.php');

[...]

            $resultSet[$rowIndex]['shortlistStar'] = '<div id="star-' . $resultSet[$rowIndex]['candidateID'] . '" class="shortlist-container" data-candidate-id="' . $resultSet[$rowIndex]['candidateID'] . '" style="text-align:center;"><i class="shortlist-star">★</i></div>';

for the filter 
   document.addEventListener('DOMContentLoaded', function() {
    var allTables = document.querySelectorAll('table');
    var gridTable = null;
    for (var i = 0; i < allTables.length; i++) {
        if (allTables[i].querySelector('a[href*="candidateID="]')) {
            gridTable = allTables[i];
            break;
        }
    }
    if (!gridTable) return;

    var headerRow = gridTable.tHead ? gridTable.tHead.rows[0] : gridTable.rows[0];
    if (headerRow) {
        var firstTh = headerRow.querySelector('th');
        if (firstTh) {
            var th = document.createElement('th');
            th.style.width = '40px';
            th.style.borderRight = '1px solid gray';
            firstTh.parentNode.insertBefore(th, firstTh);
        }
    }

    var bodyRows = gridTable.tBodies.length
        ? gridTable.tBodies[0].rows
        : Array.prototype.slice.call(gridTable.rows).slice(1);

    Array.prototype.forEach.call(bodyRows, function(row) {
        var link = row.querySelector('a');
        if (!link) return;

        var href = link.getAttribute('href');
        var match = href.match(/candidateID=(\d+)/);
        if (!match) return;

        var candidateId = match[1];
        var containerId = 'star-' + candidateId;

        if (document.getElementById(containerId)) return;

        var td = document.createElement('td');
        td.style.textAlign = 'center';
        td.style.width = '40px';
        td.innerHTML = '<div id="' + containerId + '" class="shortlist-container" data-candidate-id="' + candidateId + '"><i class="shortlist-star">★</i></div>';

        row.querySelector('td').parentNode.insertBefore(td, row.querySelector('td'));

        initShortlist(candidateId, containerId);
    });
});
            </script> 

candidatesui.php
            }
            $resultSet[$rowIndex]['shortlistStar'] = '<div id="star-' . $resultSet[$rowIndex]['candidateID'] . '" class="shortlist-container" data-candidate-id="' . $resultSet[$rowIndex]['candidateID'] . '" style="text-align:center;"><i class="shortlist-star">★</i></div>';
        }