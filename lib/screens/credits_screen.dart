import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({Key? key}) : super(key: key);

  static const Color primaryBlue = Color(0xFF0056B3);
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textMuted = Color(0xFF6C757D);
  static const Color cardBorder = Color(0xFFE5E9F0);

  Future<void> _launchUrlOrCopy(BuildContext context, String url, String copyText, String label) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: copyText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: copyText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: const Text(
            'HCP App',
            style: TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: textMuted, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: primaryBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'The Teams',
                style: TextStyle(
                  color: textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Acknowledging the dedicated minds behind the design, architecture, and deployment of the HCP App.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Decorative Bar
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Team Cards
              _buildTeamCard(
                name: 'Mr. Allen Paul Miole',
                role: 'PIMS SFE-IT Head',
                contribution:
                    'Project Initiator, facilitated system requirements and business logic alignment. Bridged the gap between Sales Force Effectiveness operations and technical system implementation.',
              ),
              const SizedBox(height: 16),

              _buildTeamCard(
                name: 'Mr. Dexter Huinda',
                role: 'PIMS-IT Manager',
                contribution:
                    'Provided project oversight, strategic direction, and resource management. Championed the initiative to ensure the successful delivery and deployment of the application.',
              ),
              const SizedBox(height: 16),

              _buildTeamCard(
                name: 'Joshua Tan',
                role: 'Lead Dev/DevOps',
                contribution:
                    'Developer of HCP App. Handled the UI/UX design, and the backend integration with the ERPNext v15 API.',
              ),
              const SizedBox(height: 32),

              // Contact Footer Section
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Have a problem with the app?',
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Feel free to reach out',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Contact Pill Buttons
              _buildContactPill(
                context: context,
                icon: Icons.email_outlined,
                prefixText: 'Contact/Email Us: ',
                linkText: 'jptan@profinsights.biz',
                onTap: () => _launchUrlOrCopy(
                  context,
                  'mailto:jptan@profinsights.biz',
                  'jptan@profinsights.biz',
                  'Email address',
                ),
              ),
              const SizedBox(height: 12),

              _buildContactPill(
                context: context,
                icon: Icons.camera_alt_outlined,
                prefixText: 'Follow Us: ',
                linkText: 'https://www.instagram.com/pmiicareers',
                onTap: () => _launchUrlOrCopy(
                  context,
                  'https://www.instagram.com/pmiicareers',
                  'https://www.instagram.com/pmiicareers',
                  'Instagram URL',
                ),
              ),
              const SizedBox(height: 12),

              _buildContactPill(
                context: context,
                icon: Icons.public,
                prefixText: 'Visit our page: ',
                linkText: 'https://www.facebook.com/pmiimarketing/',
                onTap: () => _launchUrlOrCopy(
                  context,
                  'https://www.facebook.com/pmiimarketing/',
                  'https://www.facebook.com/pmiimarketing/',
                  'Facebook URL',
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard({
    required String name,
    required String role,
    required String contribution,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        color: primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'KEY CONTRIBUTION',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            contribution,
            style: const TextStyle(
              color: Color(0xFF3A3A3C),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPill({
    required BuildContext context,
    required IconData icon,
    required String prefixText,
    required String linkText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primaryBlue, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: prefixText,
                        style: const TextStyle(color: textMuted),
                      ),
                      TextSpan(
                        text: linkText,
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
