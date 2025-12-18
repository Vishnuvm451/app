// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:darzo/ZIP/login.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Required for InputFormatters

// class StudentRegisterPage extends StatefulWidget {
//   const StudentRegisterPage({super.key});

//   @override
//   State<StudentRegisterPage> createState() => _StudentRegisterPageState();
// }

// class _StudentRegisterPageState extends State<StudentRegisterPage> {
//   // ---------------- CONTROLLERS ----------------
//   final TextEditingController fullNameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController admissionController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   // ---------------- STATE VARIABLES ----------------
//   // Store String IDs (e.g. "CSE") and Names for easier display later
//   String? selectedDeptId;
//   String? selectedDeptName;

//   String? selectedClassId;
//   String? selectedClassName;

//   String? selectedCourseType;
//   final List<String> courseTypes = ["UG", "PG"];

//   bool isLoading = false;
//   bool _isPasswordVisible = false;

//   @override
//   void dispose() {
//     fullNameController.dispose();
//     emailController.dispose();
//     admissionController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }

//   // ======================================================
//   // REGISTRATION LOGIC
//   // ======================================================
//   Future<void> registerStudent() async {
//     // 1. Validate Inputs
//     if (fullNameController.text.trim().isEmpty ||
//         emailController.text.trim().isEmpty ||
//         admissionController.text.trim().isEmpty ||
//         passwordController.text.trim().isEmpty ||
//         selectedDeptId == null ||
//         selectedCourseType == null ||
//         selectedClassId == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       // 2. Create Auth User
//       UserCredential cred = await FirebaseAuth.instance
//           .createUserWithEmailAndPassword(
//             email: emailController.text.trim(),
//             password: passwordController.text.trim(),
//           );

//       final String uid = cred.user!.uid;

//       // 3. Save Data (Using Transaction for safety)
//       await FirebaseFirestore.instance.runTransaction((transaction) async {
//         // A. Users Collection (For Role Login)
//         transaction
//             .set(FirebaseFirestore.instance.collection('users').doc(uid), {
//               "uid": uid,
//               "name": fullNameController.text.trim(),
//               "email": emailController.text.trim(),
//               "role": "student",
//               "created_at": FieldValue.serverTimestamp(),
//               "profile_completed": true,
//             });

//         // B. Students Collection (Profile Data)
//         //
//         transaction.set(
//           FirebaseFirestore.instance.collection('students').doc(uid),
//           {
//             "uid": uid,
//             "name": fullNameController.text.trim(),
//             "email": emailController.text.trim(),
//             "register_number": admissionController.text.trim(),
//             "role": "student",

//             // Saving Linked Data (Dual Saving: ID + Name)
//             "departmentId": selectedDeptId, // e.g. "CSE"
//             "departmentName": selectedDeptName, // e.g. "Computer Science"

//             "course_type": selectedCourseType, // "UG" or "PG"

//             "classId": selectedClassId, // e.g. "CSE_SECTION_A"
//             "className": selectedClassName, // e.g. "Section A"

//             "face_enabled": false, // Default
//           },
//         );
//       });

//       // 4. Logout & Redirect
//       await FirebaseAuth.instance.signOut();

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Student Registered Successfully"),
//           backgroundColor: Colors.green,
//         ),
//       );

//       await Future.delayed(const Duration(seconds: 2));

//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginPage()),
//       );
//     } on FirebaseAuthException catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(e.message ?? "Registration failed")),
//       );
//     } catch (e) {
//       // Cleanup if Firestore fails
//       await FirebaseAuth.instance.currentUser?.delete();
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // ======================================================
//   // UI BUILD
//   // ======================================================
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
//                 const Text(
//                   "DARZO",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 48,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 2,
//                   ),
//                 ),
//                 const SizedBox(height: 30),

//                 Container(
//                   padding: const EdgeInsets.all(20),
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(26),
//                   ),
//                   child: Column(
//                     children: [
//                       const Text(
//                         "STUDENT REGISTRATION",
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 20),

//                       _buildTextField(
//                         controller: fullNameController,
//                         label: "Full Name",
//                         icon: Icons.person_outline,
//                       ),
//                       const SizedBox(height: 15),

//                       _buildTextField(
//                         controller: admissionController,
//                         label: "Admission Number",
//                         icon: Icons.badge_outlined,
//                       ),
//                       const SizedBox(height: 15),

//                       _buildTextField(
//                         controller: emailController,
//                         label: "Email ID",
//                         icon: Icons.email_outlined,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.deny(RegExp(r'\s')),
//                         ],
//                       ),
//                       const SizedBox(height: 15),

//                       _buildTextField(
//                         controller: passwordController,
//                         label: "Password",
//                         icon: Icons.lock_outline,
//                         isPassword: true,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.deny(RegExp(r'\s')),
//                         ],
//                       ),
//                       const SizedBox(height: 15),

//                       // 1. DEPARTMENT DROPDOWN
//                       StreamBuilder<QuerySnapshot>(
//                         stream: FirebaseFirestore.instance
//                             .collection('departments')
//                             .orderBy('name')
//                             .snapshots(),
//                         builder: (context, snapshot) {
//                           if (!snapshot.hasData) {
//                             return const Center(
//                               child: LinearProgressIndicator(),
//                             );
//                           }

//                           final docs = snapshot.data!.docs;

//                           // SAFETY CHECK: Ensure selected ID still exists
//                           String? validValue = selectedDeptId;
//                           if (validValue != null &&
//                               !docs.any((d) => d.id == validValue)) {
//                             validValue = null;
//                           }

//                           return DropdownButtonFormField<String>(
//                             value: validValue,
//                             decoration: InputDecoration(
//                               labelText: "Department",
//                               prefixIcon: const Icon(
//                                 Icons.account_balance_outlined,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(14),
//                               ),
//                             ),
//                             items: docs.map((doc) {
//                               return DropdownMenuItem(
//                                 value: doc.id, // MANUAL STRING ID (e.g. "CSE")
//                                 child: Text(doc['name']),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 selectedDeptId = val;
//                                 // Save Name for later
//                                 selectedDeptName = docs.firstWhere(
//                                   (d) => d.id == val,
//                                 )['name'];

//                                 // Reset Dependents
//                                 selectedCourseType = null;
//                                 selectedClassId = null;
//                                 selectedClassName = null;
//                               });
//                             },
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 15),

//                       // 2. COURSE TYPE DROPDOWN
//                       _buildDropdownField(
//                         value: selectedCourseType,
//                         label: "Course Type",
//                         icon: Icons.school_outlined,
//                         items: courseTypes
//                             .map(
//                               (t) => DropdownMenuItem(value: t, child: Text(t)),
//                             )
//                             .toList(),
//                         onChanged: (val) => setState(() {
//                           selectedCourseType = val;
//                           selectedClassId = null;
//                           selectedClassName = null;
//                         }),
//                       ),
//                       const SizedBox(height: 15),

//                       // 3. CLASS DROPDOWN (Filters by Dept & Type)
//                       if (selectedDeptId != null && selectedCourseType != null)
//                         StreamBuilder<QuerySnapshot>(
//                           stream: FirebaseFirestore.instance
//                               .collection('classes')
//                               .where('departmentId', isEqualTo: selectedDeptId)
//                               .where('type', isEqualTo: selectedCourseType)
//                               .snapshots(),
//                           builder: (context, snapshot) {
//                             if (!snapshot.hasData) {
//                               return const Center(
//                                 child: LinearProgressIndicator(),
//                               );
//                             }

//                             final docs = snapshot.data!.docs;

//                             if (docs.isEmpty) {
//                               return const Padding(
//                                 padding: EdgeInsets.all(8.0),
//                                 child: Text(
//                                   "No Classes found. Contact Admin.",
//                                   style: TextStyle(color: Colors.red),
//                                 ),
//                               );
//                             }

//                             // SAFETY CHECK
//                             String? validClassValue = selectedClassId;
//                             if (validClassValue != null &&
//                                 !docs.any((d) => d.id == validClassValue)) {
//                               validClassValue = null;
//                             }

//                             return DropdownButtonFormField<String>(
//                               value: validClassValue,
//                               decoration: InputDecoration(
//                                 labelText: "Class",
//                                 prefixIcon: const Icon(Icons.class_outlined),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(14),
//                                 ),
//                               ),
//                               items: docs.map((doc) {
//                                 return DropdownMenuItem(
//                                   value: doc
//                                       .id, // MANUAL STRING ID (e.g. "CSE_SECTION_A")
//                                   child: Text(doc['name']),
//                                 );
//                               }).toList(),
//                               onChanged: (val) {
//                                 setState(() {
//                                   selectedClassId = val;
//                                   selectedClassName = docs.firstWhere(
//                                     (d) => d.id == val,
//                                   )['name'];
//                                 });
//                               },
//                             );
//                           },
//                         ),

//                       const SizedBox(height: 25),

//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: isLoading ? null : registerStudent,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: primaryBlue,
//                             padding: const EdgeInsets.symmetric(vertical: 16),
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

//                       const SizedBox(height: 16),

//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text("Already have an account? "),
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.pushReplacement(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const LoginPage(),
//                                 ),
//                               );
//                             },
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

//   // ---------------- HELPER WIDGETS ----------------
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     bool isPassword = false,
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: isPassword ? !_isPasswordVisible : false,
//       inputFormatters: inputFormatters,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
//         suffixIcon: isPassword
//             ? IconButton(
//                 icon: Icon(
//                   _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
//                   color: Colors.grey,
//                 ),
//                 onPressed: () {
//                   setState(() {
//                     _isPasswordVisible = !_isPasswordVisible;
//                   });
//                 },
//               )
//             : null,
//       ),
//     );
//   }

//   Widget _buildDropdownField<T>({
//     required T? value,
//     required String label,
//     required IconData icon,
//     required List<DropdownMenuItem<T>> items,
//     required void Function(T?) onChanged,
//   }) {
//     return DropdownButtonFormField<T>(
//       value: value,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
//       ),
//       items: items,
//       onChanged: onChanged,
//     );
//   }
// }
