import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

class CodeJob {
  final String id;
  final String project;
  final String status;
  final String summary;
  final String log;

  const CodeJob({
    required this.id,
    required this.project,
    required this.status,
    this.summary = '',
    this.log = '',
  });

  factory CodeJob.fromJson(Map<String, dynamic> json) => CodeJob(
        id: '${json['id'] ?? ''}',
        project: '${json['project'] ?? 'unknown'}',
        status: '${json['status'] ?? 'unknown'}',
        summary: '${json['summary'] ?? ''}',
        log: '${json['log'] ?? ''}',
      );
}

class CodeProposal {
  final String id;
  final String title;
  final String description;
  final String diff;
  final String risk;
  final String status;

  const CodeProposal({
    required this.id,
    required this.title,
    required this.description,
    required this.diff,
    required this.risk,
    required this.status,
  });

  factory CodeProposal.fromJson(Map<String, dynamic> json) => CodeProposal(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Code change'}',
        description: '${json['description'] ?? ''}',
        diff: '${json['diff'] ?? ''}',
        risk: '${json['risk'] ?? 'unknown'}',
        status: '${json['status'] ?? 'pending'}',
      );
}

/// Client for the approval-gated JARVIS code workspace.
///
/// The workspace is deliberately separate from the chat API. JARVIS can
/// inspect and test code, but the server must return a proposal and the user
/// must approve it before any add/remove/edit operation is applied.
class CodeWorkspaceService {
  CodeWorkspaceService._();
  static final instance = CodeWorkspaceService._();

  SettingsService get _settings => SettingsService.instance;

  Uri get _origin {
    final uri = Uri.parse(_settings.codeBackendUrl.trim());
    final path = uri.path.replaceFirst(RegExp(r'/v1/?$'), '');
    return uri.replace(path: path.isEmpty ? '' : path);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_settings.codeBackendApiKey.isNotEmpty)
          'Authorization': 'Bearer ${_settings.codeBackendApiKey}',
      };

  Uri _endpoint(String path) => _origin.replace(
        path: '${_origin.path}$path'.replaceAll('//', '/'),
      );

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = _endpoint(path);
    final response = switch (method) {
      'GET' => await http.get(uri, headers: _headers),
      'POST' => await http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
      _ => throw StateError('Unsupported code workspace method: $method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Code workspace HTTP ${response.statusCode}: ${response.body}');
    }
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  Future<List<CodeJob>> jobs() async {
    final data = await _send('GET', '/code/jobs');
    final list = data is List ? data : (data['jobs'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => CodeJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<CodeProposal>> proposals() async {
    final data = await _send('GET', '/code/proposals');
    final list = data is List ? data : (data['proposals'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => CodeProposal.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> requestReview({required String project, required String request}) async {
    await _send('POST', '/code/review', {'project': project, 'request': request});
  }

  Future<void> runTests(String project) async {
    await _send('POST', '/code/test', {'project': project});
  }

  Future<void> approve(String proposalId) async {
    await _send('POST', '/code/proposals/$proposalId/approve');
  }

  Future<void> reject(String proposalId) async {
    await _send('POST', '/code/proposals/$proposalId/reject');
  }
}
