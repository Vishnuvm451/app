import 'package:darzo/login.dart';
import 'package:darzo/students/attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:darzo/students/student_list.dart';
import 'package:darzo/students/view_internals.dart';
// import 'package:darzo/students/timetable_page.dart'; // if you add later

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final ScrollController _scrollController = ScrollController();

  // --------------------------------------------------
  // REMINDERS DATA
  // --------------------------------------------------
  final List<Map<String, String>> reminders = [
    {"title": "Record Submission", "subtitle": "This Friday"},
    {"title": "Prepare for internal test", "subtitle": "Data Structures"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 40),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF3F7EDB),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Icon(Icons.school, size: 70, color: Colors.white),

              const SizedBox(height: 10),

              const Text(
                "STUDENT DASHBOARD",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              // _buildAppBar(context),
              const SizedBox(height: 30),

              // ================= MAIN CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= ATTENDANCE SUMMARY =================
                    _attendanceSection(),

                    const SizedBox(height: 25),

                    // ================= QUICK ACTIONS =================
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _quickActionCard(
                          icon: Icons.people,
                          label: "Students",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentStudentsListPage(),
                              ),
                            );
                          },
                        ),

                        _quickActionCard(
                          icon: Icons.bar_chart,
                          label: "Internals",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StudentInternalMarksPage(),
                              ),
                            );
                          },
                        ),

                        _quickActionCard(
                          icon: Icons.pie_chart,
                          label: "Attendance",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StudentAttendanceSummaryPage(),
                              ),
                            );
                          },
                        ),

                        _quickActionCard(
                          icon: Icons.schedule,
                          label: "Time Table",
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (_) => StudentTimetablePage(),
                            //   ),
                            // );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // ================= REMINDERS =================
                    _buildReminderSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // ATTENDANCE SUMMARY CARD
  // ======================================================
  Widget _attendanceSection() {
    // MOCK VALUES – replace with calculated data
    final double attendancePercentage = 78.5;
    final int workingDays = 120;
    final double presentDays = 94.0;

    Color percentColor = attendancePercentage >= 75 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            const Text(
              "ATTENDANCE SUMMARY",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "${attendancePercentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: percentColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // QUICK ACTION CARD
  // ======================================================
  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3F7EDB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3F7EDB), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: const Color(0xFF3F7EDB)),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // REMINDERS SECTION
  // ======================================================
  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Tasks & Reminders",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF3F7EDB)),
              onPressed: _addReminder,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) {
                setState(() {
                  reminders.removeAt(index);
                });
              },
              child: Column(
                children: [
                  ListTile(
                    leading: Checkbox(
                      value: false,
                      onChanged: (_) {
                        setState(() {
                          reminders.removeAt(index);
                        });
                      },
                    ),
                    title: TextFormField(
                      initialValue: reminder["title"],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        reminder["title"] = value;
                      },
                    ),
                    subtitle: TextFormField(
                      initialValue: reminder["subtitle"],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        reminder["subtitle"] = value;
                      },
                    ),
                  ),
                  const Divider(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ======================================================
  // ADD REMINDER
  // ======================================================
  void _addReminder() {
    setState(() {
      reminders.add({"title": "New Task", "subtitle": "Deadline / Subject"});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
