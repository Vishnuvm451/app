import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Placeholder pages - replace with your real pages / widgets
/// ---------------------------------------------------------------------------
/// Replace StudentsPage, InternalsPage, TimetablePage with your actual pages.
/// Keep the constructor const if pages are stateless for performance benefit.
class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Students')),
    body: const Center(child: Text('Students')),
  );
}

class InternalsPage extends StatelessWidget {
  const InternalsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Internals')),
    body: const Center(child: Text('Internals')),
  );
}

class TimetablePage extends StatelessWidget {
  const TimetablePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Timetable')),
    body: const Center(child: Text('Timetable')),
  );
}

/// ---------------------------------------------------------------------------
/// QuickActionCard
/// Reusable rounded card button used in the Quick Actions row.
/// - icon: IconData for the inner icon.
/// - label: small label under the icon.
/// - accent: color used for icon and small background circle.
/// - onTap: navigation callback (Navigator.push or any router call).
/// ---------------------------------------------------------------------------
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const QuickActionCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = const Color(0xFF5B8DEF),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Compute width so 3 cards fit in one row with horizontal padding.
    // If you want 4 cards on tablet, change logic here.
    final width = (MediaQuery.of(context).size.width - 64) / 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // subtle shadow like reference design
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // small rounded background circle for icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// StudentDashboardModified
/// Main widget for the screen — drop into your navigation or use as a route.
/// Usage:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardModified()));
/// or set as home in MaterialApp for testing.
/// ---------------------------------------------------------------------------
class StudentDashboardModified extends StatelessWidget {
  const StudentDashboardModified({Key? key}) : super(key: key);

  // Small helper to push a page — replace with your router if needed.
  void _push(BuildContext ctx, Widget page) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Radius for the main white card — change for more/less rounded corners.
    const radius = 18.0;

    return Scaffold(
      // background color slightly off-white / light-blue
      backgroundColor: const Color(0xFFEFF6FF),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- TOP HEADER (gradient) ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A79FF), Color(0xFF7B4CFF)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  // top icon (center-left visually)
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 44,
                  ),
                  SizedBox(height: 12),
                  // screen title
                  Text(
                    'Student Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ---------------- MAIN WHITE CARD (attendance summary) ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ATTENDANCE SUMMARY',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),

                      // Row contains: circular percentage indicator + working/present stats
                      Row(
                        children: [
                          // ---------------- CIRCULAR PERCENT ----------------
                          SizedBox(
                            width: 92,
                            height: 92,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Using CircularProgressIndicator as ring.
                                // To use a custom ring with gradient or stroke effect,
                                // replace this with a custom painter.
                                SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: CircularProgressIndicator(
                                    value: 0.85, // attendance ratio (85%)
                                    strokeWidth: 8,
                                    backgroundColor: Colors.blue.shade50,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      '85%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Attendance',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 18),

                          // ---------------- STAT BLOCKS ----------------
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('120', 'WORKING DAYS'),
                                // vertical divider
                                Container(
                                  width: 1,
                                  height: 48,
                                  color: Colors.grey.shade200,
                                ),
                                _buildStat('102', 'PRESENT DAYS'),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ---------------- QUICK ACTIONS LABEL ----------------
                      const Text(
                        'Quick Actions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),

                      // ---------------- QUICK ACTION ROW ----------------
                      // Single row with 3 QuickActionCard widgets (View Students, Internals, Timetable).
                      // Each card is tappable and calls _push -> navigate to the page.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          QuickActionCard(
                            icon: Icons.people,
                            label: 'View Students',
                            accent: const Color(0xFF4A79FF),
                            onTap: () => _push(context, const StudentsPage()),
                          ),
                          QuickActionCard(
                            icon: Icons.calculate_outlined,
                            label: 'Internals',
                            accent: const Color(0xFF7B4CFF),
                            onTap: () => _push(context, const InternalsPage()),
                          ),
                          QuickActionCard(
                            icon: Icons.schedule,
                            label: 'Timetable',
                            accent: const Color(0xFF00BFA6),
                            onTap: () => _push(context, const TimetablePage()),
                          ),
                        ],
                      ),

                      // NOTE: per your request the timetable card and large CTA were removed.
                    ],
                  ),
                ),
              ),
            ),

            // bottom spacing so UI doesn't feel cramped
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  /// Small helper to render stat blocks in the summary (value + label)
  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            color: Color(0xFF3B82F6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
