import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/v2ray_service.dart';
import '../services/update_service.dart';
import '../models/app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ip_info_screen.dart';
import 'host_checker_screen.dart';
import 'speedtest_screen.dart';
import 'subscription_management_screen.dart';
import 'vpn_settings_screen.dart';
import 'blocked_apps_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({Key? key}) : super(key: key);

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  AppUpdate? _update;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final update = await updateService.checkForUpdates();

    setState(() {
      _update = update;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Tools'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_update != null) _buildUpdateCard(context, _update!),
          _buildToolCard(
            context,
            title: 'Subscription Manager',
            description:
                'Add, edit, delete and update your V2Ray subscriptions',
            icon: Icons.subscriptions,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionManagementScreen(),
                ),
              );
            },
          ),
          _buildToolCard(
            context,
            title: 'IP Information',
            description:
                'View detailed information about your current IP address',
            icon: Icons.public,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IpInfoScreen()),
              );
            },
          ),
          _buildToolCard(
            context,
            title: 'Host Checker',
            description:
                'Check status, response time and details of any web host',
            icon: Icons.link,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HostCheckerScreen(),
                ),
              );
            },
          ),
          _buildToolCard(
            context,
            title: 'Speed Test',
            description: 'Test your internet connection speed',
            icon: Icons.speed,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpeedtestScreen(),
                ),
              );
            },
          ),
          _buildToolCard(
            context,
            title: 'VPN Settings',
            description: 'Configure bypass subnets and other VPN options',
            icon: Icons.settings,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VpnSettingsScreen(),
                ),
              );
            },
          ),
          _buildToolCard(
            context,
            title: 'Blocked Apps',
            description: 'Select apps to exclude from the VPN tunnel',
            icon: Icons.block,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedAppsScreen(),
                ),
              );
            },
          ),
          // Add more tools here in the future
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.primaryGreen,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(BuildContext context, AppUpdate update) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Update Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New version: ${update.version}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(update.messText, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Current version: ${AppUpdate.currentAppVersion}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _launchUrl(update.url.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
