import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const PulseApp());
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PULSE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Science-based fitness tracking',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text('Get Started', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedGoal = 'bulk';
  String _selectedSex = 'male';
  String _selectedActivity = 'moderate';
  bool _isLoading = false;

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepPurple),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: Colors.grey[900],
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _submitProfile() async {
    final heightCm = double.tryParse(_heightController.text) ?? 0.0;
    final weightKg = double.tryParse(_weightController.text) ?? 0.0;

    setState(() => _isLoading = true);

    final profile = {
      'name': _nameController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': _selectedGoal,
      'sex': _selectedSex,
      'activity_level': _selectedActivity,
      'training_experience_years': 0.0,
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile),
      );

      if (response.statusCode == 200) {
        final bmi = heightCm > 0 ? weightKg / ((heightCm / 100) * (heightCm / 100)) : 0.0;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BMIResultScreen(
              name: _nameController.text,
              bmi: bmi,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect to backend: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Create Profile', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField('Name', _nameController),
            _buildTextField('Age', _ageController, isNumber: true),
            _buildTextField('Height (cm)', _heightController, isNumber: true),
            _buildTextField('Weight (kg)', _weightController, isNumber: true),
            _buildDropdown('Sex', _selectedSex, ['male', 'female'], (val) => setState(() => _selectedSex = val!)),
            _buildDropdown('Goal', _selectedGoal, ['bulk', 'cut', 'recomp', 'maintain'], (val) => setState(() => _selectedGoal = val!)),
            _buildDropdown('Activity Level', _selectedActivity, ['sedentary', 'light', 'moderate', 'active', 'very_active'], (val) => setState(() => _selectedActivity = val!)),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Save Profile', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class BMIResultScreen extends StatelessWidget {
  final String name;
  final double bmi;

  const BMIResultScreen({super.key, required this.name, required this.bmi});

  String get _classification {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get _classificationColor {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Your Results', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hi, $name!',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 48),
              Text(
                'Your BMI',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: _classificationColor.withAlpha(40),
                  border: Border.all(color: _classificationColor, width: 1.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _classification,
                  style: TextStyle(
                    color: _classificationColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 64),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back to Home', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}