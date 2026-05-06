import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const NutriApp());
}

class NutriApp extends StatelessWidget {
  const NutriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri Expert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

// --- MODELO DE DATOS ---
class Child {
  final String id;
  final String name;
  final DateTime birthDate;
  final List<Measurement> measurements;

  Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.measurements,
  });

  int get ageInMonths {
    DateTime today = DateTime.now();
    int years = today.year - birthDate.year;
    int months = today.month - birthDate.month;
    if (today.day < birthDate.day) months--;
    return max(0, years * 12 + months);
  }

  String get ageDisplay {
    int totalMonths = ageInMonths;
    if (totalMonths < 24) return '$totalMonths meses';
    int years = totalMonths ~/ 12;
    int remainingMonths = totalMonths % 12;
    return remainingMonths == 0 ? '$years años' : '$years años y $remainingMonths m';
  }
}

class Measurement {
  final double weight;
  final double height;
  final String nutritionalStatus;
  final Color statusColor;
  final List<String> recommendations;
  final DateTime date;

  Measurement({
    required this.weight,
    required this.height,
    required this.nutritionalStatus,
    required this.statusColor,
    required this.recommendations,
    required this.date,
  });

  double get bmi => weight / ((height / 100) * (height / 100));
}

// --- LÓGICA DE RECOMENDACIONES ---
class NutriLogic {
  static Map<String, dynamic> getDiagnosis(double weight, double heightCm) {
    double heightM = heightCm / 100;
    double imc = weight / pow(heightM, 2);

    if (imc < 18.5) {
      return {
        'status': 'Bajo Peso',
        'color': Colors.redAccent,
        'tips': [
          'Aumentar la ingesta calórica con alimentos nutritivos.',
          'Incluir snacks saludables entre comidas (frutos secos, yogurt).',
          'Asegurar un consumo adecuado de proteínas.',
          'Consultar con un pediatra para descartar causas subyacentes.'
        ],
      };
    } else if (imc < 25) {
      return {
        'status': 'Normal',
        'color': Colors.green,
        'tips': [
          'Mantener una alimentación variada y equilibrada.',
          'Fomentar la actividad física diaria (mínimo 60 min).',
          'Limitar el consumo de ultraprocesados y bebidas azucaradas.',
          'Asegurar un buen descanso nocturno.'
        ],
      };
    } else if (imc < 30) {
      return {
        'status': 'Sobrepeso',
        'color': Colors.orange,
        'tips': [
          'Aumentar el consumo de frutas y verduras frescas.',
          'Reducir las porciones de carbohidratos refinados.',
          'Evitar comer frente a pantallas (TV, tablet).',
          'Preferir el agua sobre jugos o gaseosas.'
        ],
      };
    } else {
      return {
        'status': 'Obesidad',
        'color': Colors.red,
        'tips': [
          'Establecer horarios fijos para las comidas.',
          'Eliminar por completo bebidas azucaradas y frituras.',
          'Realizar actividad física en familia.',
          'Es fundamental el seguimiento con un nutricionista infantil.'
        ],
      };
    }
  }
}

// --- PANTALLA PRINCIPAL ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Child> children = [];
  final TextEditingController _searchController = TextEditingController();
  List<Child> _filteredChildren = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterChildren);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final childrenData = await db.getChildren();
    
    List<Child> loadedChildren = [];
    for (var childMap in childrenData) {
      final measurementsData = await db.getMeasurementsForChild(childMap['id']);
      
      List<Measurement> measurements = measurementsData.map((m) {
        return Measurement(
          weight: (m['weight'] as num).toDouble(),
          height: (m['height'] as num).toDouble(),
          nutritionalStatus: m['nutritionalStatus'],
          statusColor: Color(m['statusColor'] as int),
          recommendations: (m['recommendations'] as String).split('|'),
          date: DateTime.parse(m['date']),
        );
      }).toList();

      loadedChildren.add(Child(
        id: childMap['id'],
        name: childMap['name'],
        birthDate: DateTime.parse(childMap['birthDate']),
        measurements: measurements,
      ));
    }

    setState(() {
      children = loadedChildren;
      _filteredChildren = children;
    });
  }

  void _filterChildren() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChildren = children.where((child) => child.name.toLowerCase().contains(query)).toList();
    });
  }

  void _addChild(Child child) async {
    final db = DatabaseHelper();
    
    await db.insertChild({
      'id': child.id,
      'name': child.name,
      'birthDate': child.birthDate.toIso8601String(),
    });

    for (var m in child.measurements) {
      await db.insertMeasurement({
        'id': DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(100).toString(),
        'childId': child.id,
        'weight': m.weight,
        'height': m.height,
        'nutritionalStatus': m.nutritionalStatus,
        'statusColor': m.statusColor.value,
        'recommendations': m.recommendations.join('|'),
        'date': m.date.toIso8601String(),
      });
    }

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expedientes Nutricionales'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar niño...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: _filteredChildren.isEmpty
                ? const Center(child: Text('No hay registros'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredChildren.length,
                    itemBuilder: (context, index) => _buildChildCard(context, _filteredChildren[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        label: const Text('Nuevo'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChildCard(BuildContext context, Child child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryScreen(child: child))),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(child.ageDisplay),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())).then((result) {
      if (result != null) _addChild(result);
    });
  }
}

// --- PANTALLA DE HISTORIAL ---
class HistoryScreen extends StatefulWidget {
  final Child child;
  const HistoryScreen({super.key, required this.child});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial de ${widget.child.name}')),
      body: widget.child.measurements.isEmpty
          ? const Center(child: Text('No hay mediciones'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChart(),
                const SizedBox(height: 20),
                const Text('Mediciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...widget.child.measurements.map((m) => _buildMeasurementCard(m)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMeasurementDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChart() {
    final measurements = widget.child.measurements;
    if (measurements.length < 2) {
      return Card(
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 40, color: Colors.grey),
                Text('Se necesitan al menos 2 mediciones para ver el progreso'),
              ],
            ),
          ),
        ),
      );
    }

    final firstTimestamp = measurements.first.date.millisecondsSinceEpoch.toDouble();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          children: [
            const Text('Evolución de Peso y IMC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: true),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Tiempo'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // Mostrar solo algunos puntos para no saturar
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      axisNameWidget: Text('Valor'),
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: measurements.map((m) => FlSpot(m.date.millisecondsSinceEpoch.toDouble() - firstTimestamp, m.weight)).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                    ),
                    LineChartBarData(
                      spots: measurements.map((m) => FlSpot(m.date.millisecondsSinceEpoch.toDouble() - firstTimestamp, m.bmi)).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Peso (kg)', Colors.blue),
                const SizedBox(width: 20),
                _buildLegendItem('IMC', Colors.green),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMeasurementCard(Measurement measurement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: measurement.statusColor.withOpacity(0.2),
          child: Icon(Icons.fitness_center, color: measurement.statusColor),
        ),
        title: Text('${measurement.weight}kg - ${measurement.height}cm', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${measurement.nutritionalStatus} | ${measurement.date.day}/${measurement.date.month}/${measurement.date.year}'),
        trailing: Text('IMC: ${measurement.bmi.toStringAsFixed(1)}', style: TextStyle(color: measurement.statusColor, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recomendaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...measurement.recommendations.map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip)),
                        ],
                      ),
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationScreen(child: widget.child))).then((result) async {
      if (result != null && result is Measurement) {
        final db = DatabaseHelper();
        await db.insertMeasurement({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'childId': widget.child.id,
          'weight': result.weight,
          'height': result.height,
          'nutritionalStatus': result.nutritionalStatus,
          'statusColor': result.statusColor.value,
          'recommendations': result.recommendations.join('|'),
          'date': result.date.toIso8601String(),
        });
        
        setState(() {
          widget.child.measurements.add(result);
          widget.child.measurements.sort((a, b) => b.date.compareTo(a.date));
        });
      }
    });
  }
}

// --- PANTALLA DE REGISTRO ---
class RegistrationScreen extends StatefulWidget {
  final Child? child;
  const RegistrationScreen({super.key, this.child});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.child != null) {
      _nameController.text = widget.child!.name;
      _selectedDate = widget.child!.birthDate;
      _dateController.text = _selectedDate!.toLocal().toString().split(' ')[0];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);

      if (weight == null || height == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingrese valores numéricos válidos')),
        );
        return;
      }

      final diag = NutriLogic.getDiagnosis(weight, height);

      final measurement = Measurement(
        weight: weight,
        height: height,
        nutritionalStatus: diag['status'],
        statusColor: diag['color'],
        recommendations: List<String>.from(diag['tips']),
        date: DateTime.now(),
      );

      if (widget.child == null) {
        final child = Child(
          id: DateTime.now().toString(),
          name: _nameController.text,
          birthDate: _selectedDate!,
          measurements: [measurement],
        );
        Navigator.pop(context, child);
      } else {
        Navigator.pop(context, measurement);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.child == null ? 'Nuevo Niño' : 'Nueva Medición')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.child == null) ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Fecha de Nacimiento'),
                onTap: _selectDate,
                controller: _dateController,
                validator: (value) => _selectedDate == null ? 'Selecciona fecha' : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(labelText: 'Altura (cm)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
