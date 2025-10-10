import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subscription_plan_selection.dart';

enum PaymentMethod { card, mobileMoney, bankTransfer, ussd }

enum PaymentStatus { success, failure }

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final Color _navy = const Color(0xFF1A1E3F);
  final Color _red = const Color(0xFFD62828);
  final Color _green = const Color(0xFF2ECC71);
  final Color _warmWhite = const Color(0xFFF8FAFE);

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();

  final TextEditingController _mobileMoneyNumberController = TextEditingController();
  final TextEditingController _mobileMoneyNameController = TextEditingController();

  final TextEditingController _proofUploadController = TextEditingController();

  final TextEditingController _couponController = TextEditingController();

  final GlobalKey<FormState> _accountFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _cardFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _mobileMoneyFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isAnnualBilling = false;
  bool _couponSuccess = false;
  String? _couponMessage;
  double _couponValue = 0;
  bool _saveCard = false;
  bool _autoRenew = true;
  bool _creatingAccount = true;
  bool _showProcessing = false;

  PaymentMethod _selectedMethod = PaymentMethod.card;
  PaymentStatus _paymentStatus = PaymentStatus.success;

  SubscriptionPlanSelection? _selectedPlan;
  bool _initializedFromArgs = false;

  List<SubscriptionPlanSelection> get _plans {
    return [
      SubscriptionPlanSelection(
        id: 'free',
        name: 'Free',
        subtitle: 'Get Started',
        monthlyPrice: 0,
        annualPrice: 0,
        isAnnual: _isAnnualBilling,
        features: [
          'Trivia & gamification challenges',
          'Classic literature library',
          '5 past questions per subject monthly',
          'Sample textbook chapters',
          'Community support access',
        ],
      ),
      SubscriptionPlanSelection(
        id: 'standard',
        name: 'Standard',
        subtitle: 'Everything You Need',
        monthlyPrice: 9.99,
        annualPrice: 99,
        isAnnual: _isAnnualBilling,
        features: [
          'All NACCA-aligned textbooks (JHS 1-3)',
          'Unlimited past questions (1990-2024)',
          'Student analytics dashboard',
          'Weekly parent progress reports',
          'Priority support (48hr response)',
        ],
      ),
      SubscriptionPlanSelection(
        id: 'premium',
        name: 'Premium',
        subtitle: 'Learn 2x Faster with AI',
        monthlyPrice: 14.99,
        annualPrice: 149,
        isAnnual: _isAnnualBilling,
        features: [
          'Uri AI Tutor - unlimited assistance',
          'Upload your own notes & resources',
          'Unlimited AI-generated mock exams',
          'Personalised study plans & focus mode',
          'Advanced gamification & streak boosts',
        ],
      ),
      SubscriptionPlanSelection(
        id: 'school',
        name: 'School Plan',
        subtitle: 'For institutions & academies',
        monthlyPrice: 0,
        annualPrice: 0,
        isAnnual: _isAnnualBilling,
        isSchoolPlan: true,
        features: [
          'Teacher dashboard & class analytics',
          'Bulk student onboarding & management',
          'Custom branding for your school',
          'Dedicated success manager',
          'Institutional pricing & invoicing',
        ],
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is SubscriptionPlanSelection) {
      _isAnnualBilling = routeArgs.isAnnual;
      _selectedPlan = routeArgs.copyWith(isAnnual: routeArgs.isAnnual);
    } else {
      _selectedPlan = _plans.first;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _creatingAccount = false;
      _fullNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber ?? '';
    }

    _initializedFromArgs = true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    _mobileMoneyNumberController.dispose();
    _mobileMoneyNameController.dispose();
    _proofUploadController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _warmWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Secure Checkout',
          style: GoogleFonts.montserrat(
            color: _navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  '256-bit SSL',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 1100;
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepHeader(),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildCurrentStep(isDesktop),
                          ),
                          const SizedBox(height: 40),
                          if (_currentStep < 2) _buildSecuritySection(),
                          const SizedBox(height: 40),
                          if (_currentStep < 2) _buildSupportSection(),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showProcessing) _buildProcessingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    final steps = [
      {'label': 'Choose Plan', 'icon': Icons.layers_rounded},
      {'label': 'Payment Details', 'icon': Icons.payment_rounded},
      {'label': 'Confirmation', 'icon': Icons.check_circle_rounded},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: index ~/ 2 < _currentStep ? _red : Colors.grey.shade300,
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final isActive = stepIndex == _currentStep;
        final isCompleted = stepIndex < _currentStep;
        final step = steps[stepIndex];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? _green
                      : isActive
                          ? _red
                          : Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: isCompleted || isActive ? Colors.transparent : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _red.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : step['icon'] as IconData,
                  color: isCompleted || isActive ? Colors.white : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step['label']! as String,
                style: GoogleFonts.montserrat(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _navy : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep(bool isDesktop) {
    switch (_currentStep) {
      case 0:
        return _buildPlanSelection(isDesktop);
      case 1:
        return _buildPaymentDetails(isDesktop);
      default:
        return _buildConfirmation();
    }
  }

  Widget _buildPlanSelection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your subscription',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose a plan that fits your learning journey. You can switch or cancel anytime.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        _buildBillingToggle(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: _plans.map(_buildPlanCard).toList(),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedPlan == null
                    ? null
                    : () {
                        setState(() => _currentStep = 1);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Continue to payment details'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Need a custom school quote? Select "School Plan" to request an invoice and onboarding support.',
          style: GoogleFonts.montserrat(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBillingOption('Monthly', !_isAnnualBilling, () {
            setState(() {
              _isAnnualBilling = false;
              _selectedPlan = _selectedPlan?.copyWith(isAnnual: false) ?? _plans.first;
            });
          }),
          _buildBillingOption('Annual (Save 17%)', _isAnnualBilling, () {
            setState(() {
              _isAnnualBilling = true;
              _selectedPlan = _selectedPlan?.copyWith(isAnnual: true) ?? _plans[1].copyWith(isAnnual: true);
            });
          }),
        ],
      ),
    );
  }

  Widget _buildBillingOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.white,
              ),
            if (selected) const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: selected ? Colors.white : _navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanSelection plan) {
    final bool isSelected = _selectedPlan?.id == plan.id;
    final bool annual = plan.isAnnual;
    final double priceValue = plan.isSchoolPlan
        ? 0
        : (annual ? plan.annualPrice : plan.monthlyPrice);
    final String periodLabel = plan.isSchoolPlan
        ? 'Custom quote'
        : annual
            ? 'per year'
            : 'per month';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _red : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? _red.withOpacity(0.12) : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 22 : 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plan.isSchoolPlan ? Icons.school_rounded : Icons.stars_rounded,
                  color: isSelected ? _red : _navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isSelected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: _green,
                    child: const Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.subtitle,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            if (!plan.isSchoolPlan)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GHS',
                    style: GoogleFonts.montserrat(
                      color: _navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    priceValue == 0 ? '0' : priceValue.toStringAsFixed(priceValue.truncateToDouble() == priceValue ? 0 : 2),
                    style: GoogleFonts.montserrat(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Custom institutional pricing',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              periodLabel,
              style: GoogleFonts.montserrat(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 16),
            ...plan.features.take(5).map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF2ECC71)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!plan.isSchoolPlan)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFD62828), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        annual ? 'Save up to GHS ${(plan.monthlyPrice * 12 - plan.annualPrice).toStringAsFixed(0)} when billed annually' : 'Cancel anytime. Switch plans with one click.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: _red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPlan = plan;
                    _currentStep = 1;
                    _selectedMethod = PaymentMethod.bankTransfer;
                  });
                },
                icon: const Icon(Icons.request_quote_outlined, color: Color(0xFFD62828)),
                label: Text(
                  'Request invoice & onboarding',
                  style: GoogleFonts.montserrat(color: _red, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails(bool isDesktop) {
    final Widget mainContent = Column(
      children: [
        _buildAccountSection(),
        const SizedBox(height: 24),
        _buildPromoCode(),
        const SizedBox(height: 24),
        _buildPaymentMethods(),
        const SizedBox(height: 24),
        _buildSelectedPaymentForm(),
        const SizedBox(height: 32),
        _buildParentSupport(),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );

    final Widget sidebar = _buildOrderSummary();

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: mainContent),
          const SizedBox(width: 32),
          SizedBox(width: 360, child: sidebar),
        ],
      );
    }

    return Column(
      children: [
        mainContent,
        const SizedBox(height: 24),
        sidebar,
      ],
    );
  }

  Widget _buildAccountSection() {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Account information',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              if (!isLoggedIn)
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Already have an account? Sign in',
                    style: GoogleFonts.montserrat(
                      color: _red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLoggedIn
                ? 'Welcome back! We pre-filled your details below. Update anything if needed.'
                : 'Create a secure account to manage your subscription, track progress, and access receipts anytime.',
            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          if (!isLoggedIn)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Create account for easy access',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: _navy),
              ),
              subtitle: Text(
                'Save your progress, sync across devices, and manage renewals.',
                style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _creatingAccount,
              onChanged: (value) => setState(() => _creatingAccount = value),
            ),
          Form(
            key: _accountFormKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(_fullNameController, label: 'Full name', hint: 'e.g. Ama Mensah', validator: _requiredValidator)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(_emailController, label: 'Email address', hint: 'e.g. ama@uriel.academy', keyboardType: TextInputType.emailAddress, validator: _emailValidator)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_phoneController, label: 'Phone number', hint: '+233 24 123 4567', keyboardType: TextInputType.phone, validator: _requiredValidator)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _creatingAccount
                          ? _buildTextField(
                              _passwordController,
                              label: 'Create password',
                              hint: 'Minimum 8 characters',
                              obscureText: true,
                              validator: (value) {
                                if (!_creatingAccount) return null;
                                if ((value ?? '').length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            )
                          : _buildReadOnlyField(
                              label: 'Account status',
                              value: 'Account linked',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCode() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Have a promo code?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    labelText: 'Enter code',
                    hintText: 'e.g. URIEL10',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _applyCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          if (_couponMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _couponSuccess ? Icons.check_circle : Icons.error_outline,
                  color: _couponSuccess ? _green : _red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _couponMessage!,
                    style: GoogleFonts.montserrat(
                      color: _couponSuccess ? _green : _red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select payment method',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildPaymentMethodTile(
                method: PaymentMethod.card,
                icon: Icons.credit_card,
                label: 'Card Payment',
                caption: 'Visa, Mastercard, Verve',
              ),
              _buildPaymentMethodTile(
                method: PaymentMethod.mobileMoney,
                icon: Icons.smartphone_rounded,
                label: 'Mobile Money',
                caption: 'MTN, Vodafone, AirtelTigo',
              ),
              _buildPaymentMethodTile(
                method: PaymentMethod.bankTransfer,
                icon: Icons.account_balance_outlined,
                label: 'Bank Transfer',
                caption: 'Paystack & Flutterwave',
              ),
              _buildPaymentMethodTile(
                method: PaymentMethod.ussd,
                icon: Icons.phone_in_talk_outlined,
                label: 'USSD',
                caption: 'Dial secure payment code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required PaymentMethod method,
    required IconData icon,
    required String label,
    required String caption,
  }) {
    final bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _red : Colors.grey.shade200, width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSelected ? _red.withOpacity(0.1) : Colors.grey.shade100,
                  child: Icon(icon, color: isSelected ? _red : _navy),
                ),
                const Spacer(),
                Radio<PaymentMethod>(
                  value: method,
                  groupValue: _selectedMethod,
                  activeColor: _red,
                  onChanged: (value) => setState(() => _selectedMethod = value!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPaymentForm() {
    switch (_selectedMethod) {
      case PaymentMethod.card:
        return _buildCardForm();
      case PaymentMethod.mobileMoney:
        return _buildMobileMoneyForm();
      case PaymentMethod.bankTransfer:
        return _buildBankTransfer();
      case PaymentMethod.ussd:
        return _buildUssdForm();
    }
  }

  Widget _buildCardForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _cardFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Secure card payment (Paystack)',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 16),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.shield_rounded, color: Color(0xFF2ECC71), size: 18),
                const SizedBox(width: 4),
                Text(
                  'PCI-DSS compliant',
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              _cardNumberController,
              label: 'Card number',
              hint: 'XXXX XXXX XXXX XXXX',
              keyboardType: TextInputType.number,
              validator: (value) {
                final digits = value?.replaceAll(' ', '') ?? '';
                if (digits.length < 16) {
                  return 'Enter a valid 16-digit card number';
                }
                return null;
              },
              inputFormatters: [],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _cardExpiryController,
                    label: 'Expiry date',
                    hint: 'MM/YY',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Enter expiry date';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    _cardCvvController,
                    label: 'CVV/CVC',
                    hint: '3 digits',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) {
                      if ((value ?? '').length < 3) return 'Enter CVV';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _cardNameController,
              label: 'Cardholder name',
              hint: 'As displayed on card',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveCard,
              onChanged: (value) => setState(() => _saveCard = value ?? false),
              title: Text(
                'Save card for faster checkout next time',
                style: GoogleFonts.montserrat(fontSize: 13, color: _navy, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Securely tokenised by Paystack. We never store your raw card details.',
                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600),
              ),
              activeColor: _red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMoneyForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _mobileMoneyFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay with Mobile Money',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'We’ll send a prompt to your phone. Approve with your MoMo PIN to complete payment.',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildNetworkChip('MTN Mobile Money'),
                _buildNetworkChip('Vodafone Cash'),
                _buildNetworkChip('AirtelTigo Money'),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              _mobileMoneyNumberController,
              label: 'Mobile Money number',
              hint: '0XX XXX XXXX',
              keyboardType: TextInputType.phone,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _mobileMoneyNameController,
              label: 'Account name',
              hint: 'Name on MoMo account',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2ECC71)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'After clicking "Complete payment", check your phone for an authorisation prompt. Enter your Mobile Money PIN to approve. This typically takes 30 seconds.',
                      style: GoogleFonts.montserrat(fontSize: 12, color: _navy),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkChip(String label) {
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.montserrat(color: _navy, fontWeight: FontWeight.w600, fontSize: 12)),
      selected: true,
      selectedColor: _navy.withOpacity(0.08),
      onSelected: (_) {},
    );
  }

  Widget _buildBankTransfer() {
    final double amountDue = _calculateTotal();
    final String reference = 'URI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay by bank transfer',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Bank name', 'Paystack Collection (GTBank)'),
          _buildSummaryRow('Account name', 'Uriel Academy LTD'),
          _buildSummaryRow('Account number', '0412345678'),
          _buildSummaryRow('Amount to transfer', 'GHS ${amountDue.toStringAsFixed(2)}'),
          _buildSummaryRow('Reference', reference),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Use the reference above so we can verify instantly. Upload proof below to speed up confirmation (usually 10-30 minutes).',
              style: GoogleFonts.montserrat(fontSize: 12, color: _navy),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _proofUploadController,
            label: 'Upload proof (optional)',
            hint: 'Paste transfer receipt link or reference',
          ),
        ],
      ),
    );
  }

  Widget _buildUssdForm() {
    final double amountDue = _calculateTotal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay with USSD',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'Dial the secure code below to approve your payment on your phone. Works on all major networks.',
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '*389*820#',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dial this USSD code',
                  style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepListItem('Dial the code above on your phone'),
              _buildStepListItem('Select "Pay Bills" then "Uriel Academy"'),
              _buildStepListItem('Enter amount: GHS ${amountDue.toStringAsFixed(2)}'),
              _buildStepListItem('Approve and enter your MoMo/Bank PIN'),
              _buildStepListItem('We’ll confirm automatically within seconds'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(fontSize: 12, color: _navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final double subtotal = _selectedPlan?.price ?? 0;
    final double discount = _couponValue;
    final double taxableAmount = (subtotal - discount).clamp(0, double.infinity);
    final double tax = _selectedPlan?.isSchoolPlan ?? false ? 0 : taxableAmount * 0.05;
    final double total = taxableAmount + tax;
    final DateTime renewalDate = DateTime.now().add(Duration(days: _isAnnualBilling ? 365 : 30));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order summary',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Plan', '${_selectedPlan?.name ?? '--'} (${_isAnnualBilling ? 'Annual' : 'Monthly'})'),
          _buildSummaryRow('Subtotal', 'GHS ${subtotal.toStringAsFixed(2)}'),
          _buildSummaryRow('Discount', discount > 0 ? '- GHS ${discount.toStringAsFixed(2)}' : '—'),
          _buildSummaryRow('Tax (5%)', 'GHS ${tax.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total due now',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: _navy),
              ),
              const Spacer(),
              Text(
                'GHS ${total.toStringAsFixed(2)}',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: _navy, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _autoRenew,
            onChanged: (value) => setState(() => _autoRenew = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Auto-renew on ${_formatDate(renewalDate)}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: _navy),
            ),
            subtitle: Text(
              'Cancel anytime before renewal. We’ll remind you 3 days before.',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
            ),
            activeColor: _red,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trusted & secure',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildTrustBadge('🔒 Secure Payment'),
                    _buildTrustBadge('💳 Paystack & Flutterwave'),
                    _buildTrustBadge('↩️ 7-day Guarantee'),
                    _buildTrustBadge('📱 24/7 Support'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Join 50,000+ students and 50+ schools excelling with Uriel Academy.',
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(fontSize: 12, color: _navy, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSupport() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need a parent or school to pay?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _sendParentLink,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Send payment link to parent'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: BorderSide(color: _navy.withOpacity(0.4)),
                  textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _requestSchoolQuote,
                icon: const Icon(Icons.people_outline),
                label: const Text('Request school invoice'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: BorderSide(color: _navy.withOpacity(0.4)),
                  textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _handleCompletePayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: const Text('Complete payment securely'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
              });
            },
            child: Text(
              'Back to plan selection',
              style: GoogleFonts.montserrat(color: _navy, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure and trusted payment processing',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildTrustDetail('🔒', '256-bit SSL encryption', 'Your data stays encrypted end-to-end with global industry standards.'),
              _buildTrustDetail('🛡️', 'PCI-DSS compliant', 'We partner with Paystack & Flutterwave to keep every transaction safe.'),
              _buildTrustDetail('🚫', 'No card storage', 'Cards are tokenised with the gateway. Uriel never sees or stores raw details.'),
              _buildTrustDetail('📊', 'Verified by Ghana Education Service', 'Trusted by top schools across Ghana for safe digital payments.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need help completing your payment?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildSupportTile(Icons.chat_bubble_outline, 'Live chat', 'Chat with a learning advisor in under 2 minutes.'),
              _buildSupportTile(Icons.call_outlined, 'Call us', '024 731 7076 (Mon-Fri, 8am-6pm GMT)'),
              _buildSupportTile(Icons.mail_outline, 'Email support', 'info@uriel.academy'),
              _buildSupportTile(Icons.help_outline, 'Payment FAQ', 'Troubleshoot common payment issues instantly.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustDetail(String emoji, String title, String description) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warmWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTile(IconData icon, String title, String subtitle) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _navy.withOpacity(0.08),
            child: Icon(icon, color: _navy),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFD62828)),
              const SizedBox(height: 16),
              Text(
                'Processing your payment…',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
              ),
              const SizedBox(height: 8),
              Text(
                'Please don’t close this window.\nFor Mobile Money, approve the prompt on your phone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    final bool isSuccess = _paymentStatus == PaymentStatus.success;
    final double total = _calculateTotal();

    return Center(
      child: Column(
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuccess ? _green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: isSuccess ? _green : Colors.orange,
              size: 120,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSuccess ? 'Payment Successful! 🎉' : 'Payment could not be completed',
            style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: _navy),
          ),
          const SizedBox(height: 12),
          Text(
            isSuccess
                ? 'Welcome to Uriel Academy! Your subscription is now active.'
                : 'Don’t worry—you were not charged. Let’s try another payment method or contact support.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 16)),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow('Transaction ID', 'TX-${DateTime.now().millisecondsSinceEpoch}'),
                _buildSummaryRow('Plan', _selectedPlan?.name ?? '--'),
                _buildSummaryRow('Amount paid', 'GHS ${total.toStringAsFixed(2)}'),
                _buildSummaryRow('Date', _formatDate(DateTime.now())),
                _buildSummaryRow('Renewal', _formatDate(DateTime.now().add(Duration(days: _isAnnualBilling ? 365 : 30)))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isSuccess)
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Start learning now'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download receipt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: BorderSide(color: _navy.withOpacity(0.3)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.dashboard),
                      label: const Text('View my dashboard'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: BorderSide(color: _navy.withOpacity(0.3)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildNextSteps(),
              ],
            )
          else
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                      _paymentStatus = PaymentStatus.success;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Try a different method'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Contact support',
                    style: GoogleFonts.montserrat(color: _navy, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
              });
            },
            child: Text(
              'Back to plans',
              style: GoogleFonts.montserrat(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSteps() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you can do next:',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 12),
          ...[
            '✓ Browse 10,000+ BECE & WASSCE past questions',
            '✓ Access NACCA-approved textbooks and notes',
            '✓ Take your first adaptive Uri AI quiz',
            '✓ Set up your personalised study plan',
          ].map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item,
                  style: GoogleFonts.montserrat(fontSize: 12, color: _navy),
                ),
              )),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
  final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[A-Za-z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    double discount = 0;
    bool success = false;
    String? message;

    if (code.isEmpty) {
      message = 'Enter a valid coupon code';
    } else if (_selectedPlan?.id == 'free') {
      message = 'Coupon not applicable to the Free plan';
    } else {
      switch (code) {
        case 'URIEL10':
          discount = (_selectedPlan?.price ?? 0) * 0.1;
          message = 'Great! 10% discount applied.';
          success = true;
          break;
        case 'URIELSTUDENT':
          discount = 5;
          message = 'Student bonus: GHS 5 off your total.';
          success = true;
          break;
        default:
          message = 'Invalid or expired coupon.';
      }
    }

    setState(() {
      _couponSuccess = success;
      _couponValue = discount;
      _couponMessage = message;
    });
  }

  void _handleCompletePayment() {
    if (!_accountFormKey.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
      });
      return;
    }

    if (_selectedMethod == PaymentMethod.card && !_cardFormKey.currentState!.validate()) {
      return;
    }

    if (_selectedMethod == PaymentMethod.mobileMoney && !_mobileMoneyFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _showProcessing = true);

    Timer(const Duration(seconds: 2), () {
      setState(() {
        _showProcessing = false;
        _paymentStatus = PaymentStatus.success;
        _currentStep = 2;
      });
    });
  }

  void _sendParentLink() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment link copied. Share it with a parent or guardian to complete payment.'),
        backgroundColor: _navy,
      ),
    );
  }

  void _requestSchoolQuote() {
    setState(() {
      _selectedPlan = _plans.firstWhere((plan) => plan.id == 'school');
      _selectedMethod = PaymentMethod.bankTransfer;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Our team will reach out within 24 hours with institutional pricing.'),
        backgroundColor: _navy,
      ),
    );
  }

  double _calculateTotal() {
  final subtotal = _selectedPlan?.price ?? 0;
  final discount = _couponValue;
  final double taxable = (subtotal - discount).clamp(0, double.infinity) as double;
  final double tax = _selectedPlan?.isSchoolPlan ?? false ? 0 : taxable * 0.05;
  return taxable + tax;
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String? label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      enabled: enabled,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
