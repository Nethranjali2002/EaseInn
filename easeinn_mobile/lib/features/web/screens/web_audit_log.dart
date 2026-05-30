import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/auth_provider.dart';

class WebAuditLogScreen extends ConsumerStatefulWidget {
  const WebAuditLogScreen({super.key});

  @override
  ConsumerState<WebAuditLogScreen> createState() => _WebAuditLogScreenState();
}

class _WebAuditLogScreenState extends ConsumerState<WebAuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/admin/audit-logs');
      final list = (res.data['data']['logs'] as List?) ?? [];
      setState(() {
        _logs = list.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audit Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Audit logs are recorded automatically', style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('Every create, update, delete, login, and payment action is logged',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (ctx, i) {
                            final log = _logs[i];
                            return ListTile(
                              leading: CircleAvatar(child: _iconForAction(log['action'] ?? '')),
                              title: Text(log['description'] ?? 'Unknown action'),
                              subtitle: Text('${log['entity'] ?? ''} • ${log['ip'] ?? ''}'),
                              trailing: Text(
                                log['createdAt'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(log['createdAt'])) : '',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconForAction(String action) {
    switch (action) {
      case 'create': return const Icon(Icons.add, size: 18);
      case 'update': return const Icon(Icons.edit, size: 18);
      case 'delete': return const Icon(Icons.delete, size: 18);
      case 'login': return const Icon(Icons.login, size: 18);
      case 'logout': return const Icon(Icons.logout, size: 18);
      case 'payment': return const Icon(Icons.payment, size: 18);
      case 'booking': return const Icon(Icons.book_online, size: 18);
      case 'task': return const Icon(Icons.task, size: 18);
      default: return const Icon(Icons.info, size: 18);
    }
  }
}
