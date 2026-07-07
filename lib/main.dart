import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'macro_eval.dart';
import 'supabase_config.dart';

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

String? _activeProfileId;
Map<String, dynamic>? _activeProfile;
// Override for local development with: --dart-define=PULSE_API=http://127.0.0.1:8000
const String _baseUrl = String.fromEnvironment(
  'PULSE_API',
  defaultValue: 'https://web-production-2514b.up.railway.app',
);

const List<String> _workoutTypes = [
  'Push', 'Pull', 'Legs', 'Upper', 'Lower', 'Full Body', 'Rest', 'Custom',
];

const List<String> _dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const PulseApp());
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class PlanExercise {
  String name;
  int targetSets;
  int targetReps;
  PlanExercise({required this.name, this.targetSets = 3, this.targetReps = 8});

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      name: json['exercise_name'] as String? ?? '',
      targetSets: (json['target_sets'] as int?) ?? 3,
      targetReps: (json['target_reps'] as int?) ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
    'exercise_name': name,
    'sort_order': 0,
    'target_sets': targetSets,
    'target_reps': targetReps,
  };
}

class PlanDay {
  int dayNumber;
  String workoutType;
  List<PlanExercise> exercises;
  PlanDay({
    required this.dayNumber,
    this.workoutType = 'Rest',
    List<PlanExercise>? exercises,
  }) : exercises = exercises ?? [];

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    final exList = (json['exercises'] as List<dynamic>?)
            ?.map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PlanDay(
      dayNumber: (json['day_number'] as int?) ?? 1,
      workoutType: (json['workout_type'] as String?) ?? 'Rest',
      exercises: exList,
    );
  }

  Map<String, dynamic> toJson() => {
    'day_number': dayNumber,
    'workout_type': workoutType,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

class WorkoutPlan {
  String id;
  String name;
  List<PlanDay> days;
  WorkoutPlan({required this.id, required this.name, required this.days});

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final dayList = (json['days'] as List<dynamic>?)
            ?.map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return WorkoutPlan(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      days: dayList,
    );
  }
}

class LoggedSet {
  String exerciseName;
  double weightKg;
  int reps;
  int setDurationSeconds;
  LoggedSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.setDurationSeconds,
  });
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFFA78BFA),
          surface: Color(0xFF13131A),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C27),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF7C3AED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2D2D3D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8B8B9E)),
          hintStyle: const TextStyle(color: Color(0xFF4A4A5A)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF13131A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1E1E2E), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0D0D14),
          indicatorColor: const Color(0xFF7C3AED).withOpacity(0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: Color(0xFF5A5A6E), fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFFA78BFA));
            }
            return const IconThemeData(color: Color(0xFF5A5A6E));
          }),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Screen — gates on profile existence
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<AuthState>? _authSub;
  bool _loadingProfile = false;
  bool _needsOnboarding = false;
  String? _loadError;

  Session? get _session => Supabase.instance.client.auth.currentSession;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut) {
        _activeProfileId = null;
        _activeProfile = null;
        setState(() {
          _needsOnboarding = false;
          _loadError = null;
        });
      } else if (state.session != null && _activeProfileId == null) {
        _loadProfile(state.session!.user.id);
      }
    });
    // Session restored from local storage (returning user) — load their data.
    final session = _session;
    if (session != null && _activeProfileId == null) {
      _loadProfile(session.user.id);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile(String userId) async {
    if (_loadingProfile) return;
    setState(() {
      _loadingProfile = true;
      _loadError = null;
      _needsOnboarding = false;
    });
    try {
      final r =
          await http.get(Uri.parse('$_baseUrl/api/user/profile/$userId'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        _activeProfile = jsonDecode(r.body) as Map<String, dynamic>;
        _activeProfileId = userId;
        setState(() => _loadingProfile = false);
      } else if (r.statusCode == 404) {
        // Signed in but never set up a profile — send them to onboarding.
        setState(() {
          _loadingProfile = false;
          _needsOnboarding = true;
        });
      } else {
        setState(() {
          _loadingProfile = false;
          _loadError = 'Server error (${r.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _loadError = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return _SplashScreen(onSignedIn: () => setState(() {}));
    }
    if (_loadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFF5A5A6E), size: 48),
              const SizedBox(height: 16),
              Text(_loadError!,
                  style: const TextStyle(color: Color(0xFF8B8B9E))),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _loadProfile(session.user.id),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Sign out',
                    style: TextStyle(color: Color(0xFF8B8B9E))),
              ),
            ],
          ),
        ),
      );
    }
    if (_needsOnboarding) {
      return OnboardingScreen(
        onDone: () => setState(() => _needsOnboarding = false),
      );
    }
    if (_activeProfileId == null) {
      // Session exists but profile hasn't been fetched yet (e.g. right after
      // an OAuth redirect) — the auth listener will kick off the load.
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }
    return const _MainShell();
  }
}

// ---------------------------------------------------------------------------
// Splash Screen
// ---------------------------------------------------------------------------

class _SplashScreen extends StatelessWidget {
  final VoidCallback onSignedIn;
  const _SplashScreen({required this.onSignedIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Stack(
          children: [
            // Purple glow blobs
            Positioned(
              top: -80, left: -60,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF7C3AED).withOpacity(0.22), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100, right: -80,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF4F46E5).withOpacity(0.15), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'PULSE',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Train smarter. Recover better.',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8B8B9E), letterSpacing: 0.3),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 2),
                  // Feature pills
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10, runSpacing: 10,
                    children: ['Workout Plans', 'Calorie Targets', 'AI Coach'].map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13131A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2D2D3D)),
                        ),
                        child: Text(label, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 13)),
                      );
                    }).toList(),
                  ),
                  const Spacer(flex: 1),
                  // CTA
                  _GradientButton(
                    label: 'Get Started',
                    icon: Icons.arrow_forward_rounded,
                    large: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                      onSignedIn();
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main Shell
// ---------------------------------------------------------------------------

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _WorkoutTab(),
          NutritionScreen(),
          CoachScreen(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Workout',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department),
              label: 'Nutrition',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Coach',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Tab
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  String _fmt(dynamic v) => v == null ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = _activeProfile ?? {};
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Account card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0A2E), Color(0xFF13131A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2D1B60)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fmt(profile['name']),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? 'Signed in',
                          style: const TextStyle(
                              color: Color(0xFF8B8B9E), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Stats
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E1E2E)),
              ),
              child: Column(
                children: [
                  _statRow('Age', _fmt(profile['age'])),
                  _statRow('Sex', _fmt(profile['sex'])),
                  _statRow('Height', '${_fmt(profile['height_cm'])} cm'),
                  _statRow('Weight', '${_fmt(profile['weight_kg'])} kg'),
                  _statRow('Activity level', _fmt(profile['activity_level'])),
                  _statRow('Goal', _fmt(profile['goal']), last: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _GradientButton(
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                );
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                label: const Text('Sign Out',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3D1E1E)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B8B9E))),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Tab
// ---------------------------------------------------------------------------

class _WorkoutTab extends StatefulWidget {
  const _WorkoutTab();

  @override
  State<_WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<_WorkoutTab> {
  bool _loadingActivePlan = true;
  WorkoutPlan? _activePlan;
  String? _activePlanStartDate;
  int? _todayCycleDay;
  Map<String, dynamic>? _todaySession; // non-null if workout already logged today
  bool _logExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadActivePlan();
  }

  String get _todayDateStr {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadActivePlan() async {
    final profileId = _activeProfileId;
    if (profileId == null) {
      if (mounted) setState(() => _loadingActivePlan = false);
      return;
    }
    setState(() => _loadingActivePlan = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/workout/active-plan/$profileId')),
        http.get(Uri.parse('$_baseUrl/api/workout/history/$profileId')),
      ]);

      if (!mounted) return;

      // Parse active plan
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body) as Map<String, dynamic>;
        final active = data['active'] as bool? ?? false;
        if (active) {
          final plan = WorkoutPlan.fromJson(data['plan'] as Map<String, dynamic>);
          final startDateStr = data['start_date'] as String;
          final start = DateTime.parse(startDateStr);
          final today = DateTime.now();
          final diff = today.difference(DateTime(start.year, start.month, start.day)).inDays;
          _activePlan = plan;
          _activePlanStartDate = startDateStr;
          _todayCycleDay = (diff % 7) + 1;
        } else {
          _activePlan = null;
          _activePlanStartDate = null;
          _todayCycleDay = null;
        }
      }

      // Check if workout already logged today
      if (responses[1].statusCode == 200) {
        final sessions = jsonDecode(responses[1].body) as List<dynamic>;
        final todayStr = _todayDateStr;
        final todaySession = sessions.cast<Map<String, dynamic>>().where((s) {
          final d = s['date'] as String? ?? '';
          return d.startsWith(todayStr);
        }).toList();
        _todaySession = todaySession.isNotEmpty ? todaySession.first : null;
      }

      if (mounted) setState(() => _loadingActivePlan = false);
    } catch (_) {
      if (mounted) setState(() => _loadingActivePlan = false);
    }
  }

  Widget _buildCompletedCard(Map<String, dynamic> session) {
    final totalSets = (session['total_sets'] as num?)?.toInt() ?? 0;
    final sessionName = session['session_name'] as String? ?? 'Workout';
    final sets = (session['exercise_sets'] as List<dynamic>?) ?? [];

    // Group sets by exercise
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in sets.cast<Map<String, dynamic>>()) {
      final name = s['exercise_name'] as String? ?? '';
      grouped.putIfAbsent(name, () => []).add(s);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A3D26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout Complete',
                        style: TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$sessionName · $totalSets sets logged',
                        style: const TextStyle(color: Color(0xFF5A7A62), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (grouped.isNotEmpty) ...[
            const Divider(color: Color(0xFF1A3020), height: 1),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              onTap: () => setState(() => _logExpanded = !_logExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Text('View Full Log', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(
                      _logExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4ADE80),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_logExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: grouped.entries.map((entry) {
                    final exSets = entry.value;
                    final maxWeight = exSets.fold<double>(
                        0, (m, s) => ((s['weight_kg'] as num?)?.toDouble() ?? 0) > m
                            ? (s['weight_kg'] as num).toDouble()
                            : m);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          ...exSets.asMap().entries.map((e) {
                            final s = e.value;
                            final w = (s['weight_kg'] as num?)?.toStringAsFixed(1) ?? '0';
                            final r = s['reps'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                'Set ${e.key + 1}  ·  ${w} kg × $r reps',
                                style: const TextStyle(color: Color(0xFF5A7A62), fontSize: 12),
                              ),
                            );
                          }),
                          if (exSets.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Peak: ${maxWeight.toStringAsFixed(1)} kg',
                                style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayPill(int dayNum, bool isCurrent, bool isRest) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final letter = letters[dayNum - 1];
    return Column(
      children: [
        Text(
          letter,
          style: TextStyle(
            color: isCurrent ? const Color(0xFFA78BFA) : const Color(0xFF3A3A4A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCurrent ? null : const Color(0xFF1C1C27),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isCurrent
                  ? Colors.transparent
                  : isRest
                      ? const Color(0xFF2D2D3D)
                      : const Color(0xFF4F46E5).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: isCurrent
                ? [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Icon(
            isRest ? Icons.bedtime_outlined : Icons.fitness_center_rounded,
            size: 14,
            color: isCurrent
                ? Colors.white
                : isRest
                    ? const Color(0xFF3A3A4A)
                    : const Color(0xFF4F46E5).withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  void _startTodaysWorkout() {
    final plan = _activePlan;
    final cycleDay = _todayCycleDay;
    final profileId = _activeProfileId;
    if (plan == null || cycleDay == null || profileId == null) return;
    final todayPlanDay = plan.days.firstWhere(
      (d) => d.dayNumber == cycleDay,
      orElse: () => PlanDay(dayNumber: cycleDay),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(planDay: todayPlanDay, profileId: profileId),
      ),
    ).then((_) => _loadActivePlan());
  }

  @override
  Widget build(BuildContext context) {
    final profileId = _activeProfileId;

    if (profileId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Stack(
            children: [
              // Background gradient blob
              Positioned(
                top: -80,
                left: -60,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF7C3AED).withOpacity(0.25), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                right: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF4F46E5).withOpacity(0.15), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'PULSE',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Train smarter. Recover better.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF8B8B9E), letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 56),
                    _GradientButton(
                      label: 'Get Started',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                        ).then((_) => _loadActivePlan());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingActivePlan) {
      return const Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    final plan = _activePlan;
    final cycleDay = _todayCycleDay;

    if (plan == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C27),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2D2D3D)),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, size: 40, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(height: 28),
                const Text(
                  'No Active Plan',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Build a 7-day split and let Pulse track your cycle automatically.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF8B8B9E), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _GradientButton(
                  label: 'Create Your First Plan',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlanListScreen()),
                    ).then((_) => _loadActivePlan());
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final todayDay = plan.days.firstWhere(
      (d) => d.dayNumber == cycleDay,
      orElse: () => PlanDay(dayNumber: cycleDay ?? 1),
    );
    final isRestDay = todayDay.workoutType == 'Rest';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A0A2E), Color(0xFF0A0A0F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PULSE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                            letterSpacing: 3,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PlanListScreen()),
                            ).then((_) => _loadActivePlan());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C27),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF2D2D3D)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFFA78BFA)),
                                SizedBox(width: 6),
                                Text('My Plans', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _greetingText(),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF8B8B9E), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _todayFullDate(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                    ),
                  ],
                ),
              ),
              // ── Weekly strip ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E1E2E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('THIS WEEK', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(plan.name, style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final dayNum = i + 1;
                          final isCurrent = dayNum == (cycleDay ?? 0);
                          final pd = plan.days.firstWhere(
                            (d) => d.dayNumber == dayNum,
                            orElse: () => PlanDay(dayNumber: dayNum),
                          );
                          return _buildDayPill(dayNum, isCurrent, pd.workoutType == 'Rest');
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Plan card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E1E2E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TODAY'S WORKOUT", style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isRestDay ? 'Rest & Recover' : todayDay.workoutType,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isRestDay ? const Color(0xFF5A5A6E) : Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
                            ),
                            child: Text(
                              'Day ${cycleDay ?? 1} of 7',
                              style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (!isRestDay && todayDay.exercises.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('EXERCISES', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: todayDay.exercises.map((ex) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C27),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF2D2D3D)),
                              ),
                              child: Text(ex.name, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12, fontWeight: FontWeight.w500)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Action area ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: isRestDay
                  ? Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13131A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1E1E2E)),
                      ),
                      child: const Column(
                        children: [
                          Text('😴', style: TextStyle(fontSize: 44)),
                          SizedBox(height: 14),
                          Text('Rest Day', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF5A5A6E))),
                          SizedBox(height: 6),
                          Text(
                            'Recovery is where gains are made.\nTake it easy today.',
                            style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 13, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _todaySession != null
                    ? _buildCompletedCard(_todaySession!)
                    : _GradientButton(
                        label: todayDay.exercises.isEmpty ? 'No exercises set up' : 'Start Today\'s Workout',
                        onTap: todayDay.exercises.isEmpty ? null : _startTodaysWorkout,
                        icon: Icons.play_arrow_rounded,
                        large: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final name = _activeProfile?['name'] as String? ?? '';
    final prefix = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return name.isNotEmpty ? '$prefix, $name 👋' : prefix;
  }

  String _todayFullDate() {
    final now = DateTime.now();
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = days[now.weekday - 1];
    return '$weekday, ${months[now.month - 1]} ${now.day}';
  }
}

// ---------------------------------------------------------------------------
// Nutrition Data Models
// ---------------------------------------------------------------------------

class FoodEntry {
  final String id;
  final String mealType;
  final String foodName;
  final int calories;
  final double proteinG;
  final double carbG;
  final double fatG;
  final double quantity;
  final String unit;

  FoodEntry({
    required this.id,
    required this.mealType,
    required this.foodName,
    required this.calories,
    this.proteinG = 0,
    this.carbG = 0,
    this.fatG = 0,
    this.quantity = 1,
    this.unit = 'serving',
  });

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String? ?? '',
        mealType: j['meal_type'] as String? ?? 'snack',
        foodName: j['food_name'] as String? ?? '',
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        proteinG: (j['protein_g'] as num?)?.toDouble() ?? 0,
        carbG: (j['carb_g'] as num?)?.toDouble() ?? 0,
        fatG: (j['fat_g'] as num?)?.toDouble() ?? 0,
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        unit: j['unit'] as String? ?? 'serving',
      );
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final int servings;
  final int caloriesPerServing;
  final double proteinG;
  final double carbG;
  final double fatG;
  final String instructions;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? sourceCreator;

  Recipe({
    required this.id,
    required this.name,
    this.description = '',
    required this.servings,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    this.instructions = '',
    this.sourceUrl,
    this.sourcePlatform,
    this.sourceCreator,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        servings: (j['servings'] as num?)?.toInt() ?? 1,
        caloriesPerServing: (j['calories_per_serving'] as num?)?.toInt() ?? 0,
        proteinG: (j['protein_g'] as num?)?.toDouble() ?? 0,
        carbG: (j['carb_g'] as num?)?.toDouble() ?? 0,
        fatG: (j['fat_g'] as num?)?.toDouble() ?? 0,
        instructions: j['instructions'] as String? ?? '',
        sourceUrl: j['source_url'] as String?,
        sourcePlatform: j['source_platform'] as String?,
        sourceCreator: j['source_creator'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Nutrition Screen
// ---------------------------------------------------------------------------

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  bool _loadingPlan = true;
  bool _loadingLog = false;
  Map<String, dynamic>? _plan;
  Map<String, List<FoodEntry>> _meals = {'breakfast': [], 'lunch': [], 'dinner': [], 'snack': []};
  Map<String, double> _loggedTotals = {'calories': 0, 'protein_g': 0, 'carb_g': 0, 'fat_g': 0};
  List<Recipe> _recipes = [];
  int _tab = 0; // 0=Log, 1=Recipes

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override
  void initState() {
    super.initState();
    if (_activeProfileId != null) _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPlan(), _loadLog(), _loadRecipes()]);
  }

  Future<void> _loadPlan() async {
    final id = _activeProfileId; if (id == null) return;
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/nutrition/plan/$id'));
      if (r.statusCode == 200 && mounted) setState(() { _plan = jsonDecode(r.body); _loadingPlan = false; });
    } catch (_) { if (mounted) setState(() => _loadingPlan = false); }
  }

  Future<void> _loadLog() async {
    final id = _activeProfileId; if (id == null) return;
    setState(() => _loadingLog = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/nutrition/log/$id/$_todayStr'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final rawMeals = data['meals'] as Map<String, dynamic>? ?? {};
        final totals = data['totals'] as Map<String, dynamic>? ?? {};
        setState(() {
          _meals = {
            'breakfast': (rawMeals['breakfast'] as List? ?? []).map((e) => FoodEntry.fromJson(e)).toList(),
            'lunch':     (rawMeals['lunch']     as List? ?? []).map((e) => FoodEntry.fromJson(e)).toList(),
            'dinner':    (rawMeals['dinner']    as List? ?? []).map((e) => FoodEntry.fromJson(e)).toList(),
            'snack':     (rawMeals['snack']     as List? ?? []).map((e) => FoodEntry.fromJson(e)).toList(),
          };
          _loggedTotals = {
            'calories':  (totals['calories']  as num?)?.toDouble() ?? 0,
            'protein_g': (totals['protein_g'] as num?)?.toDouble() ?? 0,
            'carb_g':    (totals['carb_g']    as num?)?.toDouble() ?? 0,
            'fat_g':     (totals['fat_g']     as num?)?.toDouble() ?? 0,
          };
          _loadingLog = false;
        });
      } else { setState(() => _loadingLog = false); }
    } catch (_) { if (mounted) setState(() => _loadingLog = false); }
  }

  Future<void> _loadRecipes() async {
    final id = _activeProfileId; if (id == null) return;
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/nutrition/recipes/$id'));
      if (r.statusCode == 200 && mounted) {
        final list = jsonDecode(r.body) as List;
        setState(() => _recipes = list.map((e) => Recipe.fromJson(e)).toList());
      }
    } catch (_) {}
  }

  Future<void> _deleteEntry(String entryId) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/api/nutrition/log/$entryId'));
      _loadLog();
    } catch (_) {}
  }

  Future<void> _deleteRecipe(String recipeId) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/api/nutrition/recipes/$recipeId'));
      _loadRecipes();
    } catch (_) {}
  }

  Future<void> _logRecipe(Recipe recipe, String mealType, double servings) async {
    final id = _activeProfileId; if (id == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/nutrition/recipes/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': id, 'recipe_id': recipe.id, 'date': _todayStr, 'meal_type': mealType, 'servings': servings}),
      );
      _loadLog();
    } catch (_) {}
  }

  String _goalLabel(String goal) {
    return {'bulk': 'Bulking +300', 'cut': 'Cutting −500', 'recomp': 'Body Recomp'}[goal] ?? 'Maintaining';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: AppBar(
          title: const Text('Nutrition'),
          bottom: TabBar(
            onTap: (i) => setState(() => _tab = i),
            indicatorColor: const Color(0xFF7C3AED),
            labelColor: const Color(0xFFA78BFA),
            unselectedLabelColor: const Color(0xFF5A5A6E),
            tabs: const [Tab(text: 'Today'), Tab(text: 'Recipes')],
          ),
          actions: [
            if (_activeProfileId != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFFA78BFA)),
                onPressed: _loadAll,
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _tab == 0 ? _showAddFoodSheet(context) : _showAddRecipeSheet(context),
          backgroundColor: const Color(0xFF7C3AED),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(_tab == 0 ? 'Log Food' : 'New Recipe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: TabBarView(children: [_buildLogTab(), _buildRecipesTab()]),
      ),
    );
  }

  // ── Today's Log Tab ──────────────────────────────────────────────────────────

  Widget _buildLogTab() {
    if (_loadingPlan) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    final plan = _plan;
    if (plan == null) return const Center(child: Text('Could not load plan.', style: TextStyle(color: Colors.grey)));

    final targetCal = (plan['target_calories'] as num?)?.toInt() ?? 0;
    final targetP   = (plan['protein_g'] as num?)?.toDouble() ?? 0;
    final targetC   = (plan['carb_g']    as num?)?.toDouble() ?? 0;
    final targetF   = (plan['fat_g']     as num?)?.toDouble() ?? 0;
    final goal = plan['goal'] as String? ?? 'maintain';

    final loggedCal = _loggedTotals['calories']!.toInt();
    final loggedP   = _loggedTotals['protein_g']!;
    final loggedC   = _loggedTotals['carb_g']!;
    final loggedF   = _loggedTotals['fat_g']!;
    final remaining = (targetCal - loggedCal).clamp(0, targetCal);
    final calFrac   = targetCal > 0 ? (loggedCal / targetCal).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: _loadLog,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Calorie hero ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1B69), Color(0xFF1A0A2E), Color(0xFF13131A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF3D2080)),
            ),
            child: Column(children: [
              const Text('CALORIES TODAY', style: TextStyle(color: Color(0xFF8B6DB0), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _heroStat('$loggedCal', 'Eaten', const Color(0xFF7C3AED)),
                  Column(children: [
                    Text('$remaining', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                    const Text('remaining', style: TextStyle(color: Color(0xFF8B6DB0), fontSize: 12)),
                  ]),
                  _heroStat('$targetCal', 'Goal', const Color(0xFF4F46E5)),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: calFrac,
                  backgroundColor: const Color(0xFF2D1B69),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
                ),
                child: Text(_goalLabel(goal), style: const TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // ── Macro progress row ──
          Row(children: [
            Expanded(child: _macroBar('Protein', loggedP, targetP, const Color(0xFF7C3AED), '🥩')),
            const SizedBox(width: 10),
            Expanded(child: _macroBar('Carbs', loggedC, targetC, const Color(0xFF2563EB), '🍚')),
            const SizedBox(width: 10),
            Expanded(child: _macroBar('Fat', loggedF, targetF, const Color(0xFFD97706), '🥑')),
          ]),
          const SizedBox(height: 14),
          // ── Daily macro check — how today's log stacks up against the plan ──
          if (loggedCal > 0)
            _buildDayCheckCard(evaluateDay(
              loggedCal: loggedCal.toDouble(), targetCal: targetCal.toDouble(),
              loggedProtein: loggedP, targetProtein: targetP,
              loggedFat: loggedF, targetFat: targetF,
              goal: goal,
            )),
          const SizedBox(height: 20),
          // ── AI recipe suggestions button ──
          GestureDetector(
            onTap: () => _showAiSuggestions(context, remaining, targetP - loggedP, targetC - loggedC, targetF - loggedF, goal),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Suggest recipes for my remaining macros', style: TextStyle(color: Color(0xFFCCCCDD), fontSize: 14, fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF5A5A6E)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          // ── Meal sections ──
          for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
            _buildMealSection(meal),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, height: 1)),
      Text(label, style: const TextStyle(color: Color(0xFF8B6DB0), fontSize: 12)),
    ]);
  }

  Widget _buildDayCheckCard(MacroEval eval) {
    if (eval.rating == 'unknown') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: eval.color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, color: eval.color, size: 18),
          const SizedBox(width: 8),
          Text('MACRO CHECK', style: TextStyle(color: eval.color, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: eval.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(eval.label, style: TextStyle(color: eval.color, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        ...eval.reasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 13)),
                Expanded(child: Text(reason, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 13, height: 1.35))),
              ]),
            )),
      ]),
    );
  }

  Widget _macroBar(String label, double logged, double target, Color color, String emoji) {
    final frac = target > 0 ? (logged / target).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text('${logged.round()}g', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text('/ ${target.round()}g', style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 10)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: frac, minHeight: 4,
          backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(color),
        )),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildMealSection(String mealType) {
    final entries = _meals[mealType] ?? [];
    final mealCals = entries.fold<int>(0, (s, e) => s + e.calories);
    final icon = {'breakfast': '🌅', 'lunch': '☀️', 'dinner': '🌙', 'snack': '🍎'}[mealType] ?? '🍽';
    final label = mealType[0].toUpperCase() + mealType.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E1E2E)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (mealCals > 0)
                Text('$mealCals kcal', style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 12)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAddFoodSheet(context, mealType: mealType),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.add, color: Color(0xFFA78BFA), size: 18),
                ),
              ),
            ]),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('Nothing logged yet — tap + to add', style: TextStyle(color: const Color(0xFF3A3A4A), fontSize: 13)),
            )
          else
            ...entries.map((e) => _buildEntryRow(e)),
          if (entries.isNotEmpty) const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Widget _buildEntryRow(FoodEntry e) {
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _deleteEntry(e.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.foodName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            Text('P ${e.proteinG.round()}g  C ${e.carbG.round()}g  F ${e.fatG.round()}g',
              style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 11)),
          ])),
          Text('${e.calories} kcal', style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Recipes Tab ──────────────────────────────────────────────────────────────

  String get _userGoal =>
      (_plan?['goal'] as String?) ?? (_activeProfile?['goal'] as String?) ?? 'maintain';

  Widget _buildRecipesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildImportBanner(),
        const SizedBox(height: 14),
        if (_recipes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Column(children: [
              Text('🍳', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text('No recipes yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Import one from a link above, or tap + to add manually',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 14)),
            ]),
          )
        else
          ..._recipes.map(_buildRecipeCard),
      ],
    );
  }

  Widget _buildImportBanner() {
    return GestureDetector(
      onTap: () => _showImportDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0A2E), Color(0xFF13131A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2D1B60)),
        ),
        child: const Row(children: [
          Icon(Icons.link_rounded, color: Color(0xFFA78BFA), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Import from a link',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('TikTok, Instagram, YouTube, or any recipe site',
                  style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFF5A5A6E)),
        ]),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe r) {
    final eval = evaluateRecipeMacros(
        r.caloriesPerServing.toDouble(), r.proteinG, r.carbG, r.fatG, _userGoal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E1E2E)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => _deleteRecipe(r.id),
                child: const Icon(Icons.delete_outline, color: Color(0xFF5A5A6E), size: 20),
              ),
            ]),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.description, style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 13)),
            ],
            const SizedBox(height: 10),
            // Goal-aware macro-friendliness badge — tap for the reasons.
            if (eval.rating != 'unknown')
              GestureDetector(
                onTap: () => _showEvalReasons(r.name, eval),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: eval.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: eval.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.insights_rounded, color: eval.color, size: 14),
                    const SizedBox(width: 6),
                    Text('${eval.score} · ${eval.label}',
                        style: TextStyle(color: eval.color, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline, color: eval.color.withValues(alpha: 0.7), size: 12),
                  ]),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              _recipeStatChip('${r.caloriesPerServing} kcal', const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              _recipeStatChip('P ${r.proteinG.round()}g', const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              _recipeStatChip('C ${r.carbG.round()}g', const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              _recipeStatChip('F ${r.fatG.round()}g', const Color(0xFFD97706)),
            ]),
            if (r.sourceUrl != null || (r.sourceCreator ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: r.sourceUrl != null
                    ? () => launchUrl(Uri.parse(r.sourceUrl!), mode: LaunchMode.externalApplication)
                    : null,
                child: Row(children: [
                  const Icon(Icons.open_in_new_rounded, color: Color(0xFF5A5A6E), size: 13),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'From ${(r.sourceCreator ?? '').isNotEmpty ? r.sourceCreator : 'source'}'
                      '${r.sourcePlatform != null ? ' on ${r.sourcePlatform}' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF8B8B9E), fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF5A5A6E)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            _GradientButton(
              label: 'Log This Recipe',
              icon: Icons.add_circle_outline,
              onTap: () => _showLogRecipeSheet(context, r),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEvalReasons(String recipeName, MacroEval eval) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.insights_rounded, color: eval.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${eval.label} · ${eval.score}/100',
                  style: TextStyle(color: eval.color, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(recipeName, style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 13)),
          const SizedBox(height: 16),
          ...eval.reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(color: Color(0xFF8B8B9E))),
                  Expanded(child: Text(reason, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 14, height: 1.4))),
                ]),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _recipeStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── Sheets ───────────────────────────────────────────────────────────────────

  void _showAddFoodSheet(BuildContext context, {String mealType = 'breakfast'}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodSheet(
        initialMeal: mealType,
        onAdd: (entry) async {
          final id = _activeProfileId; if (id == null) return;
          try {
            await http.post(
              Uri.parse('$_baseUrl/api/nutrition/log'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_id': id, 'date': _todayStr, 'meal_type': entry['meal_type'],
                'food_name': entry['food_name'], 'calories': entry['calories'],
                'protein_g': entry['protein_g'], 'carb_g': entry['carb_g'],
                'fat_g': entry['fat_g'], 'quantity': 1, 'unit': 'serving',
              }),
            );
            _loadLog();
          } catch (_) {}
        },
      ),
    );
  }

  void _showAddRecipeSheet(BuildContext context,
      {Map<String, dynamic>? draft, Map<String, dynamic>? importMeta}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRecipeSheet(
        draft: draft,
        importMeta: importMeta,
        onSave: (data) async {
          final id = _activeProfileId; if (id == null) return;
          try {
            await http.post(
              Uri.parse('$_baseUrl/api/nutrition/recipes'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({...data, 'user_id': id}),
            );
            _loadRecipes();
          } catch (_) {}
        },
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final urlCtrl = TextEditingController();
    bool importing = false;
    String? error;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, ss) {
        Future<void> doImport() async {
          final url = urlCtrl.text.trim();
          if (url.isEmpty) return;
          ss(() { importing = true; error = null; });
          try {
            final r = await http.post(
              Uri.parse('$_baseUrl/api/nutrition/recipes/import'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'url': url, 'goal': _userGoal}),
            );
            if (!dialogCtx.mounted) return;
            if (r.statusCode == 200) {
              final data = jsonDecode(r.body) as Map<String, dynamic>;
              Navigator.pop(dialogCtx);
              _showAddRecipeSheet(
                context,
                draft: data['recipe'] as Map<String, dynamic>,
                importMeta: {
                  'source': data['source'],
                  'ai': data['ai'],
                  'evaluation': data['evaluation'],
                },
              );
            } else {
              String msg;
              try {
                msg = (jsonDecode(r.body) as Map<String, dynamic>)['detail'] as String? ?? 'Import failed (${r.statusCode})';
              } catch (_) {
                msg = 'Import failed (${r.statusCode})';
              }
              ss(() { importing = false; error = msg; });
            }
          } catch (e) {
            if (dialogCtx.mounted) ss(() { importing = false; error = 'Network error — try again.'; });
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Import Recipe',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Paste a link from TikTok, Instagram, YouTube, or a recipe website. '
              'For videos, the recipe needs to be written in the caption.',
              style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlCtrl,
              enabled: !importing,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'https://…',
                prefixIcon: Icon(Icons.link_rounded, color: Color(0xFF5A5A6E)),
              ),
              onSubmitted: (_) => importing ? null : doImport(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ],
            if (importing) ...[
              const SizedBox(height: 16),
              const Row(children: [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
                SizedBox(width: 12),
                Text('Extracting recipe…', style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 13)),
              ]),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B8B9E))),
            ),
            TextButton(
              onPressed: importing ? null : doImport,
              child: const Text('Import',
                  style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  void _showLogRecipeSheet(BuildContext context, Recipe recipe) {
    String selectedMeal = 'lunch';
    double servings = 1;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF13131A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Log "${recipe.name}"', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          const Text('Meal', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: selectedMeal, isExpanded: true,
            dropdownColor: const Color(0xFF1C1C27),
            style: const TextStyle(color: Colors.white),
            items: ['breakfast','lunch','dinner','snack'].map((m) => DropdownMenuItem(value: m, child: Text(m[0].toUpperCase() + m.substring(1)))).toList(),
            onChanged: (v) => ss(() => selectedMeal = v ?? selectedMeal),
          ),
          const SizedBox(height: 16),
          const Text('Servings', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            IconButton(onPressed: () { if (servings > 0.5) ss(() => servings -= 0.5); }, icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFA78BFA))),
            Text('$servings', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            IconButton(onPressed: () => ss(() => servings += 0.5), icon: const Icon(Icons.add_circle_outline, color: Color(0xFFA78BFA))),
            const Spacer(),
            Text('${(recipe.caloriesPerServing * servings).round()} kcal', style: const TextStyle(color: Color(0xFF8B8B9E))),
          ]),
          const SizedBox(height: 24),
          _GradientButton(
            label: 'Add to Log',
            icon: Icons.add,
            large: true,
            onTap: () { Navigator.pop(ctx); _logRecipe(recipe, selectedMeal, servings); },
          ),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  void _showAiSuggestions(BuildContext ctx, int remCal, double remP, double remC, double remF, String goal) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
    );
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/api/nutrition/recipes/suggest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'profile': _activeProfile ?? {},
          'nutrition': _plan ?? {},
          'remaining': {'calories': remCal, 'protein_g': remP.round(), 'carb_g': remC.round(), 'fat_g': remF.round()},
          'meal_type': 'any meal',
        }),
      );
      if (!mounted) return;
      Navigator.pop(ctx);
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as String? ?? 'No suggestions available.';
      showModalBottomSheet(
        context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(color: Color(0xFF13131A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 20),
              SizedBox(width: 10),
              Text('AI Recipe Suggestions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(suggestions, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 14, height: 1.6)))),
          ]),
        ),
      );
    } catch (_) {
      if (mounted) Navigator.pop(ctx);
    }
  }
}

// ── Add Food Bottom Sheet ─────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  final String initialMeal;
  final Future<void> Function(Map<String, dynamic>) onAdd;
  const _AddFoodSheet({required this.initialMeal, required this.onAdd});
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  late String _meal;
  final _name = TextEditingController();
  final _cal = TextEditingController();
  final _prot = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _saving = false;

  static const _quickFoods = [
    {'name': 'Chicken Breast (100g)', 'calories': 165, 'protein_g': 31.0, 'carb_g': 0.0, 'fat_g': 3.6},
    {'name': 'Egg (large)',            'calories': 78,  'protein_g': 6.0,  'carb_g': 0.6, 'fat_g': 5.0},
    {'name': 'Oats (100g dry)',        'calories': 389, 'protein_g': 17.0, 'carb_g': 66.0,'fat_g': 7.0},
    {'name': 'Greek Yogurt (170g)',    'calories': 100, 'protein_g': 17.0, 'carb_g': 6.0, 'fat_g': 0.7},
    {'name': 'Brown Rice (100g)',      'calories': 112, 'protein_g': 2.6,  'carb_g': 24.0,'fat_g': 0.9},
    {'name': 'Whey Protein (1 scoop)','calories': 120, 'protein_g': 25.0, 'carb_g': 3.0, 'fat_g': 1.5},
    {'name': 'Banana (medium)',        'calories': 105, 'protein_g': 1.3,  'carb_g': 27.0,'fat_g': 0.4},
    {'name': 'Salmon (100g)',          'calories': 208, 'protein_g': 20.0, 'carb_g': 0.0, 'fat_g': 13.0},
  ];

  @override
  void initState() { super.initState(); _meal = widget.initialMeal; }
  @override
  void dispose() { _name.dispose(); _cal.dispose(); _prot.dispose(); _carb.dispose(); _fat.dispose(); super.dispose(); }

  void _applyFood(Map<String, dynamic> f) {
    setState(() {
      _name.text = f['name'] as String;
      _cal.text  = '${f['calories']}';
      _prot.text = '${f['protein_g']}';
      _carb.text = '${f['carb_g']}';
      _fat.text  = '${f['fat_g']}';
      _searchResults = [];
    });
  }

  void _onNameChanged(String q) {
    if (q.length < 2) { setState(() => _searchResults = []); return; }
    final lower = q.toLowerCase();
    setState(() => _searchResults = _quickFoods.where((f) => (f['name'] as String).toLowerCase().contains(lower)).toList());
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _cal.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.onAdd({
      'meal_type': _meal,
      'food_name': _name.text.trim(),
      'calories': int.tryParse(_cal.text.trim()) ?? 0,
      'protein_g': double.tryParse(_prot.text.trim()) ?? 0,
      'carb_g': double.tryParse(_carb.text.trim()) ?? 0,
      'fat_g': double.tryParse(_fat.text.trim()) ?? 0,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF13131A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Log Food', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          // Meal picker
          Row(children: ['breakfast','lunch','dinner','snack'].map((m) {
            final sel = m == _meal;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _meal = m),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF7C3AED) : const Color(0xFF1C1C27),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? const Color(0xFF7C3AED) : const Color(0xFF2D2D3D)),
                ),
                child: Text({'breakfast':'🌅','lunch':'☀️','dinner':'🌙','snack':'🍎'}[m]! + '\n${m[0].toUpperCase()}${m.substring(1)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: sel ? Colors.white : const Color(0xFF8B8B9E), height: 1.4)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          // Food name + search
          TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            onChanged: _onNameChanged,
            decoration: InputDecoration(labelText: 'Food name', prefixIcon: const Icon(Icons.search, color: Color(0xFF5A5A6E))),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1C1C27), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D3D))),
              child: Column(children: _searchResults.take(4).map((f) => ListTile(
                dense: true,
                title: Text(f['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: Text('${f['calories']} kcal', style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 12)),
                onTap: () => _applyFood(f),
              )).toList()),
            ),
          ],
          const SizedBox(height: 12),
          // Quick add chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _quickFoods.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _applyFood(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFF1C1C27), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2D2D3D))),
                  child: Text((f['name'] as String).split(' ').first, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12)),
                ),
              ),
            )).toList()),
          ),
          const SizedBox(height: 14),
          // Macros row
          Row(children: [
            Expanded(child: _macroField(_cal, 'Calories', TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _macroField(_prot, 'Protein g', const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: _macroField(_carb, 'Carbs g', const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: _macroField(_fat, 'Fat g', const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 20),
          _saving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : _GradientButton(label: 'Add to Log', icon: Icons.add, large: true, onTap: _submit),
        ]),
      ),
    );
  }

  Widget _macroField(TextEditingController ctrl, String label, TextInputType type) {
    return TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textAlign: TextAlign.center,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11)),
    );
  }
}

// ── Add Recipe Bottom Sheet ───────────────────────────────────────────────────

class _AddRecipeSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;

  /// Prefilled recipe fields when reviewing an imported recipe.
  final Map<String, dynamic>? draft;

  /// {source: {platform, creator, url}, ai: {...}, evaluation: {...}} for imports.
  final Map<String, dynamic>? importMeta;

  const _AddRecipeSheet({required this.onSave, this.draft, this.importMeta});
  @override
  State<_AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends State<_AddRecipeSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _cal = TextEditingController();
  final _prot = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  final _instructions = TextEditingController();
  int _servings = 1;
  bool _saving = false;
  List<dynamic> _ingredients = [];
  List<dynamic> _tags = [];

  bool get _isImport => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      _name.text = (d['name'] ?? '').toString();
      _desc.text = (d['description'] ?? '').toString();
      _servings = (d['servings'] as num?)?.toInt() ?? 1;
      _cal.text = '${(d['calories_per_serving'] as num?)?.toInt() ?? 0}';
      _prot.text = '${(d['protein_g'] as num?)?.toDouble() ?? 0}';
      _carb.text = '${(d['carb_g'] as num?)?.toDouble() ?? 0}';
      _fat.text = '${(d['fat_g'] as num?)?.toDouble() ?? 0}';
      _instructions.text = (d['instructions'] ?? '').toString();
      _ingredients = (d['ingredients'] as List?) ?? [];
      _tags = (d['tags'] as List?) ?? [];
    }
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); _cal.dispose(); _prot.dispose(); _carb.dispose(); _fat.dispose(); _instructions.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _cal.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final source = widget.importMeta?['source'] as Map<String, dynamic>?;
    await widget.onSave({
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'servings': _servings,
      'calories_per_serving': int.tryParse(_cal.text.trim()) ?? 0,
      'protein_g': double.tryParse(_prot.text.trim()) ?? 0,
      'carb_g': double.tryParse(_carb.text.trim()) ?? 0,
      'fat_g': double.tryParse(_fat.text.trim()) ?? 0,
      'instructions': _instructions.text.trim(),
      'ingredients': _ingredients,
      'tags': _tags,
      if (source != null) 'source_url': source['url'],
      if (source != null) 'source_platform': source['platform'],
      if (source != null && (source['creator'] ?? '').toString().isNotEmpty)
        'source_creator': source['creator'],
    });
    if (mounted) Navigator.pop(context);
  }

  Widget _importBanner() {
    final ai = widget.importMeta?['ai'] as Map<String, dynamic>?;
    final source = widget.importMeta?['source'] as Map<String, dynamic>?;
    final warnings = (ai?['warnings'] as List?)?.cast<String>() ?? [];
    final aiUsed = ai?['used'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D1B60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(aiUsed ? Icons.auto_awesome : Icons.fact_check_outlined,
              color: const Color(0xFFA78BFA), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aiUsed
                  ? 'AI-extracted — check everything before saving'
                  : 'Imported from the site\'s published recipe data',
              style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        if ((source?['creator'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Source: ${source!['creator']} on ${source['platform']}',
              style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 11)),
        ],
        ...warnings.take(3).map((w) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $w', style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, height: 1.3)),
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF13131A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_isImport ? 'Review Imported Recipe' : 'New Recipe',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (_isImport) _importBanner(),
          _field(_name, 'Recipe name'),
          const SizedBox(height: 10),
          _field(_desc, 'Description (optional)'),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Servings:', style: TextStyle(color: Color(0xFF8B8B9E))),
            const SizedBox(width: 12),
            IconButton(onPressed: () { if (_servings > 1) setState(() => _servings--); }, icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFA78BFA))),
            Text('$_servings', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(onPressed: () => setState(() => _servings++), icon: const Icon(Icons.add_circle_outline, color: Color(0xFFA78BFA))),
          ]),
          const SizedBox(height: 10),
          const Text('MACROS PER SERVING', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(_cal,  'Calories', type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _field(_prot, 'Protein g', type: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: _field(_carb, 'Carbs g',   type: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: _field(_fat,  'Fat g',      type: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 10),
          if (_ingredients.isNotEmpty) ...[
            const Text('INGREDIENTS', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D2D3D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _ingredients.take(12).map((ing) {
                  final m = ing as Map<String, dynamic>;
                  final amount = (m['amount'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• ${amount.isNotEmpty ? '$amount ' : ''}${m['name'] ?? ''}',
                      style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 12, height: 1.3),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _field(_instructions, _isImport ? 'Instructions' : 'Instructions (optional)', maxLines: _isImport ? 6 : 3),
          const SizedBox(height: 20),
          _saving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : _GradientButton(
                label: _isImport ? 'Looks Good — Save Recipe' : 'Save Recipe',
                icon: Icons.save_outlined, large: true, onTap: _save),
        ])),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl, keyboardType: type, maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label),
    );
  }
}

// ---------------------------------------------------------------------------
// Coach Screen
// ---------------------------------------------------------------------------

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  Map<String, dynamic>? _nutritionPlan;
  bool _aiPowered = false;
  bool _showApiKeyBanner = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final profileId = _activeProfileId;
    if (profileId != null) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl/api/nutrition/plan/$profileId'));
        if (response.statusCode == 200 && mounted) {
          _nutritionPlan = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final profile = _activeProfile;
    String greeting;
    if (profile == null) {
      greeting = 'Complete your profile to unlock personalised coaching.';
    } else {
      final name = profile['name'] as String? ?? 'there';
      final goal = profile['goal'] as String? ?? 'maintain';
      final calories = _nutritionPlan?['target_calories'] ?? '-';
      final protein = _nutritionPlan?['protein_g'] ?? '-';
      greeting = 'Hey $name! I\'m your Pulse coach. '
          'You\'re set to $goal at $calories kcal/day with ${protein}g protein.\n\n'
          'Ask me anything about training, nutrition, or recovery - '
          'I\'ll give you advice based on your actual data.';
    }
    setState(() {
      _messages.add({'role': 'assistant', 'text': greeting});
      _initialized = true;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
    });
    _scrollToBottom();
    try {
      final profile = _activeProfile ?? {};
      final nutrition = _nutritionPlan ?? {};
      final response = await http.post(
        Uri.parse('$_baseUrl/api/nutrition/coach/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'profile': profile,
          'nutrition': nutrition,
          'workout_context': 'User is following a structured training plan with progressive overload tracking.',
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? 'Sorry, I could not respond.';
        final aiPowered = data['ai_powered'] as bool? ?? false;
        setState(() {
          _messages.add({'role': 'assistant', 'text': reply});
          _sending = false;
          _aiPowered = aiPowered;
          if (aiPowered) _showApiKeyBanner = false;
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'Sorry, something went wrong. Please try again.'});
          _sending = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Network error. Make sure the Pulse server is running.'});
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('AI Coach'),
        actions: [
          if (_initialized)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _aiPowered
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: Color(0xFFA78BFA)),
                          SizedBox(width: 4),
                          Text('AI', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C27),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2D2D3D)),
                      ),
                      child: const Text('Rule-based', style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 12)),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_showApiKeyBanner && !_aiPowered && _initialized)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D2D3D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_outlined, color: Color(0xFF7C3AED), size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Add ANTHROPIC_API_KEY to .env to unlock full AI coaching',
                      style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showApiKeyBanner = false),
                    child: const Icon(Icons.close, color: Color(0xFF5A5A6E), size: 15),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(text: msg['text'] ?? '', isUser: isUser);
              },
            ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text('Coach is thinking…', style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 13)),
                ],
              ),
            ),
          if (_messages.length <= 1 && !_sending)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    "What should I eat today?",
                    "How do I recover faster?",
                    "Analyse my workout plan",
                    "Best exercises for my goal",
                  ].map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _inputController.text = chip;
                          _sendMessage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C27),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 11, color: Color(0xFFA78BFA)),
                              const SizedBox(width: 6),
                              Text(chip, style: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D14),
              border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    minLines: 1,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: 'Ask your coach…',
                      hintStyle: const TextStyle(color: Color(0xFF4A4A5A)),
                      filled: true,
                      fillColor: const Color(0xFF1C1C27),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF2D2D3D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF2D2D3D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                      ),
                    ),
                    onSubmitted: (_) => _sending ? null : _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: _sending
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _sending ? const Color(0xFF1C1C27) : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _sending ? null : [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: _sending ? const Color(0xFF3A3A4A) : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : const Color(0xFF1C1C27),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFF2D2D3D)),
                boxShadow: isUser ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ] : null,
              ),
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.55)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI Components
// ---------------------------------------------------------------------------

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool large;

  const _GradientButton({
    required this.label,
    this.onTap,
    this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: large ? 20 : 16,
          horizontal: 24,
        ),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: disabled ? const Color(0xFF1C1C27) : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: disabled ? null : [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: disabled ? const Color(0xFF3A3A4A) : Colors.white, size: large ? 24 : 20),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: disabled ? const Color(0xFF3A3A4A) : Colors.white,
                fontSize: large ? 18 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan List Screen
// ---------------------------------------------------------------------------

class PlanListScreen extends StatefulWidget {
  const PlanListScreen({super.key});

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  bool _loading = true;
  List<WorkoutPlan> _plans = [];
  String? _activePlanId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([_fetchPlans(), _fetchActivePlanId()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchPlans() async {
    final profileId = _activeProfileId;
    if (profileId == null) return;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/workout/plans/$profileId'));
      if (response.statusCode == 200 && mounted) {
        final list = jsonDecode(response.body) as List<dynamic>;
        _plans = list.map((p) => WorkoutPlan.fromJson(p as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchActivePlanId() async {
    final profileId = _activeProfileId;
    if (profileId == null) return;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/workout/active-plan/$profileId'));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['active'] as bool? ?? false) {
          _activePlanId = data['plan_id'] as String?;
        }
      }
    } catch (_) {}
  }

  Future<void> _setActive(WorkoutPlan plan) async {
    final profileId = _activeProfileId;
    if (profileId == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Select plan start date',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.deepPurple)),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final startDate = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/workout/active-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': profileId, 'plan_id': plan.id, 'start_date': startDate}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${plan.name}" set as active plan'), backgroundColor: Colors.deepPurple),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Plan', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${plan.name}"? This cannot be undone.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/workout/plans/${plan.id}'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan deleted'), backgroundColor: Colors.deepPurple),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('My Plans'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanBuilderScreen()))
              .then((result) { if (result == true) _loadData(); });
        },
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _plans.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No plans yet', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Tap + to create your first workout plan', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    return _buildPlanCard(plan, plan.id == _activePlanId);
                  },
                ),
    );
  }

  Widget _buildPlanCard(WorkoutPlan plan, bool isActive) {
    final summary = plan.days.map((d) => d.workoutType).join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.6)),
                    ),
                    child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCardButton(
                  label: 'Edit', icon: Icons.edit, color: const Color(0xFFA78BFA),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PlanBuilderScreen(plan: plan)))
                        .then((result) { if (result == true) _loadData(); });
                  },
                ),
                const SizedBox(width: 8),
                _buildCardButton(label: 'Set Active', icon: Icons.play_circle_outline, color: Colors.green, onTap: () => _setActive(plan)),
                const SizedBox(width: 8),
                _buildCardButton(label: 'Delete', icon: Icons.delete_outline, color: Colors.red, onTap: () => _deletePlan(plan)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Builder Screen
// ---------------------------------------------------------------------------

class PlanBuilderScreen extends StatefulWidget {
  final WorkoutPlan? plan;
  const PlanBuilderScreen({super.key, this.plan});

  @override
  State<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends State<PlanBuilderScreen> {
  late TextEditingController _nameController;
  late List<PlanDay> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.plan;
    _nameController = TextEditingController(text: existing?.name ?? '');
    if (existing != null && existing.days.isNotEmpty) {
      _days = List.generate(7, (i) {
        final dayNum = i + 1;
        try { return existing.days.firstWhere((d) => d.dayNumber == dayNum); }
        catch (_) { return PlanDay(dayNumber: dayNum); }
      });
    } else {
      _days = List.generate(7, (i) => PlanDay(dayNumber: i + 1));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profileId = _activeProfileId;
    if (profileId == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan name'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_days.any((d) => d.workoutType != 'Rest' && d.exercises.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise to a non-Rest day'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {'user_id': profileId, 'name': name, 'days': _days.map((d) => d.toJson()).toList()};
    try {
      http.Response response;
      final existing = widget.plan;
      if (existing == null) {
        response = await http.post(Uri.parse('$_baseUrl/api/workout/plans'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      } else {
        response = await http.put(Uri.parse('$_baseUrl/api/workout/plans/${existing.id}'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      }
      if (!mounted) return;
      setState(() => _saving = false);
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openDayEditor(int index) async {
    final updated = await showModalBottomSheet<PlanDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DayEditorSheet(day: _days[index]),
    );
    if (updated != null) setState(() { _days[index] = updated; });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Plan' : 'Create Plan'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: const Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: const InputDecoration(labelText: 'Plan Name', hintText: 'e.g. PPL 6-Day', hintStyle: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 28),
          const Text('7-Day Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          ...List.generate(7, (index) => _buildDayCard(_days[index], index)),
        ],
      ),
    );
  }

  Widget _buildDayCard(PlanDay day, int index) {
    final isRest = day.workoutType == 'Rest';
    return GestureDetector(
      onTap: () => _openDayEditor(index),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isRest ? Colors.grey.withOpacity(0.2) : Colors.deepPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    _dayNames[index].substring(0, 3),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isRest ? Colors.grey : const Color(0xFFA78BFA)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.workoutType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isRest ? Colors.grey : Colors.white)),
                    if (!isRest)
                      Text(
                        day.exercises.isEmpty ? 'No exercises' : '${day.exercises.length} exercise${day.exercises.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day Editor Sheet
// ---------------------------------------------------------------------------

class DayEditorSheet extends StatefulWidget {
  final PlanDay day;
  const DayEditorSheet({super.key, required this.day});

  @override
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  late String _workoutType;
  late List<PlanExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _workoutType = widget.day.workoutType;
    _exercises = widget.day.exercises.map((e) => PlanExercise(name: e.name, targetSets: e.targetSets, targetReps: e.targetReps)).toList();
  }

  void _addExercise() {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '8');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add Exercise', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Exercise name'), autofocus: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: setsCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: repsCtrl, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Reps'), keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _exercises.add(PlanExercise(
                  name: name, targetSets: int.tryParse(setsCtrl.text) ?? 3, targetReps: int.tryParse(repsCtrl.text) ?? 8));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _done() {
    Navigator.pop(context, PlanDay(dayNumber: widget.day.dayNumber, workoutType: _workoutType, exercises: _exercises));
  }

  @override
  Widget build(BuildContext context) {
    final isRest = _workoutType == 'Rest';
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Day ${widget.day.dayNumber} — ${_dayNames[widget.day.dayNumber - 1]}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _done,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.5)),
                ),
                child: DropdownButton<String>(
                  value: _workoutType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _workoutTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _workoutType = val); },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!isRest) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('Exercises', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add, color: const Color(0xFFA78BFA), size: 18),
                      label: const Text('+ Add Exercise', style: TextStyle(color: const Color(0xFFA78BFA))),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _exercises.isEmpty
                    ? const Center(child: Text('No exercises yet. Tap + Add Exercise.', style: TextStyle(color: Colors.grey)))
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _exercises.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _exercises.removeAt(oldIndex);
                            _exercises.insert(newIndex, item);
                          });
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(12), child: child);
                        },
                        itemBuilder: (context, index) {
                          final ex = _exercises[index];
                          return Card(
                            key: ValueKey('ex_${index}_${ex.name}'),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.drag_handle, color: Colors.grey),
                              title: Text(ex.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              subtitle: Text('${ex.targetSets}x${ex.targetReps}', style: const TextStyle(color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () { setState(() => _exercises.removeAt(index)); },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('😴 Rest day — no exercises', style: TextStyle(color: Colors.grey, fontSize: 16))),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Session Screen
// ---------------------------------------------------------------------------

enum _WorkoutPhase { input, setActive, resting }

class WorkoutSessionScreen extends StatefulWidget {
  final PlanDay planDay;
  final String profileId;

  const WorkoutSessionScreen({super.key, required this.planDay, required this.profileId});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _exerciseIndex = 0;
  int _setIndex = 0;
  _WorkoutPhase _phase = _WorkoutPhase.input;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  Timer? _setTimer;
  Timer? _restTimer;
  Timer? _sessionTimer;

  int _setElapsed = 0;
  int _restRemaining = 90;
  int _totalElapsed = 0;

  final List<LoggedSet> _loggedSets = [];
  final Map<String, double> _previousWeights = {};
  final Map<String, int> _previousReps = {};

  @override
  void initState() {
    super.initState();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _totalElapsed++);
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/workout/history/${widget.profileId}'));
      if (response.statusCode == 200 && mounted) {
        final sessions = jsonDecode(response.body) as List<dynamic>;
        for (final session in sessions) {
          final sets = (session['exercise_sets'] as List<dynamic>?) ?? [];
          for (final s in sets) {
            final name = s['exercise_name'] as String? ?? '';
            final weight = (s['weight_kg'] as num?)?.toDouble() ?? 0.0;
            final reps = (s['reps'] as num?)?.toInt() ?? 0;
            if (!_previousWeights.containsKey(name) || weight > (_previousWeights[name] ?? 0)) {
              _previousWeights[name] = weight;
              _previousReps[name] = reps;
            }
          }
        }
        if (mounted) {
          final exercises = widget.planDay.exercises;
          if (exercises.isNotEmpty) {
            final firstName = exercises[0].name;
            if (_previousWeights.containsKey(firstName)) {
              _weightController.text = _previousWeights[firstName]!.toString();
            }
            _repsController.text = exercises[0].targetReps.toString();
          }
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) {
        final exercises = widget.planDay.exercises;
        if (exercises.isNotEmpty) _repsController.text = exercises[0].targetReps.toString();
      }
    }
  }

  @override
  void dispose() {
    _setTimer?.cancel();
    _restTimer?.cancel();
    _sessionTimer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  PlanExercise get _currentExercise => widget.planDay.exercises[_exerciseIndex];

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startSet() {
    _setElapsed = 0;
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _setElapsed++); });
    setState(() => _phase = _WorkoutPhase.setActive);
  }

  void _doneSet() {
    _setTimer?.cancel();
    _setTimer = null;
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    _loggedSets.add(LoggedSet(exerciseName: _currentExercise.name, weightKg: weight, reps: reps, setDurationSeconds: _setElapsed));
    _restRemaining = 90;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) { _restTimer?.cancel(); _advanceToNextSet(); }
      });
    });
    setState(() => _phase = _WorkoutPhase.resting);
  }

  void _advanceToNextSet() {
    _restTimer?.cancel();
    _restTimer = null;
    final ex = _currentExercise;
    _setIndex++;
    if (_setIndex >= ex.targetSets) {
      _exerciseIndex++;
      _setIndex = 0;
      if (_exerciseIndex >= widget.planDay.exercises.length) { _finishWorkout(); return; }
      final nextEx = widget.planDay.exercises[_exerciseIndex];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise complete! Next: ${nextEx.name}'), backgroundColor: Colors.deepPurple, duration: const Duration(seconds: 2)),
      );
      if (_previousWeights.containsKey(nextEx.name)) {
        _weightController.text = _previousWeights[nextEx.name]!.toString();
      } else {
        _weightController.clear();
      }
      _repsController.text = nextEx.targetReps.toString();
    } else {
      if (_previousWeights.containsKey(_currentExercise.name)) {
        _weightController.text = _previousWeights[_currentExercise.name]!.toString();
      }
      _repsController.text = _currentExercise.targetReps.toString();
    }
    setState(() => _phase = _WorkoutPhase.input);
  }

  void _skipRest() { _restTimer?.cancel(); _restTimer = null; _advanceToNextSet(); }

  void _completeExercise() {
    _restTimer?.cancel(); _restTimer = null;
    _setTimer?.cancel(); _setTimer = null;
    _exerciseIndex++;
    _setIndex = 0;
    if (_exerciseIndex >= widget.planDay.exercises.length) { _finishWorkout(); return; }
    final nextEx = widget.planDay.exercises[_exerciseIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moving to: ${nextEx.name}'), backgroundColor: Colors.deepPurple, duration: const Duration(seconds: 2)),
    );
    if (_previousWeights.containsKey(nextEx.name)) {
      _weightController.text = _previousWeights[nextEx.name]!.toString();
    } else {
      _weightController.clear();
    }
    _repsController.text = nextEx.targetReps.toString();
    setState(() => _phase = _WorkoutPhase.input);
  }

  void _setRestTime(int seconds) { setState(() => _restRemaining = seconds); }

  void _finishWorkout() {
    _sessionTimer?.cancel(); _sessionTimer = null;
    _setTimer?.cancel(); _restTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          workoutType: widget.planDay.workoutType,
          sessionDurationSeconds: _totalElapsed,
          loggedSets: List.from(_loggedSets),
          profileId: widget.profileId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.planDay.exercises;
    if (exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.planDay.workoutType)),
        body: const Center(child: Text('No exercises in this workout.', style: TextStyle(color: Colors.grey))),
      );
    }
    final ex = _currentExercise;
    final prevWeight = _previousWeights[ex.name];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text(widget.planDay.workoutType),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                _formatTime(_totalElapsed),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFA78BFA), fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Exercise ${_exerciseIndex + 1} of ${exercises.length}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const Spacer(),
                        Text('Set ${_setIndex + 1} of ${ex.targetSets}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_exerciseIndex * ex.targetSets + _setIndex) /
                          (exercises.fold(0, (sum, e) => sum + e.targetSets)),
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      ex.name,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFA78BFA)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (prevWeight != null)
                      Text('Last session: ${prevWeight}kg', style: const TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    if (_phase == _WorkoutPhase.input) _buildInputPhase(),
                    if (_phase == _WorkoutPhase.setActive) _buildSetActivePhase(),
                    if (_phase == _WorkoutPhase.resting) _buildRestingPhase(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TextButton(
                onPressed: _finishWorkout,
                child: const Text('Finish Workout Early', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _repsController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _startSet,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          child: const Text('▶ Start Set'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _exerciseIndex < widget.planDay.exercises.length - 1 ? _completeExercise : _finishWorkout,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _exerciseIndex < widget.planDay.exercises.length - 1 ? 'Complete Exercise →' : 'Finish Workout',
            style: const TextStyle(color: const Color(0xFFA78BFA)),
          ),
        ),
      ],
    );
  }

  Widget _buildSetActivePhase() {
    final weight = _weightController.text;
    final reps = _repsController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Text('SET IN PROGRESS', style: TextStyle(color: const Color(0xFFA78BFA), fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(
                '0:${_setElapsed.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text('Weight: ${weight}kg  ·  Reps: $reps', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _doneSet,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          child: const Text('✓ Done'),
        ),
      ],
    );
  }

  Widget _buildRestingPhase() {
    final timerColor = _restRemaining > 60 ? Colors.green : _restRemaining > 30 ? Colors.orange : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Rest', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(
          _formatTime(_restRemaining),
          style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: timerColor, fontFamily: 'monospace'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [60, 90, 120, 180].map((secs) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ActionChip(
                label: Text('${secs}s', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.deepPurple.withOpacity(0.3),
                side: BorderSide(color: Colors.deepPurple.withOpacity(0.5)),
                onPressed: () => _setRestTime(secs),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _skipRest,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('Skip Rest →'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Summary Screen
// ---------------------------------------------------------------------------

class WorkoutSummaryScreen extends StatefulWidget {
  final String workoutType;
  final int sessionDurationSeconds;
  final List<LoggedSet> loggedSets;
  final String profileId;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutType,
    required this.sessionDurationSeconds,
    required this.loggedSets,
    required this.profileId,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool _saving = true;
  String? _saveError;
  Map<String, double> _previousWeights = {};
  Map<String, int> _previousReps = {};

  @override
  void initState() {
    super.initState();
    _saveAndLoad();
  }

  Future<void> _saveAndLoad() async {
    await Future.wait([_saveSession(), _loadPreviousWeights()]);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveSession() async {
    try {
      final Map<String, List<LoggedSet>> grouped = {};
      for (final s in widget.loggedSets) {
        grouped.putIfAbsent(s.exerciseName, () => []).add(s);
      }
      final exercises = grouped.entries.map((entry) {
        final sets = entry.value;
        final maxWeight = sets.fold(0.0, (max, s) => s.weightKg > max ? s.weightKg : max);
        final totalReps = sets.fold(0, (sum, s) => sum + s.reps);
        final avgReps = sets.isEmpty ? 0 : (totalReps / sets.length).round();
        return {'exercise_name': entry.key, 'sets': sets.length, 'reps': avgReps, 'weight_kg': maxWeight, 'rir': null};
      }).toList();
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await http.post(
        Uri.parse('$_baseUrl/api/workout/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.profileId, 'date': dateStr, 'session_name': widget.workoutType, 'exercises': exercises, 'notes': ''}),
      );
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    }
  }

  Future<void> _loadPreviousWeights() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/workout/history/${widget.profileId}'));
      if (response.statusCode == 200 && mounted) {
        final sessions = jsonDecode(response.body) as List<dynamic>;
        final Map<String, double> prev = {};
        final Map<String, bool> seenToday = {};
        for (final session in sessions) {
          final sets = (session['exercise_sets'] as List<dynamic>?) ?? [];
          for (final s in sets) {
            final name = s['exercise_name'] as String? ?? '';
            final weight = (s['weight_kg'] as num?)?.toDouble() ?? 0.0;
            final reps = (s['reps'] as num?)?.toInt() ?? 0;
            if (!seenToday.containsKey(name)) {
              seenToday[name] = true;
            } else {
              if (!prev.containsKey(name) || weight > (prev[name] ?? 0)) {
                prev[name] = weight;
                _previousReps[name] = reps;
              }
            }
          }
        }
        _previousWeights = prev;
      }
    } catch (_) {}
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LoggedSet>> grouped = {};
    for (final s in widget.loggedSets) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: _saving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    SizedBox(height: 16),
                    Text('Saving workout...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(Icons.check_circle, size: 80, color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    const Text(
                      'Workout Complete!',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 8),
                      Text('Note: Could not save to server', style: TextStyle(color: Colors.orange.shade300, fontSize: 12), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: const Color(0xFFA78BFA)),
                            const SizedBox(width: 12),
                            const Text('Duration', style: TextStyle(color: Colors.grey)),
                            const Spacer(),
                            Text(
                              _formatDuration(widget.sessionDurationSeconds),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Exercises', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    ...grouped.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFA78BFA))),
                              const SizedBox(height: 8),
                              ...entry.value.asMap().entries.map((setEntry) {
                                final setNum = setEntry.key + 1;
                                final s = setEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Set $setNum: ${s.weightKg}kg x ${s.reps} reps (${s.setDurationSeconds}s)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Text('Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    ...grouped.entries.map((entry) {
                      final exName = entry.key;
                      final sets = entry.value;
                      final todayMaxWeight = sets.fold(0.0, (max, s) => s.weightKg > max ? s.weightKg : max);
                      final todayMaxReps = sets.fold(0, (max, s) => s.reps > max ? s.reps : max);
                      final prevWeight = _previousWeights[exName];
                      final prevReps = _previousReps[exName];

                      String progressLabel;
                      Color progressColor;

                      if (prevWeight == null) {
                        progressLabel = 'First time 🎉';
                        progressColor = const Color(0xFFA78BFA);
                      } else if (todayMaxWeight > prevWeight) {
                        progressLabel = '↑ +${(todayMaxWeight - prevWeight).toStringAsFixed(1)}kg';
                        progressColor = Colors.green;
                      } else if (todayMaxWeight == prevWeight && prevReps != null && todayMaxReps > prevReps) {
                        progressLabel = '↑ +${todayMaxReps - prevReps} reps';
                        progressColor = Colors.green;
                      } else if (todayMaxWeight < prevWeight) {
                        progressLabel = '↓ Regression';
                        progressColor = Colors.red;
                      } else {
                        progressLabel = '✓ Maintained';
                        progressColor = Colors.blue;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(child: Text(exName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                              Text(progressLabel, style: TextStyle(color: progressColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () { Navigator.of(context).popUntil((route) => route.isFirst); },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back to Home', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding Screen
// ---------------------------------------------------------------------------

class OnboardingScreen extends StatefulWidget {
  /// Called after the profile is saved when this screen is shown as the
  /// post-sign-in setup step (not pushed). When null, the screen pops itself.
  final VoidCallback? onDone;
  const OnboardingScreen({super.key, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _sex = 'male';
  String _goal = 'maintain';
  String _activityLevel = 'moderate';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Editing an existing profile — prefill the form.
    final p = _activeProfile;
    if (p != null) {
      _nameCtrl.text = (p['name'] ?? '').toString();
      _ageCtrl.text = (p['age'] ?? '').toString();
      _heightCtrl.text = (p['height_cm'] ?? '').toString();
      _weightCtrl.text = (p['weight_kg'] ?? '').toString();
      _sex = (p['sex'] as String?) ?? _sex;
      _goal = (p['goal'] as String?) ?? _goal;
      _activityLevel = (p['activity_level'] as String?) ?? _activityLevel;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    // Tie the profile row to the signed-in Supabase account so it can be
    // restored on any device the user signs in from.
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    final payload = {
      if (authUserId != null) 'id': authUserId,
      'name': _nameCtrl.text.trim(),
      'age': int.parse(_ageCtrl.text.trim()),
      'sex': _sex,
      'height_cm': double.parse(_heightCtrl.text.trim()),
      'weight_kg': double.parse(_weightCtrl.text.trim()),
      'activity_level': _activityLevel,
      'goal': _goal,
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _activeProfileId = data['id'] as String?;
        _activeProfile = {
          'name': _nameCtrl.text.trim(),
          'age': int.parse(_ageCtrl.text.trim()),
          'sex': _sex,
          'height_cm': double.parse(_heightCtrl.text.trim()),
          'weight_kg': double.parse(_weightCtrl.text.trim()),
          'activity_level': _activityLevel,
          'goal': _goal,
        };
        if (widget.onDone != null) {
          widget.onDone!();
        } else {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF5A5A6E),
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text(widget.onDone != null ? 'Set Up Your Profile' : 'Edit Profile'),
        actions: [
          if (widget.onDone != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout, color: Color(0xFF8B8B9E)),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A0A2E), Color(0xFF13131A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2D1B60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.bolt, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tell us about yourself', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                            SizedBox(height: 3),
                            Text("Personalised calories, macros & training.", style: TextStyle(color: Color(0xFF8B8B9E), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── Section: Basic Info ──
                _sectionLabel('BASIC INFO'),
                _buildTextField(_nameCtrl, 'Name'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _ageCtrl, 'Age',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 13 || n > 100) return '13–100';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown('Sex', _sex, ['male', 'female'],
                          (v) => setState(() => _sex = v ?? 'male')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _heightCtrl, 'Height (cm)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final n = double.tryParse(v.trim());
                          if (n == null || n <= 100 || n >= 250) return '100–250 cm';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        _weightCtrl, 'Weight (kg)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final n = double.tryParse(v.trim());
                          if (n == null || n <= 30 || n >= 300) return '30–300 kg';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // ── Section: Goals ──
                _sectionLabel('YOUR GOAL'),
                _buildGoalSelector(),
                const SizedBox(height: 28),
                // ── Section: Activity ──
                _sectionLabel('ACTIVITY LEVEL'),
                _buildDropdown('Activity Level', _activityLevel,
                    ['sedentary', 'light', 'moderate', 'active', 'very_active'],
                    (v) => setState(() => _activityLevel = v ?? 'moderate')),
                const SizedBox(height: 36),
                _submitting
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                    : _GradientButton(
                        label: 'Create Profile',
                        onTap: _submitProfile,
                        large: true,
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalSelector() {
    final goals = [
      ('bulk', 'Bulk', 'Build muscle mass', Icons.trending_up_rounded),
      ('cut', 'Cut', 'Lose body fat', Icons.trending_down_rounded),
      ('recomp', 'Recomp', 'Build & lose simultaneously', Icons.autorenew_rounded),
      ('maintain', 'Maintain', 'Stay at current weight', Icons.horizontal_rule_rounded),
    ];
    return Column(
      children: goals.map((g) {
        final (value, label, desc, icon) = g;
        final selected = _goal == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => setState(() => _goal = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7C3AED).withOpacity(0.15) : const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? const Color(0xFF7C3AED) : const Color(0xFF1E1E2E),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFF1C1C27),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: selected ? const Color(0xFFA78BFA) : const Color(0xFF5A5A6E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFFCCCCDD), fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(desc, style: const TextStyle(color: Color(0xFF8B8B9E), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
