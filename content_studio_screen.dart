import 'package:flutter/material.dart';

import '../../services/ai_service.dart';

enum _ContentType { socialPost, shortVideo }

/// Content creation workspace. Generation is allowed; publishing is always
/// approval-gated and requires a connected official platform account.
class ContentStudioScreen extends StatefulWidget {
  const ContentStudioScreen({super.key});

  @override
  State<ContentStudioScreen> createState() => _ContentStudioScreenState();
}

class _ContentStudioScreenState extends State<ContentStudioScreen> {
  final _idea = TextEditingController();
  final _ai = AiService.instance;
  _ContentType _type = _ContentType.shortVideo;
  final _platforms = <String>{'YouTube'};
  String _draft = '';
  String? _error;
  bool _generating = false;
  bool _approvalRequired = true;

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_idea.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    final kind = _type == _ContentType.shortVideo ? 'short video package' : 'social post';
    final prompt = '''Create a ${kind} for: ${_idea.text.trim()}

Target platforms: ${_platforms.join(', ')}

Return a practical production package with these headings:
TITLE
HOOK
SCRIPT
SCENES (include duration and visual direction)
CAPTION
HASHTAGS
THUMBNAIL BRIEF
SAFETY/COPYRIGHT CHECKS
Do not claim that anything was published. This is a draft awaiting the user's approval.''';
    try {
      final result = await _ai.chat(message: prompt);
      if (!mounted) return;
      setState(() => _draft = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _askToPublish() async {
    if (_draft.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve publishing?'),
        content: Text(
          'JARVIS wants permission to publish this exact draft to ${_platforms.join(', ')}.\n\n'
          'Nothing will be posted unless you approve it here. Connected official accounts and platform permissions are required.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve draft')),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approval recorded. Connect the platform OAuth accounts to publish.')),
    );
  }

  void _togglePlatform(String platform, bool value) {
    setState(() {
      if (value) {
        _platforms.add(platform);
      } else if (_platforms.length > 1) {
        _platforms.remove(platform);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Content Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Create content', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(controller: _idea, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'What should JARVIS create?', hintText: 'A 30-second video explaining my new project...')),
                const SizedBox(height: 12),
                SegmentedButton<_ContentType>(
                  segments: const [
                    ButtonSegment(value: _ContentType.shortVideo, label: Text('Video package'), icon: Icon(Icons.video_library_outlined)),
                    ButtonSegment(value: _ContentType.socialPost, label: Text('Social post'), icon: Icon(Icons.post_add_outlined)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (values) => setState(() => _type = values.first),
                ),
                const SizedBox(height: 12),
                const Text('Target platforms'),
                for (final platform in const ['YouTube', 'Instagram', 'Facebook'])
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(platform),
                    value: _platforms.contains(platform),
                    onChanged: (value) => _togglePlatform(platform, value ?? false),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ask before publishing'),
                  subtitle: const Text('Required safety lock; cannot be disabled.'),
                  value: _approvalRequired,
                  onChanged: (_) {},
                ),
                FilledButton.icon(onPressed: _generating ? null : _generate, icon: const Icon(Icons.auto_awesome), label: Text(_generating ? 'Creating…' : 'Create draft')),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(color: theme.colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
          ],
          if (_draft.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Draft preview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(_draft))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _askToPublish, icon: const Icon(Icons.verified_user_outlined), label: const Text('Ask permission to publish')),
          ],
        ],
      ),
    );
  }
}
