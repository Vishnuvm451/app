import 'package:darzo/login/login.dart';
import 'package:flutter/material.dart';

class StudentDashboardPage extends StatelessWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Overall blue background
      backgroundColor: const Color(0xFF3F7EDB),

      body: SafeArea(
        // Makes the page scrollable
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                  ),
                ],
                // title: const Text(
                //   "Student Dashboard",
                //   style: TextStyle(color: Colors.white),
                // ),
                // centerTitle: true,
              ),
              // ================= HEADER ICON =================
              Icon(Icons.access_time_filled, size: 80, color: Colors.white),

              const SizedBox(height: 10),

              // ================= TITLE =================
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
                    // ---------- Attendance Summary Title ----------
                    Center(
                      child: const Text(
                        "ATTENDANCE SUMMARY",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Text student name
                    Center(
                      child: const Text(
                        "Heyy!+name",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ---------- Attendance Info Row ----------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ===== Circular Percentage =====
                        Container(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // // Outer circle
                              // CircularProgressIndicator(
                              //   value: 0.85, // 85%
                              //   strokeWidth: 28,
                              //   backgroundColor: Colors.grey.shade300,
                              //   valueColor: const AlwaysStoppedAnimation(
                              //     Color(0xFF3F7EDB),
                              //   ),
                              // ),

                              // Center text
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    "85%",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Attendance\nPercentage",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ===== Working Days =====
                        Column(
                          children: const [
                            Text(
                              "120",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F7EDB),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text("WORKING\nDAYS", textAlign: TextAlign.center),
                          ],
                        ),

                        // Divider line
                        Container(
                          height: 50,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),

                        // ===== Present Days =====
                        Column(
                          children: const [
                            Text(
                              "102",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F7EDB),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text("PRESENT\nDAYS", textAlign: TextAlign.center),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ================= BUTTONS =================

                    // Students Button
                    _dashboardButton(title: "STUDENTS", onTap: () {}),

                    const SizedBox(height: 15),

                    // Internal Button
                    _dashboardButton(title: "INTERNAL", onTap: () {}),

                    const SizedBox(height: 15),

                    // Time Table Button
                    _dashboardButton(title: "TIME TABLE", onTap: () {}),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= REUSABLE BUTTON WIDGET =================
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
