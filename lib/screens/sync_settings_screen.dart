import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sync_settings.dart';
import '../services/sync_config_service.dart';
import '../services/haptic_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final SyncConfigService _syncConfigService = SyncConfigService();
  late SyncSettings _currentSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _syncConfigService.initialize();
    setState(() {
      _currentSettings = _syncConfigService.currentSettings;
      _isLoading = false;
    });
  }

  Future<void> _setPresetMode(SyncMode mode) async {
    HapticService().lightImpact();
    setState(() => _isLoading = true);
    
    await _syncConfigService.setPresetMode(mode);
    
    setState(() {
      _currentSettings = _syncConfigService.currentSettings;
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${mode.displayName} mode'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleCustomSetting(String setting, bool value) async {
    HapticService().lightImpact();
    
    switch (setting) {
      case 'realtime_decks':
        await _syncConfigService.setCustomSettings(enableRealtimeDecks: value);
        break;
      case 'realtime_games':
        await _syncConfigService.setCustomSettings(enableRealtimeGames: value);
        break;
      case 'realtime_leaderboards':
        await _syncConfigService.setCustomSettings(enableRealtimeLeaderboards: value);
        break;
    }
    
    setState(() {
      _currentSettings = _syncConfigService.currentSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticService().lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Data Sync Settings',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Control how your app syncs data with Firebase to optimize costs and performance.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Usage Estimate
                  _buildUsageEstimateCard(),
                  const SizedBox(height: 24),

                  // Preset Modes
                  Text(
                    'Preset Modes',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPresetCard(SyncMode.reduceCosts),
                  const SizedBox(height: 12),
                  _buildPresetCard(SyncMode.balanced),
                  const SizedBox(height: 12),
                  _buildPresetCard(SyncMode.bestPerformance),
                  const SizedBox(height: 32),

                  // Custom Settings
                  Text(
                    'Custom Settings',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomSettingsCard(),
                  const SizedBox(height: 24),

                  // Info Section
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildUsageEstimateCard() {
    final usage = _syncConfigService.getEstimatedUsage();
    final reads = usage['estimatedReadsPerMonth'] as int;
    final cost = usage['estimatedCostUSD'] as double;
    final savings = usage['savingsVsRealtime'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Estimated Usage',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUsageStat('Reads/Month', '${(reads / 1000).toStringAsFixed(1)}K'),
              _buildUsageStat('Est. Cost', '\$${cost.toStringAsFixed(2)}'),
              _buildUsageStat('Savings', '${savings.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(SyncMode mode) {
    final isSelected = _currentSettings.mode == mode;

    return GestureDetector(
      onTap: () => _setPresetMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.2)
              : const Color(0xFF1D1F33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mode.displayName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mode.description,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode.estimatedReads,
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSettingsCard() {
    final isCustomMode = _currentSettings.mode == SyncMode.custom;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildToggleTile(
            'Real-time Deck Updates',
            'Auto-sync deck changes instantly',
            _currentSettings.enableRealtimeDecks,
            (value) => _toggleCustomSetting('realtime_decks', value),
            enabled: isCustomMode,
          ),
          Divider(color: Colors.white.withOpacity(0.1)),
          _buildToggleTile(
            'Real-time Game Updates',
            'Sync game history during gameplay',
            _currentSettings.enableRealtimeGames,
            (value) => _toggleCustomSetting('realtime_games', value),
            enabled: isCustomMode,
          ),
          Divider(color: Colors.white.withOpacity(0.1)),
          _buildToggleTile(
            'Real-time Leaderboards',
            'Auto-update leaderboard positions',
            _currentSettings.enableRealtimeLeaderboards,
            (value) => _toggleCustomSetting('realtime_leaderboards', value),
            enabled: isCustomMode,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
              const SizedBox(width: 8),
              Text(
                'About Data Sync',
                style: GoogleFonts.inter(
                  color: Colors.orange.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Real-time sync keeps your data always up-to-date but uses more Firebase reads\n'
            '• Manual sync reduces costs but requires pull-to-refresh for updates\n'
            '• Balanced mode optimizes for both performance and cost\n'
            '• Changes take effect immediately',
            style: GoogleFonts.inter(
              color: Colors.orange.shade200,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

