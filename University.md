# University Reference Table — Implementation Notes

## Overview

Universities were previously stored as free text in the `extra_field` table,
which led to naming inconsistencies (e.g. "LAU" vs "Lebanese American
University") and typos. This was replaced with a proper reference table
(`university`) and a `university_id` foreign-key-style column on `candidate`.
Since the recruiter now selects from a dropdown sourced from `university`,
new typos are no longer possible.

The dropdown displays both the short name and canonical name (e.g.
`LAU — Lebanese American University`) so the filter can match everything
under a given institution regardless of which form was previously typed.

Note: the `candidate` table uses the MyISAM engine, which does not enforce
foreign keys. Referential integrity is therefore enforced at the
application layer only (the dropdown prevents invalid values from being
entered).

---

## 1. Schema

```sql
CREATE TABLE `university` (
  `university_id` int(11) NOT NULL AUTO_INCREMENT,
  `canonical_name` varchar(255) NOT NULL DEFAULT '',
  `short_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`university_id`),
  UNIQUE KEY `uq_canonical_name` (`canonical_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

ALTER TABLE `candidate`
  ADD COLUMN `university_id` int(11) DEFAULT NULL;


  INSERT INTO `university` (`canonical_name`, `short_name`) VALUES
('Académie Libanaise des Beaux-Arts', 'ALBA'),
('Al-Kafaàt University', 'AKU'),
('Al Maaref University', 'MU'),
('American University of Beirut', 'AUB'),
('American University of Culture & Education', 'AUCE'),
('American University of Science and Technology', 'AUST'),
('American University of Technology', 'AUT'),
('Antonine University', 'UA'),
('Arab Open University', 'AOU'),
('Arts, Sciences and Technology University in Lebanon', 'AUL'),
('Beirut Arab University', 'BAU'),
('Beirut Islamic University', 'BIU'),
('Conservatoire National des Arts et Métiers', 'Cnam'),
('East International University', 'EIU'),
('Ecole Superieure des Affaires', 'ESA'),
('Global University', 'GU'),
('Haigazian University', 'HU'),
('Islamic University of Lebanon', 'IUL'),
('Jinan University', 'JU'),
('Lebanese American University', 'LAU'),
('Lebanese Canadian University', 'LCU'),
('Lebanese German University', 'LGU'),
('Lebanese International University', 'LIU'),
('Lebanese National Higher Conservatory of Music', 'LNHCM'),
('Lebanese University', 'UL'),
('Makassed University of Beirut', 'MUB'),
('Middle East University', 'MEU'),
('Modern University for Business and Science', 'MUBS'),
('Notre Dame University - Louaize', 'NDU'),
('Phoenicia University', 'PU'),
('Rafik Hariri University', 'RHU'),
('Saint George University of Beirut', 'SGU'),
('Saint Joseph University of Beirut', 'USJ'),
('Tripoli University Institute for Islamic Studies', 'UT'),
('Université La Sagesse', 'ULS'),
('Université Libano-Française de Technologie et des Sciences Appliqués', 'ULF'),
('University of Balamand', 'UoB'),
('University of Sciences & Arts in Lebanon', 'USAL'),
('Université Saint-Esprit de Kaslik', 'USEK'),
('Université Sainte Famille', 'USF'),
('Joyaa University Institute of Technology', 'JUIT'),
('Ouzai University College', 'OUC'),
('Matn University College', 'MUC'),
('Sidoon University College', 'SUC'),
('Saint Paul Institute of Philosophy & Theology', 'NEST');
```

Seeded with 45 Lebanese universities and institutes (sourced from the
Wikipedia "List of universities and related institutions in Lebanon").

---

## 2. `lib/Candidates.php`

### `add()`
- Added `$universityID = 0` to the parameter list (before `$skipHistory`).
- Added `university_id` to the `INSERT INTO candidate (...)` column list.
- Added a corresponding `%s` placeholder in `VALUES (...)`.
- Added `$this->_db->makeQueryInteger($universityID)` to the bind value list.

### `update()`
- Added `$universityID = 0` to the parameter list.
- Added `university_id = %s` to the `SET` clause (comma after `gpa = %s,`).
- Added `$this->_db->makeQueryInteger($universityID)` to the bind value list.

### `get()`
- Added to the `SELECT` list:
  ```sql
  candidate.university_id AS universityID,
  university.canonical_name AS universityCanonicalName,
  university.short_name AS universityShortName,
  ```
- Added join:
  ```sql
  LEFT JOIN university
      ON university.university_id = candidate.university_id
  ```

### `getForEditing()`
- Added `candidate.university_id AS universityID,` to the `SELECT` list.

### New method
```php
public function getPossibleUniversities()
{
    $sql = sprintf(
        "SELECT
            university.university_id AS universityID,
            university.canonical_name AS canonicalName,
            university.short_name AS shortName
        FROM
            university
        ORDER BY
            university.canonical_name ASC"
    );

    return $this->_db->getAllAssoc($sql);
}
```

---

## 3. `modules/candidates/CandidatesUI.php`

### `add()`
- After `$sourcesRS = $candidates->getPossibleSources();`:
  ```php
  $universitiesRS = $candidates->getPossibleUniversities();
  ```
- Template assign block:
  ```php
  $this->_template->assign('universitiesRS', $universitiesRS);
  ```

### `show()`
- After the `isHot` / `titleClass` if/else block:
  ```php
  if (!empty($data['universityID']))
  {
      $data['university'] = $data['universityShortName'] . ' — ' . $data['universityCanonicalName'];
  }
  else
  {
      $data['university'] = '';
  }
  ```

### `edit()`
- After `$sourcesString = ListEditor::getStringFromList($sourcesRS, 'name');`:
  ```php
  $universitiesRS = $candidates->getPossibleUniversities();
  ```
- Template assign block:
  ```php
  $this->_template->assign('universitiesRS', $universitiesRS);
  ```

### `onEdit()`
- Read posted value (alongside other field reads):
  ```php
  $universityID = $this->getTrimmedInput('universityID', $_POST);
  $universityID = ($universityID > 0) ? $universityID : null;
  ```
- Pass `$universityID` as the final argument to `$candidates->update(...)`.

### `_addCandidate()`
- Read posted value (alongside other field reads):
  ```php
  $universityID = $this->getTrimmedInput('universityID', $_POST);
  $universityID = ($universityID > 0) ? $universityID : null;
  ```
- Pass `$universityID` as the final argument to `$candidates->add(...)`.

---

## 4. `modules/candidates/Add.tpl`

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>

            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['universityID']) ?>">
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['canonicalName']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 5. `modules/candidates/Edit.tpl`

Same as Add, with the current value pre-selected:

```php
<tr>
    <td class="tdVertical">
        <label id="universityIDLabel" for="universityID">University:</label>
    </td>
    <td class="tdData">
        <select tabindex="X" id="universityID" name="universityID" class="inputbox" style="width: 250px;">
            <option value="-1">-- Select University --</option>

            <?php foreach ($this->universitiesRS as $universityData): ?>
                <option value="<?php $this->_($universityData['universityID']) ?>"
                    <?php if (isset($this->data['universityID']) && $this->data['universityID'] == $universityData['universityID']) echo('selected'); ?>>
                    <?php $this->_($universityData['shortName']) ?> &mdash; <?php $this->_($universityData['canonicalName']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </td>
</tr>
```

---

## 6. `modules/candidates/Show.tpl`

Added after the GPA row:

```php
<tr>
    <td class="vertical">University:</td>
    <td class="data"><?php $this->_($this->data['university']); ?></td>
</tr>
```

---

## Status

- [x] `university` reference table created and seeded (45 rows)
- [x] `candidate.university_id` column added
- [x] Add Candidate page — dropdown, save
- [x] Edit Candidate page — dropdown (pre-selected), save
- [x] Candidate Details page — display formatted name
- [ ] Candidate search/filter page — filter by university
- [ ] Migration plan for legacy `extra_field` / free-text `university`
      column data (not in scope for this implementer; needs DB access
      to execute)

## Known bug fixed during implementation

In `_addCandidate()`, the line:
```php
$universityID = ($universityID > 0) ? $universityID : null;
```
originally referenced `$universityID` before it was ever read from
`$_POST`, causing it to always evaluate to `null`/`0` regardless of the
dropdown selection. Fixed by reading the posted value first:
```php
$universityID = $this->getTrimmedInput('universityID', $_POST);
$universityID = ($universityID > 0) ? $universityID : null;
```