// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:darzo/ZIP/login.dart';

// class TeacherRegisterPage extends StatefulWidget {
//   const TeacherRegisterPage({super.key});

//   @override
//   State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
// }

// class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
//   final TextEditingController fullNameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   // Stores the Manual ID (e.g. "CSE") and Name
//   String? selectedDeptId;
//   String? selectedDeptName;

//   bool isLoading = false;
//   bool _isPasswordVisible = false;

//   @override
//   void dispose() {
//     fullNameController.dispose();
//     emailController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> registerTeacher() async {
//     if (fullNameController.text.trim().isEmpty ||
//         emailController.text.trim().isEmpty ||
//         passwordController.text.trim().isEmpty ||
//         selectedDeptId == null) {
//       _showDialog("Error", "Please fill all fields");
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final email = emailController.text.trim();

//       // Creates a request in 'teacher_requests'
//       // The Admin must 'Approve' this later to create the actual 'teachers' document
//       await FirebaseFirestore.instance.collection("teacher_requests").add({
//         "name": fullNameController.text.trim(),
//         "email": email,
//         "password": passwordController.text
//             .trim(), // Note: Hash this in real apps
//         // Linking to the Manual ID from Departments
//         "departmentId": selectedDeptId, // e.g. "CSE"
//         "departmentName": selectedDeptName, // e.g. "Computer Science"

//         "status": "pending",
//         "created_at": FieldValue.serverTimestamp(),
//       });

//       fullNameController.clear();
//       emailController.clear();
//       passwordController.clear();
//       setState(() {
//         selectedDeptId = null;
//         selectedDeptName = null;
//       });

//       _showDialog(
//         "Request Sent",
//         "Your request has been sent to admin.\nPlease wait for approval.",
//       );
//     } catch (e) {
//       _showDialog("Error", "Could not submit request. Please try again.");
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _showDialog(String title, String message) {
//     return showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               if (title == "Request Sent") Navigator.of(context).pop();
//             },
//             child: const Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     const Color primaryBlue = Color(0xFF2196F3);

//     return Scaffold(
//       backgroundColor: primaryBlue,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 const SizedBox(height: 12),
//                 const Text(
//                   "DARZO",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 56,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 2.2,
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Container(
//                   padding: const EdgeInsets.all(18),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.white.withOpacity(0.18),
//                   ),
//                   child: const Icon(
//                     Icons.school_outlined,
//                     size: 56,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 28),

//                 Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(22),
//                   ),
//                   child: Column(
//                     children: [
//                       const Text(
//                         "TEACHER REGISTRATION",
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 18),

//                       _buildTextField(
//                         controller: fullNameController,
//                         label: "Full Name",
//                         icon: Icons.person_outline,
//                       ),
//                       const SizedBox(height: 14),

//                       _buildTextField(
//                         controller: emailController,
//                         label: "Email ID",
//                         icon: Icons.email_outlined,
//                         keyboardType: TextInputType.emailAddress,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.deny(RegExp(r'\s')),
//                         ],
//                       ),
//                       const SizedBox(height: 14),

//                       // Department Dropdown
//                       StreamBuilder<QuerySnapshot>(
//                         stream: FirebaseFirestore.instance
//                             .collection('departments')
//                             .orderBy('name')
//                             .snapshots(),
//                         builder: (context, snapshot) {
//                           if (snapshot.hasError) {
//                             return Text("Error: ${snapshot.error}");
//                           }
//                           if (!snapshot.hasData) {
//                             return const SizedBox(
//                               height: 55,
//                               child: Center(child: LinearProgressIndicator()),
//                             );
//                           }

//                           final docs = snapshot.data!.docs;

//                           // SAFE VALIDATION: Ensure selected ID still exists in the list
//                           // If Admin deleted "CSE" while Teacher was selecting it
//                           String? validValue = selectedDeptId;
//                           if (validValue != null &&
//                               !docs.any((doc) => doc.id == validValue)) {
//                             validValue = null;
//                           }

//                           return DropdownButtonFormField<String>(
//                             value: validValue,
//                             decoration: InputDecoration(
//                               labelText: "Department",
//                               prefixIcon: const Icon(Icons.apartment_outlined),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                             items: docs.map((doc) {
//                               return DropdownMenuItem(
//                                 value:
//                                     doc.id, // Using the Manual ID (e.g. "CSE")
//                                 child: Text(doc['name']),
//                               );
//                             }).toList(),
//                             onChanged: (value) {
//                               setState(() {
//                                 selectedDeptId = value;
//                                 // Store name for easier display later
//                                 if (value != null) {
//                                   selectedDeptName = docs.firstWhere(
//                                     (d) => d.id == value,
//                                   )['name'];
//                                 }
//                               });
//                             },
//                           );
//                         },
//                       ),

//                       const SizedBox(height: 14),

//                       _buildTextField(
//                         controller: passwordController,
//                         label: "Password",
//                         icon: Icons.lock_outline,
//                         isPassword: true,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.deny(RegExp(r'\s')),
//                         ],
//                       ),
//                       const SizedBox(height: 22),

//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: isLoading ? null : registerTeacher,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: primaryBlue,
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                           ),
//                           child: isLoading
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                 )
//                               : const Text(
//                                   "REGISTER",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                         ),
//                       ),

//                       const SizedBox(height: 14),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text("Already have an account? "),
//                           GestureDetector(
//                             onTap: () => Navigator.pushReplacement(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (_) => const LoginPage(),
//                               ),
//                             ),
//                             child: const Text(
//                               "Login",
//                               style: TextStyle(
//                                 color: primaryBlue,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     bool isPassword = false,
//     TextInputType keyboardType = TextInputType.text,
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: isPassword ? !_isPasswordVisible : false,
//       keyboardType: keyboardType,
//       inputFormatters: inputFormatters,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//         suffixIcon: isPassword
//             ? IconButton(
//                 icon: Icon(
//                   _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
//                   color: Colors.grey,
//                 ),
//                 onPressed: () =>
//                     setState(() => _isPasswordVisible = !_isPasswordVisible),
//               )
//             : null,
//       ),
//     );
//   }
// }
