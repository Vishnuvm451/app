import 'package:demoapp/login/loginpage.dart';
import 'package:flutter/material.dart';

// ======================================================
// STUDENT DASHBOARD PAGE (STATEFUL)
// ======================================================
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final ScrollController _scrollController = ScrollController();
  // --------------------------------------------------
  // REMINDER DATA (student side)
  // --------------------------------------------------
  final List<Map<String, String>> reminders = [
    {"title": "Record Submission", "subtitle": "This Friday"},
    {"title": "Prepare for internal test", "subtitle": "Data Structures"},
  ];

  // --------------------------------------------------
  // MAIN BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F7EDB),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: 10),

              // HEADER ICON
              const Icon(
                Icons.access_time_filled,
                size: 80,
                color: Colors.white,
              ),

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

              const SizedBox(height: 30),

              // ================= MAIN WHITE CARD =================
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
                    _attendanceSection(),
                    const SizedBox(height: 25),

                    // DASHBOARD BUTTONS
                    _dashboardButton(title: "STUDENTS", onTap: () {}),
                    const SizedBox(height: 15),
                    _dashboardButton(title: "INTERNAL", onTap: () {}),
                    const SizedBox(height: 15),
                    _dashboardButton(title: "TIME TABLE", onTap: () {}),

                    const SizedBox(height: 25),

                    // ================= REMINDERS SECTION =================
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
  // APP BAR
  // ======================================================
  Widget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Loginpage()),
            );
          },
        ),
      ],
    );
  }

  // ======================================================
  // ATTENDANCE SUMMARY (unchanged)
  // ======================================================
  Widget _attendanceSection() {
    return Column(
      children: [
        const Center(
          child: Text(
            "ATTENDANCE SUMMARY",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            "Heyy! + name",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  // ======================================================
  // REMINDERS (STUDENT)
  // ======================================================
  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER + ADD
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

        // REMINDER LIST
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
                    title: TextFormField(
                      initialValue: reminder["title"],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        reminder["title"] = value;
                      },
                    ),

                    // EDITABLE SUBTITLE
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
      reminders.add({"title": "New Task", "subtitle": "Deadline/Subject"});
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

  // ======================================================
  // BUTTON WIDGET
  // ======================================================
  Widget _dashboardButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3F7EDB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
