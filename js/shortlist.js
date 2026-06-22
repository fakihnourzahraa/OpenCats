
function updateStatus(candidateId, starIcon)
{
    $.ajax(
    {
        url: 'ajax.php?f=shortlist&action=isShortlisted&candidateId=' + candidateId,
        type: 'GET',
        dataType: 'xml',
        success: function(response)
        {
            var isShortlisted = $(response).find('isShortlisted').text() === '1';
            if (isShortlisted)
                starIcon.classList.add('shortlist-starred');
            else
                starIcon.classList.remove('shortlist-starred')
        }
    });
}

function toggleShortlist(candidateId, starIcon)
{
    var action = starIcon.classList.contains('shortlist-starred') ? 'remove' : 'add';
    //if is starred remove, else add

    $.ajax(
    {
        url: 'ajax.php?f=shortlist&action=' + action + '&candidateId=' + candidateId,
        type: 'GET',
        dataType: 'xml',
        success: function(response)
        {
            if (action === 'add')
                starIcon.classList.add('shortlist-starred');
            else if (action == 'remove')
                starIcon.classList.remove('shortlist-starred');
        }
    });
}

function initShortlist(candidateId, containerId)
{
    var starIcon = document.getElementById(containerId).querySelector('.shortlist-star');

    updateStatus(candidateId, starIcon);
    starIcon.addEventListener('click', function(e)
    {
        e.preventDefault();
        e.stopPropagation();
        toggleShortlist(candidateId, starIcon);
    });
}
