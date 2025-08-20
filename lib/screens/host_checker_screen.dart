import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../theme/app_theme.dart';

class HostCheckerScreen extends StatefulWidget {
  const HostCheckerScreen({Key? key}) : super(key: key);

  @override
  State<HostCheckerScreen> createState() => _HostCheckerScreenState();
}

class _HostCheckerScreenState extends State<HostCheckerScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  // List of default URLs for quick selection
  final List<String> _defaultUrls = [
    'https://www.google.com',
    'https://www.youtube.com',
    'https://firebase.google.com',
    'https://x.com',
    'https://chat.openai.com',
    'https://gemini.google.com',
    'https://www.tiktok.com',
    'https://www.instagram.com',
    'https://www.facebook.com',
    'https://telegram.org',
  ];

  // Map of URL display names
  final Map<String, String> _urlDisplayNames = {
    'https://www.google.com': 'Google',
    'https://www.youtube.com': 'YouTube',
    'https://firebase.google.com': 'Firebase',
    'https://x.com': 'X (Twitter)',
    'https://chat.openai.com': 'ChatGPT',
    'https://gemini.google.com': 'Gemini',
    'https://www.tiktok.com': 'TikTok',
    'https://www.instagram.com': 'Instagram',
    'https://www.facebook.com': 'Facebook',
    'https://telegram.org': 'Telegram',
  };

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkHost() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    // Validate URL format
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _errorMessage = 'URL must start with http:// or https://';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out after 10 seconds');
            },
          );

      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;

      setState(() {
        _isLoading = false;
        _result = {
          'statusCode': response.statusCode,
          'responseTime': responseTime,
          'isSuccess': response.statusCode >= 200 && response.statusCode < 300,
          'headers': response.headers,
          'contentLength': response.contentLength,
        };
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Instead of showing error message, create a result with status false
        _result = {
          'statusCode': 0,
          'responseTime': 0,
          'isSuccess': false,
          'headers': <String, String>{},
          'contentLength': 0,
          'errorMessage':
              'Could not connect to host. Please check your internet connection or the URL.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Host Checker'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUrlInput(),
            const SizedBox(height: 24),
            _buildCheckButton(),
            const SizedBox(height: 24),
            Expanded(child: _buildResultSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Column(
      children: [
        Card(
          color: AppTheme.cardDark,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter URL',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.link,
                        color: AppTheme.primaryGreen,
                      ),
                      suffixIcon:
                          _urlController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _urlController.clear();
                                  setState(() {});
                                },
                              )
                              : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _checkHost(),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.primaryGreen,
                  ),
                  tooltip: 'Select a default URL',
                  onSelected: (String url) {
                    setState(() {
                      _urlController.text = url;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return _defaultUrls.map((String url) {
                      return PopupMenuItem<String>(
                        value: url,
                        child: Text(_urlDisplayNames[url] ?? url),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _defaultUrls.take(5).map((url) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _urlController.text = url;
                    });
                  },
                  child: Chip(
                    backgroundColor: AppTheme.cardDark,
                    label: Text(
                      _urlDisplayNames[url] ?? url,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _checkHost,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: AppTheme.primaryGreen.withOpacity(0.5),
      ),
      child:
          _isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : const Text(
                'Check Host',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
    );
  }

  Widget _buildResultSection() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking host...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, color: Colors.grey[400], size: 64),
            const SizedBox(height: 16),
            Text(
              'Enter a URL and click "Check Host"',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildResponseDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final bool isSuccess = _result!['isSuccess'] as bool;
    final int statusCode = _result!['statusCode'] as int;
    final int responseTime = _result!['responseTime'] as int;
    final String? errorMessage = _result!['errorMessage'] as String?;

    return Card(
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSuccess
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSuccess ? 'Success' : 'Failed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (statusCode > 0)
                        Text(
                          'Status Code: $statusCode',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (responseTime > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Response Time: ${responseTime}ms',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                      if (errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseDetailsCard() {
    final int? contentLength = _result!['contentLength'] as int?;
    final bool isSuccess = _result!['isSuccess'] as bool;

    return Card(
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Response Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('URL', _urlController.text),
            if (contentLength != null && contentLength > 0)
              _buildInfoRow('Content Length', '$contentLength bytes'),
            if (isSuccess) ...[
              const SizedBox(height: 8),
              const Text(
                'Headers and cookies information hidden for security reasons',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
