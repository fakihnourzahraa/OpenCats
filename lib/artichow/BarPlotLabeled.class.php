<?php
/**
 * BarPlotLabeled.class.php
 * Added for IBC
 *
 * Plain (non-cumulative) bar plot with a value label drawn above each
 * bar - same drawSpecial()-based approach as BarPlotFunnel (plain text,
 * not the generic awBarPlot::drawComponent() label placement which goes
 * through label->draw() and picks up background/border styling
 * instead), but positioned above the bar's top edge rather than
 * mid-bar, and drawn bold.
 *
 * Extends awBarPlot directly, NOT awBarPlotPipeline/awBarPlotFunnel -
 * there's no cumulative/tapered/totalValue relationship between bars
 * here (unlike the funnel, where each bar is a fraction of a running
 * total). Each bar is an independent value, so the percent-of-previous
 * calculation BarPlotFunnel does is dropped; the label is just the
 * bar's own value, formatted to 1 decimal place (average days).
 *
 * BOLD NOTE: this codebase's fonts (Tuffy(7), Tuffy(8), etc.) don't
 * have a confirmed bold variant available (no TuffyBold or similar seen
 * in lib/artichow/fonts/ so far). Rather than guess a class name that
 * might not exist and fatal, bold is faked here by drawing the label
 * twice with a 1px horizontal offset - font-agnostic, no dependency on
 * a bold font file existing. If a real bold font class is available,
 * swap the double-draw below for a single drawSpecial() call using it.
 */

require_once dirname(__FILE__)."/BarPlot.class.php";

class awBarPlotLabeled extends awBarPlot {

	// Vertical gap (in pixels) between the bar's top edge and the label
	// drawn above it.
	const LABEL_OFFSET = 14;

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

		// Draw labels - above the bar's top edge (not mid-bar), drawn
		// twice with a 1px x-offset to fake bold weight.
		foreach($this->datay as $key => $value) {

			if($value !== NULL && $value != 0) {

				$position = awAxis::toPosition(
					$this->xAxis,
					$this->yAxis,
					new awPoint($key, $value)
				);

				$labelPoint = new awPoint(
					$barPosition + ($this->identifier - 1) * $this->barSpace + $position->x + $barSize / 2 + 1 + $this->depth,
					$position->y - $this->depth - self::LABEL_OFFSET
				);

				$formattedValue = number_format($value, 1);

				// Faux-bold: draw twice, 1px apart horizontally.
				$labelPointBold = new awPoint($labelPoint->x + 1, $labelPoint->y);
				$this->label->drawSpecial($drawer, $labelPoint, $key, $formattedValue);
				$this->label->drawSpecial($drawer, $labelPointBold, $key, $formattedValue);

			}

		}

	}

}

registerClass('BarPlotLabeled');
?>