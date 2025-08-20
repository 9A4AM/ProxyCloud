import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/models/app_update.dart';

class UpdateService {
  static const String updateUrl =
      'https://raw.githubusercontent.com/code3-dev/ProxyCloud-GUI/refs/heads/main/config/mobile.json';

  // Check for updates
  Future<AppUpdate?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(updateUrl));
      if (response.statusCode == 200) {
        final AppUpdate? update = AppUpdate.fromJsonString(response.body);
        if (update != null && update.hasUpdate()) {
          return update;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  // Show update dialog
  void showUpdateDialog(BuildContext context, AppUpdate update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Available'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New version: ${update.version}'),
                const SizedBox(height: 8),
                Text(update.messText),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchUrl(update.url.trim());
                },
                child: const Text('Download'),
              ),
            ],
          ),
    );
  }

  // Launch URL
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}
