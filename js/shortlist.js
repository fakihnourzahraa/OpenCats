
// function checkStatus(candidateId, callback) {
//     $.ajax({
//         url: 'ajax.php?f=shortlist&action=isShortlisted&candidateId=' + candidateId,
//         type: 'GET',
//         dataType: 'xml',
//         success: function(response) {
//             var isShortlisted = $(response).find('isShortlisted').text() === '1';
//             if (callback) callback(isShortlisted);
//         },
//         error: function() {
//             if (callback) callback(false);
//         }
//     });
// }
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


