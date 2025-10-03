// lib/widgets/offline_status_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/offline_provider.dart';

class OfflineStatusWidget extends StatelessWidget {
  const OfflineStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        // Only show if offline or has pending orders
        if (offlineProvider.isOnline && offlineProvider.pendingOrdersCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(8.0),
          child: Card(
            color: offlineProvider.isOnline ? Colors.orange : Colors.red,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    offlineProvider.isOnline
                        ? Icons.sync
                        : Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _getStatusText(offlineProvider),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (offlineProvider.isSyncing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                  if (offlineProvider.pendingOrdersCount > 0 && offlineProvider.isOnline) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showSyncDialog(context, offlineProvider),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(OfflineProvider offlineProvider) {
    if (!offlineProvider.isOnline) {
      if (offlineProvider.pendingOrdersCount > 0) {
        return 'Offline - ${offlineProvider.pendingOrdersCount} orders saved';
      }
      return 'Offline mode';
    }

    if (offlineProvider.isSyncing) {
      return 'Syncing orders...';
    }

    if (offlineProvider.pendingOrdersCount > 0) {
      return '${offlineProvider.pendingOrdersCount} orders pending sync';
    }

    return '';
  }

  void _showSyncDialog(BuildContext context, OfflineProvider offlineProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pending Orders'),
          content: Text(
            'You have ${offlineProvider.pendingOrdersCount} orders waiting to be processed.\n\n'
            'These orders will be automatically processed when connection is stable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (offlineProvider.isOnline && !offlineProvider.isSyncing)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await offlineProvider.forceSyncNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync initiated - check console for logs'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Force Sync'),
              ),
          ],
        );
      },
    );
  }
}

// Mini version for use in app bars
class OfflineStatusIndicator extends StatelessWidget {
  const OfflineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (offlineProvider.isOnline && offlineProvider.pendingOrdersCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: offlineProvider.isOnline ? Colors.orange : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                offlineProvider.isOnline ? Icons.sync : Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              if (offlineProvider.pendingOrdersCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${offlineProvider.pendingOrdersCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}