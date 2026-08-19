<?php
/**
 * BarPlotLabeled.class.php
 * Added for IBC
 *
 * Plain (non-cumulative) bar plot with a value label drawn centered
 * inside each bar - same label placement/style as BarPlotFunnel
 * (mid-bar position, drawn via label->drawSpecial() as plain text, not
 * the generic awBarPlot::drawComponent() top-of-bar label placement
 * which goes through label->draw() and picks up background/border
 * styling instead).
 *
 * Extends awBarPlot directly, NOT awBarPlotPipeline/awBarPlotFunnel -
 * there's no cumulative/tapered/totalValue relationship between bars
 * here (unlike the funnel, where each bar is a fraction of a running
 * total). Each bar is an independent value, so the percent-of-previous
 * calculation BarPlotFunnel does is dropped; the label is just the
 * bar's own value, formatted to 1 decimal place (average days).
 */

require_once dirname(__FILE__)."/BarPlot.class.php";

class awBarPlotLabeled extends awBarPlot {

	public function drawComponent(awDrawer $drawer, $x1, $y1, $x2, $y2, $aliasing) {

		$count = count($this->datay);
		$max = $this->getRealYMax(NULL);
		$min = $this->getRealYMin(NULL);

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

				$this->drawBar($drawer, $p1, $p2);

			}

		}

		// Draw labels - centered mid-bar (value / 2), same positioning
		// BarPlotFunnel uses, via drawSpecial() so it's plain text, not
		// boxed/backgrounded like the base class's label->draw() path.
		foreach($this->datay as $key => $value) {

			if($value !== NULL && $value != 0) {

				$position2 = awAxis::toPosition(
					$this->xAxis,
					$this->yAxis,
					new awPoint($key, $value / 2)
				);

				$point2 = new awPoint(
					$barPosition + ($this->identifier - 1) * $this->barSpace + $position2->x + $barSize / 2 + 1 + $this->depth,
					$position2->y - $this->depth
				);

				$formattedValue = number_format($value, 1);

				$this->label->drawSpecial($drawer, $point2, $key, $formattedValue);

			}

		}

	}

}

registerClass('BarPlotLabeled');
?>