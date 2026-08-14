<?php
/*
 * Evaluation Scoring
 */

class EvaluationScore
{

    const SCALE_MIN = 1;
    const SCALE_MAX = 5;


    public static function isScored($criterion)
    {
        return (isset($criterion['is_gradeable']) && (int) $criterion['is_gradeable'] === 1);
    }

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


    public static function scoreStage(array $stage)
    {
        $result = array(
            'score'       => null,
            'percent'     => null,
            'evaluators'  => array(),
            'shares'      => array(),
            'scoredCount' => 0,
        );

        /* Collect the gradeable criteria and their raw weights. */
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

                $grade = self::parseGrade($raw);


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
            $result['percent'] = ($result['score'] / self::SCALE_MAX) * 100;
        }

        return $result;
    }

    public static function format($score)
    {
        return ($score === null) ? '—' : number_format((float) $score, 1);
    }

    public static function formatPercent($score)
    {
        if ($score === null)
        {
            return '';
        }
        return (string) round(((float) $score / self::SCALE_MAX) * 100) . '%';
    }
}
?>