# Shortlist Feature

A recruiter candidate shortlisting built on top of OpenCATS. Recruiters star candidates and filter the candidates list to their shortlist. Shortlists are private, each recruiter sees only their own.



## Files

### New

| File | Purpose |
|---|---|
| `lib/Shortlist.php` | Library class wrapping all `shortlist` table operations |
| `ajax/shortlist.php` | AJAX endpoint for add, remove, and status check |
| `js/shortlist.js` | Injects star icons, calls AJAX endpoint, handles toggle |

### Modified

| File | Change |
|---|---|
| `lib/Candidates.php` | Added `IsShortlist` column to `CandidatesDataGrid::_classColumns` |
| `modules/candidates/Candidates.tpl` | Added checkbox filter, includes `shortlist.js`, injects stars into DataGrid |
| `modules/candidates/Show.tpl` | Added star to candidate detail page |

---

## Database

```sql
CREATE TABLE `shortlist` (
  `shortlist_id` int(11) AUTO_INCREMENT PRIMARY KEY,
  `recruiter_id` int(11),
  `candidate_id` int(11),
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

```

## `lib/Shortlist.php`

```php
$sl = new Shortlist();

$sl->add($recruiterID, $candidateID);
$sl->remove($recruiterID, $candidateID);
$sl->isShortlisted($recruiterID, $candidateID); // bool
$sl->getSL($recruiterID);                        // int[]
$sl->getCount($recruiterID);                     // int
```

All parameters pass through `makeQueryInteger()`.

---

## `ajax/shortlist.php`

**URL:** `ajax.php?f=shortlist&action=<action>&candidateId=<id>`

| Action | Description |
|---|---|
| `isShortlisted` | Returns `<isShortlisted>1</isShortlisted>` or `0` |
| `addToShortlist` | Adds candidate to recruiter's shortlist |
| `removeFromShortlist` | Removes candidate from recruiter's shortlist |

Responses use the standard OpenCATS XML envelope.

---

## `js/shortlist.js`

**`initShortlist(candidateId, containerId)`** sets initial star state via `isShortlisted` on load, then attaches a click handler to toggle it.

**`injectShortlistColumn()`** runs on `DOMContentLoaded` on the Candidates page. Scans DataGrid rows for candidate links, appends a star `<td>` to each row and a blank `<th>` to the header, then calls `initShortlist()` per row.

---

## DataGrid Filter — `lib/Candidates.php`

Shortlist status lives in a separate table, so the filter uses `filterRender=#` so we use a subquery:

```php
'IsShortlist' => array(
    'select'            => '',
    'pagerOptional'     => false,
    'filterable'        => false,
    'filterDescription' => 'Only Shortlisted Candidates',
    'filterTypes'       => '=#',
    'filterRender=#'    => '
        return "candidate.candidate_id IN (
            SELECT candidate_id FROM shortlist
            WHERE recruiter_id = " . $db->makeQueryInteger($argument) . "
        )";
    '),
```

### Checkbox — `Candidates.tpl`

```php
<input type="checkbox" name="onlyShortlisted"
  <?php if ($this->dataGrid->getFilterValue('IsShortlist') == $this->userID): ?>checked<?php endif; ?>
  onclick="<?php echo $this->dataGrid->getJSAddRemoveFilterFromCheckbox('IsShortlist', '=#', $this->userID); ?>" />
Only Shortlisted Candidates
```

---

## `Show.tpl`

```php
<div id="star-<?= $this->candidateID ?>" class="shortlist-container">
  <i class="shortlist-star">☆</i>
</div>

<script>
document.addEventListener('DOMContentLoaded', function () {
    initShortlist(<?= $this->candidateID ?>, 'star-<?= $this->candidateID ?>');
});
</script>
