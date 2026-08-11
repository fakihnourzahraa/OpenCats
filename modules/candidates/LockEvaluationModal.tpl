<?php /* modules/candidates/LockEvaluationModal.tpl  IBC */ ?>

<?php TemplateUtility::printModalHeader('Candidates', array(), 'Candidates: Lock Evaluation'); ?>

<div id="contents">
<?php if ($this->isFinishedMode): ?>
    <script type="text/javascript">
        parent.hidePopWin(false);
        parent.window.location.reload();
    </script>
<?php elseif ($this->isLocked): ?>
    <table class="editTable" width="100%">
        <tr>
            <td class="tdVertical">Evaluation:</td>
            <td class="tdData"><?php echo htmlspecialchars($this->evaluationTitle, ENT_QUOTES, 'UTF-8'); ?></td>
        </tr>
        <tr>
            <td class="tdVertical">Status:</td>
            <td class="tdData">Locked (read-only)</td>
        </tr>
    </table>

    <p class="note">
        This evaluation is locked and cannot be unlocked. Its stages, criteria and
        evaluator entries are permanently read-only. It can still be deleted.
    </p>

    <input type="button" class="button" value="Close" onclick="parent.hidePopWin(false);" />
<?php else: ?>
    <form name="lockEvaluationForm" method="post"
          action="<?php echo(CATSUtility::getIndexName()); ?>?m=candidates&amp;a=lockEvaluation">
        <input type="hidden" name="postback" value="postback" />
        <input type="hidden" name="csrfToken" value="<?php echo htmlspecialchars($_SESSION['CATS']->getCSRFToken(), ENT_QUOTES, 'UTF-8'); ?>" />
        <input type="hidden" name="candidateID" value="<?php echo (int) $this->candidateID; ?>" />
        <input type="hidden" name="instanceID" value="<?php echo (int) $this->instanceID; ?>" />

        <table class="editTable" width="100%">
            <tr>
                <td class="tdVertical">Evaluation:</td>
                <td class="tdData"><?php echo htmlspecialchars($this->evaluationTitle, ENT_QUOTES, 'UTF-8'); ?></td>
            </tr>
            <tr>
                <td class="tdVertical">Status:</td>
                <td class="tdData">Unlocked</td>
            </tr>
            <tr>
                <td class="tdVertical">Activity:</td>
                <td class="tdData">
                    <input type="checkbox" name="logActivity" checked="checked" />&nbsp;Log an Activity
                </td>
            </tr>
        </table>

        <p class="note">
            Locking makes this evaluation read-only. Nothing on it can be added,
            renamed or deleted afterwards, and this cannot be undone.
        </p>

        <input type="submit" class="button" value="Lock"
               onclick="return confirm('Lock this evaluation? This cannot be undone.');" />
        <input type="button" class="button" value="Cancel" onclick="parent.hidePopWin(false);" />
    </form>
<?php endif; ?>
</div>

<?php TemplateUtility::printModalFooter(); ?>