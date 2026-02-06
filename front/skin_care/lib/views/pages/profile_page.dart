import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skin_care/modules/app_theme.dart';
import 'package:skin_care/views/shared/glass_appbar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _kName = 'profile_name';
  static const _kSkinType = 'profile_skin_type';
  static const _kAvatarPath = 'profile_avatar';
  static const _kJoined = 'profile_joined';
  static const _kImprovement = 'profile_improvement';
  static const _kScanCount = 'scan_count';
  static const _kAvgSeverity = 'avg_severity';
  static const _kLastScan = 'last_scan_ts';
  static const _kPreferences = 'profile_preferences';
  static const _kAge = 'profile_age';
  static const _kConcerns = 'profile_concerns';
  static const _kGoals = 'profile_goals';

  final List<String> skinTypeOptions = ['Oily', 'Dry', 'Combination', 'Normal', 'Sensitive'];
  final List<String> concernOptions = ['Acne', 'Wrinkles', 'Dryness', 'Sensitivity', 'Oiliness', 'Dark spots', 'Texture'];
  final List<String> goalOptions = ['Clear skin', 'Anti-aging', 'Hydration', 'Reduce redness', 'Minimize pores', 'Even tone'];

  List<String> preferences = [];
  String? userAge;
  List<String> selectedConcerns = [];
  List<String> selectedGoals = [];
  List<Map<String, dynamic>> scanHistory = [];



  String displayName = "Guest User";
  String skinType = "Unknown";
  String? avatarPath;
  DateTime joined = DateTime.now();
  double improvement = 0.35;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final scanCount = prefs.getInt(_kScanCount) ?? 0;
    final avgSeverity = prefs.getDouble(_kAvgSeverity) ?? 100;

    // Simple heuristic: lower severity = better progress
    if (scanCount >= 2) {
      improvement = (1 - (avgSeverity / 100)).clamp(0.0, 1.0);
    } else {
      improvement = 0.0;
    }
    preferences = prefs.getStringList(_kPreferences) ?? [];
    
    // Load scan history
    final scanHistoryJson = prefs.getString('scan_history');
    if (scanHistoryJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(scanHistoryJson);
        scanHistory = decoded.map((item) {
          return {
            'timestamp': DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int),
            'severity': item['severity'] as int,
            'conditions': List<String>.from(item['conditions'] as List? ?? []),
            'recommendations': List<String>.from(item['recommendations'] as List? ?? []),
            'image': item['image'] != null ? base64Decode(item['image'] as String) : null,
          };
        }).toList();
      } catch (e) {
        scanHistory = [];
      }
    }

    setState(() {
      displayName = prefs.getString(_kName) ?? displayName;
      skinType = prefs.getString(_kSkinType) ?? skinType;
      avatarPath = prefs.getString(_kAvatarPath);
      improvement = prefs.getDouble(_kImprovement) ?? improvement;
      userAge = prefs.getString(_kAge);
      selectedConcerns = prefs.getStringList(_kConcerns) ?? [];
      selectedGoals = prefs.getStringList(_kGoals) ?? [];

      final joinedMillis = prefs.getInt(_kJoined);
      if (joinedMillis != null) {
        joined = DateTime.fromMillisecondsSinceEpoch(joinedMillis);
      } else {
        prefs.setInt(_kJoined, joined.millisecondsSinceEpoch);
      }

      loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, displayName);
    await prefs.setString(_kSkinType, skinType);
    await prefs.setDouble(_kImprovement, improvement);
    await prefs.setStringList(_kPreferences, preferences);
    if (userAge != null && userAge!.isNotEmpty) {
      await prefs.setString(_kAge, userAge!);
    }
    await prefs.setStringList(_kConcerns, selectedConcerns);
    await prefs.setStringList(_kGoals, selectedGoals);

    if (avatarPath != null) {
      await prefs.setString(_kAvatarPath, avatarPath!);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      avatarPath = image.path;
    });

    _saveProfile();
  }

  void _editProfile() {
    final nameController = TextEditingController(text: displayName);
    final ageController = TextEditingController(text: userAge ?? '');
    // Ensure selectedType is valid, default to first option if not
    String selectedType = skinTypeOptions.contains(skinType) ? skinType : skinTypeOptions[0];
    List<String> tempConcerns = List.from(selectedConcerns);
    List<String> tempGoals = List.from(selectedGoals);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit profile"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Display name"),
              ),
              const SizedBox(height: 16),

              // Age
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: "Age (optional)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Skin Type Dropdown
              StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: "Skin type",
                    border: OutlineInputBorder(),
                  ),
                  items: skinTypeOptions.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value ?? skinTypeOptions[0];
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Skin Concerns
              Text(
                'Skin concerns (select all that apply)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: concernOptions.map((concern) {
                    final isSelected = tempConcerns.contains(concern);
                    return FilterChip(
                      label: Text(concern),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            tempConcerns.add(concern);
                          } else {
                            tempConcerns.remove(concern);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Goals
              Text(
                'Goals (select all that apply)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: goalOptions.map((goal) {
                    final isSelected = tempGoals.contains(goal);
                    return FilterChip(
                      label: Text(goal),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            tempGoals.add(goal);
                          } else {
                            tempGoals.remove(goal);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                displayName =
                    nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : displayName;
                skinType = selectedType;
                userAge = ageController.text.trim().isNotEmpty
                    ? ageController.text.trim()
                    : null;
                selectedConcerns = tempConcerns;
                selectedGoals = tempGoals;
              });
              _saveProfile();
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        Container(decoration: AppTheme.backgroundDecoration(context)),
        Column(
          children: [
            const GlassAppBar(
              title: "Profile",
              subtitle: "Your skin journey",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: [
                    // PROFILE CARD
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(context),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickAvatar,
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor:
                                      scheme.primary.withOpacity(0.18),
                                  backgroundImage: avatarPath != null
                                      ? FileImage(File(avatarPath!))
                                      : null,
                                  child: avatarPath == null
                                      ? const Icon(Icons.person, size: 42)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _editProfile,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: scheme.primary,
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Joined ${joined.month}/${joined.year}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Skin type: $skinType",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                                if (userAge != null && userAge!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "Age: $userAge",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: _editProfile,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // SKIN CONCERNS & GOALS
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedConcerns.isNotEmpty) ...[
                            Text(
                              "Your concerns",
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedConcerns.map((concern) {
                                return Chip(
                                  label: Text(concern, style: const TextStyle(fontSize: 12)),
                                  backgroundColor:
                                      scheme.primary.withOpacity(0.1),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (selectedGoals.isNotEmpty) ...[
                            Text(
                              "Your goals",
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedGoals.map((goal) {
                                return Chip(
                                  label: Text(goal, style: const TextStyle(fontSize: 12)),
                                  backgroundColor:
                                      scheme.secondary.withOpacity(0.1),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("Journey progress"),
                              const Spacer(),
                              Text("${(improvement * 100).round()}%"),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: improvement,
                              minHeight: 10,
                              backgroundColor:
                                  scheme.surface.withOpacity(0.3),
                              valueColor:
                                  AlwaysStoppedAnimation(scheme.primary),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Progress is estimated from changes in severity across your recent scans.",
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // PREFERENCES (FUTURE-READY)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.glassCardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Preferences"),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...preferences.map(
                                (p) => Chip(
                                  label: Text(p),
                                  onDeleted: () {
                                    setState(() {
                                      preferences.remove(p);
                                    });
                                    _saveProfile();
                                  },
                                ),
                              ),

                              ActionChip(
                                label: const Text("+ Add"),
                                onPressed: () async {
                                  final controller = TextEditingController();

                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Add preference"),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          hintText: "e.g. Fragrance-free",
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, controller.text.trim()),
                                          child: const Text("Add"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (result != null && result.isNotEmpty) {
                                    setState(() {
                                      preferences.add(result);
                                    });
                                    _saveProfile();
                                  }
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Text(
                            "Preferences are stored on this device and used to personalize recommendations.",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // SCAN HISTORY
                    if (scanHistory.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: AppTheme.glassCardDecoration(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Scan History",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: scanHistory.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final scan = scanHistory[index];
                                final ts = scan['timestamp'] as DateTime;
                                final sev = scan['severity'] as int;
                                final cond = (scan['conditions'] as List).cast<String>();
                                
                                Color _severityColor(int score) {
                                  if (score < 0) return Colors.grey;
                                  if (score < 30) return Colors.green;
                                  if (score < 60) return Colors.orange;
                                  return Colors.red;
                                }

                                String _severityLabel(int score) {
                                  if (score < 0) return 'Unknown';
                                  if (score < 30) return 'Low';
                                  if (score < 60) return 'Moderate';
                                  return 'Severe';
                                }

                                final color = _severityColor(sev);

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${ts.hour.toString().padLeft(2, '0')}:'
                                            '${ts.minute.toString().padLeft(2, '0')}  '
                                            '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
                                            '${ts.day.toString().padLeft(2, '0')}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: Colors.white70),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Severity ${sev >= 0 ? '$sev%' : 'N/A'} • ${_severityLabel(sev)}',
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (cond.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          cond.join(', '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
