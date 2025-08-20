import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../providers/v2ray_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/error_snackbar.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _isUpdating = false;
  String? _currentSubscriptionId;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _urlController.clear();
      _isUpdating = false;
      _currentSubscriptionId = null;
    });
  }

  void _prepareForUpdate(Subscription subscription) {
    setState(() {
      _nameController.text = subscription.name;
      _urlController.text = subscription.url;
      _isUpdating = true;
      _currentSubscriptionId = subscription.id;
    });
  }

  Future<void> _addOrUpdateSubscription(BuildContext context) async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for the subscription'),
        ),
      );
      return;
    }

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL for the subscription'),
        ),
      );
      return;
    }

    // Check if name is 'Default' or 'default'
    if (name.toLowerCase() == 'default') {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.secondaryDark,
              title: const Text('Reserved Name'),
              content: const Text(
                'The name "Default" is reserved for system use. Please choose a different name.',
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

    final provider = Provider.of<V2RayProvider>(context, listen: false);

    // Check for duplicate name when adding a new subscription
    if (!_isUpdating) {
      final nameExists = provider.subscriptions.any(
        (sub) => sub.name.toLowerCase() == name.toLowerCase(),
      );
      if (nameExists) {
        // Show error dialog for duplicate name
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: AppTheme.secondaryDark,
                title: const Text('Duplicate Name'),
                content: Text(
                  'A subscription with the name "$name" already exists. Please choose a different name.',
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
    } else if (_currentSubscriptionId != null) {
      // When updating, check if the new name conflicts with any subscription other than the current one
      final nameExists = provider.subscriptions.any(
        (sub) =>
            sub.name.toLowerCase() == name.toLowerCase() &&
            sub.id != _currentSubscriptionId,
      );
      if (nameExists) {
        // Show error dialog for duplicate name
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: AppTheme.secondaryDark,
                title: const Text('Duplicate Name'),
                content: Text(
                  'A subscription with the name "$name" already exists. Please choose a different name.',
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
    }

    try {
      if (_isUpdating && _currentSubscriptionId != null) {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updating subscription...')),
        );

        // Find the subscription to update
        final subscription = provider.subscriptions.firstWhere(
          (sub) => sub.id == _currentSubscriptionId,
        );

        // Create updated subscription
        final updatedSubscription = subscription.copyWith(name: name, url: url);

        // Update the subscription
        await provider.updateSubscriptionInfo(updatedSubscription);

        // Check if there was an error
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
            const SnackBar(content: Text('Subscription updated successfully')),
          );
        }
      } else {
        // Show loading indicator
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Adding subscription...')));

        // Add new subscription
        await provider.addSubscription(name, url);

        // Check if there was an error
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
            const SnackBar(content: Text('Subscription added successfully')),
          );
        }
      }

      // Reset the form
      _resetForm();
    } catch (e) {
      ErrorSnackbar.show(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _deleteSubscription(
    BuildContext context,
    Subscription subscription,
  ) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: AppTheme.secondaryDark,
                title: const Text('Delete Subscription'),
                content: Text(
                  'Are you sure you want to delete "${subscription.name}"? This will also remove all servers from this subscription.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirmed) {
      final provider = Provider.of<V2RayProvider>(context, listen: false);

      try {
        await provider.removeSubscription(subscription);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted successfully')),
        );

        // If we were editing this subscription, reset the form
        if (_isUpdating && _currentSubscriptionId == subscription.id) {
          _resetForm();
        }
      } catch (e) {
        ErrorSnackbar.show(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _updateAllSubscriptions(BuildContext context) async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updating all subscriptions...')),
      );

      await provider.updateAllSubscriptions();

      // Check if there was an error
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
            content: Text('All subscriptions updated successfully'),
          ),
        );
      }
    } catch (e) {
      ErrorSnackbar.show(context, 'Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Manage Subs'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _updateAllSubscriptions(context),
            tooltip: 'Update All Subscriptions',
          ),
        ],
      ),
      body: Consumer<V2RayProvider>(
        builder: (context, provider, _) {
          final subscriptions = provider.subscriptions;

          return Column(
            children: [
              // Add/Edit Subscription Form
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: AppTheme.cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isUpdating
                              ? 'Edit Subscription'
                              : 'Add Subscription',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: AppTheme.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'URL',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: AppTheme.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_isUpdating)
                              TextButton(
                                onPressed: _resetForm,
                                child: const Text('Cancel'),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  () => _addOrUpdateSubscription(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                              ),
                              child: Text(_isUpdating ? 'Update' : 'Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Subscription List
              Expanded(
                child:
                    provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : subscriptions.isEmpty
                        ? const Center(
                          child: Text('No subscriptions added yet'),
                        )
                        : ListView.builder(
                          itemCount: subscriptions.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final subscription = subscriptions[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppTheme.cardDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(subscription.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subscription.url,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Last updated: ${_formatDate(subscription.lastUpdated)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'Servers: ${subscription.configIds.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed:
                                          () => _prepareForUpdate(subscription),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color:
                                            subscription.name.toLowerCase() ==
                                                    'default subscription'
                                                ? Colors.grey
                                                : Colors.red,
                                      ),
                                      onPressed:
                                          subscription.name.toLowerCase() ==
                                                  'default subscription'
                                              ? null
                                              : () => _deleteSubscription(
                                                context,
                                                subscription,
                                              ),
                                      tooltip:
                                          subscription.name.toLowerCase() ==
                                                  'default subscription'
                                              ? 'Cannot delete default subscription'
                                              : 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.secondaryDark,
            title: Row(
              children: [
                const Icon(Icons.help_outline, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                const Text('How to Add?'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To add a subscription, you need a URL that contains V2Ray configurations.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Format Requirements:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• HTTP or HTTPS URL with V2Ray configs'),
                        Text('• One configuration per line'),
                        Text('• Supports vless://, vmess://, ss://, etc.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Example:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('vless://...'),
                        Text('vmess://...'),
                        Text('ss://...'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Steps:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Enter a unique name for your subscription'),
                  const Text(
                    '2. Enter the URL containing V2Ray configurations',
                  ),
                  const Text('3. Click "Add" to save your subscription'),
                  const Text(
                    '4. Use the refresh button to update configurations',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
    );
  }
}
