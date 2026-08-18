<?php
/**
 * BarPlotFunnel.class.php
 * Added for IBC
 */

require_once dirname(__FILE__)."/BarPlotPipeline.class.php";

class awBarPlotFunnel extends awBarPlotPipeline {

	public function drawComponent(awDrawer $drawer, $x1, $y1, $x2, $y2, $aliasing) {

		$datayReal = $this->datay;

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

		//get base position
		$zero = awAxis::toPosition($this->xAxis, $this->yAxis, new awPoint(0, $zero));

		//distance between two values on the graph
		$distance = $this->xAxis->getDistance(0, 1);
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

				$this->drawBar($drawer, $p1, $p2, $key);

			}

		}

		$maxValue = $this->maxValue;

		foreach($datayReal as $key => $value) {

			if($value !== NULL) {

				if ($value > $maxValue)
					$maxValue = $value;

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
					$maxValue = 1;

				if($value != 0 && $this->drawPercent)
				{
					$formattedValue = number_format($value);

					if ($key > 0 && isset($datayReal[$key - 1]) && $datayReal[$key - 1] != 0)
					{
						$percent = round(($value / $datayReal[$key - 1]) * 100);
						$combinedLabel = $formattedValue . ' (' . $percent . '%)';
					}
					else
					{
						$combinedLabel = $formattedValue;
					}
					$this->label->drawSpecial($drawer, $point2, $key, $combinedLabel);
				}
			}
		}
	}

}

registerClass('BarPlotFunnel');
?>