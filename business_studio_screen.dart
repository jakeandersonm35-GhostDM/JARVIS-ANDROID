import 'package:flutter/material.dart';

import '../../services/ai_service.dart';

/// Business builder and approval-gated outreach workspace.
class BusinessStudioScreen extends StatefulWidget {
  const BusinessStudioScreen({super.key});

  @override
  State<BusinessStudioScreen> createState() => _BusinessStudioScreenState();
}

class _BusinessStudioScreenState extends State<BusinessStudioScreen> {
  final _idea = TextEditingController();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _attachments = TextEditingController();
  String _draft = '';
  String? _error;
  bool _working = false;
  String _mailProvider = 'Gmail';

  @override
  void dispose() {
    _idea.dispose();
    _company.dispose();
    _contact.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<void> _buildBusiness() async {
    if (_idea.text.trim().isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final prompt = '''Act as JARVIS business strategist. Build a practical small business around this idea:
${_idea.text.trim()}

Return:
1. Business model and target customer
2. 30-day launch plan
3. Product/service that can be built first
4. Documents and app/tools required
5. Ethical company outreach strategy
6. A concise outreach email draft

Do not claim to have contacted anyone or sent anything. Everything is a proposal awaiting the user's approval.''';
    try {
      final result = await AiService.instance.chat(message: prompt);
      if (mounted) setState(() => _draft = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestSendApproval() async {
    if (_draft.isEmpty || _company.text.trim().isEmpty || _contact.text.trim().isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve this email?'),
        content: Text(
          'JARVIS wants permission to send the reviewed draft to ${_company.text.trim()} at ${_contact.text.trim()} using $_mailProvider.\n\n'
          'Attachments: ${_attachments.text.trim().isEmpty ? 'none' : _attachments.text.trim()}\n\n'
          'No email is sent without this approval.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve send')),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approval recorded. Connect Gmail or Outlook OAuth to send.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Business Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Build a business', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(controller: _idea, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Business idea or goal')),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _working ? null : _buildBusiness, icon: const Icon(Icons.rocket_launch_outlined), label: Text(_working ? 'Building plan…' : 'Build business plan')),
          ]))),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Company outreach', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('JARVIS drafts the message and attachments. You approve the exact send before anything leaves your account.'),
            const SizedBox(height: 12),
            TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company or recipient name')),
            const SizedBox(height: 10),
            TextField(controller: _contact, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Recipient email')),
            const SizedBox(height: 10),
            TextField(controller: _attachments, decoration: const InputDecoration(labelText: 'Attachments or app links', hintText: 'proposal.pdf, demo URL')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: _mailProvider, decoration: const InputDecoration(labelText: 'Email connection'), items: const [DropdownMenuItem(value: 'Gmail', child: Text('Gmail OAuth')), DropdownMenuItem(value: 'Outlook', child: Text('Outlook OAuth'))], onChanged: (value) => setState(() => _mailProvider = value ?? 'Gmail')),
          ]))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(color: theme.colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
          ],
          if (_draft.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Business and outreach draft', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(_draft))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _requestSendApproval, icon: const Icon(Icons.mark_email_read_outlined), label: const Text('Ask permission to send')),
          ],
        ],
      ),
    );
  }
}
