import 'package:darzo/login.dart';
import 'package:darzo/students/attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:darzo/students/students.dart';
import 'package:darzo/students/view_internals.dart';
import 'package:darzo/students/mark_attendance_page.dart';

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
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 36),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
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

              const SizedBox(height: 25),
              _buildMainCard(),

              const SizedBox(height: 20),
              _buildReminderCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // MAIN CARD (Attendance + Quick Actions)
  // ======================================================
  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _attendanceSection(),
          const Divider(),
          const SizedBox(height: 15),
          // ✅ MARK ATTENDANCE BUTTON (SAFE)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarkAttendancePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F7EDB),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "MARK ATTENDANCE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      builder: (_) => const StudentInternalMarksPage(),
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
                      builder: (_) => const StudentAttendanceSummaryPage(),
                    ),
                  );
                },
              ),
              _quickActionCard(
                icon: Icons.schedule,
                label: "Time Table",
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================================================
  // ATTENDANCE SUMMARY
  // ======================================================
  Widget _attendanceSection() {
    final double attendancePercentage = 78.5;
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // REMINDERS / TO-DO LIST
  // Checkbox = auto delete
  // Swipe = delete
  // Editable text
  Widget _buildReminderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Tasks & Reminders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.grey),
                onPressed: _addReminder,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ================= REMINDER LIST =================
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
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
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
                      // CHECKBOX → AUTO DELETE
                      leading: Checkbox(
                        value: false,
                        onChanged: (_) {
                          setState(() {
                            reminders.removeAt(index);
                          });
                        },
                      ),

                      // EDITABLE TITLE
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextFormField(
                          initialValue: reminder["title"],
                          cursorColor: Colors.black,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            reminder["title"] = value;
                          },
                        ),
                      ),
                      // EDITABLE SUBTITLE
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextFormField(
                          initialValue: reminder["subtitle"],
                          cursorColor: Colors.black,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            reminder["subtitle"] = value;
                          },
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ADD NEW REMINDER
  void _addReminder() {
    setState(() {
      reminders.add({"title": "New Task", "subtitle": "Subject/Deadline"});
    });
    // Scroll to bottom AFTER UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
