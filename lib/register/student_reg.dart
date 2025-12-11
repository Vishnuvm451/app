import 'package:darzo/login/login.dart';
import 'package:flutter/material.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ─────────────────────────────────────────────
  // TEXT CONTROLLERS (No backend – just UI)
  // ─────────────────────────────────────────────
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController admissionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Dropdown values
  String? selectedDepartment;
  String? selectedYear;

  // ─────────────────────────────────────────────
  // DEPARTMENT LIST + DEPARTMENT -> YEARS MAP
  // (Added: map to provide dept-specific year options)
  // ─────────────────────────────────────────────
  final List<String> departments = ["Computer Science", "Physics", "BCom"];

  // Map of department -> available years (department-specific)
  final Map<String, List<String>> deptToYears = {
    "Computer Science": ["CS1", "CS2", "CS3", "PG1", "PG2"],
    "Physics": ["PHY1", "PHY2", "PHY3", "PG1", "PG2"],
    "BCom": ["BCOM1", "BCOM2", "BCOM3", "MCOM1", "MCOM2"],
  };

  // Helper getter: returns year list for the currently selected department
  List<String> get currentYearOptions {
    if (selectedDepartment == null) return <String>[];
    return deptToYears[selectedDepartment!] ?? <String>[];
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: primaryBlue,

      // Safe area + scroll view
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                // ─────────────────────
                // APP TITLE
                // ─────────────────────
                const Text(
                  "DARZO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 20),

                // Icon Circle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    size: 56,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // ─────────────────────
                // CARD (White Box)
                // ─────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      const Text(
                        "STUDENT REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ───────────────────────────────
                      // FULL NAME FIELD
                      // ───────────────────────────────
                      _buildTextField(
                        controller: fullNameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 15),

                      // EMAIL FIELD
                      _buildTextField(
                        controller: emailController,
                        label: "Email ID",
                        icon: Icons.school,
                      ),
                      const SizedBox(height: 15),

                      // ───────────────────────────────
                      // DEPARTMENT DROPDOWN
                      // (Changed: this was previously 'Admission Number' dropdown)
                      // ───────────────────────────────
                      _buildDropdown(
                        value: selectedDepartment,
                        label: "Department",
                        items: departments,
                        icon: Icons.account_balance_outlined,
                        onChanged: (value) {
                          // When department changes, reset selectedYear so user must re-pick
                          setState(() {
                            selectedDepartment = value;
                            selectedYear = null;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // ───────────────────────────────
                      // YEAR DROPDOWN (Dynamic based on department)
                      // (Changed: items now come from deptToYears via currentYearOptions)
                      // ───────────────────────────────
                      DropdownButtonFormField<String>(
                        initialValue: selectedYear,
                        decoration: InputDecoration(
                          labelText: selectedDepartment == null
                              ? "Select Department first"
                              : "Year",
                          prefixIcon: const Icon(Icons.bookmark_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        // If no department selected, present empty list
                        items: currentYearOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // PASSWORD FIELD
                      _buildTextField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),

                      const SizedBox(height: 25),

                      // ───────────────────────────────
                      // REGISTER BUTTON
                      // ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // UI only: you can inspect selectedDepartment and selectedYear here
                            debugPrint(
                              'Dept: $selectedDepartment, Year: $selectedYear',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "REGISTER",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Already have account?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────
  // TEXT FIELD BUILDER (Reusable)
  // ───────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ───────────────────────────────
  // DROPDOWN BUILDER (Reusable)
  // (used for Department)
  // ───────────────────────────────
  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
