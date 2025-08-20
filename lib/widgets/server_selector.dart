import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/v2ray_config.dart';
import '../providers/v2ray_provider.dart';
import '../theme/app_theme.dart';
import '../screens/server_selection_screen.dart';
import 'error_snackbar.dart';

class ServerSelector extends StatelessWidget {
  const ServerSelector({Key? key}) : super(key: key);

  // Proxy mode switch removed as requested

  @override
  Widget build(BuildContext context) {
    return Consumer<V2RayProvider>(
      builder: (context, provider, _) {
        final selectedConfig = provider.selectedConfig;
        final configs = provider.configs;
        final isConnecting = provider.isConnecting;
        final isLoadingServers = provider.isLoadingServers;

        if (isLoadingServers) {
          return const _LoadingServerCard();
        }

        if (configs.isEmpty) {
          return const _EmptyServerCard();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Server',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap:
                      isConnecting
                          ? null
                          : () {
                            // Check if already connected to VPN
                            if (provider.activeConfig != null) {
                              // Show popup to inform user to disconnect first
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Connection Active'),
                                      content: const Text(
                                        'Please disconnect from VPN before selecting a different server.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                              );
                            } else {
                              // Not connected, show server selector as full page
                              showServerSelectionScreen(
                                context: context,
                                configs: configs,
                                selectedConfig: selectedConfig,
                                isConnecting: isConnecting,
                                onConfigSelected: (config) async {
                                  await provider.selectConfig(config);
                                },
                              );
                            }
                          },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardDark),
                    ),
                    child: Row(
                      children: [
                        if (selectedConfig != null) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getServerStatusColor(
                                selectedConfig,
                                provider,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedConfig.remark,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          // Removed server delay icon as requested
                        ] else ...[
                          const Expanded(
                            child: Text(
                              'Select a server',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Proxy Mode Switch removed as requested
                // Server and config type information removed as requested
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getServerStatusColor(V2RayConfig config, V2RayProvider provider) {
    // Check if this is the active config (connected)
    final activeConfig = provider.activeConfig;
    if (activeConfig != null && activeConfig.id == config.id) {
      return AppTheme.primaryGreen;
    }
    // Check if this is the selected config (but not connected)
    final selectedConfig = provider.selectedConfig;
    if (selectedConfig != null && selectedConfig.id == config.id) {
      return Colors.orange;
    }
    return AppTheme.textGrey;
  }
}

class _ServerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ServerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textGrey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LoadingServerCard extends StatelessWidget {
  const _LoadingServerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              SizedBox(height: 16),
              Text('Loading servers...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyServerCard extends StatelessWidget {
  const _EmptyServerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.textGrey),
              const SizedBox(height: 16),
              const Text('No servers available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final provider = Provider.of<V2RayProvider>(
                    context,
                    listen: false,
                  );
                  try {
                    // Since we no longer have default servers, we'll show a message
                    ErrorSnackbar.show(
                      context,
                      'Please add a subscription to get servers',
                    );

                    // Check if there was an error
                    if (provider.errorMessage.isNotEmpty) {
                      ErrorSnackbar.show(context, provider.errorMessage);
                      provider.clearError();
                    }
                  } catch (e) {
                    ErrorSnackbar.show(
                      context,
                      'Error refreshing servers: ${e.toString()}',
                    );
                  }
                },
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
