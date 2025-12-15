import 'package:flutter/material.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  // --------------------------------------------------
  // CONTROLLERS
  // --------------------------------------------------
  final TextEditingController rollController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController admissionController = TextEditingController();

  // --------------------------------------------------
  // ATTENDANCE (AUTO – NOT EDITABLE)
  // --------------------------------------------------
  int presentPeriods = 0;
  int totalPeriods = 0;

  double get attendancePercentage {
    if (totalPeriods == 0) return 0;
    return (presentPeriods / totalPeriods) * 100;
  }

  // --------------------------------------------------
  // FORM KEY
  // --------------------------------------------------
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Student"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= ROLL NO =================
              _buildTextField(
                controller: rollController,
                label: "Roll Number",
                hint: "Enter roll number",
              ),

              const SizedBox(height: 16),

              // ================= STUDENT NAME =================
              _buildTextField(
                controller: nameController,
                label: "Student Name",
                hint: "Enter student name",
              ),

              const SizedBox(height: 16),

              // ================= ADMISSION NUMBER =================
              _buildTextField(
                controller: admissionController,
                label: "Admission Number",
                hint: "Enter admission number",
              ),

              const SizedBox(height: 24),

              // ================= AUTO ATTENDANCE DISPLAY =================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Attendance %",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      totalPeriods == 0
                          ? "--"
                          : "${attendancePercentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ================= SAVE BUTTON =================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Save Student",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // TEXT FIELD WIDGET
  // --------------------------------------------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: (value) =>
              value == null || value.isEmpty ? "Required field" : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // SAVE STUDENT LOGIC
  // --------------------------------------------------
  void _saveStudent() {
    if (!_formKey.currentState!.validate()) return;

    final studentData = {
      "rollNo": rollController.text.trim(),
      "name": nameController.text.trim(),
      "admissionNo": admissionController.text.trim(),
      "presentPeriods": 0,
      "totalPeriods": 0,
      // Attendance % is derived, NOT stored
    };

    // 🔥 BACKEND HOOK (Firestore)
    // Save `studentData` to students collection

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Student added successfully")));

    // Clear fields for next entry
    rollController.clear();
    nameController.clear();
    admissionController.clear();
  }
}
