import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skin_care/modules/app_theme.dart';
import 'package:skin_care/modules/app_config.dart';
import 'package:flutter/services.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _loading = true;
  final bool _isGuest = true;
  bool _showAdvanced = false;

  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _ollamaUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final dark = prefs.getBool('darkMode') ?? false;
    final notify = prefs.getBool('notifications') ?? true;
    final showAdv = prefs.getBool('showAdvanced') ?? false;

    final apiBase = await AppConfig.getApiBaseUrl();
    final ollamaBase = await AppConfig.getOllamaBaseUrl();


    setState(() {
      _darkMode = dark;
      _notifications = notify;
      _showAdvanced = showAdv;
      _apiUrlController.text =
          apiBase ?? 'https://secondly-unlidded-lennox.ngrok-free.dev';
      _ollamaUrlController.text = ollamaBase ?? '';
      _loading = false;
    });
  }

  Future<void> _setDarkMode(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('darkMode', value);

  AppTheme.themeMode.value =
      value ? ThemeMode.dark : ThemeMode.light;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarIconBrightness:
          value ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          value ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          value ? Colors.black : Colors.white,
    ),
  );

  setState(() => _darkMode = value);
}


  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() => _notifications = value);
  }

  Future<void> _toggleAdvanced(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAdvanced', value);
    setState(() => _showAdvanced = value);
  }

  String _normalizeBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<void> _saveApiUrl() async {
    final raw = _apiUrlController.text.trim();
    if (raw.isEmpty) return;

    final normalized = _normalizeBaseUrl(raw);

    await AppConfig.setApiBaseUrl(normalized);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('API saved: $normalized')),
    );
  }

  Future<void> _saveOllamaUrl() async {
    final raw = _ollamaUrlController.text.trim();
    final finalUrl = raw.isEmpty ? null : _normalizeBaseUrl(raw);

    await AppConfig.setOllamaBaseUrl(finalUrl);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ollama saved (FastAPI proxy active)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration(context)),
          Positioned(
            top: -40,
            right: -30,
            child: _bubble(140, scheme.primary.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -70,
            left: -50,
            child: _bubble(200, scheme.secondary.withOpacity(0.12)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Settings',
                          style: textTheme.headlineMedium),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: scheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _sectionHeader(context, 'Appearance'),
                      _glassTile(
                        context,
                        child: SwitchListTile(
                          value: _darkMode,
                          onChanged: _setDarkMode,
                          title: Text('Dark mode',
                              style: textTheme.titleMedium),
                          subtitle: Text('Switch app appearance',
                              style: textTheme.bodyMedium),
                          secondary: Icon(Icons.dark_mode,
                              color: scheme.primary),
                        ),
                      ),
                      _sectionHeader(context, 'Notifications'),
                      _glassTile(
                        context,
                        child: SwitchListTile(
                          value: _notifications,
                          onChanged: _setNotifications,
                          title: Text('Notifications',
                              style: textTheme.titleMedium),
                          subtitle: Text('Tips and reminders',
                              style: textTheme.bodyMedium),
                          secondary: Icon(Icons.notifications,
                              color: scheme.secondary),
                        ),
                      ),
                      _sectionHeader(context, 'Advanced'),
                      _glassTile(
                        context,
                        child: SwitchListTile(
                          value: _showAdvanced,
                          onChanged: _toggleAdvanced,
                          title: Text('Developer Mode',
                              style: textTheme.titleMedium),
                          subtitle: Text(
                            _showAdvanced
                                ? 'Backend URLs shown'
                                : 'Enable dev settings',
                            style: textTheme.bodyMedium,
                          ),
                          secondary: Icon(Icons.code,
                              color: scheme.tertiary),
                        ),
                      ),
                      if (_showAdvanced) ...[
                        _glassTile(
                          context,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FastAPI URL (Scan + Chat)',
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _apiUrlController,
                                  decoration:
                                      const InputDecoration(
                                    hintText:
                                        'https://secondly-unlidded-lennox.ngrok-free.dev',
                                    border:
                                        OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment:
                                      Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _saveApiUrl,
                                    child:
                                        const Text('Save API'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Direct Ollama (Optional)',
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller:
                                      _ollamaUrlController,
                                  decoration:
                                      const InputDecoration(
                                    hintText:
                                        'Empty = FastAPI proxy',
                                    border:
                                        OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment:
                                      Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed:
                                        _saveOllamaUrl,
                                    child: const Text(
                                        'Save Ollama'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      _sectionHeader(context, 'Account'),
                      _glassTile(
                        context,
                        child: ListTile(
                          leading: Icon(Icons.person,
                              color: scheme.primary),
                          title: Text(
                            _isGuest ? 'Guest' : 'Account',
                            style: textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            _isGuest
                                ? 'Sign in for sync'
                                : 'Manage profile',
                            style: textTheme.bodyMedium,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: scheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ),
                      _sectionHeader(context, 'Data'),
                      _glassTile(
                        context,
                        child: ListTile(
                          leading: Icon(Icons.restore,
                              color: scheme.error),
                          title: Text('Reset Data',
                              style: textTheme.titleMedium),
                          subtitle: Text('Clear preferences',
                              style: textTheme.bodyMedium),
                          onTap: () =>
                              _showResetDialog(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _glassTile(BuildContext context,
      {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: AppTheme.glassCardDecoration(context),
      child: child,
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Data'),
        content:
            const Text('This will remove profile info, scans, and preferences stored on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();

              // Profile data
              await prefs.remove('profile_name');
              await prefs.remove('profile_skin_type');
              await prefs.remove('profile_avatar');
              await prefs.remove('profile_joined');
              await prefs.remove('profile_improvement');
              await prefs.remove('profile_preferences');

              // Scan-related data
              await prefs.remove('scan_count');
              await prefs.remove('avg_severity');
              await prefs.remove('last_scan_ts');

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User data cleared')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
