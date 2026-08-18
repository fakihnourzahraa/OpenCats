<?php /* Recruitment Analytics Funnel */ ?>
<?php TemplateUtility::printHeader('Recruitment Analytics'); ?>
<?php TemplateUtility::printHeaderBlock(); ?>
<?php TemplateUtility::printTabs($this->active); ?>
    <div id="main">
        <?php TemplateUtility::printQuickSearch(); ?>

        <div id="contents">
            <table width="100%">
                <tr>
                    <td width="3%">
                        <img src="images/job_orders.gif" width="24" height="24" border="0" alt="Recruitment Analytics" style="margin-top: 3px;" />&nbsp;
                    </td>
                    <td><h2>Recruitment Funnel</h2></td>
                </tr>
            </table>

            <p class="note">
                Candidates by Interview Stage, cumulative. Filtering (recruiter,
                department, date range, etc.) is not yet available on this page.
            </p>

            <div style="padding: 10px 0;">
                <?php echo($this->funnelGraphHTML); ?>
            </div>
        </div>
    </div>

<?php TemplateUtility::printFooter(); ?>