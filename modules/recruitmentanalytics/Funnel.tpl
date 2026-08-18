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
                    <td><h2>Recruitment Analytics</h2></td>
                </tr>
            </table>

            <p class="note">
                Filtering (recruiter, department, date range, etc.) is not
                yet available on this page.
            </p>

            <!-- KPI overview -->
            <div class="noteUnsizedSpan">Overview</div>
            <table>
                <tr>
                    <td align="center" valign="top" style="text-align: left; width: 180px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;"><?php echo(number_format($this->candidatesCount)); ?></div>
                        <div style="font-size: 11px;">Pipeline Entries</div>
                    </td>
                    <td align="center" valign="top" style="text-align: left; width: 180px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;">
                            <?php echo($this->timeToHire['averageDays'] !== null ? number_format($this->timeToHire['averageDays'], 1) : '&mdash;'); ?>
                        </div>
                        <div style="font-size: 11px;">Avg. Days to Hire (<?php echo((int) $this->timeToHire['hiredCount']); ?> hired)</div>
                    </td>
                    <td align="center" valign="top" style="text-align: left; width: 220px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;">
                            <?php echo($this->offerAcceptanceRate['rate'] !== null ? number_format($this->offerAcceptanceRate['rate'], 1) . '%' : '&mdash;'); ?>
                        </div>
                        <div style="font-size: 11px;">
                            Offer Acceptance Rate
                            (<?php echo((int) $this->offerAcceptanceRate['placedCount']); ?> placed,
                            <?php echo((int) $this->offerAcceptanceRate['declinedCount']); ?> declined)
                        </div>
                    </td>
                </tr>
            </table>

            <!-- Funnel + time-in-stage graphs side by side -->
            <table>
                <tr>
                    <td align="left" valign="top" style="text-align: left; width: 50%;">
                        <div class="noteUnsizedSpan">Recruitment Funnel</div>
                        <div style="padding: 10px 0;">
                            <?php echo($this->funnelGraphHTML); ?>
                        </div>
                    </td>

                    <td align="left" valign="top" style="text-align: left; width: 50%;">
                        <div class="noteUnsizedSpan">Time in Stage</div>
                        <div style="padding: 10px 0;">
                            <?php echo($this->timeInStageGraphHTML); ?>
                        </div>
                    </td>
                </tr>
            </table>

            <!-- Source of hire + funnel effectiveness side by side -->
            <table>
                <tr>
                    <td align="left" valign="top" style="text-align: left; width: 50%; height: 240px;">
                        <div class="noteUnsizedSpan">Source of Hire</div>

                        <?php if (!count($this->sourceOfHire)): ?>
                            <p style="font-size: 11px;">No placed candidates yet.</p>
                        <?php else: ?>
                        <table class="sortable" style="margin: 0 0 4px 0;">
                            <tr>
                                <th align="left" style="font-size:11px;">Source</th>
                                <th align="left" style="font-size:11px;">Hires</th>
                                <th align="left" style="font-size:11px;">% of Hires</th>
                            </tr>
                            <?php foreach ($this->sourceOfHire as $index => $data): ?>
                            <tr class="<?php TemplateUtility::printAlternatingRowClass($index); ?>">
                                <td style="font-size:11px;"><?php $this->_($data['source']); ?></td>
                                <td style="font-size:11px;"><?php echo((int) $data['hiredCount']); ?></td>
                                <td style="font-size:11px;"><?php echo($data['percentOfHires'] !== null ? number_format($data['percentOfHires'], 1) . '%' : '&mdash;'); ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </table>
                        <?php endif; ?>
                    </td>

                    <td align="left" valign="top" style="text-align: left; width: 50%; height: 240px;">
                        <div class="noteUnsizedSpan">Funnel Effectiveness</div>

                        <?php if (!count($this->funnelEffectiveness)): ?>
                            <p style="font-size: 11px;">No funnel data yet.</p>
                        <?php else: ?>
                        <table class="sortable" style="margin: 0 0 4px 0;">
                            <tr>
                                <th align="left" style="font-size:11px;">Stage</th>
                                <th align="left" style="font-size:11px;">Candidates</th>
                                <th align="left" style="font-size:11px;">Conversion from Previous</th>
                            </tr>
                            <?php foreach ($this->funnelEffectiveness as $index => $data): ?>
                            <tr class="<?php TemplateUtility::printAlternatingRowClass($index); ?>">
                                <td style="font-size:11px;"><?php $this->_($data['stage']); ?></td>
                                <td style="font-size:11px;"><?php echo((int) $data['count']); ?></td>
                                <td style="font-size:11px;"><?php echo($data['conversionRate'] !== null ? number_format($data['conversionRate'], 1) . '%' : '&mdash;'); ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </table>
                        <?php endif; ?>
                    </td>
                </tr>
            </table>
        </div>
    </div>

<?php TemplateUtility::printFooter(); ?>