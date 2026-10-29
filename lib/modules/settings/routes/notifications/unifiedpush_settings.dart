import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunasea/core/services/unifiedpush_service.dart';

class UnifiedPushSettingsRoute extends StatefulWidget {
  const UnifiedPushSettingsRoute({Key? key}) : super(key: key);

  @override
  State<UnifiedPushSettingsRoute> createState() => _UnifiedPushSettingsRouteState();
}

class _UnifiedPushSettingsRouteState extends State<UnifiedPushSettingsRoute> {
  final UnifiedPushService _upService = UnifiedPushService();
  List<String> _distributors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshDistributors();
  }

  Future<void> _refreshDistributors() async {
    setState(() => _isLoading = true);
    final list = await _upService.getDistributors();
    setState(() {
      _distributors = list;
      _isLoading = false;
    });
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      await _upService.registerApp();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered with UnifiedPush!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unregister() async {
    setState(() => _isLoading = true);
    await _upService.unregisterApp();
    setState(() => _isLoading = false);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endpoint copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endpoint = _upService.endpoint;
    final isRegistered = _upService.isRegistered;
    final distributor = _upService.distributor ?? (_distributors.isNotEmpty ? _distributors.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UnifiedPush Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDistributors,
            tooltip: 'Refresh Distributors',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Status Overview Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isRegistered ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: isRegistered ? Colors.green : Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRegistered ? 'Push Active (Zero-Server)' : 'Push Inactive',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              distributor != null ? 'Distributor: $distributor' : 'No distributor detected',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (!isRegistered) ...[
                    const Text(
                      'UnifiedPush allows Radarr and Sonarr to notify you directly without needing a self-hosted relay or Firebase.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_done),
                        label: const Text('Register with Distributor'),
                        onPressed: _isLoading ? null : _register,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Your Webhook Endpoint URL:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              endpoint ?? 'Pending...',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: endpoint != null ? () => _copyToClipboard(endpoint) : null,
                            tooltip: 'Copy Endpoint',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _unregister,
                            child: const Text('Unregister'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Radarr / Sonarr Connection Instructions
          const Text(
            'How to connect Radarr & Sonarr',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(child: Text('1')),
            title: const Text('Copy Endpoint'),
            subtitle: const Text('Copy the endpoint URL shown above.'),
          ),
          ListTile(
            leading: const CircleAvatar(child: Text('2')),
            title: const Text('Open Settings > Connect'),
            subtitle: const Text('In Radarr or Sonarr web UI, add a new "Webhook" connection.'),
          ),
          ListTile(
            leading: const CircleAvatar(child: Text('3')),
            title: const Text('Paste URL & Test'),
            subtitle: const Text('Paste into URL field, check "On Grab" & "On Download", then click Test.'),
          ),
        ],
      ),
    );
  }
}

