import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/territory_web_server.dart';
import 'components/app_drawer.dart';

class TerritoryPortalLauncherScreen extends StatefulWidget {
  const TerritoryPortalLauncherScreen({Key? key}) : super(key: key);

  @override
  State<TerritoryPortalLauncherScreen> createState() => _TerritoryPortalLauncherScreenState();
}

class _TerritoryPortalLauncherScreenState extends State<TerritoryPortalLauncherScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startEmbeddedServer();
  }

  Future<void> _startEmbeddedServer() async {
    setState(() => _isLoading = true);
    await TerritoryWebServer.start();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchPortalUrl(BuildContext context, String primaryUrl, [String? fallbackUrl]) async {
    final urls = [primaryUrl];
    if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != primaryUrl) {
      urls.add(fallbackUrl);
    }

    bool launched = false;
    for (final targetUrl in urls) {
      try {
        final uri = Uri.parse(targetUrl);

        // Attempt 1: External Application (Chrome, Samsung Browser, Safari)
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) break;
        } catch (_) {}

        // Attempt 2: Platform Default
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
            if (launched) break;
          } catch (_) {}
        }

        // Attempt 3: In-App Browser View
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            if (launched) break;
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (!launched && context.mounted) {
      Clipboard.setData(ClipboardData(text: primaryUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('URL copied to clipboard ($primaryUrl). Please open your browser and paste.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _copyPortalLink(BuildContext context, String url, bool isLaptop) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLaptop
                    ? 'Laptop URL copied! Paste this in Chrome on your laptop (connected to same Wi-Fi).'
                    : 'Device portal URL copied to clipboard!',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final userEmail = apiService.loggedInEmail ?? 'admin@pims-marketing.com';
    final userRole = apiService.isSfe ? 'SFE Lead' : 'Administrator';
    final programName = apiService.selectedProgram.isEmpty ? 'Abbott Diabetes Care' : apiService.selectedProgram;

    final deviceUrl = TerritoryWebServer.buildPortalUrl(
      email: userEmail,
      program: programName,
      forLaptop: false,
    );

    final laptopUrl = TerritoryWebServer.buildPortalUrl(
      email: userEmail,
      program: programName,
      forLaptop: true,
    );

    final baseNetworkUrl = TerritoryWebServer.networkBaseUrl;

    final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(laptopUrl)}';

    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        title: const Text(
          'Territory Reconfiguration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFA855F7), size: 14),
                const SizedBox(width: 5),
                Text(
                  userRole,
                  style: const TextStyle(color: Color(0xFFA855F7), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.dashboard),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Welcome Card with Built-in Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3E62), Color(0xFF0B192C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066FF).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0066FF), width: 1.5),
                          ),
                          child: const Icon(Icons.hub_rounded, color: Color(0xFF38BDF8), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dedicated Built-In Web App',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Self-Hosted Directly Inside HCP Profiling',
                                style: TextStyle(
                                  color: const Color(0xFF38BDF8).withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This dedicated web portal runs directly inside the mobile app on an embedded server. It works offline, requires zero setup on ERPNext, and opens seamlessly in device browsers and laptop browsers.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Server status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B192C).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isLoading
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLoading ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                            color: _isLoading ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLoading
                                  ? 'Initializing Built-In Server...'
                                  : 'Built-In Web Server Active (Port ${TerritoryWebServer.port})',
                              style: TextStyle(
                                color: _isLoading ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Restart Server',
                            onPressed: _startEmbeddedServer,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Launch in Browser',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Opens the dedicated portal directly in your device browser (Chrome / Safari) without touching ERPNext desk routes.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                    ),
                    const SizedBox(height: 14),

                    // Primary Button: Open in Device Browser
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                        label: const Text(
                          'Open in Device Browser (Chrome / Safari)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _launchPortalUrl(context, deviceUrl, laptopUrl),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secondary Button: Copy Link for Laptop
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF0066FF), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.laptop_chromebook_rounded, size: 18),
                        label: const Text(
                          'Copy Link for Laptop Browser',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _copyPortalLink(context, laptopUrl, true),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Network Connection & Laptop Pairing Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_tethering_rounded, color: Color(0xFF38BDF8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Laptop Wi-Fi Pairing',
                          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Connect your laptop to the same Wi-Fi or mobile hotspot as this device. Scan the QR code or paste the URL into your laptop browser.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                    ),
                    const SizedBox(height: 10),

                    // Active URLs Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Laptop Wi-Fi URL (Auto-Program):',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              InkWell(
                                onTap: () => _copyPortalLink(context, laptopUrl, true),
                                child: const Text(
                                  'Copy Link',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            laptopUrl,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shortest Direct IP (Quick Typing):',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              InkWell(
                                onTap: () => _copyPortalLink(context, baseNetworkUrl, true),
                                child: const Text(
                                  'Copy IP',
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            baseNetworkUrl,
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Device Localhost URL:',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              InkWell(
                                onTap: () => _copyPortalLink(context, deviceUrl, false),
                                child: const Text(
                                  'Copy',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            deviceUrl,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.network(
                        qrImageUrl,
                        width: 170,
                        height: 170,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 170,
                          height: 170,
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: const Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Capabilities List
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Web Portal Capabilities',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureItem(
                      Icons.table_view_rounded,
                      'Pre-Import CSV Live Grid Preview',
                      'Upload your real CSV proposals and inspect all rows with zero server commit risk.',
                    ),
                    _buildFeatureItem(
                      Icons.drive_file_rename_outline_rounded,
                      'Program-Specific Territory Code Renaming',
                      'Assign newer codes for specific programs with automatic cascade across HCP Accounts.',
                    ),
                    _buildFeatureItem(
                      Icons.history_toggle_off_rounded,
                      'Multi-Cycle Historical Dataset Matching',
                      'Cross-reference Cycle 1–3 doctor rosters and balance quotas effortlessly.',
                    ),
                    _buildFeatureItem(
                      Icons.archive_outlined,
                      'Zero-Loss Territory Archiving',
                      'Decommissioned codes move safely to Archived Territories for future reactivation.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
