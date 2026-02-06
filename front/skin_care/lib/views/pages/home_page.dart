import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:skin_care/modules/app_theme.dart';
import 'package:skin_care/modules/app_config.dart';
import 'package:skin_care/views/shared/glass_appbar.dart';
import 'package:skin_care/views/pages/chatbot_page.dart';
import 'package:shared_preferences/shared_preferences.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  XFile? pickedImage;
  Uint8List? selectedImageBytes;
  Uint8List? analyzedImageBytes;

  int severityScore = -1;
  List<String> issues = [];
  List<String> recommendations = [];
  
  static const _kScanCount = 'scan_count';
  static const _kAvgSeverity = 'avg_severity';
  static const _kLastScan = 'last_scan_ts';

  bool loading = false;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scanAnimation = Tween<double>(
      begin: -1.2,
      end: 1.2,
    ).animate(_scanController);
  }
  @override
void dispose() {
  _scanController.dispose();
  super.dispose();
}

  final picker = ImagePicker();

  /// Each scan keeps timestamp, severity, conditions, recommendation and image
  final List<Map<String, dynamic>> recentScans = [];

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      pickedImage = picked;
      selectedImageBytes = bytes;
      analyzedImageBytes = null;
      severityScore = -1;
      issues.clear();
      recommendations.clear();
    });
  }

  Future<void> _updateScanStats() async {
  final prefs = await SharedPreferences.getInstance();

  final prevCount = prefs.getInt(_kScanCount) ?? 0;
  final prevAvg = prefs.getDouble(_kAvgSeverity) ?? 0;

  final newCount = prevCount + 1;
  final newAvg = ((prevAvg * prevCount) + severityScore) / newCount;

  await prefs.setInt(_kScanCount, newCount);
  await prefs.setDouble(_kAvgSeverity, newAvg);
  await prefs.setInt(
    _kLastScan,
    DateTime.now().millisecondsSinceEpoch,
  );
}

  Future<void> _saveScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final scansJson = recentScans
        .map((scan) {
          final img = scan['annotatedImage'] as Uint8List?;
          return {
            'timestamp': (scan['timestamp'] as DateTime).millisecondsSinceEpoch,
            'severity': scan['severity'],
            'conditions': scan['conditions'],
            'recommendations': scan['recommendations'],
            'image': img != null ? base64Encode(img) : null,
          };
        })
        .toList();
    
    await prefs.setString('scan_history', jsonEncode(scansJson));
  }


  Future<void> sendToBackend() async {
    if (selectedImageBytes == null) return;

    setState(() { 
      loading = true;
    });
    _scanController.repeat();


    try {
      final baseUrl =
      await AppConfig.getApiBaseUrl()
      ?? 'https://secondly-unlidded-lennox.ngrok-free.dev';


      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          selectedImageBytes!,
          filename: pickedImage?.name ?? 'face.jpg',
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception(body);
      }

      final decoded = jsonDecode(body);

      // ---- SAFE PARSING ----
      final rawSeverity = decoded['severity_score'];
      final parsedSeverity = rawSeverity is num
          ? rawSeverity.toInt()
          : int.tryParse(rawSeverity?.toString() ?? '');

      // support both annotated_image_base64 and annotated_image
      String? rawBase64 =
          decoded['annotated_image_base64'] ?? decoded['annotated_image'];
      if (rawBase64 != null && rawBase64.contains(',')) {
        rawBase64 = rawBase64.split(',').last;
      }

      final List<String> parsedIssues =
          (decoded['detected_conditions'] as List? ?? [])
              .map((e) => e.toString())
              .toList();

      final recRaw = decoded['recommendation'];
      List<String> parsedRecs;
      if (recRaw is List) {
        parsedRecs = recRaw.map((e) => e.toString()).toList();
      } else if (recRaw is String) {
        parsedRecs = recRaw
            .replaceAll(RegExp(r'[#*`]'), '')
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        parsedRecs = [];
      }

      Uint8List? imageBytes;
      if (rawBase64 != null && rawBase64.isNotEmpty) {
        imageBytes = base64Decode(rawBase64);
      }

      setState(() {
        severityScore = parsedSeverity ?? -1;
        issues = parsedIssues;
        recommendations = parsedRecs;
        analyzedImageBytes = imageBytes;
      });

      // store full scan history (latest first)
      recentScans.insert(0, {
        'timestamp': DateTime.now(),
        'severity': severityScore,
        'conditions': parsedIssues,
        'recommendations': parsedRecs,
        'annotatedImage': imageBytes,
      });
      await _updateScanStats();
      await _saveScanHistory();

      if (recentScans.length > 5) {
        recentScans.removeLast();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted){
        _scanController.stop();
        _scanController.reset();
        setState(() => loading = false);
      }
    }
  }

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

  Widget buildSeverityBar() {
  if (severityScore < 0) {
    return const Text('Severity unavailable');
  }

  final double targetValue =
      severityScore.clamp(0, 100) / 100.0;
  final Color barColor = _severityColor(severityScore);
  final String label = _severityLabel(severityScore);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Severity: $severityScore%',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: barColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      /// 🔥 FORCE animation restart
      TweenAnimationBuilder<double>(
        key: ValueKey(severityScore), // 👈 THIS is the fix
        tween: Tween<double>(begin: 0, end: targetValue),
        duration: const Duration(milliseconds: 9000),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 12,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          );
        },
      ),
    ],
  );
}






/// Parse LLM recommendation text into topic → bullet structure
Map<String, List<String>> _groupRecommendations(List<String> lines) {
  final Map<String, List<String>> sections = {};
  String currentTopic = 'General advice';

  void ensureTopic(String topic) {
    sections.putIfAbsent(topic, () => []);
  }

  ensureTopic(currentTopic);

  for (final raw in lines) {
    String line = raw.trim();

    if (line.isEmpty) continue;

    // Remove common LLM bullet/number prefixes repeatedly
line = line
    .replaceAll(RegExp(r'^[\s•\-\–\—\.\*]+'), '')
    .replaceAll(RegExp(r'^\d+[\.\)\-:]\s*'), '')
    .replaceAll(RegExp(r'^[a-zA-Z][\.\)]\s*'), '')
    .trim();


    final lower = line.toLowerCase();

    // ---- Topic detection (DO NOT discard content) ----
    if (lower.startsWith('sun protection') ||
        lower.startsWith('use sunscreen')) {
      currentTopic = 'Sun protection';
      ensureTopic(currentTopic);
    } else if (lower.startsWith('moistur')) {
      currentTopic = 'Moisturization';
      ensureTopic(currentTopic);
    } else if (lower.contains('retinoid')) {
      currentTopic = 'Topical retinoids';
      ensureTopic(currentTopic);
    } else if (lower.contains('salicylic') ||
        lower.contains('benzoyl')) {
      currentTopic = 'Acne actives';
      ensureTopic(currentTopic);
    } else if (lower.startsWith('additional')) {
      currentTopic = 'Additional advice';
      ensureTopic(currentTopic);
    }

    // ---- Merge paragraph continuation ----
    final bullets = sections[currentTopic]!;

    if (bullets.isNotEmpty &&
        !line.endsWith('.') &&
        bullets.last.length < 200) {
      bullets[bullets.length - 1] =
          '${bullets.last} $line';
    } else {
      bullets.add(line);
    }
  }

  return sections;
}


Widget _buildRecommendationSection() {
  if (recommendations.isEmpty) {
    return const SizedBox.shrink();
  }

  final textTheme = Theme.of(context).textTheme;
  final grouped = _groupRecommendations(recommendations);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // SECTION TITLE
      Text(
        'Personalized Skin Care Plan',
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 14),

      // GROUPED RECOMMENDATIONS
      ...grouped.entries
          .map((entry) {
            final topic = entry.key.trim();

            final bullets = entry.value
                .map((e) => e.trim())
                .where(
                  (e) =>
                      e.isNotEmpty &&
                      e.length > 8 &&
                      !e.toLowerCase().startsWith('recommendation') &&
                      !e.toLowerCase().startsWith('summary') &&
                      !e.toLowerCase().startsWith('additional'),
                )
                .toList();

            if (bullets.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOPIC TITLE
                  Text(
                    topic,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BULLETS
                  ...bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          })
          .where((widget) => widget is! SizedBox)
          .toList(),

      const SizedBox(height: 8),

      // CONTINUE CHAT BUTTON
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 18,
          ),
          label: const Text('Continue chat with AI'),
          onPressed: () {
            final contextSummary = StringBuffer();

            if (severityScore >= 0) {
              contextSummary.write(
                'Severity score: $severityScore%. ',
              );
            }

            if (issues.isNotEmpty) {
              contextSummary.write(
                'Detected conditions: ${issues.join(', ')}. ',
              );
            }

            if (recommendations.isNotEmpty) {
              contextSummary.write(
                'Care plan highlights: ${recommendations.take(5).join(' • ')}',
              );
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatbotPage(
                  initialSystemContext: contextSummary.toString(),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}



  String _formatConditionName(String condition) {
    // Convert snake_case to Title Case
    return condition
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildIssuesSection() {
    if (issues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detected conditions',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: issues
              .map(
                (issue) => Chip(
                  label: Text(_formatConditionName(issue)),
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget buildResultCard(BuildContext context) {
    final hasData = severityScore >= 0 ||
        issues.isNotEmpty ||
        recommendations.isNotEmpty ||
        analyzedImageBytes != null;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current analysis',
              style: Theme.of(context).textTheme.titleMedium),
          if (analyzedImageBytes != null) ...[
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: SafeArea(
                              child: InteractiveViewer(
                                child: Center(
                                  child: Image.memory(analyzedImageBytes!),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Image.memory(
                      analyzedImageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          buildSeverityBar(),
          const SizedBox(height: 16),
          _buildIssuesSection(),
          if (issues.isNotEmpty) const SizedBox(height: 16),
          _buildRecommendationSection(),
        ],
      ),
    );
  }

Widget _buildScanningOverlay() {
  return Positioned.fill(
    child: IgnorePointer(
      child: ClipOval(
        child: AnimatedBuilder(
          animation: _scanAnimation,
          builder: (context, _) {
            return Stack(
              children: [
                // subtle dim overlay
                Container(
                  color: Colors.black.withOpacity(0.15),
                ),

                // scanning line
                Align(
                  alignment: Alignment(0, _scanAnimation.value),
                  child: Container(
                    width: double.infinity,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.95),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  Widget buildCircularScanner(BuildContext context) {
  return Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 220,
        height: 220,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: selectedImageBytes == null
              ? GestureDetector(
                  onTap: () => pickImage(ImageSource.camera),
                  child: Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.5),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.35),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 38,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to scan',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Image.memory(
                  selectedImageBytes!,
                  fit: BoxFit.cover,
                  width: 220,
                  height: 220,
                ),
        ),
      ),
      if (loading) _buildScanningOverlay(),

      Positioned(
        bottom: 16,
        child: ElevatedButton.icon(
          style: AppTheme.pillButton(context, primary: true),
          onPressed: loading ? null : sendToBackend,
          icon: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            loading ? 'Analyzing...' : 'Scan skin',
          ),
        ),
      ),
    ],
  );
}


  Widget buildSourceButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: AppTheme.pillButton(context),
            onPressed: () => pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_outlined),
            label: const Text('Gallery'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: AppTheme.pillButton(context),
            onPressed: () => pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Camera'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentScans() {
    if (recentScans.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Past scans',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: recentScans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final scan = recentScans[index];
              final ts = scan['timestamp'] as DateTime;
              final sev = scan['severity'] as int;
              final cond = (scan['conditions'] as List).cast<String>();
              final img = scan['annotatedImage'] as Uint8List?;
              final color = _severityColor(sev);

              return InkWell(
                onTap: () {
                  setState(() {
                    severityScore = sev;
                    issues = cond;
                    recommendations =
                        (scan['recommendations'] as List).cast<String>();
                    analyzedImageBytes = img;
                  });
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.black12,
                        width: 54,
                        height: 54,
                        child: img != null
                            ? Image.memory(img, fit: BoxFit.cover)
                            : const Icon(
                                Icons.image_not_supported_outlined,
                                size: 28),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 4),
                          Text(
                            'Severity ${sev >= 0 ? '$sev%' : 'N/A'} • ${_severityLabel(sev)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (cond.isNotEmpty)
                            Text(
                              cond.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration(context)),
          Column(
            children: [
              const GlassAppBar(
                title: 'DermaScan AI',
                subtitle: 'Upload photo for analysis',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      buildCircularScanner(context),
                      const SizedBox(height: 18),
                      buildSourceButtons(context),
                      buildResultCard(context),
                      _buildRecentScans(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _ResultCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

