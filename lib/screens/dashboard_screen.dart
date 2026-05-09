import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/adas_state.dart';
import '../services/auth_service.dart';
import 'adas_camera_screen.dart';
import '../services/emergency_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final EmergencyService _emergencyService = EmergencyService();
  //bool _adasActive = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _features = [
    _FeatureData('Lane Detection', Icons.route_rounded, Color(0xFF3B82F6)),
    _FeatureData('Collision Warning', Icons.car_crash_rounded, Color(0xFFEF4444)),
    _FeatureData('Drowsiness Alert', Icons.bedtime_rounded, Color(0xFF8B5CF6)),
    _FeatureData('Sign Recognition', Icons.traffic_rounded, Color(0xFFF59E0B)),
    _FeatureData('Pothole Detection', Icons.warning_rounded, Color(0xFFEC4899)),
    _FeatureData('Safe Distance', Icons.social_distance_rounded, Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /*void _toggleADAS() {
    setState(() => _adasActive = !_adasActive);
    if (_adasActive) {
      if (kIsWeb) {
        _showSnackBar('ADAS not supported on Web', Icons.warning_amber, Colors.orange);
        return;
      }
      _showSnackBar('ADAS services started', Icons.check_circle, Colors.green);
    } else {
      if (kIsWeb) {
        _showSnackBar('ADAS stopped (Web Mode)', Icons.info, Colors.blue);
        return;
      }
      _showSnackBar('ADAS services stopped', Icons.info, Colors.grey);
    }
  }*/

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openADASCamera() {
    if (kIsWeb) {
      _showSnackBar('Camera not supported on Web', Icons.warning_amber, Colors.orange);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ADASCameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Automatically adapts to system theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    //new
    final adasState = context.watch<AdasState>();
    //final theme = _AppTheme(isDark: isDark, adasActive: _adasActive);
    final theme = _AppTheme(isDark: isDark, adasActive: adasState.isActive);

    return Scaffold(
      backgroundColor: theme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(theme),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20, 20, 20,
                  MediaQuery.of(context).padding.bottom + 90,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusCard(theme),
                    const SizedBox(height: 28),
                    _buildEmergencyButton(theme),

                    const SizedBox(height: 28),
                    _buildSectionHeader(theme),
                    const SizedBox(height: 16),
                    _buildFeaturesGrid(theme),
                    const SizedBox(height: 24),
                    _buildCameraButton(theme),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(_AppTheme theme) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.background,
      expandedHeight: 70,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.directions_car_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              'ADAS System',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        background: Container(color: theme.background),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: _ActionButton(
            icon: Icons.logout_rounded,
            color: theme.surface,
            iconColor: theme.textSecondary,
            onTap: () async => await _authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(_AppTheme theme) {
    final adasState = context.watch<AdasState>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: adasState.isActive
              ? [const Color(0xFF1D4ED8), const Color(0xFF2563EB), const Color(0xFF3B82F6)]
              : theme.isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                  : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: adasState.isActive
                ? const Color(0xFF3B82F6).withOpacity(0.35)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(
                        'System Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: adasState.isActive
                              ? Colors.white70
                              : theme.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: adasState.isActive
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (adasState.isActive
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFFEF4444))
                                      .withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            adasState.isActive ? 'Active & Monitoring' : 'Inactive',
                            style: TextStyle(
                              fontSize: 22,
                              color: adasState.isActive ? Colors.white : theme.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                /*_StyledSwitch(
                  value: _adasActive,
                  onChanged: (_) => _toggleADAS(),
                ),*/
                //new
                _StyledSwitch(
                value: adasState.isActive,
                onChanged: (_) {
                  adasState.toggleAdas();

                  if (adasState.isActive) {
                    if (kIsWeb) {
                      _showSnackBar('ADAS not supported on Web', Icons.warning_amber, Colors.orange);
                      return;
                    }
                    _showSnackBar('ADAS services started', Icons.check_circle, Colors.green);
                  } else {
                    _showSnackBar('ADAS services stopped', Icons.info, Colors.grey);
                  }
                },
              ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: adasState.isActive
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatusPill(Icons.visibility_rounded, 'Vision'),
                            _VerticalDivider(),
                            _StatusPill(Icons.sensors_rounded, 'Sensors'),
                            _VerticalDivider(),
                            _StatusPill(Icons.notifications_active_rounded, 'Alerts'),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(_AppTheme theme) {
    final adasState = context.watch<AdasState>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: adasState.isActive
                ? const Color(0xFF10B981).withOpacity(0.15)
                : theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: adasState.isActive
                  ? const Color(0xFF10B981)
                  : theme.divider,
              width: 1.5,
            ),
          ),
          child: Text(
            adasState.isActive ? '6 Active' : '0 Active',
            style: TextStyle(
              color: adasState.isActive ? const Color(0xFF10B981) : theme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid(_AppTheme theme) {
    final adasState = context.watch<AdasState>();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) {
        final f = _features[index];
        return _FeatureCard(
          data: f,
          active: adasState.isActive,
          theme: theme,
        );
      },
    );
  }

Widget _buildEmergencyButton(_AppTheme theme) {
  return GestureDetector(
    onTap: () async {

      final currentUser = FirebaseAuth.instance.currentUser;

if (currentUser == null) return;

final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();

final emergencyNumber =
    userDoc.data()?['emergencyContact'];

if (emergencyNumber == null ||
    emergencyNumber.toString().isEmpty) {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("No emergency contact found"),
      backgroundColor: Colors.red,
    ),
  );

  return;
}

      final success =
          await _emergencyService.sendEmergencyAlert(
        emergencyNumber,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Emergency SMS opened"
                : "Failed to send emergency alert",
          ),
          backgroundColor:
              success ? Colors.green : Colors.red,
        ),
      );
    },

    child: Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFDC2626),
            Color(0xFFB91C1C),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sos_rounded,
            color: Colors.white,
            size: 34,
          ),

          SizedBox(width: 14),

          Text(
            "EMERGENCY SOS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCameraButton(_AppTheme theme) {
    return GestureDetector(
      onTap: _openADASCamera,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openADASCamera,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withOpacity(0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Open Camera View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feature Data Model ────────────────────────────────────────────────────

class _FeatureData {
  final String title;
  final IconData icon;
  final Color color;
  const _FeatureData(this.title, this.icon, this.color);
}

// ─── Theme Helper ──────────────────────────────────────────────────────────

class _AppTheme {
  final bool isDark;
  final bool adasActive;

  const _AppTheme({required this.isDark, required this.adasActive});

  Color get background => isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF1F5F9);
  Color get surface => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  Color get surfaceVariant => isDark ? const Color(0xFF253147) : const Color(0xFFEEF2F7);
  Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get divider => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _StyledSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _StyledSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.1,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4ADE80),
        activeTrackColor: const Color(0xFF16A34A).withOpacity(0.6),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade600.withOpacity(0.4),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF4ADE80), size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.15),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  final bool active;
  final _AppTheme theme;

  const _FeatureCard({
    required this.data,
    required this.active,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? data.color.withOpacity(0.4) : theme.divider,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: data.color.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active
                    ? data.color.withOpacity(0.15)
                    : theme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.icon,
                size: 28,
                color: active ? data.color : theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? theme.textPrimary : theme.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: active ? data.color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                active ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? data.color : theme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}