import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/v2ray_provider.dart';
import '../services/v2ray_service.dart';
import '../theme/app_theme.dart';

class IpInfoScreen extends StatefulWidget {
  const IpInfoScreen({Key? key}) : super(key: key);

  @override
  State<IpInfoScreen> createState() => _IpInfoScreenState();
}

class _IpInfoScreenState extends State<IpInfoScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _ipData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchIpInfo();
  }

  Future<void> _fetchIpInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await Provider.of<V2RayProvider>(
            context,
            listen: false,
          ).v2rayService.fetchIpInfo();

      if (response.success) {
        // Fetch the full details from the API
        final fullResponse = await _fetchFullIpDetails();
        setState(() {
          _ipData = fullResponse;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response.errorMessage ?? 'Failed to fetch IP information';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchFullIpDetails() async {
    try {
      final response = await http.get(Uri.parse('https://ipleak.net/json/'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch full IP details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('IP Information'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchIpInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchIpInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_ipData == null) {
      return const Center(
        child: Text(
          'No IP information available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildDetailsCard(),
          const SizedBox(height: 16),
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildNetworkCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
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
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('IP Address', _ipData!['ip'] ?? 'Unknown'),
            _buildInfoRow(
              'Location',
              '${_ipData!['country_name'] ?? 'Unknown'} - ${_ipData!['city_name'] ?? 'Unknown'}',
            ),
            _buildInfoRow('ISP', _ipData!['isp_name'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
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
              'Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Query Type', _ipData!['query_type'] ?? 'Unknown'),
            _buildInfoRow('Query Text', _ipData!['query_text'] ?? 'Unknown'),
            _buildInfoRow('Reverse DNS', _ipData!['reverse'] ?? 'None'),
            _buildInfoRow('Level', _ipData!['level'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
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
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Country',
              '${_ipData!['country_name'] ?? 'Unknown'} (${_ipData!['country_code'] ?? 'Unknown'})',
            ),
            _buildInfoRow(
              'Region',
              '${_ipData!['region_name'] ?? 'Unknown'} (${_ipData!['region_code'] ?? 'Unknown'})',
            ),
            _buildInfoRow('City', _ipData!['city_name'] ?? 'Unknown'),
            _buildInfoRow(
              'Continent',
              '${_ipData!['continent_name'] ?? 'Unknown'} (${_ipData!['continent_code'] ?? 'Unknown'})',
            ),
            _buildInfoRow(
              'Postal Code',
              _ipData!['postal_code']?.toString() ?? 'Unknown',
            ),
            _buildInfoRow('Time Zone', _ipData!['time_zone'] ?? 'Unknown'),
            _buildInfoRow(
              'Coordinates',
              '${_ipData!['latitude']?.toString() ?? 'Unknown'}, ${_ipData!['longitude']?.toString() ?? 'Unknown'}',
            ),
            _buildInfoRow(
              'Accuracy Radius',
              '${_ipData!['accuracy_radius']?.toString() ?? 'Unknown'} km',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard() {
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
              'Network',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('ISP', _ipData!['isp_name'] ?? 'Unknown'),
            _buildInfoRow(
              'AS Number',
              _ipData!['as_number']?.toString() ?? 'Unknown',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

// End of file
