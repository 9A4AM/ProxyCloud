import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/telegram_proxy.dart';
import '../providers/telegram_proxy_provider.dart';
import '../widgets/background_gradient.dart';
import '../widgets/error_snackbar.dart';
import '../theme/app_theme.dart';

class TelegramProxyScreen extends StatefulWidget {
  const TelegramProxyScreen({Key? key}) : super(key: key);

  @override
  State<TelegramProxyScreen> createState() => _TelegramProxyScreenState();
}

class _TelegramProxyScreenState extends State<TelegramProxyScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch proxies when screen is first loaded
    Future.microtask(() {
      Provider.of<TelegramProxyProvider>(context, listen: false).fetchProxies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Telegram Proxies'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                Provider.of<TelegramProxyProvider>(
                  context,
                  listen: false,
                ).fetchProxies();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Consumer<TelegramProxyProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading proxies',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        provider.fetchProxies();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            if (provider.proxies.isEmpty) {
              return const Center(child: Text('No proxies available'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.proxies.length,
              itemBuilder: (context, index) {
                final proxy = provider.proxies[index];
                return _buildProxyCard(context, proxy);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProxyCard(BuildContext context, TelegramProxy proxy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    proxy.host,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Port: ${proxy.port}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.public, size: 16, color: Colors.blue[300]),
                const SizedBox(width: 4),
                Text(
                  proxy.country,
                  style: TextStyle(fontSize: 14, color: Colors.blue[300]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.business, size: 16, color: Colors.amber[300]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    proxy.provider,
                    style: TextStyle(fontSize: 14, color: Colors.amber[300]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.speed, size: 16, color: _getPingColor(proxy.ping)),
                const SizedBox(width: 4),
                Text(
                  '${proxy.ping} ms',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getPingColor(proxy.ping),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Uptime: ${proxy.uptime}%',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Details'),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Server: ${proxy.host}\nPort: ${proxy.port}\nSecret: ${proxy.secret}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Proxy details copied to clipboard',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Copy URL'),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: proxy.telegramHttpsUrl),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Telegram Proxy URL copied to clipboard',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.telegram),
                  label: const Text('Connect to Telegram'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  onPressed: () async {
                    final url = proxy.telegramUrl;
                    try {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        ErrorSnackbar.show(
                          context,
                          'Could not launch Telegram. Please make sure Telegram is installed.',
                        );
                      }
                    } catch (e) {
                      ErrorSnackbar.show(
                        context,
                        'Error launching Telegram: $e',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping < 300) {
      return Colors.green;
    } else if (ping < 500) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
