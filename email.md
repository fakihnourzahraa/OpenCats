# Per-Status Change E-Mail Templates

Adds the ability to define a **separate status-change e-mail template for each candidate
pipeline status**, instead of one generic `EMAIL_TEMPLATE_STATUSCHANGE` template used for
every status.

**How it works**

* The generic template keeps its existing tag: `EMAIL_TEMPLATE_STATUSCHANGE`.
* Per-status templates are stored as regular e-mail templates with the tag
  `EMAIL_TEMPLATE_STATUSCHANGE_<statusID>` (e.g. `EMAIL_TEMPLATE_STATUSCHANGE_400`).
* In **Settings → Administration → E-Mail Templates**, selecting the Status Change template
  reveals a second dropdown listing every candidate status. Picking a status swaps in that
  status's own edit form.
* In **Add Activity / Change Status**, choosing a pipeline swaps the message body to that
  status's template if one exists, otherwise it falls back to the generic one.

Each section below names the file, says where the change goes, and gives the code verbatim.

---

## 1. `modules/settings/EmailTemplates.tpl`

**Replace** the existing `$(document).ready()` / `showTemplate()` / `showLastTemplate()` block:

```php
                $(document).ready(function() { 
                    $("select option:last").attr("selected", "selected");
                    showLastTemplate();
                });
                function showTemplate(templateID)
                {
                    <?php foreach ($this->emailTemplatesRS as $data): ?>
                        document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                    <?php endforeach; ?>
                    document.getElementById('editTable' + templateID).style.display = '';
                }
                function showLastTemplate()
                {
                    <?php foreach ($this->emailTemplatesRS as $data): ?>
                        document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                    <?php endforeach; ?>
                    <?php $templateID = end($this->emailTemplatesRS)['emailTemplateID'];?>
                    document.getElementById('editTable' + <?php echo $templateID; ?>).style.display = '';
                }
```

**with:**

```php
            <?php
                $statusChangeMainID = 0;
                foreach ($this->emailTemplatesRS as $_tpl)
                {
                    if ($_tpl['emailTemplateTag'] == 'EMAIL_TEMPLATE_STATUSCHANGE')
                    {
                        $statusChangeMainID = (int) $_tpl['emailTemplateID'];
                        break;
                    }
                }
            ?>
            var STATUS_CHANGE_TEMPLATE_ID = <?php echo $statusChangeMainID; ?>;

            $(document).ready(function() { 
                $("select option:last").attr("selected", "selected");
                showTemplate(document.getElementById('titleSelect').value);
            });

            function hideAllStatusSubForms()
            {
                <?php foreach ($this->candidateStatusesRS as $status): ?>
                    var _el = document.getElementById('editTableStatus_<?php echo (int) $status['statusID']; ?>');
                    if (_el) _el.style.display = 'none';
                <?php endforeach; ?>
            }

            function showTemplate(templateID)
            {
                <?php foreach ($this->emailTemplatesRS as $data): ?>
                    document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                <?php endforeach; ?>
                hideAllStatusSubForms();
                document.getElementById('statusSubSelectorRow').style.display = 'none';
                document.getElementById('statusSubSelect').value = '';
                document.getElementById('editTable' + templateID).style.display = '';
                if (parseInt(templateID) === STATUS_CHANGE_TEMPLATE_ID)
                    document.getElementById('statusSubSelectorRow').style.display = '';
            }

            function showLastTemplate()
            {
                <?php foreach ($this->emailTemplatesRS as $data): ?>
                    document.getElementById('editTable<?php echo($data['emailTemplateID']); ?>').style.display = 'none';
                <?php endforeach; ?>
                hideAllStatusSubForms();
                document.getElementById('statusSubSelectorRow').style.display = 'none';

                <?php $lastTemplateID = end($this->emailTemplatesRS)['emailTemplateID']; ?>
                document.getElementById('editTable<?php echo $lastTemplateID; ?>').style.display = '';
                if (<?php echo $lastTemplateID; ?> === STATUS_CHANGE_TEMPLATE_ID) {
                    document.getElementById('statusSubSelectorRow').style.display = '';
                }
            }

            function showStatusSubTemplate(statusID)
            {
                /* Collapse the generic form and all per-status forms. */
                document.getElementById('editTable' + STATUS_CHANGE_TEMPLATE_ID).style.display = 'none';
                hideAllStatusSubForms();

                if (statusID === '') {
                    document.getElementById('editTable' + STATUS_CHANGE_TEMPLATE_ID).style.display = '';
                    return;
                }
                var target = document.getElementById('editTableStatus_' + statusID);
                if (target) target.style.display = '';
            }
```

Key differences from the original:

* `STATUS_CHANGE_TEMPLATE_ID` is resolved server-side by scanning `emailTemplatesRS` for the
  `EMAIL_TEMPLATE_STATUSCHANGE` tag, so the JS never hardcodes an ID.
* `$(document).ready()` now calls `showTemplate()` with the currently selected value of
  `titleSelect` instead of always jumping to the last template.
* `showTemplate()` hides all per-status sub-forms and only shows the status dropdown row
  (`statusSubSelectorRow`) when the Status Change template is the one selected.
* `showStatusSubTemplate()` is new — it swaps between the generic form and the per-status forms.

### Markup this JS depends on

The template must also contain (see *Known Issues* below):

* a `<tr id="statusSubSelectorRow">` containing `<select id="statusSubSelect" onchange="showStatusSubTemplate(this.value);">`, populated from `$this->candidateStatusesRS` with an empty first option;
* one form per status with `id="editTableStatus_<statusID>"`, each posting `isStatusSubTemplate=1` and `statusID=<statusID>`, pre-filled from `$this->statusChangeTemplatesRS[$statusID]['text']` when present and otherwise from `$this->statusChangeFallbackText`.

---

## 2. `modules/settings/SettingsUI.php`

### 2a. In the e-mail templates display action

**Replace:**

```php
        if (!eval(Hooks::get('SETTINGS_EMAIL_TEMPLATES'))) return;

        $this->_template->assign('active', $this);
        $this->_template->assign('subActive', 'Administration');
        $this->_template->assign('emailTemplatesRS', $emailTemplatesRS);
        $this->_template->display('./modules/settings/EmailTemplates.tpl');
    }

    //FIXME: Document me.
    private function onEmailTemplates()
    {
        if (!$this->isRequiredIDValid('templateID', $_POST))
        {
```

**with:**

```php
        $emailTemplatesRS = array_values(array_filter($emailTemplatesRS, function($tpl) {
            return strpos($tpl['emailTemplateTag'], 'EMAIL_TEMPLATE_STATUSCHANGE_') !== 0;
        }));

        $pipelines = new Pipelines($this->_siteID);
        $candidateStatusesRS = $pipelines->getStatusesForPicking();

        $statusChangeFallbackText = '';
        $statusChangePossibleVariables = '';
        foreach ($emailTemplatesRS as $tpl) {
            if ($tpl['emailTemplateTag'] === 'EMAIL_TEMPLATE_STATUSCHANGE') {
                $statusChangeFallbackText      = $tpl['text'];
                $statusChangePossibleVariables = $tpl['possibleVariables'];
                break;
            }
        }

        $emailTemplates = new EmailTemplates($this->_siteID);
        $allTemplatesRS = $emailTemplates->getAll();

        $emailTemplatesRS = array_values(array_filter($allTemplatesRS, function($tpl) {
            return strpos($tpl['emailTemplateTag'], 'EMAIL_TEMPLATE_STATUSCHANGE_') !== 0;
        }));

        $statusChangeTemplatesRS = array();
        foreach ($allTemplatesRS as $tpl) {
            if (strpos($tpl['emailTemplateTag'], 'EMAIL_TEMPLATE_STATUSCHANGE_') === 0) {
                $sid = (int) substr($tpl['emailTemplateTag'], strlen('EMAIL_TEMPLATE_STATUSCHANGE_'));
                $statusChangeTemplatesRS[$sid] = $tpl;
            }
        }

        if (!eval(Hooks::get('SETTINGS_EMAIL_TEMPLATES'))) return;

        $this->_template->assign('candidateStatusesRS',           $candidateStatusesRS);
        $this->_template->assign('statusChangeTemplatesRS',        $statusChangeTemplatesRS);
        $this->_template->assign('statusChangeFallbackText',       $statusChangeFallbackText);
        $this->_template->assign('statusChangePossibleVariables',  $statusChangePossibleVariables);

        $this->_template->assign('active', $this);
        $this->_template->assign('subActive', 'Administration');
        $this->_template->assign('emailTemplatesRS', $emailTemplatesRS);
        $this->_template->display('./modules/settings/EmailTemplates.tpl');
    }

    //FIXME: Document me.
    private function onEmailTemplates()
    {
        // if (!$this->isRequiredIDValid('templateID', $_POST))
        // {
        //     CommonErrors::fatal(COMMONERROR_BADINDEX, $this, 'Invalid template ID.');
        // }
        $isStatusSub = !empty($_POST['isStatusSubTemplate']);
        if (!$isStatusSub && !$this->isRequiredIDValid('templateID', $_POST)) {
```

What this does:

* `EMAIL_TEMPLATE_STATUSCHANGE_*` templates are stripped out of `emailTemplatesRS` so they
  never show up as entries in the main template dropdown.
* They are collected separately into `$statusChangeTemplatesRS`, keyed by status ID.
* `$candidateStatusesRS` comes from `Pipelines::getStatusesForPicking()` and drives both the
  status dropdown and the per-status forms in the template.
* `$statusChangeFallbackText` / `$statusChangePossibleVariables` come from the generic
  `EMAIL_TEMPLATE_STATUSCHANGE` template and are used to pre-fill a status that has no template yet.
* The `templateID` validity check in `onEmailTemplates()` is now skipped for status sub-template
  posts, because a *new* per-status template is submitted with `templateID = 0`.

### 2b. In `onEmailTemplates()` — save/insert branch

Immediately after the existing `$emailTemplates = new EmailTemplates($this->_siteID);` line and
**before** the final `CATSUtility::transferRelativeURI('m=settings&a=emailTemplates');`, **add:**

```php
        $genericTpl = $emailTemplates->getByTag('EMAIL_TEMPLATE_STATUSCHANGE');
        $statusChangePossibleVariables = $genericTpl['possibleVariables'] ?? '';

        if ($isStatusSub && (int) $templateID === 0) {
            $statusID = (int) $_POST['statusID'];
            $tag      = 'EMAIL_TEMPLATE_STATUSCHANGE_' . $statusID;
            $emailTemplates->add($text, $tag, $tag, $this->_siteID, $statusChangePossibleVariables);
        } else {
            $emailTemplates->update($templateID, $templateTitle, $text, $disabled);
        }
```

So: a per-status form submitted with `templateID = 0` **inserts** a new template tagged
`EMAIL_TEMPLATE_STATUSCHANGE_<statusID>`, inheriting the generic template's `possibleVariables`.
Everything else (including editing an existing per-status template, which posts its real
`templateID`) goes down the normal `update()` path.

> The `error_log()` line is debug output — remove it before shipping.

---

## 3. `modules/candidates/AddActivityChangeStatus.tpl`

**Add** after the existing `statusTriggersEmailArray` loop and before the closing `</script>` /
`<form name="changePipelineStatusForm" ...>`:

```php
    var statusChangeTemplatesMap = <?php echo json_encode($this->statusChangeTemplatesMap); ?>;

    function AS_updateOriginalTemplate(statusID)
    {
        if (statusChangeTemplatesMap[statusID] !== undefined) {
            document.getElementById('origionalCustomMessage').value = statusChangeTemplatesMap[statusID];
        }
    }
```

**Replace** the `onchange` on the `regardingID` select (around line 70):

```php
<select id="regardingID" name="regardingID" class="inputbox" style="width: 150px;" onchange="AS_onRegardingChange(statusesArray, jobOrdersArray, 'regardingID', 'statusID', 'statusTR', 'sendEmailCheckTR', 'triggerEmail', 'triggerEmailSpan', 'changeStatus', 'changeStatusSpanA', 'changeStatusSpanB');">
```

**with:**

```php
<select id="regardingID" name="regardingID" class="inputbox" style="width: 150px;" onchange="AS_updateOriginalTemplate(this.value); AS_onRegardingChange(statusesArray, jobOrdersArray, 'regardingID', 'statusID', 'statusTR', 'sendEmailCheckTR', 'triggerEmail', 'triggerEmailSpan', 'changeStatus', 'changeStatusSpanA', 'changeStatusSpanB');">
```

`AS_updateOriginalTemplate()` runs first so `origionalCustomMessage` already holds the correct
per-status body by the time `AS_onRegardingChange()` copies it into the visible message box.

---

## 4. `modules/candidates/CandidatesUI.php`

**Add** after the existing `$statusChangeTemplate = str_replace($stringsToFind, $replacementStrings, $statusChangeTemplate);`
block and before the `/* Are we in "Only Schedule Event" mode? */` block:

```php
        $statusChangeTemplatesMap = array();
        foreach ($statusRS as $status)
        {
            $perStatusRS = $emailTemplates->getByTag(
                'EMAIL_TEMPLATE_STATUSCHANGE_' . $status['statusID']
            );

            if (!empty($perStatusRS) && !empty($perStatusRS['textReplaced']))
            {
                $text = str_replace($stringsToFind, $replacementStrings, $perStatusRS['textReplaced']);
            }
            else
            {
                $text = $statusChangeTemplate;
            }

            $statusChangeTemplatesMap[$status['statusID']] = $text;
        }
```

Then assign it to the template alongside the other `assign()` calls in the same action:

```php
        $this->_template->assign('statusChangeTemplatesMap', $statusChangeTemplatesMap);
```

The map holds one fully variable-substituted message body per status ID; statuses with no
per-status template fall back to the generic `$statusChangeTemplate`.

---

## 5. `modules/joborders/JobOrdersUI.php`

Same change as above, in the job-orders equivalent of the Add Activity / Change Status action.
**Add** after the `$statusChangeTemplate = str_replace(...)` block and before the
`$calendar = new Calendar($this->_siteID);` / `$calendarEventTypes = $calendar->getAllEventTypes();` block:

```php
        $statusChangeTemplatesMap = array();
        foreach ($statusRS as $status)
        {
            $perStatusRS = $emailTemplates->getByTag(
                'EMAIL_TEMPLATE_STATUSCHANGE_' . $status['statusID']
            );

            if (!empty($perStatusRS) && !empty($perStatusRS['textReplaced']))
            {
                $text = str_replace($stringsToFind, $replacementStrings, $perStatusRS['textReplaced']);
            }
            else
            {
                $text = $statusChangeTemplate;
            }

            $statusChangeTemplatesMap[$status['statusID']] = $text;
        }
```

And assign it:

```php
        $this->_template->assign('statusChangeTemplatesMap', $statusChangeTemplatesMap);
```

---

## Known Issues / Follow-ups

* **Duplicate filtering in `SettingsUI`.** `$emailTemplatesRS` is filtered once, then the full list
  is re-fetched via `$emailTemplates->getAll()` and filtered again. The first filter and the
  `$statusChangeFallbackText` loop that runs against it are redundant — the fallback loop should
  really run after `$allTemplatesRS` is loaded. Harmless but worth collapsing.

* **Template markup not included here.** The JS in `EmailTemplates.tpl` assumes
  `statusSubSelectorRow`, `statusSubSelect` and one `editTableStatus_<statusID>` form per status
  already exist in the markup. If they don't, `showTemplate()` will throw on the first
  `getElementById(...).style` call and the whole page's JS dies.

