import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/v2ray_config.dart';
import 'package:flutter_application_1/models/subscription.dart';
import 'package:flutter_application_1/providers/v2ray_provider.dart';
import 'package:flutter_application_1/services/v2ray_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

class ServerSelectionScreen extends StatefulWidget {
  final List<V2RayConfig> configs;
  final V2RayConfig? selectedConfig;
  final bool isConnecting;
  final Future<void> Function(V2RayConfig) onConfigSelected;

  const ServerSelectionScreen({
    Key? key,
    required this.configs,
    required this.selectedConfig,
    required this.isConnecting,
    required this.onConfigSelected,
  }) : super(key: key);

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  String _selectedFilter = 'All';
  final Map<String, int?> _pings = {};
  final Map<String, bool> _loadingPings = {};
  final V2RayService _v2rayService = V2RayService();
  final StreamController<String> _autoConnectStatusStream =
      StreamController<String>.broadcast();
  
  Future<void> _importFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
        return;
      }

      final provider = Provider.of<V2RayProvider>(context, listen: false);
      final config = await provider.importConfigFromText(clipboardData.text!);
      
      if (config != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration imported successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import configuration: Invalid format'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing configuration: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteLocalConfig(V2RayConfig config) async {
    try {
      await Provider.of<V2RayProvider>(context, listen: false).removeConfig(config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete configuration: $e')),
      );
    }
  }
  final Map<String, bool> _cancelPingTasks = {};
  Timer? _batchTimeoutTimer;
  bool _sortByPing = false; // New variable for ping sorting
  bool _sortAscending = true; // New variable for sort direction
  bool _isPingingServers = false; // New variable for ping loading state

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'All';
  }

  @override
  void dispose() {
    _autoConnectStatusStream.close();
    _batchTimeoutTimer?.cancel();
    _cancelAllPingTasks();
    super.dispose();
  }

  Map<String, List<V2RayConfig>> _groupConfigsByHost(
    List<V2RayConfig> configs,
  ) {
    final Map<String, List<V2RayConfig>> groupedConfigs = {};
    for (var config in configs) {
      // Use config.id as the key to ensure each config is treated individually
      final key = config.id;
      if (!groupedConfigs.containsKey(key)) {
        groupedConfigs[key] = [];
      }
      groupedConfigs[key]!.add(config);
    }
    return groupedConfigs;
  }

  Future<void> _loadAllPings() async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final configs = provider.configs;
    final groupedConfigs = _groupConfigsByHost(configs);
    for (var host in groupedConfigs.keys) {
      if (!mounted) return;
      final configsForHost = groupedConfigs[host]!;
      final representativeConfig = configsForHost.first;
      await _loadPingForConfig(representativeConfig, configsForHost);
    }
  }

  Future<void> _loadPingForConfig(
    V2RayConfig config,
    List<V2RayConfig> relatedConfigs,
  ) async {
    if (_cancelPingTasks[config.id] == true) return;

    // Safely update loading state
    if (mounted) {
      setState(() {
        for (var relatedConfig in relatedConfigs) {
          _loadingPings[relatedConfig.id] = true;
        }
      });
    }

    try {
      // Add timeout to prevent hanging
      final ping = await _v2rayService
          .getServerDelay(config)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Ping timeout for server ${config.remark}');
              return null; // Return null on timeout
            },
          );

      // Check if widget is still mounted and task wasn't cancelled
      if (mounted && _cancelPingTasks[config.id] != true) {
        setState(() {
          for (var relatedConfig in relatedConfigs) {
            _pings[relatedConfig.id] = ping;
            _loadingPings[relatedConfig.id] = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error pinging server ${config.remark}: $e');
      // Safely handle error state
      if (mounted) {
        setState(() {
          for (var relatedConfig in relatedConfigs) {
            _pings[relatedConfig.id] = null;
            _loadingPings[relatedConfig.id] = false;
          }
        });
      }
    }
  }

  Future<int?> _pingServer(V2RayConfig config) async {
    try {
      if (_cancelPingTasks[config.id] == true) return null;
      return await _v2rayService
          .getServerDelay(config)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Ping timeout for server ${config.remark}');
              return null; // Return null on timeout
            },
          );
    } catch (e) {
      debugPrint('Error pinging server ${config.remark}: $e');
      return null;
    }
  }

  Future<void> _runAutoConnectAlgorithm(
    List<V2RayConfig> configs,
    BuildContext context,
  ) async {
    _cancelPingTasks.clear();
    V2RayConfig? selectedConfig;
    final remainingConfigs = List<V2RayConfig>.from(configs);

    try {
      while (remainingConfigs.isNotEmpty && selectedConfig == null && mounted) {
        final batchSize = min(5, remainingConfigs.length);
        final currentBatch = remainingConfigs.take(batchSize).toList();
        remainingConfigs.removeRange(0, batchSize);

        _autoConnectStatusStream.add(
          'Testing batch of ${currentBatch.length} servers...',
        );

        final completer = Completer<V2RayConfig?>();
        
        // Create a timeout that won't crash the app
        _batchTimeoutTimer?.cancel();
        _batchTimeoutTimer = Timer(const Duration(seconds: 10), () {
          if (!completer.isCompleted) {
            debugPrint('Batch timeout reached, moving to next batch');
            _autoConnectStatusStream.add('Batch timeout reached, trying next servers...');
            completer.complete(null);
          }
        });

        try {
          final pingTasks = currentBatch.map((config) => _processPingTask(config, completer)).toList();
          selectedConfig = await completer.future;
          _batchTimeoutTimer?.cancel();
        } catch (e) {
          debugPrint('Error in batch processing: $e');
          // Don't rethrow, just continue to next batch
          continue;
        }
      }

      // Clean up timer
      _batchTimeoutTimer?.cancel();
      _batchTimeoutTimer = null;

      if (!mounted) return;

      if (selectedConfig != null) {
        _autoConnectStatusStream.add(
          'Connecting to ${selectedConfig.remark} (${_pings[selectedConfig.id]}ms)',
        );
        try {
          await widget.onConfigSelected(selectedConfig);
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          }
        } catch (e) {
          debugPrint('Error connecting to selected server: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to connect: ${e.toString()}')),
            );
          }
        }
      } else {
        if (mounted) {
          _autoConnectStatusStream.add('No suitable server found');
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No server with valid ping found. Please try again.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in auto connect algorithm: $e');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during auto-select: ${e.toString()}')),
        );
      }
    } finally {
      // Ensure cleanup happens
      _batchTimeoutTimer?.cancel();
      _batchTimeoutTimer = null;
      _cancelAllPingTasks();
    }
  }

  Future<void> _processPingTask(
    V2RayConfig config,
    Completer<V2RayConfig?> completer,
  ) async {
    if (!mounted || completer.isCompleted) return;

    try {
      _autoConnectStatusStream.add('Testing ${config.remark}...');

      // Add timeout to prevent hanging
      final ping = await _pingServer(config).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Ping timeout for server ${config.remark}');
          return null;
        },
      );

      // Check if completer is already completed or widget is unmounted
      if (completer.isCompleted || !mounted) return;

      // Safely update state
      if (mounted) {
        setState(() {
          _pings[config.id] = ping;
          _loadingPings[config.id] = false;
        });
      }

      // If we found a server with ping (not -1, not 0), select it immediately
      if (ping != null && ping > 0) {
        if (mounted && !completer.isCompleted) {
          _autoConnectStatusStream.add(
            '${config.remark} responded with ${ping}ms',
          );
          _cancelAllPingTasks();
          completer.complete(config);
        }
      } else {
        if (mounted) {
          _autoConnectStatusStream.add('${config.remark} failed or timed out');
        }
      }
    } catch (e) {
      debugPrint('Error in _processPingTask for ${config.remark}: $e');
      // Don't complete the completer on error, let other servers try
    }
  }

  void _cancelAllPingTasks() {
    _cancelPingTasks.updateAll((key, value) => true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<V2RayProvider>(context, listen: true);
    final subscriptions = provider.subscriptions;
    final configs = provider.configs;

    final filterOptions = ['All', 'Local', ...subscriptions.map((sub) => sub.name)];

    // Add sort and ping buttons in the app bar actions
    final List<Widget> appBarActions = [
      // Ping button
      IconButton(
        icon:
            _isPingingServers
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen,
                    ),
                  ),
                )
                : const Icon(Icons.network_check),
        tooltip: 'Test Ping',
        onPressed:
            _isPingingServers
                ? null
                : () async {
                  setState(() {
                    _isPingingServers = true;
                    // Clear existing pings when starting new test
                    _pings.clear();
                  });

                  try {
                    if (_selectedFilter == 'All') {
                      await _loadAllPings();
                    } else if (_selectedFilter == 'Local') {
                      // Get local configs (not in any subscription)
                      final allSubscriptionConfigIds = subscriptions
                          .expand((sub) => sub.configIds)
                          .toSet();
                      final provider = Provider.of<V2RayProvider>(context, listen: false);
                      final allConfigs = provider.configs;
                      final localConfigs = allConfigs
                          .where((config) => !allSubscriptionConfigIds.contains(config.id))
                          .toList();
                      
                      // Test pings for local configs
                      for (var config in localConfigs) {
                        if (!mounted) break;
                        await _loadPingForConfig(config, [config]);
                      }
                    } else {
                      final subscription = subscriptions.firstWhere(
                        (sub) => sub.name == _selectedFilter,
                        orElse:
                            () => Subscription(
                              id: '',
                              name: '',
                              url: '',
                              lastUpdated: DateTime.now(),
                              configIds: [],
                            ),
                      );
                      final provider = Provider.of<V2RayProvider>(context, listen: false);
                      final allConfigs = provider.configs;
                      final configsToTest =
                          allConfigs
                              .where(
                                (config) =>
                                    subscription.configIds.contains(config.id),
                              )
                              .toList();
                      for (var config in configsToTest) {
                        if (!mounted) break;
                        await _loadPingForConfig(config, [config]);
                      }
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isPingingServers = false;
                      });
                    }
                  }
                },
      ),
      // Sort button
      IconButton(
        icon: Icon(
          _sortByPing ? Icons.sort : Icons.sort_outlined,
          color: _sortByPing ? AppTheme.primaryGreen : null,
        ),
        tooltip: 'Sort by Ping',
        onPressed: () {
          setState(() {
            if (_sortByPing) {
              _sortAscending = !_sortAscending;
            } else {
              _sortByPing = true;
              _sortAscending = true;
            }
          });
        },
      ),
    ];

    List<V2RayConfig> filteredConfigs = [];
    if (_selectedFilter == 'All') {
      filteredConfigs = List.from(configs);
    } else if (_selectedFilter == 'Local') {
      // Filter configs that don't belong to any subscription
      final allSubscriptionConfigIds = subscriptions
          .expand((sub) => sub.configIds)
          .toSet();
      filteredConfigs = configs
          .where((config) => !allSubscriptionConfigIds.contains(config.id))
          .toList();
    } else {
      final subscription = subscriptions.firstWhere(
        (sub) => sub.name == _selectedFilter,
        orElse:
            () => Subscription(
              id: '',
              name: '',
              url: '',
              lastUpdated: DateTime.now(),
              configIds: [],
            ),
      );
      filteredConfigs =
          configs
              .where((config) => subscription.configIds.contains(config.id))
              .toList();
    }

    // Sort configs by ping if enabled
    if (_sortByPing) {
      filteredConfigs.sort((a, b) {
        final pingA = _pings[a.id];
        final pingB = _pings[b.id];

        // Check if ping values are valid (not null, -1, or 0)
        final isValidPingA = pingA != null && pingA > 0;
        final isValidPingB = pingB != null && pingB > 0;

        // Handle invalid pings - put them at the bottom
        if (!isValidPingA && !isValidPingB) return 0;
        if (!isValidPingA) return 1;
        if (!isValidPingB) return -1;

        // Sort by ping value (only valid pings reach here)
        return _sortAscending ? pingA!.compareTo(pingB!) : pingB!.compareTo(pingA!);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      floatingActionButton: _selectedFilter == 'Local' ? FloatingActionButton(
        onPressed: _importFromClipboard,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.paste),
      ) : null,
      appBar: AppBar(
        title: const Text('Select Server'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        actions: [
          ...appBarActions,
          if (_selectedFilter != 'Local')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Updating servers...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                if (_selectedFilter == 'All') {
                  await provider.updateAllSubscriptions();
                } else if (_selectedFilter != 'Default') {
                  final subscription = subscriptions.firstWhere(
                    (sub) => sub.name == _selectedFilter,
                    orElse:
                        () => Subscription(
                          id: '',
                          name: '',
                          url: '',
                          lastUpdated: DateTime.now(),
                          configIds: [],
                        ),
                  );
                  if (subscription.id.isNotEmpty) {
                    await provider.updateSubscription(subscription);
                  }
                }

                setState(() {});
                await _loadAllPings();

                if (provider.errorMessage.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  provider.clearError();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Servers updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating servers: ${e.toString()}'),
                  ),
                );
              }
            },
            tooltip: 'Update Servers',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filterOptions.length,
              itemBuilder: (context, index) {
                final filter = filterOptions[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 8,
                    right: index == filterOptions.length - 1 ? 16 : 0,
                  ),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                    backgroundColor: AppTheme.cardDark,
                    selectedColor: AppTheme.primaryGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child:
                filteredConfigs.isEmpty
                    ? Center(
                      child: Text(
                        'No servers available for $_selectedFilter',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredConfigs.length + 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.cardDark,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap:
                                  widget.isConnecting
                                      ? null
                                      : () async {
                                        final provider =
                                            Provider.of<V2RayProvider>(
                                              context,
                                              listen: false,
                                            );
                                        if (provider.activeConfig != null) {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  backgroundColor:
                                                      AppTheme.secondaryDark,
                                                  title: const Text(
                                                    'Connection Active',
                                                  ),
                                                  content: const Text(
                                                    'Please disconnect from VPN before selecting a different server.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          color:
                                                              AppTheme
                                                                  .primaryGreen,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                        } else {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder:
                                                (context) => AlertDialog(
                                                  backgroundColor:
                                                      AppTheme.secondaryDark,
                                                  title: const Text(
                                                    'Auto Select',
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              AppTheme
                                                                  .primaryGreen,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      const Text(
                                                        'Testing servers for fastest connection...',
                                                      ),
                                                      const SizedBox(height: 8),
                                                      StreamBuilder<String>(
                                                        stream:
                                                            _autoConnectStatusStream
                                                                .stream,
                                                        builder: (
                                                          context,
                                                          snapshot,
                                                        ) {
                                                          return Text(
                                                            snapshot.data ??
                                                                'Starting tests...',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                          );
                                          await _runAutoConnectAlgorithm(
                                            filteredConfigs,
                                            context,
                                          );
                                        }
                                      },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auto Select',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Connect to server with lowest ping',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.bolt,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final config = filteredConfigs[index - 1];
                        final isSelected =
                            provider.selectedConfig?.id == config.id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.cardDark,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap:
                                widget.isConnecting
                                    ? null
                                    : () async {
                                      final provider =
                                          Provider.of<V2RayProvider>(
                                            context,
                                            listen: false,
                                          );
                                      if (provider.activeConfig != null) {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                backgroundColor:
                                                    AppTheme.secondaryDark,
                                                title: const Text(
                                                  'Connection Active',
                                                ),
                                                content: const Text(
                                                  'Please disconnect from VPN before selecting a different server.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                        ),
                                                    child: const Text(
                                                      'OK',
                                                      style: TextStyle(
                                                        color:
                                                            AppTheme
                                                                .primaryGreen,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        );
                                      } else {
                                        await widget.onConfigSelected(config);
                                        if (mounted &&
                                            Navigator.of(context).canPop()) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          isSelected
                                              ? AppTheme.primaryGreen
                                              : AppTheme.textGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                config.remark,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (_selectedFilter == 'Local')
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () => _deleteLocalConfig(config),
                                              ),
                                            _loadingPings[config.id] == true
                                                ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          AppTheme.primaryGreen,
                                                        ),
                                                  ),
                                                )
                                                : _pings[config.id] != null
                                                ? Text(
                                                  '${_pings[config.id]}ms',
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.primaryGreen,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                                : const SizedBox.shrink(),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${config.address}:${config.port}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getConfigTypeColor(
                                                  config.configType,
                                                ).withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                config.configType
                                                    .toString()
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: _getConfigTypeColor(
                                                    config.configType,
                                                  ),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getSubscriptionName(config),
                                                style: const TextStyle(
                                                  color: Colors.blueGrey,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color:
                                        isSelected
                                            ? AppTheme.primaryGreen
                                            : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Color _getConfigTypeColor(String configType) {
    switch (configType.toLowerCase()) {
      case 'vmess':
        return Colors.blue;
      case 'vless':
        return Colors.purple;
      case 'shadowsocks':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSubscriptionName(V2RayConfig config) {
    final subscriptions =
        Provider.of<V2RayProvider>(context, listen: false).subscriptions;
    return subscriptions
        .firstWhere(
          (sub) => sub.configIds.contains(config.id),
          orElse:
              () => Subscription(
                id: '',
                name: 'Default Subscription',
                url: '',
                lastUpdated: DateTime.now(),
                configIds: [],
              ),
        )
        .name;
  }
}

void showServerSelectionScreen({
  required BuildContext context,
  required List<V2RayConfig> configs,
  required V2RayConfig? selectedConfig,
  required bool isConnecting,
  required Future<void> Function(V2RayConfig) onConfigSelected,
}) {
  final provider = Provider.of<V2RayProvider>(context, listen: false);
  if (provider.activeConfig != null) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.secondaryDark,
            title: const Text('Connection Active'),
            content: const Text(
              'Please disconnect from VPN before selecting a different server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (context) => ServerSelectionScreen(
            configs: configs,
            selectedConfig: selectedConfig,
            isConnecting: isConnecting,
            onConfigSelected: onConfigSelected,
          ),
    ),
  );
}
