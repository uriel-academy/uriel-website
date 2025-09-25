import 'package:flutter/material.dart';
import 'sign_up.dart';
import 'sign_in.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Hero Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final bool isSmall = constraints.maxWidth < 800;
                return Column(
                  children: [
                    // Modern Brand Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'URIEL ACADEMY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Hero Content
                    if (isSmall) ...[
                      _buildMobileHero(context),
                    ] else ...[
                      _buildDesktopHero(context),
                    ],
                  ],
                );
              }),
            ),

            // Feature cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _FeatureCard(icon: Icons.library_books, title: 'Past Questions', subtitle: 'BECE & WASSCE'),
                  _FeatureCard(icon: Icons.menu_book, title: 'Textbooks', subtitle: 'NACCA-approved'),
                  _FeatureCard(icon: Icons.smart_toy, title: 'AI Tutor', subtitle: 'Instant help & summaries'),
                  _FeatureCard(icon: Icons.bar_chart, title: 'Progress', subtitle: 'Track performance'),
                ],
              ),
            ),

            // Testimonials + FAQ section (kept but with lighter styling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Testimonials', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Card(elevation: 2, child: ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('“Uriel helped me pass my BECE with confidence!”'), subtitle: Text('- Student'))),
                  SizedBox(height: 8),
                  Card(elevation: 2, child: ListTile(leading: CircleAvatar(child: Icon(Icons.family_restroom)), title: Text('“The weekly reports keep me updated on my child’s progress.”'), subtitle: Text('- Parent'))),
                  SizedBox(height: 8),
                  Card(elevation: 2, child: ListTile(leading: CircleAvatar(child: Icon(Icons.school)), title: Text('“Managing our students and tracking performance is so easy now.”'), subtitle: Text('- School Admin'))),
                ],
              ),
            ),

            // FAQ + Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('FAQ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  ExpansionTile(title: Text('What exams does Uriel Academy cover?'), children: [Padding(padding: EdgeInsets.all(8.0), child: Text('BECE and WASSCE for Ghanaian students.'))]),
                  ExpansionTile(title: Text('How does the AI assistant work?'), children: [Padding(padding: EdgeInsets.all(8.0), child: Text('It helps with instant question solving, revision plans, summaries, and more.'))]),
                  ExpansionTile(title: Text('Is there a free trial?'), children: [Padding(padding: EdgeInsets.all(8.0), child: Text('Yes, you can try Uriel Academy for free for 7 days.'))]),
                  SizedBox(height: 24),
                  Center(child: Text('Privacy Policy | Terms of Use | Copyright © 2025 Uriel Academy', style: TextStyle(fontSize: 13, color: Colors.black54))),
                  SizedBox(height: 8),
                  Center(child: Text('Disclaimer: Uriel Academy is not affiliated with WAEC or NACCA.', style: TextStyle(fontSize: 12, color: Colors.black45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHero(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Excel in BECE & WASSCE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Join thousands of Ghanaian students achieving academic excellence with AI-powered learning',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 32),
        
        // Modern CTA Buttons
        Column(
          children: [
            Container(
              width: double.infinity,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const SignUpPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF667eea),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Start Learning Free',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const SignInPage()),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        
        // Modern Illustration Replacement (No PNG)
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
                SizedBox(height: 16),
                Text(
                  'AI-Powered Learning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Smart Study Plans • Past Questions • Mock Exams',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHero(BuildContext context) {
    return Row(
      children: [
        // Left Content
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Excel in BECE & WASSCE with AI-Powered Learning',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Join thousands of Ghanaian students achieving academic excellence with personalized study plans, 10,000+ past questions, and intelligent AI tutoring.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              
              // CTA Buttons Row
              Row(
                children: [
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (c) => const SignUpPage()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Learning Free',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (c) => const SignInPage()),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        
        // Right Illustration (No PNG)
        Expanded(
          flex: 4,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 80,
                    color: Colors.white70,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'AI-Powered Learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Smart Study Plans • Past Questions • Mock Exams',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: const Color(0xFFD62828), child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
