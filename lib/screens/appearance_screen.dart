import 'package:flutter/material.dart';
import 'package:light/light.dart';
import '../core/thems/app_theme_notifier.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/thems/app_colors.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _isAutoSunModeEnabled = false;
  Light? _light;
  StreamSubscription? _subscription;

  int _autoDayThemeIndex = 1;
  int _autoNightThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  @override
  void dispose() {
    _stopListeningToLightSensor();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoSunModeEnabled = prefs.getBool('auto_sun_mode') ?? false;
      _autoDayThemeIndex = prefs.getInt('auto_day_theme_index') ?? 1;
      _autoNightThemeIndex = prefs.getInt('auto_night_theme_index') ?? 0;
    });

    if (_isAutoSunModeEnabled) {
      _startListeningToLightSensor();
    }
  }

  void _toggleAutoSunMode(bool enabled) {
    setState(() => _isAutoSunModeEnabled = enabled);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('auto_sun_mode', enabled));

    if (enabled) {
      _startListeningToLightSensor();
    } else {
      _stopListeningToLightSensor();
    }
  }

  void _startListeningToLightSensor() {
    try {
      _light = Light();
      _subscription = _light?.lightSensorStream.listen((int luxValue) {
        if (luxValue > 10000) {
          if (themeNotifier.currentThemeIndex != _autoDayThemeIndex) {
            themeNotifier.setThemeIndex(_autoDayThemeIndex);
          }
        } else {
          if (themeNotifier.currentThemeIndex != _autoNightThemeIndex) {
            themeNotifier.setThemeIndex(_autoNightThemeIndex);
          }
        }
      });
    } catch (_) {}
  }

  void _stopListeningToLightSensor() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _navigateToCreateThemeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateCustomThemeScreen(),
      ),
    );
  }

  void _navigateToAutoSunSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AutoSunSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              'إعدادات المظهر',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            centerTitle: true,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'السمات المفضلة',
                    style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _navigateToCreateThemeScreen,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 4),
                            Text('إنشاء سمة مخصصة', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Stack(
                children: [
                  Opacity(
                    opacity: _isAutoSunModeEnabled ? 0.35 : 1.0,
                    child: IgnorePointer(
                      ignoring: _isAutoSunModeEnabled,
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.1,
                        children: [
                          _buildThemeCard('الوضع الداكن', const Color(0xFF121212), const Color(0xFF1E1E1E), 0),
                          _buildThemeCard('الوضع الفاتح', Colors.white, const Color(0xFFF5F5F7), 1),
                          _buildThemeCard('الوضع الوردي', AppColors.pinkPrimary, AppColors.pinkSurface, 2),
                          _buildThemeCard('الوضع الأخضر', AppColors.greenPrimary, AppColors.greenSurface, 3),

                          ...List.generate(themeNotifier.customThemes.length, (i) {
                            final item = themeNotifier.customThemes[i];
                            return Stack(
                              children: [
                                _buildThemeCard(item['name'], Color(item['primary']), Color(item['bg']), 4 + i),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: GestureDetector(
                                    onTap: () => themeNotifier.deleteCustomTheme(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  if (_isAutoSunModeEnabled)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'يرجى إيقاف الوضع التلقائي لتغيير السمة يدوياً',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('الوضع التلقائي (الضوء/الشمس)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text('التبديل التلقائي للوضع بناءً على الإضاءة المحيطة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      value: _isAutoSunModeEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: _toggleAutoSunMode,
                    ),
                    if (_isAutoSunModeEnabled) ...[
                      const Divider(height: 1, color: Colors.white12),
                      ListTile(
                        onTap: _navigateToAutoSunSettingsScreen,
                        leading: Icon(Icons.wb_sunny_rounded, color: AppColors.primary),
                        title: Text('تخصيص سمات الوضع التلقائي', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeCard(String title, Color c1, Color c2, int index) {
    bool isSelected = themeNotifier.currentThemeIndex == index;
    return GestureDetector(
      onTap: () => themeNotifier.setThemeIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.5),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(painter: DiagonalSplitPainter(c1, c2), child: Container()),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class AutoSunSettingsScreen extends StatefulWidget {
  const AutoSunSettingsScreen({super.key});

  @override
  State<AutoSunSettingsScreen> createState() => _AutoSunSettingsScreenState();
}

class _AutoSunSettingsScreenState extends State<AutoSunSettingsScreen> {
  int _dayIndex = 1;
  int _nightIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dayIndex = prefs.getInt('auto_day_theme_index') ?? 1;
      _nightIndex = prefs.getInt('auto_night_theme_index') ?? 0;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_day_theme_index', _dayIndex);
    await prefs.setInt('auto_night_theme_index', _nightIndex);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> allThemes = [
      {'name': 'الوضع الداكن', 'c1': const Color(0xFF121212), 'c2': const Color(0xFF1E1E1E)},
      {'name': 'الوضع الفاتح', 'c1': Colors.white, 'c2': const Color(0xFFF5F5F7)},
      {'name': 'الوضع الوردي', 'c1': AppColors.pinkPrimary, 'c2': AppColors.pinkSurface},
      {'name': 'الوضع الأخضر', 'c1': AppColors.greenPrimary, 'c2': AppColors.greenSurface},
      ...themeNotifier.customThemes.map((e) => {
            'name': e['name'].toString(),
            'c1': Color(e['primary']),
            'c2': Color(e['bg']),
          })
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('إعدادات السمات التلقائية', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text('سمة النهار (إضاءة عالية)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allThemes.length,
              itemBuilder: (context, index) {
                final item = allThemes[index];
                bool isSelected = _dayIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _dayIndex = index),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CustomPaint(painter: DiagonalSplitPainter(item['c1'], item['c2']), child: Container()),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          Text('سمة الليل (إضاءة منخفضة)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allThemes.length,
              itemBuilder: (context, index) {
                final item = allThemes[index];
                bool isSelected = _nightIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _nightIndex = index),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CustomPaint(painter: DiagonalSplitPainter(item['c1'], item['c2']), child: Container()),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _savePrefs,
              child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateCustomThemeScreen extends StatefulWidget {
  const CreateCustomThemeScreen({super.key});

  @override
  State<CreateCustomThemeScreen> createState() => _CreateCustomThemeScreenState();
}

class _CreateCustomThemeScreenState extends State<CreateCustomThemeScreen> {
  final TextEditingController _nameController = TextEditingController();
  
  late Color _selectedPrimary;
  late Color _selectedBg;
  late Color _selectedSurface;
  late Color _selectedTextPrimary;

  @override
  void initState() {
    super.initState();
    _selectedPrimary = AppColors.primary;
    _selectedBg = AppColors.background;
    _selectedSurface = AppColors.surface;
    _selectedTextPrimary = AppColors.textPrimary;
  }

  void _showColorPicker(Color currentColor, ValueChanged<Color> onColorChanged) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('اختر اللون', style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (color) => tempColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تم', style: TextStyle(color: Colors.white)),
            onPressed: () {
              onColorChanged(tempColor);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('إنشاء سمة مخصصة', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'اسم السمة',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildColorOptionRow('اللون الأساسي (Primary)', _selectedPrimary, (c) => setState(() => _selectedPrimary = c)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12)),
                _buildColorOptionRow('لون الخلفية (Background)', _selectedBg, (c) => setState(() => _selectedBg = c)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12)),
                _buildColorOptionRow('لون الأسطح والكروت (Surface)', _selectedSurface, (c) => setState(() => _selectedSurface = c)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12)),
                _buildColorOptionRow('لون النصوص (Text)', _selectedTextPrimary, (c) => setState(() => _selectedTextPrimary = c)),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          
          Text(
            'معاينة حية',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _selectedPrimary.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('عنوان تجريبي', style: TextStyle(color: _selectedTextPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(Icons.palette_rounded, color: _selectedPrimary),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _selectedPrimary, size: 20),
                      const SizedBox(width: 10),
                      Text('هذا نص داخل بطاقة المعاينة', style: TextStyle(color: _selectedTextPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {},
                    child: const Text('زر تجريبي', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text('الرجاء إدخال اسم السمة أولاً', style: TextStyle(color: Colors.white)),
                    ),
                  );
                  return;
                }
                
                themeNotifier.addCustomThemeWith4Colors(
                  _nameController.text.trim(), 
                  _selectedPrimary, 
                  _selectedBg, 
                  _selectedSurface, 
                  _selectedTextPrimary
                );
                Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOptionRow(String title, Color color, ValueChanged<Color> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: () => _showColorPicker(color, onChanged),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class DiagonalSplitPainter extends CustomPainter {
  final Color c1, c2;
  DiagonalSplitPainter(this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = c1;
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(0, size.height)..close(), paint);
    paint.color = c2;
    canvas.drawPath(Path()..moveTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}