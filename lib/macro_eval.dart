import 'package:flutter/material.dart';

/// Macro-friendliness scoring for recipes and the daily log.
///
/// The recipe scoring mirrors the backend implementation in
/// pulse/services/macro_eval_service.py — keep the two in sync.
class MacroEval {
  final int score;
  final String label;
  final String rating; // great | good | okay | poor | unknown
  final List<String> reasons;

  const MacroEval({
    required this.score,
    required this.label,
    required this.rating,
    required this.reasons,
  });

  Color get color => switch (rating) {
        'great' => const Color(0xFF22C55E),
        'good' => const Color(0xFFA3E635),
        'okay' => const Color(0xFFF59E0B),
        'poor' => const Color(0xFFEF4444),
        _ => const Color(0xFF5A5A6E),
      };
}

/// Score a recipe's per-serving macros against a goal (bulk/cut/recomp/maintain).
MacroEval evaluateRecipeMacros(
    double calories, double proteinG, double carbG, double fatG, String goal) {
  goal = goal.toLowerCase();
  if (calories <= 0) {
    return const MacroEval(
        score: 0, label: 'No macro data', rating: 'unknown', reasons: []);
  }

  final reasons = <String>[];

  // Protein density (0-60)
  final proteinPer100 = proteinG * 100 / calories;
  final proteinScore = (proteinPer100 / 8.0).clamp(0.0, 1.0) * 60;
  if (proteinPer100 >= 8) {
    reasons.add('Excellent protein: ${proteinPer100.round()}g per 100 kcal');
  } else if (proteinPer100 >= 5) {
    reasons.add('Solid protein: ${proteinPer100.round()}g per 100 kcal');
  } else {
    reasons.add('Low protein: only ${proteinPer100.round()}g per 100 kcal');
  }

  // Goal fit by calories per serving (0-25)
  int goalScore;
  String msg;
  if (goal == 'cut') {
    if (calories <= 400) {
      goalScore = 25; msg = 'Light per serving — easy to fit in a deficit';
    } else if (calories <= 550) {
      goalScore = 18; msg = 'Moderate calories — portion carefully on a cut';
    } else if (calories <= 700) {
      goalScore = 10; msg = 'Calorie-dense for a cut — watch portions';
    } else {
      goalScore = 3; msg = 'Heavy for a cut (${calories.round()} kcal/serving)';
    }
  } else if (goal == 'bulk') {
    if (calories >= 550) {
      goalScore = 25; msg = 'Calorie-dense — great for hitting a surplus';
    } else if (calories >= 400) {
      goalScore = 20; msg = 'Decent calories per serving for a bulk';
    } else if (calories >= 250) {
      goalScore = 12; msg = 'A bit light for a bulk — take extra servings';
    } else {
      goalScore = 6; msg = 'Very light — hard to hit a surplus with this';
    }
  } else {
    if (calories >= 300 && calories <= 650) {
      goalScore = 25; msg = 'Well-sized serving for maintenance';
    } else if (calories < 300) {
      goalScore = 15; msg = 'Light serving — fine as a smaller meal';
    } else {
      goalScore = 12; msg = 'Large serving — balance the rest of the day';
    }
  }
  reasons.add(msg);

  // Macro balance: fat share of calories (0-15)
  final fatShare = (fatG * 9) / calories;
  int balanceScore;
  if (fatShare >= 0.15 && fatShare <= 0.40) {
    balanceScore = 15;
  } else if (fatShare < 0.15) {
    balanceScore = 10;
  } else {
    balanceScore = (15 - ((fatShare - 0.40) * 50)).round().clamp(0, 15);
    reasons.add('High fat: ${(fatShare * 100).round()}% of calories from fat');
  }

  final score = (proteinScore + goalScore + balanceScore).round();
  final goalWord = switch (goal) {
    'cut' => 'cutting',
    'bulk' => 'bulking',
    'recomp' => 'recomp',
    _ => 'maintenance',
  };
  final (rating, label) = switch (score) {
    >= 75 => ('great', 'Great for $goalWord'),
    >= 55 => ('good', 'Good for $goalWord'),
    >= 35 => ('okay', 'Okay for $goalWord'),
    _ => ('poor', 'Poor fit for $goalWord'),
  };

  return MacroEval(score: score, label: label, rating: rating, reasons: reasons);
}

/// Evaluate today's logged totals against the plan targets.
MacroEval evaluateDay({
  required double loggedCal,
  required double targetCal,
  required double loggedProtein,
  required double targetProtein,
  required double loggedFat,
  required double targetFat,
  required String goal,
}) {
  goal = goal.toLowerCase();
  if (targetCal <= 0) {
    return const MacroEval(
        score: 0, label: 'No plan targets', rating: 'unknown', reasons: []);
  }

  final reasons = <String>[];
  final calPct = loggedCal / targetCal;
  final proteinLeft = (targetProtein - loggedProtein).clamp(0, targetProtein).toDouble();
  final calLeft = targetCal - loggedCal;

  // Calorie budget status (0-50)
  int calScore;
  if (calPct <= 1.05) {
    calScore = 50;
    if (calLeft > 0) {
      reasons.add('${calLeft.round()} kcal left in today\'s budget');
    } else {
      reasons.add('Right on your calorie target');
    }
  } else if (calPct <= 1.15) {
    calScore = 30;
    reasons.add('${(loggedCal - targetCal).round()} kcal over target');
  } else {
    calScore = goal == 'bulk' ? 30 : 10;
    reasons.add('${(loggedCal - targetCal).round()} kcal over — '
        '${goal == 'cut' ? 'this eats into your deficit' : 'well past target'}');
  }

  // Protein pace vs calorie pace (0-40): protein should keep up with calories.
  int proteinScore;
  final proteinPct = targetProtein > 0 ? loggedProtein / targetProtein : 0.0;
  if (proteinPct >= 0.95) {
    proteinScore = 40;
    reasons.add('Protein target hit (${loggedProtein.round()}g)');
  } else if (proteinPct + 0.10 >= calPct) {
    proteinScore = 40;
    reasons.add('Protein on pace — ${proteinLeft.round()}g to go');
  } else if (proteinPct + 0.25 >= calPct) {
    proteinScore = 25;
    reasons.add('Protein lagging — prioritize it: ${proteinLeft.round()}g to go');
  } else {
    proteinScore = 10;
    reasons.add('Protein far behind calories — ${proteinLeft.round()}g still needed');
  }

  // Fat sanity (0-10)
  int fatScore = 10;
  if (targetFat > 0 && loggedFat > targetFat * 1.25) {
    fatScore = 3;
    reasons.add('Fat well over target (${loggedFat.round()}g / ${targetFat.round()}g)');
  }

  final score = calScore + proteinScore + fatScore;
  final (rating, label) = switch (score) {
    >= 80 => ('great', 'On track'),
    >= 60 => ('good', 'Mostly on track'),
    >= 40 => ('okay', 'Needs attention'),
    _ => ('poor', 'Off track today'),
  };
  return MacroEval(score: score, label: label, rating: rating, reasons: reasons);
}
