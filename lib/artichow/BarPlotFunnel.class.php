<?php
/**
 * awBarPlotFunnel
 *
 * New class, not part of the original Artichow distribution.
 *
 * Extends awBarPlotPipeline for the recruitment funnel chart, with two
 * deliberate departures from the parent's behavior:
 *
 * 1. No skew-compression. awBarPlotPipeline silently rescales later bars
 *    upward if an early bar drops below 50% of the one before it, so bars
 *    stay visible even after a steep drop-off. For the funnel we want bar
 *    height to be a true, literal proportion of candidate count, so that
 *    block of logic is removed entirely rather than overridden - it isn't
 *    reused for anything else here.
 *
 * 2. Percentage label is computed as percent of the PREVIOUS stage
 *    (value[key] / value[key - 1]), not percent of the plot's max value
 *    (which awBarPlotPipeline always uses). This matches the "% of going
 *    to next stage" metric in the reference mockup. The first stage has
 *    no previous stage, so it's intentionally left unlabeled with a
 *    percentage (matching the mockup's plain "100%" / no-parens treatment
 *    - the caller can prepend that separately if desired).
 *
 * Everything else - bar drawing, shadow, border, background gradient,
 * value label via drawSpecial()/label->draw() - is inherited unchanged
 * from awBarPlotPipeline.
 *
 * @package Artichow
 */

require_once dirname(__FILE__)."/BarPlotPipeline.class.php";

class awBarPlotFunnel extends awBarPlotPipeline {

	public function drawComponent(awDrawer $drawer, $x1, $y1, $x2, $y2, $aliasing) {

		$datayReal = $this->datay;

		$count = count($this->datay);
		$max = $this->getRealYMax(NULL);
		$min = $this->getRealYMin(NULL);

		// Find zero for bars
		if($this->xAxisZero and $min <= 0 and $max >= 0) {
			$zero = 0;
		} else if($max < 0) {
			$zero = $max;
		} else {
			$zero = $min;
		}

		// Get base position
		$zero = awAxis::toPosition($this->xAxis, $this->yAxis, new awPoint(0, $zero));

		// Distance between two values on the graph
		$distance = $this->xAxis->getDistance(0, 1);

		// Compute paddings
		$leftPadding = $this->barPadding->left * $distance;
		$rightPadding = $this->barPadding->right * $distance;

		$padding = $leftPadding + $rightPadding;
		$space = $this->barSpace * ($this->number - 1);

		$barSize = ($distance - $padding - $space) / $this->number;
		$barPosition = $leftPadding + $barSize * ($this->identifier - 1);

		// No skew-compression pass here (this is the deliberate omission
		// vs. awBarPlotPipeline::drawComponent() - bars are drawn strictly
		// proportional to $this->datay as given).

		for($key = 0; $key < $count; $key++) {

			$value = $this->datay[$key];

			if($value !== NULL) {

				$position = awAxis::toPosition(
					$this->xAxis,
					$this->yAxis,
					new awPoint($key, $value)
				);

				$barStart = $barPosition + ($this->identifier - 1) * $this->barSpace + $position->x;
				$barStop = $barStart + $barSize;

				$t1 = min($zero->y, $position->y);
				$t2 = max($zero->y, $position->y);

				if(round($t2 - $t1) == 0) {
					continue;
				}

				$p1 = new awPoint(
					round($barStart) + $this->depth + $this->move->left,
					round($t1) - $this->depth + $this->move->top
				);

				$p2 = new awPoint(
					round($barStop) + $this->depth + $this->move->left,
					round($t2) - $this->depth + $this->move->top
				);

				$this->drawBar($drawer, $p1, $p2, $key);

			}

		}

		$maxValue = $this->maxValue;

		// Draw labels
		foreach($datayReal as $key => $value) {

			if($value !== NULL) {

				if ($value > $maxValue)
				{
					$maxValue = $value;
				}

				$position = awAxis::toPosition(
					$this->xAxis,
					$this->yAxis,
					new awPoint($key, $this->datay[$key])
				);

				$position2 = awAxis::toPosition(
					$this->xAxis,
					$this->yAxis,
					new awPoint($key, $this->datay[$key] / 2)
				);

				$point = new awPoint(
					$barPosition + ($this->identifier - 1) * $this->barSpace + $position->x + $barSize / 2 + 1 + $this->depth,
					$position->y - $this->depth
				);

				$point2 = new awPoint(
					$barPosition + ($this->identifier - 1) * $this->barSpace + $position2->x + $barSize / 2 + 1 + $this->depth,
					$position2->y - $this->depth
				);

				if($maxValue == 0)
				{
					$maxValue = 1;
				}

				if($value != 0 && $this->drawPercent)
				{
					/* Percent of the PREVIOUS stage, not percent of max.
					 * First stage (key === 0, or no prior value) has no
					 * previous stage to compare against, so it's shown
					 * as the bare count with no parenthetical - matching
					 * the mockup's plain "100%"/first-row treatment. */
					$formattedValue = number_format($value);

					if ($key > 0 && isset($datayReal[$key - 1]) && $datayReal[$key - 1] != 0)
					{
						$percent = round(($value / $datayReal[$key - 1]) * 100, 2);
						$combinedLabel = $formattedValue . ' (' . $percent . '%)';
					}
					else
					{
						$combinedLabel = $formattedValue;
					}

					/* Single label, drawn once at the bar's midpoint,
					 * replacing the parent's two separately-positioned
					 * draw()/drawSpecial() calls. */
					$this->label->drawSpecial($drawer, $point2, $key, $combinedLabel);
				}
			}
		}
	}

}

registerClass('BarPlotFunnel');
?>