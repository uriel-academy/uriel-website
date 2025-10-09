import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackPage extends StatefulWidget {
  final bool isEmbedded;

  const FeedbackPage({
    Key? key,
    this.isEmbedded = true,
  }) : super(key: key);

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _reproController = TextEditingController();
  final TextEditingController _featureController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _screenshotController = TextEditingController();

  String? _selectedExperience;
  String? _selectedPriority;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _allowFollowUp = false;
  int _charCount = 0;

  final Map<String, bool> _categories = {
    'bug': false,
    'performance': false,
    'uiux': false,
    'content': false,
    'features': false,
    'other': false,
  };

  final Map<String, String> _categoryLabels = {
    'bug': 'Bug / Error',
    'performance': 'Performance / Speed',
    'uiux': 'Design / UX',
    'content': 'Content / Questions / Textbooks',
    'features': 'Feature Request',
    'other': 'Other',
  };

  String _getUsername() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'there';
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedCategories = _categories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user?.uid ?? 'anonymous',
        'username': _getUsername(),
        'email': user?.email ?? _contactController.text.trim(),
        'experience': _selectedExperience,
        'priority': _selectedPriority,
        'categories': selectedCategories,
        'details': _detailsController.text.trim(),
        'reproSteps': _reproController.text.trim(),
        'featureIdea': _featureController.text.trim(),
        'contact': _contactController.text.trim(),
        'screenshot': _screenshotController.text.trim(),
        'allowFollowUp': _allowFollowUp,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
      });

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });

      // Reset form after showing success
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isSubmitted = false;
            _selectedExperience = null;
            _selectedPriority = null;
            _categories.updateAll((key, value) => false);
            _allowFollowUp = false;
            _charCount = 0;
          });
          _formKey.currentState?.reset();
          _detailsController.clear();
          _reproController.clear();
          _featureController.clear();
          _contactController.clear();
          _screenshotController.clear();
        }
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting feedback: $e'),
          backgroundColor: const Color(0xFFD62828),
        ),
      );
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _reproController.dispose();
    _featureController.dispose();
    _contactController.dispose();
    _screenshotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (_isSubmitted) {
      return _buildSuccessView(isMobile);
    }

    if (widget.isEmbedded) {
      return _buildEmbeddedContent(isMobile);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        title: Text(
          'Feedback',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
      ),
      body: _buildEmbeddedContent(isMobile),
    );
  }

  Widget _buildSuccessView(bool isMobile) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(isMobile ? 16 : 24),
        padding: EdgeInsets.all(isMobile ? 32 : 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF2ECC71),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thanks for your feedback!',
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We appreciate you taking the time to help us improve Uriel.\nWe promise to make it better. ✨',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedContent(bool isMobile) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 32,
              isMobile ? 24 : 40,
              isMobile ? 16 : 32,
              isMobile ? 16 : 24,
            ),
            child: Column(
              children: [
                Text(
                  'Hi there, ${_getUsername()}! 👋',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    'Thanks for visiting our site! We\'re hard at work building something great, and your feedback is invaluable to us.\n\nWe\'d love to hear from you:\n\n• Did you run into any issues or bugs?\n• What\'s working well?\n• Is there a feature you\'re hoping to see?\n• Any other thoughts or suggestions?\n\nYour input helps us create a better experience for everyone. Don\'t hold back — we\'re all ears!',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Feedback Form
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 32,
            0,
            isMobile ? 16 : 32,
            isMobile ? 24 : 40,
          ),
          sliver: SliverToBoxAdapter(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: _buildFeedbackForm(isMobile),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackForm(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share your feedback',
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 24),

            // Experience and Priority
            isMobile
                ? Column(
                    children: [
                      _buildDropdownField(
                        'Overall experience',
                        _selectedExperience,
                        ['Excellent', 'Good', 'Okay', 'Poor', 'Very Poor'],
                        (value) => setState(() => _selectedExperience = value),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        'How urgent is this?',
                        _selectedPriority,
                        ['Nice to have', 'Important', 'Critical'],
                        (value) => setState(() => _selectedPriority = value),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Overall experience',
                          _selectedExperience,
                          ['Excellent', 'Good', 'Okay', 'Poor', 'Very Poor'],
                          (value) => setState(() => _selectedExperience = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField(
                          'How urgent is this?',
                          _selectedPriority,
                          ['Nice to have', 'Important', 'Critical'],
                          (value) => setState(() => _selectedPriority = value),
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Categories
            Text(
              'What does your feedback relate to? (Select all that apply)',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoriesGrid(isMobile),

            const SizedBox(height: 24),

            // Details
            _buildTextAreaField(
              'Tell us more',
              _detailsController,
              'Describe the issue, what worked, or what you\'d like to see…',
              minLines: 5,
              required: true,
              onChanged: (value) => setState(() => _charCount = value.length),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$_charCount / 1000 characters',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Optional fields
            isMobile
                ? Column(
                    children: [
                      _buildTextAreaField(
                        'Steps to reproduce (optional)',
                        _reproController,
                        '1) Go to… 2) Click… 3) Expected… 4) Actual…',
                        minLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildTextAreaField(
                        'Feature idea (optional)',
                        _featureController,
                        'I\'d love a feature that…',
                        minLines: 3,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextAreaField(
                          'Steps to reproduce (optional)',
                          _reproController,
                          '1) Go to… 2) Click… 3) Expected… 4) Actual…',
                          minLines: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextAreaField(
                          'Feature idea (optional)',
                          _featureController,
                          'I\'d love a feature that…',
                          minLines: 3,
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Contact and Screenshot
            isMobile
                ? Column(
                    children: [
                      _buildTextField(
                        'Contact (optional)',
                        _contactController,
                        'Email (so we can follow up)',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Screenshot / link (optional)',
                        _screenshotController,
                        'Paste a link to an image or page',
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Contact (optional)',
                          _contactController,
                          'Email (so we can follow up)',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Screenshot / link (optional)',
                          _screenshotController,
                          'Paste a link to an image or page',
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Follow-up consent
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow follow-up?',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If enabled, we may contact you about your feedback.',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowFollowUp,
                    onChanged: (value) => setState(() => _allowFollowUp = value),
                    activeColor: const Color(0xFF2ECC71),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          _formKey.currentState?.reset();
                          setState(() {
                            _selectedExperience = null;
                            _selectedPriority = null;
                            _categories.updateAll((key, value) => false);
                            _allowFollowUp = false;
                            _charCount = 0;
                          });
                          _detailsController.clear();
                          _reproController.clear();
                          _featureController.clear();
                          _contactController.clear();
                          _screenshotController.clear();
                        },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sending…',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      : Text(
                          'Send feedback',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Select an option',
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Please select an option' : null,
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 1 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 6 : 5,
      children: _categories.keys.map((key) {
        return InkWell(
          onTap: () => setState(() => _categories[key] = !_categories[key]!),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _categories[key]! ? const Color(0xFF2ECC71) : Colors.grey[300]!,
                width: _categories[key]! ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _categories[key]! ? const Color(0xFF2ECC71).withOpacity(0.05) : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  _categories[key]! ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _categories[key]! ? const Color(0xFF2ECC71) : Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _categoryLabels[key]!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTextAreaField(
    String label,
    TextEditingController controller,
    String hint, {
    int minLines = 4,
    bool required = false,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: null,
          minLines: minLines,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterText: '',
          ),
          style: GoogleFonts.montserrat(fontSize: 14),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  if (value.trim().length < 20) {
                    return 'Please provide at least 20 characters';
                  }
                  return null;
                }
              : null,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
