<?php
/*
 * CATS
 * Evaluation Scoring
 *
 * The Original Code is "CATS Standard Edition".
 * This file was added for IBC
 *
 * Pure arithmetic over the nested array Evaluations::getFullEvaluation()
 * returns. Nothing here touches the database, which is what lets the evaluate
 * page, the candidate detail list and the export all score identically.
 *
 * The model, in one place:
 *
 *   stageScore(evaluator) = SUM(grade * weight) / SUM(weight)
 *                           over the scored criteria THAT EVALUATOR ANSWERED
 *
 *   stageScore           = mean of stageScore(evaluator)
 *                           over evaluators who graded at least one criterion
 *
 *   total                = SUM(stageScore * stageWeight) / SUM(stageWeight)
 *                           over stages that HAVE a score
 *
 * Renormalisation happens at all three levels. That is the whole point: a
 * stage nobody has touched drops out of the total instead of dragging it to
 * zero, so a half-finished evaluation shows a fair running score rather than
 * an artificially low one that climbs as people fill it in.
 */

class EvaluationScore
{
    /* Grades are integers 1-5. */
    const SCALE_MIN = 1;
    const SCALE_MAX = 5;

    /*
     * A criterion only counts if it was DECLARED as a graded one. This is what
     * keeps 'Comments' (text) and 'Salary Expectation' (number) out of the
     * arithmetic - they are informational and carry no weight.
     */
    public static function isScored($criterion)
    {
        return (isset($criterion['data_type']) && $criterion['data_type'] === 'score');
    }

    /*
     * A blank, a non-numeric string, or anything outside 1-5 is UNANSWERED,
     * not zero. Reading a blank as 0 would silently mark an evaluator's
     * unanswered criterion as the worst possible grade.
     */
    public static function parseGrade($value)
    {
        if ($value === null || $value === '' || !is_numeric($value))
        {
            return null;
        }

        $grade = (float) $value;

        if ($grade < self::SCALE_MIN || $grade > self::SCALE_MAX)
        {
            return null;
        }

        return $grade;
    }

    /*
     * Weights are whatever the user typed - they are NOT required to sum to
     * anything. Their share is what matters, so this converts a raw set into
     * fractions of 1.
     *
     * An all-zero set (which is every row in the database immediately after
     * the migration, and any stage where nobody has set weights yet) falls
     * back to EQUAL shares. Without that this divides by zero on the first
     * page load after upgrading.
     */
    public static function normalizeWeights(array $weights)
    {
        $total = 0.0;
        foreach ($weights as $weight)
        {
            $total += max(0.0, (float) $weight);
        }

        if (count($weights) === 0)
        {
            return array();
        }

        if ($total <= 0)
        {
            $equalShare = 1.0 / count($weights);

            $out = array();
            foreach ($weights as $key => $ignored)
            {
                $out[$key] = $equalShare;
            }
            return $out;
        }

        $out = array();
        foreach ($weights as $key => $weight)
        {
            $out[$key] = max(0.0, (float) $weight) / $total;
        }
        return $out;
    }

    /*
     * One stage. Returns:
     *
     *   score        float|null   0-5, null when nothing has been graded
     *   percent      float|null   score as a percentage of the 1-5 scale
     *   evaluators   [evaluator_id => float|null]
     *   shares       [criteria_id  => float]   fraction of 1, for display
     *   scoredCount  int          how many criteria are graded ones
     *
     * Two evaluators can end up with scores computed over DIFFERENT
     * denominators - one who answered 3 of 4 criteria is scored over those 3.
     * That is the renormalisation, and it means their scores are only
     * comparable in the loose sense that both are "out of 5".
     */
    public static function scoreStage(array $stage)
    {
        $result = array(
            'score'       => null,
            'percent'     => null,
            'evaluators'  => array(),
            'shares'      => array(),
            'scoredCount' => 0,
        );

        /* Collect the graded criteria and their raw weights. */
        $weights = array();
        if (!empty($stage['criteria']))
        {
            foreach ($stage['criteria'] as $criterion)
            {
                if (!self::isScored($criterion))
                {
                    continue;
                }

                $criteriaID = (int) $criterion['instance_criteria_id'];
                $weights[$criteriaID] = max(
                    0.0, (float) (isset($criterion['weight']) ? $criterion['weight'] : 0)
                );
            }
        }

        $result['scoredCount'] = count($weights);
        $result['shares']      = self::normalizeWeights($weights);

        if (empty($weights) || empty($stage['evaluators']))
        {
            return $result;
        }

        /* Same equal-share fallback the shares got, applied to the raw
           weights the arithmetic below actually divides by. */
        if (array_sum($weights) <= 0)
        {
            foreach ($weights as $criteriaID => $ignored)
            {
                $weights[$criteriaID] = 1.0;
            }
        }

        $stageScores = array();

        foreach ($stage['evaluators'] as $evaluator)
        {
            $numerator   = 0.0;
            $denominator = 0.0;

            foreach ($weights as $criteriaID => $weight)
            {
                $raw = isset($evaluator['values'][$criteriaID])
                     ? $evaluator['values'][$criteriaID] : null;

                $grade = self::parseGrade($raw);

                /* Unanswered: excluded from BOTH sides, so the weight it
                   would have carried is redistributed across what this
                   evaluator did answer. */
                if ($grade === null)
                {
                    continue;
                }

                $numerator   += $grade * $weight;
                $denominator += $weight;
            }

            $evaluatorScore = ($denominator > 0) ? ($numerator / $denominator) : null;

            $result['evaluators'][(int) $evaluator['evaluator_id']] = $evaluatorScore;

            if ($evaluatorScore !== null)
            {
                $stageScores[] = $evaluatorScore;
            }
        }

        if (!empty($stageScores))
        {
            $result['score']   = array_sum($stageScores) / count($stageScores);
            $result['percent'] = ($result['score'] / self::SCALE_MAX) * 100;
        }

        return $result;
    }

    /*
     * Whole evaluation. Takes getFullEvaluation()'s output and returns the
     * same array with a 'scoring' key added to each stage, plus the totals.
     *
     *   stages    the input, each stage annotated with its scoreStage() result
     *   score     float|null  0-5
     *   percent   float|null
     *   shares    [instance_stage_id => float]  stage weight shares, display
     */
    public static function scoreEvaluation(array $stages)
    {
        $result = array(
            'stages'  => $stages,
            'score'   => null,
            'percent' => null,
            'shares'  => array(),
        );

        if (empty($stages))
        {
            return $result;
        }

        $stageWeights = array();

        foreach ($result['stages'] as $index => $stage)
        {
            $stageID = (int) $stage['instance_stage_id'];

            $result['stages'][$index]['scoring'] = self::scoreStage($stage);

            $stageWeights[$stageID] = max(
                0.0, (float) (isset($stage['weight']) ? $stage['weight'] : 0)
            );
        }

        $result['shares'] = self::normalizeWeights($stageWeights);

        /* Only stages that actually HAVE a score participate. An ungraded
           stage is absent from the total, not a zero in it. */
        $numerator   = 0.0;
        $denominator = 0.0;
        $scoredStages = array();

        foreach ($result['stages'] as $stage)
        {
            if ($stage['scoring']['score'] === null)
            {
                continue;
            }

            $stageID = (int) $stage['instance_stage_id'];
            $scoredStages[$stageID] = $stage['scoring']['score'];

            $numerator   += $stage['scoring']['score'] * $stageWeights[$stageID];
            $denominator += $stageWeights[$stageID];
        }

        if (empty($scoredStages))
        {
            return $result;
        }

        /* Every participating stage weighted zero: fall back to a plain mean
           rather than reporting nothing. */
        if ($denominator <= 0)
        {
            $result['score'] = array_sum($scoredStages) / count($scoredStages);
        }
        else
        {
            $result['score'] = $numerator / $denominator;
        }

        $result['percent'] = ($result['score'] / self::SCALE_MAX) * 100;

        return $result;
    }

    /* '4.30', or an em dash when nothing has been graded yet. Never '0.00' -
       zero is a real grade-adjacent number and would read as a bad score. */
    public static function format($score)
    {
        return ($score === null) ? '&mdash;' : number_format((float) $score, 2);
    }

    /*
     * '79%'. This is score / 5, so a straight-1s evaluation reads 20% rather
     * than 0%. The alternative - (score - 1) / 4 - is arguably truer to a 1-5
     * scale having only four intervals of real range, but reads oddly.
     */
    public static function formatPercent($score)
    {
        if ($score === null)
        {
            return '&mdash;';
        }

        return number_format(((float) $score / self::SCALE_MAX) * 100, 0) . '%';
    }

    /* '4.30 / 5 (86%)' for a one-line display. */
    public static function formatFull($score)
    {
        if ($score === null)
        {
            return '&mdash;';
        }

        return sprintf(
            '%s / %d (%s)',
            self::format($score),
            self::SCALE_MAX,
            self::formatPercent($score)
        );
    }
}
?>