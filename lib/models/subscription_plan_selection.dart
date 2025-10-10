import 'package:flutter/foundation.dart';

@immutable
class SubscriptionPlanSelection {
  final String id;
  final String name;
  final String subtitle;
  final double monthlyPrice;
  final double annualPrice;
  final bool isAnnual;
  final bool isSchoolPlan;
  final List<String> features;

  const SubscriptionPlanSelection({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.isAnnual,
    this.isSchoolPlan = false,
    this.features = const [],
  });

  double get price => isAnnual ? annualPrice : monthlyPrice;

  String get billingCycleLabel => isSchoolPlan
      ? 'Custom'
      : isAnnual
          ? 'Annual'
          : 'Monthly';

  SubscriptionPlanSelection copyWith({bool? isAnnual}) {
    return SubscriptionPlanSelection(
      id: id,
      name: name,
      subtitle: subtitle,
      monthlyPrice: monthlyPrice,
      annualPrice: annualPrice,
      isAnnual: isAnnual ?? this.isAnnual,
      isSchoolPlan: isSchoolPlan,
      features: features,
    );
  }
}
