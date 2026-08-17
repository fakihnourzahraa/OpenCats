<?php
/*
 * CATS
 * EvaluationScore Library
 *
 * The Original Code is "CATS Standard Edition".
 * This file was added for IBC
 *
 * Turns getFullEvaluation()'s nested stage/criteria/evaluator array into a
 * score, at three levels: per evaluator within a stage, per stage, and the
 * whole evaluation. Each level renormalizes over whatever was actually
 * graded - an evaluator who only graded half the criteria in a stage is
 * scored over that half, not penalized for the blanks. A stage nobody has
 * touched drops out of the total instead of dragging it to zero, so a
 * half-finished evaluation shows a fair running score rather than an
 * artificially low one that climbs as people fill it in.
 *
 * Grades are no longer a fixed 1-5 scale. Each 'score' criterion carries its
 * own max_range (set on the criteria editor, defaulting to 5), and grades
 * run 0..max_range as a double. Because two criteria can have different
 * ranges (a /5 and a /10 in the same stage), grades are normalized to a
 * 0-1 fraction of their own max_range BEFORE being weighted against each
 * other - a 4/5 and an 8/10 are the same fraction and should count the same.
 * The final score is then projected onto a fixed REPORT_SCALE purely for
 * display (the "/5" in formatFull()), independent of any one criterion's
 * range.
 */

class EvaluationScore
{
    /* Grades start at 0. There is no fixed upper bound anymore - each
       criterion supplies its own via max_range. */
    const SCALE_MIN = 0;

    /* Only used for display (formatFull()'s "/5") once everything has
       already been normalized to a 0-1 fraction. Not a validation bound. */
    const REPORT_SCALE = 5;

    /* Fallback when a criterion is missing max_range entirely (old data,
       or a row saved before this column existed). */
    const DEFAULT_MAX_RANGE = 5;

    /*
     * A criterion only counts if it was DECLARED as a graded one. This is
     * what keeps 'Comments' (text) and 'Salary Expectation' (number) out of
     * the arithmetic - they are informational and carry no weight.
     */
    public static function isScored($criterion)
    {
        return (isset($criterion['data_type']) && $criterion['data_type'] === 'score');
    }

    /*
     * A criterion's own ceiling. Anything missing, non-numeric, or <= 0
     * falls back to DEFAULT_MAX_RANGE rather than letting a bad value divide
     * by zero further down.
     */
    public static function maxRange($criterion)
    {
        if (!isset($criterion['max_range']) || !is_numeric($criterion['max_range']))
        {
            return self::DEFAULT_MAX_RANGE;
        }

        $max = (float) $criterion['max_range'];

        return ($max > 0) ? $max : self::DEFAULT_MAX_RANGE;
    }

    /*
     * A blank, a non-numeric string, or anything outside 0..$maxRange is
     * UNANSWERED, not zero. Reading a blank as 0 would silently mark an
     * evaluator's unanswered criterion as the worst possible grade - which
     * is now indistinguishable from an intentional, real 0.
     */
    public static function parseGrade($value, $maxRange = null)
    {
        if ($value === null || $value === '' || !is_numeric($value))
        {
            return null;
        }

        $grade = (float) $value;
        $max   = ($maxRange !== null && $maxRange > 0) ? (float) $maxRange : self::DEFAULT_MAX_RANGE;

        if ($grade < self::SCALE_MIN || $grade > $max)
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
     * An all-zero set (every stage/criterion before anyone touches a weight
     * box, or every row immediately after a fresh migration) falls back to
     * EQUAL shares. Without that this divides by zero.
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
     * One stage.
     *
     * Returns:
     *
     *   score        float|null   0-1 fraction, null when nothing has been graded
     *   percent      float|null   score as a percentage
     *   evaluators   [evaluator_id => float|null]   0-1 fraction per evaluator
     *   shares       [instance_criteria_id => float]   fraction of 1, display only
     *   scoredCount  int          how many criteria are gradeable ('score' type)
     *
     * Two evaluators can end up with scores computed over DIFFERENT
     * denominators - one who graded 3 of 4 gradeable criteria is scored over
     * those 3. That is the renormalisation, and it means their scores are
     * only comparable in the loose sense that both are a 0-1 fraction of
     * "how well they scored on what they did grade."
     *
     * Every grade is converted to a 0-1 fraction of ITS OWN criterion's
     * max_range before being weighted, so a /5 criterion and a /10 criterion
     * combine on equal footing.
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

        /* Collect the gradeable criteria, their raw weights, and their own
           max_range (needed per-criterion below, not just for validation). */
        $weights  = array();
        $maxes    = array();

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
                $maxes[$criteriaID] = self::maxRange($criterion);
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
                $raw = isset($evaluator['grades'][$criteriaID])
                     ? $evaluator['grades'][$criteriaID] : null;

                $grade = self::parseGrade($raw, $maxes[$criteriaID]);

                /* Ungraded: excluded from BOTH sides, so the weight it would
                   have carried is redistributed across what this evaluator
                   did grade. */
                if ($grade === null)
                {
                    continue;
                }

                /* Normalize to a 0-1 fraction of this criterion's own range
                   BEFORE weighting, so a 4/5 and an 8/10 count the same. */
                $fraction = $grade / $maxes[$criteriaID];

                $numerator   += $fraction * $weight;
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
            $result['percent'] = $result['score'] * 100;
        }

        return $result;
    }

    /*
     * Whole evaluation. Takes getFullEvaluation()'s output and returns the
     * same array with a 'scoring' key added to each stage, plus the totals.
     *
     *   stages    the input, each stage annotated with its scoreStage() result
     *   score     float|null  0-1 fraction
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
        $scoredStageWeights = array();
        $stageScoresByID    = array();

        foreach ($result['stages'] as $stage)
        {
            $stageID = (int) $stage['instance_stage_id'];
            $score   = $stage['scoring']['score'];

            if ($score === null)
            {
                continue;
            }

            $scoredStageWeights[$stageID] = max(
                0.0, (float) (isset($stage['weight']) ? $stage['weight'] : 0)
            );
            $stageScoresByID[$stageID] = $score;
        }

        if (empty($scoredStageWeights))
        {
            return $result;
        }

        if (array_sum($scoredStageWeights) <= 0)
        {
            foreach ($scoredStageWeights as $stageID => $ignored)
            {
                $scoredStageWeights[$stageID] = 1.0;
            }
        }

        $numerator   = 0.0;
        $denominator = 0.0;

        foreach ($scoredStageWeights as $stageID => $weight)
        {
            $numerator   += $stageScoresByID[$stageID] * $weight;
            $denominator += $weight;
        }

        if ($denominator > 0)
        {
            $result['score']   = $numerator / $denominator;
            $result['percent'] = $result['score'] * 100;
        }

        return $result;
    }

    /* Display helpers. $score here is always the 0-1 fraction scoreStage()/
       scoreEvaluation() return - NOT a raw grade - so every caller (evaluate
       page, candidate list, CSV export) formats a null score the same way
       rather than each inventing its own placeholder text. */

    /* '3.90' - the fraction projected onto REPORT_SCALE, two decimals. Never
       '0.00' when null; an em dash instead, since a real 0 score is a
       legitimate result now and must not read the same as "ungraded". */
    public static function format($score)
    {
        return ($score === null) ? '-' : number_format($score * self::REPORT_SCALE, 2);
    }

    /* '78%'. */
    public static function formatPercent($score)
    {
        if ($score === null)
        {
            return '-';
        }

        return number_format($score * 100, 0) . '%';
    }

    /* '78% (3.90/5)' - percent leads, raw/REPORT_SCALE follows. */
    public static function formatFull($score)
    {
        if ($score === null)
        {
            return '-';
        }

        return sprintf(
            '%s (%s/%d)',
            self::formatPercent($score),
            self::format($score),
            self::REPORT_SCALE
        );
    }
}
?>