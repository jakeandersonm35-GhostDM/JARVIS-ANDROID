import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/settings_service.dart';

/// Connection manager for the private JARVIS backend and publishing services.
/// OAuth tokens are issued and stored by the backend, not in the app.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _settings = SettingsService.instance;
  late final TextEditingController _codeUrl;
  late final TextEditingController _codeKey;
  late final TextEditingController _videoUrl;

  @override
  void initState() {
    super.initState();
    _codeUrl = TextEditingController(text: _settings.codeBackendUrl);
    _codeKey = TextEditingController(text: _settings.codeBackendApiKey);
    _videoUrl = TextEditingController(text: _settings.videoBackendUrl);
  }

  @override
  void dispose() {
    _codeUrl.dispose();
    _codeKey.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _settings.setCodeBackendUrl(_codeUrl.text);
    await _settings.setCodeBackendApiKey(_codeKey.text);
    await _settings.setVideoBackendUrl(_videoUrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection settings saved')));
    }
  }

  Future<void> _connect(String path, String name) async {
    final base = _codeUrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the JARVIS backend URL first')));
      return;
    }
    final uri = Uri.tryParse('$base$path');
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $name connection')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connections')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('JARVIS backend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('This backend runs code jobs, renders media, handles OAuth, and sends notifications. Keep tokens on the server.'),
          const SizedBox(height: 12),
          TextField(controller: _codeUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Code/backend URL', hintText: 'https://jarvis.example.com')),
          const SizedBox(height: 10),
          TextField(controller: _codeKey, obscureText: true, decoration: const InputDecoration(labelText: 'Backend API key')),
          const SizedBox(height: 10),
          TextField(controller: _videoUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Video/render service URL', hintText: 'Optional; defaults to backend')),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save connections')),
          const SizedBox(height: 24),
          const Text('Email and publishing accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Connect through OAuth. JARVIS will ask before sending or publishing anything.'),
          const SizedBox(height: 12),
          _connectionTile(Icons.email_outlined, 'Gmail', 'Connect Gmail OAuth', '/oauth/gmail/start'),
          _connectionTile(Icons.mail_outline, 'Outlook', 'Connect Outlook OAuth', '/oauth/outlook/start'),
          _connectionTile(Icons.play_circle_outline, 'YouTube', 'Connect YouTube channel', '/oauth/youtube/start'),
          _connectionTile(Icons.camera_alt_outlined, 'Instagram', 'Connect Instagram Professional account', '/oauth/instagram/start'),
          _connectionTile(Icons.facebook, 'Facebook', 'Connect Facebook Page', '/oauth/facebook/start'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Safety lock: account connections do not grant permission to send or publish. Each email, upload, post, attachment, and recipient still requires your approval.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionTile(IconData icon, String title, String subtitle, String path) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: OutlinedButton(onPressed: () => _connect(path, title), child: const Text('Connect')),
        ),
      );
}
