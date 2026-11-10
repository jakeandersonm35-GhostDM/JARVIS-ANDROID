import 'package:flutter/material.dart';

import '../../services/code_workspace_service.dart';

/// Separate, approval-gated development panel for JARVIS.
class CodePanelScreen extends StatefulWidget {
  const CodePanelScreen({super.key});

  @override
  State<CodePanelScreen> createState() => _CodePanelScreenState();
}

class _CodePanelScreenState extends State<CodePanelScreen> {
  final _workspace = CodeWorkspaceService.instance;
  final _project = TextEditingController();
  final _request = TextEditingController();
  List<CodeJob> _jobs = const [];
  List<CodeProposal> _proposals = const [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _project.dispose();
    _request.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_workspace.jobs(), _workspace.proposals()]);
      if (!mounted) return;
      setState(() {
        _jobs = results[0] as List<CodeJob>;
        _proposals = results[1] as List<CodeProposal>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Code workspace unavailable. Configure the JARVIS server first.';
      });
    }
  }

  Future<void> _requestReview() async {
    if (_project.text.trim().isEmpty || _request.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _workspace.requestReview(
        project: _project.text.trim(),
        request: _request.text.trim(),
      );
      _request.clear();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runTests() async {
    if (_project.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _workspace.runTests(_project.text.trim());
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decision(CodeProposal proposal, bool approve) async {
    final action = approve ? 'approve' : 'reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${approve ? 'Approve' : 'Reject'} change?'),
        content: Text(approve
            ? 'JARVIS will apply this proposed code change and record a backup.'
            : 'This proposal will be discarded without changing your code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (approve) {
        await _workspace.approve(proposal.id);
      } else {
        await _workspace.reject(proposal.id);
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _showDiff(CodeProposal proposal) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(proposal.title),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(
              proposal.diff.isEmpty ? 'No diff returned.' : proposal.diff,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('JARVIS Code Panel'),
        actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Approval gate', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('JARVIS may inspect and test code automatically. Additions, removals, and fixes require your approval.'),
                  const SizedBox(height: 14),
                  TextField(controller: _project, decoration: const InputDecoration(labelText: 'Project name', hintText: 'my-app')),
                  const SizedBox(height: 10),
                  TextField(controller: _request, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Review or change request', hintText: 'Find errors, run tests, and propose a fix...')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(onPressed: _loading ? null : _requestReview, icon: const Icon(Icons.rate_review_outlined), label: const Text('Review & propose')),
                    OutlinedButton.icon(onPressed: _loading ? null : _runTests, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Run tests')),
                  ]),
                ]),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(color: theme.colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
            ],
            const SizedBox(height: 18),
            Text('Pending approvals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_proposals.isEmpty) const Text('No pending code changes.'),
            for (final proposal in _proposals.where((item) => item.status == 'pending')) _proposalCard(proposal),
            const SizedBox(height: 18),
            Text('Recent jobs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_jobs.isEmpty) const Text('No code jobs yet.'),
            for (final job in _jobs) _jobCard(job),
          ],
        ),
      ),
    );
  }

  Widget _proposalCard(CodeProposal proposal) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(proposal.title, style: const TextStyle(fontWeight: FontWeight.w700))), Chip(label: Text(proposal.risk))]),
            if (proposal.description.isNotEmpty) Text(proposal.description),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => _showDiff(proposal), child: const Text('View diff')),
              FilledButton(onPressed: () => _decision(proposal, true), child: const Text('Approve')),
              TextButton(onPressed: () => _decision(proposal, false), child: const Text('Reject')),
            ]),
          ]),
        ),
      );

  Widget _jobCard(CodeJob job) => Card(
        child: ListTile(
          leading: Icon(job.status == 'succeeded' ? Icons.check_circle : Icons.build_circle_outlined),
          title: Text('${job.project} · ${job.status}'),
          subtitle: Text(job.summary.isEmpty ? job.id : job.summary),
          isThreeLine: job.summary.isNotEmpty,
        ),
      );
}
