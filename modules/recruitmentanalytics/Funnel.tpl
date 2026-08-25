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

            <div class="noteUnsizedSpan">Overview</div>
            <table>
                <tr>
                    <td align="center" valign="top" style="text-align: left; width: 180px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;"><?php echo(number_format($this->candidatesCount)); ?></div>
                        <div style="font-size: 11px;">Candidates</div>
                    </td>
                    <td align="center" valign="top" style="text-align: left; width: 180px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;">
                            <?php echo($this->timeToHire['averageDays'] !== null ? number_format($this->timeToHire['averageDays'], 1) : 'NA'); ?>
                        </div>
                        <div style="font-size: 11px;">Avg. Days to Hire (<?php echo((int) $this->timeToHire['hiredCount']); ?> hired)</div>
                    </td>
                    <td align="center" valign="top" style="text-align: left; width: 220px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;">
                            <?php echo($this->overallAcceptanceRate['rate'] !== null ? number_format($this->overallAcceptanceRate['rate'], 1) . '%' : 'NA'); ?>
                        </div>
                        <div style="font-size: 11px;">
                            Overall Acceptance Rate
                            (<?php echo((int) $this->overallAcceptanceRate['placedCount']); ?> placed of
                            <?php echo((int) $this->overallAcceptanceRate['candidatesCount']); ?> pipeline entries)
                        </div>
                    </td>
                    <td align="center" valign="top" style="text-align: left; width: 220px; height: 60px;">
                        <div style="font-size: 22px; font-weight: bold;">
                            <?php echo($this->offerAcceptanceRate['rate'] !== null ? number_format($this->offerAcceptanceRate['rate'], 1) . '%' : 'NA'); ?>
                        </div>
                        <div style="font-size: 11px;">
                            Offer Acceptance Rate
                            (<?php echo((int) $this->offerAcceptanceRate['placedCount']); ?> placed,
                            <?php echo((int) $this->offerAcceptanceRate['declinedCount']); ?> declined)
                        </div>
                    </td>
                </tr>
            </table>

            <div class="noteUnsizedSpan">Applications by Role</div>

            <form method="get" action="<?php echo(CATSUtility::getIndexName()); ?>">
                <input type="hidden" name="m" value="recruitmentanalytics" />
                <input type="hidden" name="a" value="funnel" />

                <table style="margin: 0 0 10px 0;">
                    <tr>
                                               <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Time Period<br />
                            <select id="dateRangeYear" style="font-size:11px;"></select>
                            <select id="dateRangeQuarter" style="font-size:11px; display:none;"></select>
                            <select id="dateRangeMonth" style="font-size:11px; display:none;"></select>
                            <input type="hidden" name="dateRangeValue" id="dateRangeValue" value="<?php echo(htmlspecialchars($this->selectedFilters['dateRangeValue'])); ?>" />
                        </td>
                        <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Owner<br />
                            <select name="owner" style="font-size:11px;">
                                <option value="">All</option>
                                <?php foreach ($this->filterOptions['owners'] as $owner): ?>
                                <option value="<?php echo(htmlspecialchars($owner)); ?>"<?php echo($this->selectedFilters['owner'] === $owner ? ' selected="selected"' : ''); ?>><?php echo(htmlspecialchars($owner)); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                        <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Role<br />
                            <select name="jobOrderID" style="font-size:11px;">
                                <option value="">All</option>
                                <?php foreach ($this->filterOptions['jobOrders'] as $jobOrderID => $title): ?>
                                <option value="<?php echo((int) $jobOrderID); ?>"<?php echo(((int) $this->selectedFilters['jobOrderID'] === (int) $jobOrderID) ? ' selected="selected"' : ''); ?>><?php echo(htmlspecialchars($title)); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                        <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Career Level<br />
                            <select name="careerLevel" style="font-size:11px;">
                                <option value="">All</option>
                                <?php foreach ($this->filterOptions['careerLevels'] as $careerLevel): ?>
                                <option value="<?php echo(htmlspecialchars($careerLevel)); ?>"<?php echo($this->selectedFilters['careerLevel'] === $careerLevel ? ' selected="selected"' : ''); ?>><?php echo(htmlspecialchars($careerLevel)); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                
                        <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Source<br />
                            <select name="source" style="font-size:11px;">
                                <option value="">All</option>
                                <?php foreach ($this->filterOptions['sources'] as $source): ?>
                                <option value="<?php echo(htmlspecialchars($source)); ?>"<?php echo($this->selectedFilters['source'] === $source ? ' selected="selected"' : ''); ?>><?php echo(htmlspecialchars($source)); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                    </tr><tr>
                        <td style="font-size:11px; padding: 2px 8px 2px 0;">
                            Status<br />
                            <select name="status" style="font-size:11px;">
                                <option value="">All</option>
                                <?php foreach ($this->filterOptions['statuses'] as $statusRow): ?>
                                <option value="<?php echo(htmlspecialchars($statusRow['status'])); ?>"<?php echo($this->selectedFilters['status'] === $statusRow['status'] ? ' selected="selected"' : ''); ?>><?php echo(htmlspecialchars($statusRow['status'])); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>

                        <td style="font-size:11px; padding: 6px 8px 2px 0;">
                            Date Available From<br />
                            <input type="date" name="dateAvailableFrom" value="<?php echo(htmlspecialchars($this->selectedFilters['dateAvailableFrom'])); ?>" style="font-size:11px;" />
                        </td>
                        <td style="font-size:11px; padding: 6px 8px 2px 0;">
                            Date Available To<br />
                            <input type="date" name="dateAvailableTo" value="<?php echo(htmlspecialchars($this->selectedFilters['dateAvailableTo'])); ?>" style="font-size:11px;" />
                        </td>
           
                        <td style="font-size:11px; padding: 6px 8px 2px 0;">
                            Date Modified From<br />
                            <input type="date" name="dateModifiedFrom" value="<?php echo(htmlspecialchars($this->selectedFilters['dateModifiedFrom'])); ?>" style="font-size:11px;" />
                        </td>
                        <td style="font-size:11px; padding: 6px 8px 2px 0;">
                            Date Modified To<br />
                            <input type="date" name="dateModifiedTo" value="<?php echo(htmlspecialchars($this->selectedFilters['dateModifiedTo'])); ?>" style="font-size:11px;" />
                        </td>
                    </tr>
                    <tr>
                        <td colspan="5" style="padding: 8px 0 0 0;">
                            <input type="submit" value="Apply Filters" style="font-size:11px;" />
                            &nbsp;
                            <a href="<?php echo(CATSUtility::getIndexName()); ?>?m=recruitmentanalytics&amp;a=funnel" style="font-size:11px;">Clear Filters</a>
                        </td>
                    </tr>
                </table>
                                <script>
                (function () {
                    var years    = <?php echo(json_encode(!empty($this->filterOptions['dateModifiedPeriods']['years'])    ? $this->filterOptions['dateModifiedPeriods']['years']    : array())); ?>;
                    var quarters = <?php echo(json_encode(!empty($this->filterOptions['dateModifiedPeriods']['quarters']) ? $this->filterOptions['dateModifiedPeriods']['quarters'] : array())); ?>;
                    var months   = <?php echo(json_encode(!empty($this->filterOptions['dateModifiedPeriods']['months'])   ? $this->filterOptions['dateModifiedPeriods']['months']   : array())); ?>;
                    var initialValue = <?php echo(json_encode($this->selectedFilters['dateRangeValue'])); ?>;

                    var yearSelect    = document.getElementById('dateRangeYear');
                    var quarterSelect = document.getElementById('dateRangeQuarter');
                    var monthSelect   = document.getElementById('dateRangeMonth');
                    var hiddenInput   = document.getElementById('dateRangeValue');

                    function extractYear(value) {
                        var m = value.match(/^(?:year|quarter|month):(\d{4})/);
                        return m ? m[1] : null;
                    }
                    function quarterOfMonth(value) {
                        var m = value.match(/^month:\d{4}-(\d{2})$/);
                        return m ? (Math.floor((parseInt(m[1], 10) - 1) / 3) + 1) : null;
                    }
                    function quarterNum(value) {
                        var m = value.match(/^quarter:\d{4}-Q([1-4])$/);
                        return m ? parseInt(m[1], 10) : null;
                    }

                    function fillSelect(select, options, placeholderLabel) {
                        select.innerHTML = '';
                        var placeholder = document.createElement('option');
                        placeholder.value = '';
                        placeholder.textContent = placeholderLabel;
                        select.appendChild(placeholder);
                        options.forEach(function (period) {
                            var o = document.createElement('option');
                            o.value = period.value;
                            o.textContent = period.label;
                            select.appendChild(o);
                        });
                    }

                    function populateQuarters(year) {
                        var filtered = quarters.filter(function (q) { return extractYear(q.value) === year; });
                        fillSelect(quarterSelect, filtered, 'All year');
                        quarterSelect.style.display = filtered.length ? '' : 'none';
                        monthSelect.style.display = 'none';
                        monthSelect.innerHTML = '';
                    }

                    function populateMonths(year, qNum) {
                        var filtered = months.filter(function (mo) {
                            return extractYear(mo.value) === year && quarterOfMonth(mo.value) === qNum;
                        });
                        fillSelect(monthSelect, filtered, 'All quarter');
                        monthSelect.style.display = filtered.length ? '' : 'none';
                    }

                    function updateHidden() {
                        if (monthSelect.style.display !== 'none' && monthSelect.value) {
                            hiddenInput.value = monthSelect.value;
                        } else if (quarterSelect.style.display !== 'none' && quarterSelect.value) {
                            hiddenInput.value = quarterSelect.value;
                        } else if (yearSelect.value) {
                            hiddenInput.value = yearSelect.value;
                        } else {
                            hiddenInput.value = '';
                        }
                    }

                    fillSelect(yearSelect, years, 'All time');

                    yearSelect.addEventListener('change', function () {
                        quarterSelect.style.display = 'none';
                        monthSelect.style.display = 'none';
                        quarterSelect.innerHTML = '';
                        monthSelect.innerHTML = '';
                        if (yearSelect.value) {
                            populateQuarters(extractYear(yearSelect.value));
                        }
                        updateHidden();
                    });

                    quarterSelect.addEventListener('change', function () {
                        monthSelect.style.display = 'none';
                        monthSelect.innerHTML = '';
                        if (quarterSelect.value) {
                            populateMonths(extractYear(quarterSelect.value), quarterNum(quarterSelect.value));
                        }
                        updateHidden();
                    });

                    monthSelect.addEventListener('change', updateHidden);

                    /* Restore the current filter (deepest level first) after a page reload. */
                    if (initialValue) {
                        var year = extractYear(initialValue);
                        if (year) {
                            yearSelect.value = 'year:' + year;
                            populateQuarters(year);

                            if (/^quarter:/.test(initialValue)) {
                                quarterSelect.value = initialValue;
                                populateMonths(year, quarterNum(initialValue));
                            } else if (/^month:/.test(initialValue)) {
                                var qNum = quarterOfMonth(initialValue);
                                quarterSelect.value = 'quarter:' + year + '-Q' + qNum;
                                populateMonths(year, qNum);
                                monthSelect.value = initialValue;
                            }
                        }
                    }

                    updateHidden();
                })();
                </script>
            </form>

            <?php if (!count($this->applicationsByRole)): ?>
                <p style="font-size: 11px;">No pipeline entries match the current filters.</p>
            <?php else: ?>
            <?php
                $applicationsTotal = 0;
                foreach ($this->applicationsByRole as $data)
                {
                    $applicationsTotal += $data['count'];
                }
            ?>
            <table style="margin: 0 0 10px 0; width: 50%;">
                <tr>
                    <th align="left" style="font-size:11px;">Role</th>
                    <th align="left" style="font-size:11px;">Applications</th>
                </tr>
                <?php foreach ($this->applicationsByRole as $index => $data): ?>
                <tr class="<?php TemplateUtility::printAlternatingRowClass($index); ?>">
                    <td style="font-size:11px;">
                        <a href="<?php echo(CATSUtility::getIndexName()); ?>?m=recruitmentanalytics&amp;a=funnel&amp;jobOrderID=<?php echo((int) $data['jobOrderID']); ?>"><?php $this->_($data['role']); ?></a>
                    </td>
                    <td style="font-size:11px;"><?php echo((int) $data['count']); ?></td>
                </tr>
                <?php endforeach; ?>
                <tr>
                    <td style="font-size:11px; font-weight: bold; border-top: 1px solid #D0D0D0;">Total</td>
                    <td style="font-size:11px; font-weight: bold; border-top: 1px solid #D0D0D0;"><?php echo((int) $applicationsTotal); ?></td>
                </tr>
            </table>
            <?php endif; ?>

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
                                <td style="font-size:11px;"><?php echo($data['percentOfHires'] !== null ? number_format($data['percentOfHires'], 1) . '%' : 'NA'); ?></td>
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
                                <td style="font-size:11px;"><?php echo($data['conversionRate'] !== null ? number_format($data['conversionRate'], 1) . '%' : 'NA'); ?></td>
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