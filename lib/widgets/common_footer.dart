import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';

class CommonFooter extends StatelessWidget {
  final bool isSmallScreen;
  final bool showLinks;
  final bool showPricing;

  const CommonFooter({
    Key? key,
    required this.isSmallScreen,
    this.showLinks = true,
    this.showPricing = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 24 : 32,
      ),
      color: const Color(0xFF1A1E3F),
      child: Column(
        children: [
          if (showLinks) ...[
            Text(
              'Uriel Academy',
              style: AppStyles.brandNameDark(fontSize: isSmallScreen ? 18 : 22),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              'Empowering Ghanaian students to excel in BECE & WASSCE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            // Footer Links
            Wrap(
              spacing: 32,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                if (showPricing) _buildFooterLink(context, 'Pricing', () => Navigator.pushNamed(context, '/pricing')),
                _buildFooterLink(context, 'Payment', () => Navigator.pushNamed(context, '/payment')),
                _buildFooterLink(context, 'About Us', () => Navigator.pushNamed(context, '/about')),
                _buildFooterLink(context, 'Contact', () => Navigator.pushNamed(context, '/contact')),
                _buildFooterLink(context, 'Privacy Policy', () => Navigator.pushNamed(context, '/privacy')),
                _buildFooterLink(context, 'Terms of Service', () => Navigator.pushNamed(context, '/terms')),
                _buildFooterLink(context, 'FAQ', () => Navigator.pushNamed(context, '/faq')),
              ],
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Divider(color: Colors.white.withOpacity(0.2)),
            SizedBox(height: isSmallScreen ? 12 : 16),
          ] else ...[
            Text(
              'Uriel Academy',
              style: AppStyles.brandNameDark(fontSize: isSmallScreen ? 18 : 20),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
          ],
          
          Text(
            '© 2025 Uriel Academy. Built with ❤️ for Ghanaian students.',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          if (showLinks) SizedBox(height: isSmallScreen ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.white.withOpacity(0.8),
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}