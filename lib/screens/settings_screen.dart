import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme_notifier.dart';
import 'about_screen.dart';
import 'etude_questions.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'proposition_question_screen.dart';
import 'questions_selection_screen.dart';
import 'signalements_questions_screen.dart';

class SettingsScreen extends StatefulWidget {
  final User user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  bool _incognito = false;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('incognito')) {
      _incognito = doc.data()!['incognito'] == true;
    }
    final prefs = await SharedPreferences.getInstance();
    _notifications = prefs.getBool('notifications_enabled') ?? true;
    setState(() {});
  }

  Future<void> _toggleIncognito(bool value) async {
    setState(() => _incognito = value);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .update({'incognito': value, 'online': !value});
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notifications = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (value) {
      await NotificationService.init();
    } else {
      await NotificationService.disable();
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final uid = widget.user.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await widget.user.delete();
        await _auth.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
            (_) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de la suppression.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Compte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Mode incognito'),
            value: _incognito,
            onChanged: _toggleIncognito,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Déconnexion'),
            onTap: _logout,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Supprimer mon compte'),
            onTap: _deleteAccount,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Application',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            value: _notifications,
            onChanged: _toggleNotifications,
          ),
          SwitchListTile(
            title: const Text('Thème sombre'),
            value: ThemeNotifier.theme.value == ThemeMode.dark,
            onChanged: (v) => ThemeNotifier.setDark(v),
          ),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.orangeAccent),
            title: const Text('Mes favoris'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aide',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: Colors.blueAccent),
            title: const Text('Étude des questions'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EtudeQuestionsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: const Text('Proposer une question'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PropositionQuestionScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          if (widget.user.email == 'pacman93@gmail.com' ||
              widget.user.email == 'alexandrejordan84@gmail.com' ||
              widget.user.email == 'dev.msj2025@gmail.com') ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Administration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded,
                  color: Colors.deepOrange),
              title: const Text('Voir les signalements'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SignalementsQuestionsScreen())),
            ),
            ListTile(
              leading:
                  const Icon(Icons.lightbulb_outline, color: Colors.purple),
              title: const Text('Voir les propositions'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => QuestionsSelectionScreen())),
            ),
          ],
        ],
      ),
    );
  }
}
