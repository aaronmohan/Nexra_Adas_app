import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/adas_state.dart';
import '../services/auth_service.dart';
import '../screens/edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String _userName = "Driver";

  // ADAS toggles
  //bool _enableLaneDetection = true;
  //bool _enableCollisionWarning = true;
  //bool _enableDrowsinessDetection = true;
  //bool _enableTrafficSignRecognition = true;
  //bool _enablePotholeDetection = true;

  // App toggles
  bool _enableBackgroundProcessing = true;
  bool _enableNotifications = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadUserName();
  }
    Future<void> _loadUserName() async {
      final user = _authService.currentUser;
      if (user == null) return;

      final data = await _authService.getUserData(user.uid);

      if (data != null && mounted) {
        setState(() {
          _userName = data.name;
        });
      }
    }
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adas = context.watch<AdasState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _SettingsTheme(isDark: isDark);

    return Scaffold(
      backgroundColor: theme.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(theme),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20, 8, 20,
                  MediaQuery.of(context).padding.bottom + 90,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Profile card
                    _buildProfileCard(theme),
                    const SizedBox(height: 28),

                    // ADAS Features section
                    _SectionLabel(label: 'ADAS Features', theme: theme),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      theme: theme,
                      children: [
                        _SettingsTile(
                          icon: Icons.route_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Lane Detection',
                          subtitle: 'Alert when drifting from lane',
                          value: adas.laneEnabled, 
                          theme: theme,
                          onChanged: (v) => adas.setLane(v),
                        ),
                        _Separator(theme: theme),
                        _SettingsTile(
                          icon: Icons.car_crash_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'Collision Warning',
                          subtitle: 'Alert when too close to vehicle ahead',
                          value: adas.collisionEnabled,
                          theme: theme,
                          onChanged: (v) => adas.setCollision(v),
                        ),
                        _Separator(theme: theme),
                        _SettingsTile(
                          icon: Icons.bedtime_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Drowsiness Detection',
                          subtitle: 'Monitor driver alertness levels',
                          value: adas.drowsinessEnabled,
                          theme: theme,
                          onChanged: (v) => adas.setDrowsiness(v),
                        ),
                        _Separator(theme: theme),
                        _SettingsTile(
                          icon: Icons.traffic_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Traffic Sign Recognition',
                          subtitle: 'Identify and display road signs',
                          value: adas.trafficSignEnabled,
                          theme: theme,
                          onChanged: (v) => adas.setTrafficSign(v),
                        ),
                        _Separator(theme: theme),
                        _SettingsTile(
                          icon: Icons.warning_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: 'Pothole Detection',
                          subtitle: 'Detect and record road hazards',
                          value: adas.potholeEnabled,
                          theme: theme,
                          onChanged: (v) => adas.setPothole(v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // App Settings section
                    _SectionLabel(label: 'App Settings', theme: theme),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      theme: theme,
                      children: [
                        _SettingsTile(
                          icon: Icons.memory_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Background Processing',
                          subtitle: 'Keep app active in background',
                          value: _enableBackgroundProcessing,
                          theme: theme,
                          onChanged: (v) => setState(() => _enableBackgroundProcessing = v),
                        ),
                        _Separator(theme: theme),
                        _SettingsTile(
                          icon: Icons.notifications_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Notifications',
                          subtitle: 'Enable real-time ADAS alerts',
                          value: _enableNotifications,
                          theme: theme,
                          onChanged: (v) => setState(() => _enableNotifications = v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // About section
                    _SectionLabel(label: 'About', theme: theme),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      theme: theme,
                      children: [
                        _InfoTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: const Color(0xFF64748B),
                          title: 'App Version',
                          value: '1.0.0',
                          theme: theme,
                        ),
                        _Separator(theme: theme),
                        _InfoTile(
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF64748B),
                          title: 'Privacy Policy',
                          value: '',
                          showChevron: true,
                          theme: theme,
                          onTap: () {},
                        ),
                        _Separator(theme: theme),
                        _InfoTile(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF64748B),
                          title: 'Terms of Service',
                          value: '',
                          showChevron: true,
                          theme: theme,
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Sign Out button
                    _buildSignOutButton(theme),

                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'ADAS System · v1.0.0',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(_SettingsTheme theme) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.background,
      expandedHeight: 60,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        background: Container(color: theme.background),
      ),
    );
  }

Widget _buildProfileCard(_SettingsTheme theme) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: theme.isDark
            ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
            : [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3B82F6).withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),

        const SizedBox(width: 16),

        // Name + Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'ADAS monitoring active',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Edit Button
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditProfileScreen(),
              ),
            ).then((_) => _loadUserName());
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSignOutButton(_SettingsTheme theme) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => _SignOutDialog(theme: theme),
        );
        if (confirm == true) await _authService.signOut();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(theme.isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme ─────────────────────────────────────────────────────────────────

class _SettingsTheme {
  final bool isDark;
  const _SettingsTheme({required this.isDark});

  Color get background => isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF1F5F9);
  Color get surface => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted => isDark ? const Color(0xFF475569) : const Color(0xFFADB5BD);
  Color get divider => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get separator => isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0);
}

// ─── Reusable Widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final _SettingsTheme theme;

  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final _SettingsTheme theme;

  const _SettingsGroup({required this.children, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final _SettingsTheme theme;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CompactSwitch(value: value, color: iconColor, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      activeColor: Colors.white,
      activeTrackColor: color,
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.withOpacity(0.25),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final bool showChevron;
  final _SettingsTheme theme;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.showChevron = false,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: theme.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  final _SettingsTheme theme;
  const _Separator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: theme.separator),
    );
  }
}

// ─── Sign Out Confirmation Dialog ──────────────────────────────────────────

class _SignOutDialog extends StatelessWidget {
  final _SettingsTheme theme;
  const _SignOutDialog({required this.theme});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Sign Out?',
        style: TextStyle(
          color: theme.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Text(
        'You will need to sign in again to access ADAS monitoring.',
        style: TextStyle(color: theme.textSecondary, fontSize: 14),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: theme.separator),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}