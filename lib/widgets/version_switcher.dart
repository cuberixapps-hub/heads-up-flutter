import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A widget that allows switching between Home Screen V1 and V2
/// This is useful for A/B testing and user preference
class VersionSwitcher extends StatefulWidget {
  const VersionSwitcher({super.key});

  @override
  State<VersionSwitcher> createState() => _VersionSwitcherState();
}

class _VersionSwitcherState extends State<VersionSwitcher> {
  bool _useV2 = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useV2 = prefs.getBool('use_home_v2') ?? false;
    });
  }

  Future<void> _toggleVersion(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_home_v2', value);
    setState(() {
      _useV2 = value;
    });
    
    // Show a snackbar to inform the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Using Home Screen ${value ? 'V2 (Netflix Style)' : 'V1 (Original)'}',
            style: GoogleFonts.poppins(),
          ),
          action: SnackBarAction(
            label: 'Restart App',
            onPressed: () {
              // In a real scenario, you might want to restart the app
              // For now, just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please restart the app to see changes',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Home Screen Version',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _toggleVersion(false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: !_useV2 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_useV2 
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.view_quilt,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Original',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: _useV2 
                                ? FontWeight.normal 
                                : FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _toggleVersion(true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _useV2 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _useV2 
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.video_library,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Netflix',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: _useV2 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _useV2 
                ? '✨ Modern, cinematic design with content focus'
                : '🎮 Classic, familiar game interface',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Helper function to get the preferred home screen version
class HomeScreenPreference {
  static const String _key = 'use_home_v2';

  static Future<bool> shouldUseV2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setUseV2(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  static Future<String> getHomeRoute() async {
    final useV2 = await shouldUseV2();
    return useV2 ? '/home-v2' : '/home';
  }
}

