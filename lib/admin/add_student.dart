import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final admissionController = TextEditingController();
  final nameController = TextEditingController();

  String? department;
  String? year;

  final List<String> departments = ["Computer Science", "Physics", "BCom"];
  final Map<String, List<String>> years = {
    "Computer Science": ["CS1", "CS2", "CS3", "PG1", "PG2"],
    "Physics": ["PHY1", "PHY2", "PHY3", "PG1", "PG2"],
    "BCom": ["BCOM1", "BCOM2", "BCOM3", "MCOM1", "MCOM2"],
  };

  Future<void> saveStudent() async {
    if (admissionController.text.isEmpty ||
        nameController.text.isEmpty ||
        department == null ||
        year == null) {
      _snack("Fill all fields");
      return;
    }

    await FirebaseFirestore.instance
        .collection("student_master")
        .doc(admissionController.text.trim())
        .set({
          "admission_no": admissionController.text.trim(),
          "name": nameController.text.trim(),
          "department": department,
          "year": year,
          "is_registered": false,
        });

    _snack("Student added successfully");
    admissionController.clear();
    nameController.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: primaryBlue, // light background
      appBar: AppBar(
        title: const Text("Add Student"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Student Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                _inputField(
                  controller: admissionController,
                  label: "Admission Number",
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),

                _inputField(
                  controller: nameController,
                  label: "Student Name",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: department,
                  decoration: _dropdownDecoration(
                    "Department",
                    Icons.apartment_outlined,
                  ),
                  items: departments
                      .map(
                        (String d) =>
                            DropdownMenuItem<String>(value: d, child: Text(d)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    department = v;
                    year = null;
                  }),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: year,
                  decoration: _dropdownDecoration(
                    "Year",
                    Icons.school_outlined,
                  ),
                  items: (department == null ? <String>[] : years[department]!)
                      .map(
                        (String y) =>
                            DropdownMenuItem<String>(value: y, child: Text(y)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => year = v),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "SAVE STUDENT",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF1F3F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF1F3F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
