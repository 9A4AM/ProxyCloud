import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/v2ray_provider.dart';
import '../widgets/connection_button.dart';
import '../widgets/server_selector.dart';
import '../widgets/background_gradient.dart';
import '../widgets/error_snackbar.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import '../services/v2ray_service.dart';
import 'subscription_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = ''; // Default to empty subscription URL

    // Ping functionality removed

    // Listen for connection state changes
    final v2rayProvider = Provider.of<V2RayProvider>(context, listen: false);
    v2rayProvider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    // Check if the provider is connected and not connecting
    final v2rayProvider = Provider.of<V2RayProvider>(context, listen: false);
    // Ping functionality removed
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _showAddSubscriptionDialog(BuildContext context) async {
    final TextEditingController _nameController = TextEditingController(
      text: 'New Subscription',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Subscription'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Subscription Name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Subscription URL',
                    hintText: 'Enter subscription URL',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final provider = Provider.of<V2RayProvider>(
                    context,
                    listen: false,
                  );
                  final url = _urlController.text.trim();
                  final name = _nameController.text.trim();

                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a subscription URL'),
                      ),
                    );
                    return;
                  }

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a subscription name'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Show a loading snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Adding subscription...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  try {
                    // Add subscription with URL
                    await provider.addSubscription(name, url);

                    // Check if there was an error
                    if (provider.errorMessage.isNotEmpty) {
                      ErrorSnackbar.show(context, provider.errorMessage);
                      provider.clearError();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscription added successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    ErrorSnackbar.show(context, 'Error: ${e.toString()}');
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Proxy Cloud'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final provider = Provider.of<V2RayProvider>(
                  context,
                  listen: false,
                );

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Updating all subscriptions...'),
                  ),
                );

                // Update all subscriptions instead of just fetching servers
                await provider.updateAllSubscriptions();
                provider.fetchNotificationStatus();

                // Show success message
                if (provider.errorMessage.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All subscriptions updated successfully'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage)),
                  );
                  provider.clearError();
                }
              },
              tooltip: 'Update All Subscriptions',
            ),
            IconButton(
              icon: const Icon(Icons.vpn_key),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionManagementScreen(),
                  ),
                );
              },
              tooltip: 'Add Subscription',
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
              tooltip: 'About',
            ),
          ],
        ),
        body: Column(
          children: [
            // Connection status removed as requested

            // Main content
            Expanded(
              child: Consumer<V2RayProvider>(
                builder: (context, provider, _) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Server selector (now includes Proxy Mode Switch)
                          const ServerSelector(),

                          const SizedBox(height: 20),

                          // Connection button
                          const ConnectionButton(),

                          const SizedBox(height: 40),

                          // Connection stats
                          if (provider.activeConfig != null)
                            _buildConnectionStats(provider),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStats(V2RayProvider provider) {
    // Get the V2RayService instance
    final v2rayService = provider.v2rayService;

    // Use StreamBuilder to update the UI when statistics change
    return StreamBuilder(
      // Create a periodic stream to update the UI every second
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final ipInfo = v2rayService.ipInfo;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connection Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                Icons.timer,
                'Connected Time',
                v2rayService.getFormattedConnectedTime(),
              ),
              const Divider(height: 24),
              // Server ping information removed
              if (v2rayService.isLoadingIpInfo)
                _buildLoadingIpInfoRow()
              else if (ipInfo != null && ipInfo.success)
                _buildIpInfoRow(ipInfo)
              else
                _buildIpErrorRow(
                  'IP Information',
                  ipInfo?.errorMessage ?? 'cant get ip',
                  () async {
                    // Retry fetching IP info
                    await v2rayService.fetchIpInfo();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Cached ping value and loading state
  // Ping functionality removed

  // Server ping row removed

  Widget _buildIpInfoRow(IpInfo ipInfo) {
    return Row(
      children: [
        const Icon(Icons.public, size: 18, color: AppTheme.textGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${ipInfo.country} - ${ipInfo.city}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textGrey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textGrey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildIpErrorRow(
    String label,
    String errorMessage,
    VoidCallback onRetry,
  ) {
    return Row(
      children: [
        const Icon(Icons.public, size: 18, color: AppTheme.textGrey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textGrey)),
        const Spacer(),
        Text(
          errorMessage,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              Icons.refresh,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIpInfoRow() {
    return Row(
      children: [
        const Icon(Icons.public, size: 18, color: AppTheme.textGrey),
        const SizedBox(width: 12),
        const Text(
          'IP Information',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        const Spacer(),
        const Text(
          'Fetching...',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
