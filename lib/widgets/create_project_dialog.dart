import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  String? _selectedManager;

  List<String> _states = [];
  List<String> _countries = [];
  List<String> _managers = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _loadManagers();
  }

  void _loadCountries() {
    setState(() {
      _countries = CountryService().getAll().map((c) => c.name).toList();
    });
  }

  Future<void> _loadManagers() async {
    final snapshot = await FirebaseFirestore.instance.collection('manager').get();
    setState(() {
      _managers = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void _onCountryChanged(String? country) {
    setState(() {
      _selectedCountry = country;
      if (country == 'United States') {
        _states = [
          'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware',
          'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky',
          'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi',
          'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico',
          'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania',
          'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
          'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'
        ];
      } else if (country == 'Mexico') {
        _states = [
          'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche', 'Chiapas', 'Chihuahua',
          'Coahuila', 'Colima', 'Durango', 'Guanajuato', 'Guerrero', 'Hidalgo', 'Jalisco', 'México',
          'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca', 'Puebla', 'Querétaro', 'Quintana Roo',
          'San Luis Potosí', 'Sinaloa', 'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz',
          'Yucatán', 'Zacatecas'
        ];
      } else {
        _states = [];
      }
      _selectedState = null;
    });
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;
    await FirebaseFirestore.instance.collection('projects').add({
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'street': _streetController.text.trim(),
      'number': _numberController.text.trim(),
      'zip': _zipController.text.trim(),
      'city': _cityController.text.trim(),
      'country': _selectedCountry,
      'state': _selectedState,
      'manager': _selectedManager,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Project Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(labelText: 'Project Code'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(labelText: 'Street'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _numberController,
                decoration: InputDecoration(labelText: 'Number'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _zipController,
                decoration: InputDecoration(labelText: 'ZIP Code'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'City'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _onCountryChanged,
                decoration: InputDecoration(labelText: 'Country'),
                validator: (v) => v == null ? 'Required' : null,
              ),
              if (_states.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedState,
                  items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedState = v),
                  decoration: InputDecoration(labelText: 'State'),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              DropdownButtonFormField<String>(
                value: _selectedManager,
                items: _managers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _selectedManager = v),
                decoration: InputDecoration(labelText: 'Project Manager'),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createProject,
          child: Text('Create'),
        ),
      ],
    );
  }
}