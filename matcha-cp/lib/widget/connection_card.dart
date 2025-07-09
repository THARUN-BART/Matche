import 'package:flutter/material.dart';

class ConnectionCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isConnected;
  final bool hasSentRequest;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final Future<bool> Function()? onConnect;
  final Future<bool> Function()? onResend;
  final bool isLoading;

  const ConnectionCard({
    super.key,
    required this.user,
    this.isConnected = false,
    this.hasSentRequest = false,
    this.onTap,
    this.onMessage,
    this.onConnect,
    this.onResend,
    this.isLoading = false,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  late bool _isConnected;
  late bool _hasSentRequest;
  bool _isButtonLoading = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _hasSentRequest = widget.hasSentRequest;
  }

  @override
  void didUpdateWidget(ConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isConnected != widget.isConnected) {
      _isConnected = widget.isConnected;
    }
    if (oldWidget.hasSentRequest != widget.hasSentRequest) {
      _hasSentRequest = widget.hasSentRequest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = (widget.user['name'] is String && (widget.user['name'] as String).isNotEmpty)
        ? widget.user['name']
        : 'Unknown';
    final String? avatarUrl = (widget.user['avatarUrl'] is String && (widget.user['avatarUrl'] as String).isNotEmpty)
        ? widget.user['avatarUrl']
        : null;
    final String subtitle = (widget.user['bio'] is String && widget.user['bio'].toString().isNotEmpty)
        ? widget.user['bio']
        : (widget.user['email'] is String ? widget.user['email'] : '');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isLoading
          ? _buildSkeleton()
          : Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? Text(name[0].toUpperCase()) : null,
                  radius: 26,
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: widget.onTap,
                trailing: _buildTrailingWidget(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
    );
  }

  Widget _buildTrailingWidget() {
    if (_isConnected) {
      return IconButton(
        icon: const Icon(Icons.message, color: Colors.deepPurple),
        onPressed: widget.onMessage,
        tooltip: 'Message',
      );
    } else if (_hasSentRequest) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: ElevatedButton.icon(
          key: const ValueKey('requested'),
          onPressed: null,
          icon: const Icon(Icons.hourglass_top, size: 18),
          label: const Text('Requested'),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Colors.grey[400],
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    } else if (widget.onResend != null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isButtonLoading
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton.icon(
                key: const ValueKey('resend'),
                onPressed: () async {
                  setState(() => _isButtonLoading = true);
                  final result = await widget.onResend!();
                  setState(() {
                    _hasSentRequest = result;
                    _isButtonLoading = false;
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Resend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
      );
    } else {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isButtonLoading
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton.icon(
                key: const ValueKey('connect'),
                onPressed: () async {
                  setState(() => _isButtonLoading = true);
                  final result = await widget.onConnect?.call();
                  setState(() {
                    _hasSentRequest = result ?? true;
                    _isButtonLoading = false;
                  });
                },
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
      );
    }
  }

  Widget _buildSkeleton() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        title: Container(
          width: 80,
          height: 16,
          color: Colors.grey[300],
        ),
        subtitle: Container(
          width: 120,
          height: 12,
          color: Colors.grey[200],
        ),
        trailing: Container(
          width: 80,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
