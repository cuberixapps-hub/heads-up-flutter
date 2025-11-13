import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sync_config_service.dart';
import '../services/listener_manager.dart';
import '../services/cache_service.dart';
import '../services/image_preload_service.dart';

/// Widget to display Firebase usage statistics and data monitoring
/// Helps track reads/writes and cache performance
class FirebaseUsageWidget extends StatefulWidget {
  const FirebaseUsageWidget({super.key});

  @override
  State<FirebaseUsageWidget> createState() => _FirebaseUsageWidgetState();
}

class _FirebaseUsageWidgetState extends State<FirebaseUsageWidget> {
  final SyncConfigService _syncConfigService = SyncConfigService();
  final ListenerManager _listenerManager = ListenerManager();
  final CacheService _cacheService = CacheService();
  final ImagePreloadService _imagePreloadService = ImagePreloadService();

  @override
  void initState() {
    super.initState();
    _syncConfigService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Firebase Usage Monitor',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                onPressed: () => setState(() {}),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estimated Usage
          _buildSection('Estimated Monthly Usage', [
            _buildUsageRow(
              'Firestore Reads',
              _getFormattedReads(),
              Icons.cloud_download,
              Colors.blue,
            ),
            _buildUsageRow(
              'Estimated Cost',
              _getFormattedCost(),
              Icons.attach_money,
              Colors.green,
            ),
            _buildUsageRow(
              'Savings vs Real-time',
              _getFormattedSavings(),
              Icons.trending_down,
              Colors.orange,
            ),
          ]),

          const Divider(color: Colors.white12, height: 24),

          // Active Listeners
          _buildSection('Active Listeners', [
            _buildStatusRow(
              'Real-time Listeners',
              '${_listenerManager.activeListenerCount}',
              _listenerManager.activeListenerCount > 0 ? Colors.green : Colors.grey,
            ),
            _buildStatusRow(
              'Listener Summary',
              _listenerManager.getListenerSummary(),
              Colors.white70,
              isSmallText: true,
            ),
          ]),

          const Divider(color: Colors.white12, height: 24),

          // Cache Statistics
          _buildSection('Cache Performance', [
            _buildCacheRow(),
            _buildImageCacheRow(),
          ]),

          const Divider(color: Colors.white12, height: 24),

          // Current Mode
          _buildSection('Sync Mode', [
            _buildModeRow(),
          ]),

          const SizedBox(height: 8),

          // Data Saver Toggle
          _buildDataSaverSection(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildUsageRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    Color valueColor, {
    bool isSmallText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: valueColor,
                fontSize: isSmallText ? 10 : 12,
                fontWeight: isSmallText ? FontWeight.normal : FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheRow() {
    final cacheStats = _cacheService.getCacheStatistics();
    final totalEntries = cacheStats['totalEntries'] ?? 0;
    final sizeMB = cacheStats['totalSizeMB'] ?? '0.00';

    return _buildStatusRow(
      'Cached Entries',
      '$totalEntries items • ${sizeMB}MB',
      Colors.blue,
    );
  }

  Widget _buildImageCacheRow() {
    final imageStats = _imagePreloadService.getStatistics();
    final count = imageStats['preloaded_count'] ?? 0;
    final sizeMB = imageStats['estimated_size_mb'] ?? '0.00';

    return _buildStatusRow(
      'Cached Images',
      '$count images • ${sizeMB}MB',
      Colors.purple,
    );
  }

  Widget _buildModeRow() {
    final currentMode = _syncConfigService.currentSettings.mode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getModeColor(currentMode).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getModeColor(currentMode).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(_getModeIcon(currentMode), color: _getModeColor(currentMode), size: 16),
          const SizedBox(width: 8),
          Text(
            currentMode.displayName,
            style: GoogleFonts.inter(
              color: _getModeColor(currentMode),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSaverSection() {
    final isDataSaverMode = _syncConfigService.currentSettings.mode == SyncMode.reduceCosts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.data_saver_on,
            color: isDataSaverMode ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Saver Mode',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isDataSaverMode ? 'Enabled' : 'Disabled',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isDataSaverMode,
            onChanged: (value) async {
              await _syncConfigService.setPresetMode(
                value ? SyncMode.reduceCosts : SyncMode.balanced,
              );
              setState(() {});
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  String _getFormattedReads() {
    final usage = _syncConfigService.getEstimatedUsage();
    final reads = usage['estimatedReadsPerMonth'] as int;
    if (reads >= 1000000) {
      return '${(reads / 1000000).toStringAsFixed(1)}M';
    } else if (reads >= 1000) {
      return '${(reads / 1000).toStringAsFixed(1)}K';
    }
    return reads.toString();
  }

  String _getFormattedCost() {
    final usage = _syncConfigService.getEstimatedUsage();
    final cost = usage['estimatedCostUSD'] as double;
    return '\$${cost.toStringAsFixed(2)}';
  }

  String _getFormattedSavings() {
    final usage = _syncConfigService.getEstimatedUsage();
    final savings = usage['savingsVsRealtime'] as double;
    return '${savings.toStringAsFixed(0)}%';
  }

  Color _getModeColor(SyncMode mode) {
    switch (mode) {
      case SyncMode.reduceCosts:
        return Colors.green;
      case SyncMode.balanced:
        return Colors.blue;
      case SyncMode.bestPerformance:
        return Colors.orange;
      case SyncMode.custom:
        return Colors.purple;
    }
  }

  IconData _getModeIcon(SyncMode mode) {
    switch (mode) {
      case SyncMode.reduceCosts:
        return Icons.savings;
      case SyncMode.balanced:
        return Icons.balance;
      case SyncMode.bestPerformance:
        return Icons.speed;
      case SyncMode.custom:
        return Icons.tune;
    }
  }
}

