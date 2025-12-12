import 'package:flutter/material.dart';

class OfflineMedicalGuidesPage extends StatefulWidget {
  const OfflineMedicalGuidesPage({super.key});

  @override
  State<OfflineMedicalGuidesPage> createState() =>
      _OfflineMedicalGuidesPageState();
}

class _OfflineMedicalGuidesPageState extends State<OfflineMedicalGuidesPage> {
  final List<Map<String, dynamic>> _allGuides = [
    {
      'title': 'Bleeding/Blood',
      'imagePath': 'assets/images/bleeding.jpg',
      'steps': [
        '1. Determine the presence of consciousness and breathing',
        '2. Call emergency services',
        '3. Put a sterile bandage on the wound',
        '4. Apply a tourniquet if bleeding is severe',
        '5. Elevate the injured limb',
        '6. Get medical care',
      ],
    },
    {
      'title': 'Choking',
      'imagePath': 'assets/images/choking.jpg',
      'steps': [
        '1. Ask the person: "Are you choking?"',
        '2. Slap it out (5 back blows)',
        '3. Squeeze it out (5 abdominal thrusts)',
        '4. Check the mouth for objects',
        '5. Give 30 compressions pushing down',
        '6. Give 2 breaths',
      ],
    },
    {
      'title': 'CPR (Cardiopulmonary Resuscitation)',
      'imagePath': 'assets/images/cpr.jpg',
      'steps': [
        '1. Call emergency',
        '2. Check vital signs',
        '3. Lift chin, check breathing',
        '4. Give 2 rescue breaths',
        '5. Perform CPR: 30 compressions x15 cycles',
        '6. Wait for help',
      ],
    },
    {
      'title': 'Dehydration Symptoms',
      'imagePath': 'assets/images/dehydration.jpg',
      'steps': [
        'Thirst',
        'Dry mouth',
        'Less frequent urination',
        'Dry skin',
        'Headache',
        'Rapid heartbeat',
      ],
    },
    {
      'title': 'Epilepsy',
      'imagePath': 'assets/images/epilepsy.jpg',
      'steps': [
        '1. Do not restrain the person\'s movements',
        '2. Keep the person safe from harmful objects',
        '3. When seizure ends, roll the person onto their side',
        '4. If seizure lasts more than 5 minutes, call 911',
        '5. Stay with them until ambulance arrives',
      ],
    },
    {
      'title': 'Heat Stroke',
      'imagePath': 'assets/images/heat_stroke.jpg',
      'steps': [
        'Symptoms: High body temperature, Headache, Dizziness, Nausea',
        'Prevention: Stay hydrated, Wear a hat, Avoid alcohol, Take rest',
        'First Aid: Move to a cool place, Cool the body, Give water',
      ],
    },
  ];

  List<Map<String, dynamic>> _filteredGuides = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredGuides = _allGuides;
    _searchController.addListener(_filterGuides);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterGuides);
    _searchController.dispose();
    super.dispose();
  }

  void _filterGuides() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGuides = _allGuides.where((guide) {
        final title = guide['title'].toString().toLowerCase();
        final steps = guide['steps'] as List<String>;
        final stepsText = steps.join(' ').toLowerCase();
        return title.contains(query) || stepsText.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offline Medical Guides',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFC3B3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search guides... (e.g. heat, CPR)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterGuides();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredGuides.length} guide${_filteredGuides.length == 1 ? '' : 's'} found',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredGuides.isEmpty
                ? const Center(
                    child: Text(
                      'No guides found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredGuides.length,
                    itemBuilder: (context, index) {
                      final guide = _filteredGuides[index];
                      return _buildGuide(
                        title: guide['title'],
                        imagePath: guide['imagePath'],
                        steps: guide['steps'],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuide({
    required String title,
    required String imagePath,
    required List<String> steps,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ZoomableImagePage(imagePath: imagePath),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    color: Colors.red.shade50,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Image not found',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap image to zoom',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(step, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ZoomableImagePage extends StatelessWidget {
  final String imagePath;

  const ZoomableImagePage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Image failed to load',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
