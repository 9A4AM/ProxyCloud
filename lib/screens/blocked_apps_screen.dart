import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/v2ray_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({Key? key}) : super(key: key);

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class AppInfo {
  final String packageName;
  final String name;
  final bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
  });
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen> {
  final V2RayService _v2rayService = V2RayService();
  List<AppInfo> _availableApps = [];
  List<String> _selectedApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterApps(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredApps = List.from(_availableApps);
      } else {
        _filteredApps =
            _availableApps
                .where(
                  (app) =>
                      app.name.toLowerCase().contains(query.toLowerCase()) ||
                      app.packageName.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      }
    });
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load saved blocked apps
      final prefs = await SharedPreferences.getInstance();
      final savedBlockedApps = prefs.getStringList('blocked_apps') ?? [];

      // Get available apps from device
      if (defaultTargetPlatform == TargetPlatform.android) {
        final apps = await _v2rayService.getInstalledApps();

        // Convert the raw data to AppInfo objects
        List<AppInfo> appInfoList = [];

        // For Android, we expect a list of maps with name and packageName
        if (apps is List<dynamic>) {
          for (var app in apps) {
            if (app is Map<String, dynamic>) {
              appInfoList.add(
                AppInfo(
                  name: app['name'] ?? 'Unknown',
                  packageName: app['packageName'] ?? '',
                  isSystemApp: app['isSystemApp'] ?? false,
                ),
              );
            }
          }
        }

        setState(() {
          _availableApps = appInfoList;
          _filteredApps = List.from(appInfoList);
          _selectedApps = savedBlockedApps;
          _isLoading = false;
        });
      } else {
        // Non-Android platforms
        setState(() {
          _availableApps = [];
          _filteredApps = [];
          _selectedApps = savedBlockedApps;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load apps: $e')));
      }
    }
  }

  Future<void> _saveBlockedApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // If _selectedApps is empty, save null by removing the key
      if (_selectedApps.isEmpty) {
        await prefs.remove('blocked_apps');
      } else {
        await prefs.setStringList('blocked_apps', _selectedApps);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedApps.isEmpty
                  ? 'No apps selected for blocking'
                  : 'Blocked apps saved successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save blocked apps: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Blocked Apps'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        actions: [
          // Clear selection button
          if (_selectedApps.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all selections',
              onPressed: () {
                setState(() {
                  _selectedApps = [];
                });
              },
            ),
          TextButton(
            onPressed: _saveBlockedApps,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterApps,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryDark.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  // App list
                  Expanded(
                    child:
                        _filteredApps.isEmpty
                            ? Center(
                              child: Text(
                                _availableApps.isEmpty
                                    ? 'No apps found'
                                    : 'No matching apps',
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _filteredApps.length,
                              itemBuilder: (context, index) {
                                final app = _filteredApps[index];
                                final isSelected = _selectedApps.contains(
                                  app.packageName,
                                );

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  color: AppTheme.primaryDark.withOpacity(0.8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          app.isSystemApp
                                              ? Colors.blueGrey
                                              : AppTheme.accentGreen,
                                      child: Text(
                                        app.name.isNotEmpty
                                            ? app.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      app.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      app.packageName,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      activeColor: AppTheme.accentGreen,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedApps.add(app.packageName);
                                          } else {
                                            _selectedApps.remove(
                                              app.packageName,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (_selectedApps.contains(
                                          app.packageName,
                                        )) {
                                          _selectedApps.remove(app.packageName);
                                        } else {
                                          _selectedApps.add(app.packageName);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
