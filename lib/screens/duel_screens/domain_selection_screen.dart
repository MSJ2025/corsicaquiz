import 'dart:math';
import 'package:flutter/material.dart';

class DomainSelectionScreen extends StatefulWidget {
  @override
  _DomainSelectionScreenState createState() => _DomainSelectionScreenState();
}

class _DomainSelectionScreenState extends State<DomainSelectionScreen> {
  final List<String> availableDomains = [
    'questions_culture',
    'questions_faune_flore',
    'questions_histoire',
    'questions_personnalites',
  ];
  final List<String?> selectedDomains = List.generate(6, (_) => null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir 6 domaines'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow.shade100, Colors.blue.shade100, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    'Domaines sélectionnés : ${selectedDomains.where((domain) => domain != null).length}/6',
                    key: ValueKey(selectedDomains.where((domain) => domain != null).length),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              if (selectedDomains.any((d) => d != null))
                Container(
                  height: 35,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: selectedDomains.where((d) => d != null).map((domain) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            domain!
                                .replaceAll('questions_', '')
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((word) => word[0].toUpperCase() + word.substring(1))
                                .join(' '),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedDomains.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: selectedDomains[index] != null
                              ? Border.all(color: Colors.orangeAccent, width: 2)
                              : Border.all(color: Colors.transparent),
                          gradient: LinearGradient(
                            colors: selectedDomains[index] != null
                                ? [Colors.blueAccent.shade200, Colors.yellow.shade400]
                                : [Colors.orangeAccent, Colors.blueAccent.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: selectedDomains[index] != null
                              ? [BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))]
                              : [],
                        ),
                        transform: selectedDomains[index] != null
                            ? (Matrix4.identity()..scale(1.05))
                            : Matrix4.identity(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDomains[index],
                            icon: const Icon(Icons.expand_circle_down_rounded, color: Colors.blueAccent),
                            isExpanded: true,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                            hint: Text('Domaine pour question ${index + 1}',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            ),
                            items: availableDomains.map((domain) {
                              return DropdownMenuItem(
                                value: domain,
                                child: Text(
                                  domain
                                      .replaceAll('questions_', '')
                                      .replaceAll('_', ' ')
                                      .split(' ')
                                      .map((word) => word[0].toUpperCase() + word.substring(1))
                                      .join(' '),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDomains[index] = value;
                              });
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Sélection aléatoire'),
                  onPressed: () {
                    final random = Random();
                    final shuffled = List<String>.from(availableDomains)..shuffle(random);
                    setState(() {
                      for (int i = 0; i < selectedDomains.length; i++) {
                        selectedDomains[i] = shuffled[i % shuffled.length];
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton.extended(
                  onPressed: selectedDomains.every((d) => d != null)
                      ? () {
                          Navigator.pop(context, selectedDomains);
                        }
                      : null,
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('Valider les domaines'),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
