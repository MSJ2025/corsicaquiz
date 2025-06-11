import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class PropositionQuestionScreen extends StatefulWidget {
  const PropositionQuestionScreen({Key? key}) : super(key: key);

  @override
  State<PropositionQuestionScreen> createState() => _PropositionQuestionScreenState();
}

class _PropositionQuestionScreenState extends State<PropositionQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _categorie;
  String? _question;
  String? _explication;
  String? _difficulte;
  String? _imageUrl;

  final List<String> _categoriesDisponibles = [
    'Personnalités de la Corse',
    'Culture Corse',
    'Faune et Flore',
    'Histoire de la Corse'
  ];

  List<Map<String, dynamic>> _reponses = [
    {'texte': '', 'correct': true},
    {'texte': '', 'correct': false},
    {'texte': '', 'correct': false},
    {'texte': '', 'correct': false},
  ];

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();
      final data = {
        'categorie': _categorie,
        'question': _question,
        'reponses': _reponses,
        'explication': _explication,
        'difficulte': _difficulte,
        'image': _imageUrl,
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('propositions_questions').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question envoyée avec succès !')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildReponseField(int index) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Card(
        key: ValueKey<bool>(_reponses[index]['correct']),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: () {
            setState(() {
              for (var i = 0; i < _reponses.length; i++) {
                _reponses[i]['correct'] = i == index;
              }
            });
          },
          child: Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Réponse ${index + 1}',
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onSaved: (val) => _reponses[index]['texte'] = val ?? '',
                      validator: (val) => val == null || val.isEmpty ? 'Champ requis' : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _reponses[index]['correct'] ? Colors.greenAccent : Colors.grey[300],
                    ),
                    child: Icon(
                      _reponses[index]['correct'] ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _reponses[index]['correct'] ? Colors.white : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposer une question'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 1),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: const Text(
                              'Proposer une question',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Catégorie', icon: Icon(Icons.storage_outlined)),
                          items: _categoriesDisponibles.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat, style: TextStyle(color: Colors.black87)),
                          )).toList(),
                          onChanged: (val) => setState(() => _categorie = val),
                          validator: (val) => val == null ? 'Sélectionnez une catégorie' : null,
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Question'),
                          onSaved: (val) => _question = val,
                          validator: (val) => val == null || val.isEmpty ? 'Champ requis' : null,
                        ),
                      ),
                      ...List.generate(4, _buildReponseField),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Explication'),
                          onSaved: (val) => _explication = val,
                          validator: (val) => val == null || val.isEmpty ? 'Champ requis' : null,
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Difficulté', icon: Icon(Icons.star)),
                          items: const [
                            DropdownMenuItem(value: 'Facile', child: Text('Facile')),
                            DropdownMenuItem(value: 'Moyen', child: Text('Moyen')),
                            DropdownMenuItem(value: 'Difficile', child: Text('Difficile')),
                          ],
                          onChanged: (val) => _difficulte = val,
                          validator: (val) => val == null ? 'Sélectionnez une difficulté' : null,
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Lien vers une image (facultatif)'),
                          onSaved: (val) => _imageUrl = val?.isEmpty == true ? null : val,
                        ),
                      ),
                      if (_imageUrl != null && _imageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imageUrl!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Text(
                                'Prévisualisation non disponible.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Envoyer'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            elevation: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
