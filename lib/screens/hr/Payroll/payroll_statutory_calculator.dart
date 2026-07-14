/// Pure, IO-free Kenyan statutory payroll deduction calculator.
///
/// Rates reflect the Finance Act 2023 / Tax Laws (Amendment) Act 2024 regime
/// (PAYE bands effective Jul 2023, NSSF Tier I/II post-transition rates,
/// SHIF replacing NHIF at 2.75% of gross from Oct 2024, and the Affordable
/// Housing Levy at 1.5% of gross). These are `static const` on purpose so a
/// future rate change is a one-file diff — update the constants below and
/// nothing else needs to change.
class PayrollStatutoryCalculator {
  const PayrollStatutoryCalculator._();

  // ── PAYE bands (KES, monthly, cumulative) ───────────────────────────────
  static const double _payeBand1 = 24000; // 10%
  static const double _payeBand2 = 32333; // 25%
  static const double _payeBand3 = 500000; // 30%
  static const double _payeBand4 = 800000; // 32.5%
  // Above _payeBand4: 35%
  static const double payeMonthlyPersonalRelief = 2400;

  // ── NSSF (Tier I / Tier II) ──────────────────────────────────────────────
  static const double nssfTier1Ceiling = 8000;
  static const double nssfTier2Ceiling = 72000;
  static const double nssfRate = 0.06;
  static const double nssfTier1MaxContribution = nssfTier1Ceiling * nssfRate; // 480
  static const double nssfTier2MaxContribution =
      (nssfTier2Ceiling - nssfTier1Ceiling) * nssfRate; // 3,840
  static const double nssfMaxTotalContribution =
      nssfTier1MaxContribution + nssfTier2MaxContribution; // 4,320

  // ── SHIF (Social Health Insurance Fund) ──────────────────────────────────
  static const double shifRate = 0.0275;
  static const double shifMinimumContribution = 300;

  // ── Affordable Housing Levy ──────────────────────────────────────────────
  static const double housingLevyRate = 0.015;

  /// Computes PAYE on [grossPay], applying the cumulative band structure and
  /// subtracting the fixed monthly personal relief (floored at 0).
  static double calculatePaye(double grossPay) {
    if (grossPay <= 0) return 0;

    double tax = 0;
    double remaining = grossPay;

    double band(double lower, double upper, double rate) {
      if (remaining <= 0) return 0;
      final span = (upper - lower).clamp(0, double.infinity);
      final taxable = remaining > span ? span : remaining;
      remaining -= taxable;
      return taxable * rate;
    }

    tax += band(0, _payeBand1, 0.10);
    tax += band(_payeBand1, _payeBand2, 0.25);
    tax += band(_payeBand2, _payeBand3, 0.30);
    tax += band(_payeBand3, _payeBand4, 0.325);
    if (remaining > 0) {
      tax += remaining * 0.35;
    }

    final net = tax - payeMonthlyPersonalRelief;
    return net > 0 ? net : 0;
  }

  /// Employee NSSF contribution (Tier I + Tier II), capped at the statutory
  /// maximum regardless of how high [grossPay] is.
  static double calculateNssf(double grossPay) {
    if (grossPay <= 0) return 0;
    final tier1 = grossPay < nssfTier1Ceiling
        ? grossPay * nssfRate
        : nssfTier1MaxContribution;

    double tier2 = 0;
    if (grossPay > nssfTier1Ceiling) {
      final tier2Pensionable =
          (grossPay - nssfTier1Ceiling).clamp(0, nssfTier2Ceiling - nssfTier1Ceiling);
      tier2 = tier2Pensionable * nssfRate;
    }

    final total = tier1 + tier2;
    return total > nssfMaxTotalContribution ? nssfMaxTotalContribution : total;
  }

  /// SHIF contribution: 2.75% of gross pay, floored at the statutory minimum.
  static double calculateShif(double grossPay) {
    if (grossPay <= 0) return shifMinimumContribution;
    final computed = grossPay * shifRate;
    return computed < shifMinimumContribution ? shifMinimumContribution : computed;
  }

  /// Affordable Housing Levy: 1.5% of gross pay, uncapped.
  static double calculateHousingLevy(double grossPay) {
    if (grossPay <= 0) return 0;
    return grossPay * housingLevyRate;
  }

  /// Computes the full statutory breakdown for a given [grossPay] in one call.
  static StatutoryBreakdown calculateAll({required double grossPay}) {
    final paye = calculatePaye(grossPay);
    final nssf = calculateNssf(grossPay);
    final shif = calculateShif(grossPay);
    final housingLevy = calculateHousingLevy(grossPay);
    return StatutoryBreakdown(
      payeTax: paye,
      nssfDeduction: nssf,
      shifDeduction: shif,
      housingLevy: housingLevy,
      total: paye + nssf + shif + housingLevy,
    );
  }
}

/// Bundled result of [PayrollStatutoryCalculator.calculateAll].
class StatutoryBreakdown {
  final double payeTax;
  final double nssfDeduction;
  final double shifDeduction;
  final double housingLevy;
  final double total;

  const StatutoryBreakdown({
    required this.payeTax,
    required this.nssfDeduction,
    required this.shifDeduction,
    required this.housingLevy,
    required this.total,
  });
}
