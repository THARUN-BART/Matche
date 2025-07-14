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
  final double? cardHeight;
  final VoidCallback? onAvatarTap;

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
    this.cardHeight,
    this.onAvatarTap,
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
        : (widget.user['username'] is String ? widget.user['username'] : '');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isLoading
          ? _buildSkeleton()
          : Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25),
          side: BorderSide(
          color: Color(0xFFFFEC3D),
          width: 1.2,
        ),
      ),
        margin: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: widget.cardHeight ?? 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: widget.onAvatarTap,
                  child: CircleAvatar(
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 24),
                    )
                        : null,
                    radius: 26,
                    backgroundColor: Color(0xFFFFEC3D),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                _buildTrailingWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingWidget() {
    if (_isConnected) {
      return IconButton(
        icon: const Icon(Icons.chat, color: Colors.white),
        onPressed: widget.onMessage,
        tooltip: 'Message',
      );
    } else if (_hasSentRequest) {
      return ElevatedButton.icon(
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
      );
    } else if (widget.onResend != null) {
      return _isButtonLoading
          ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
        icon: const Icon(Icons.refresh, size: 25, color: Colors.black),
        onPressed: () async {
          setState(() => _isButtonLoading = true);
          final result = await widget.onResend!();
          setState(() {
            _hasSentRequest = result;
            _isButtonLoading = false;
          });
        },
      );
    } else {
      return _isButtonLoading
          ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
        icon: const Icon(Icons.person_add_alt_1, size: 25, color: Colors.white),
        onPressed: () async {
          setState(() => _isButtonLoading = true);
          final result = await widget.onConnect?.call();
          setState(() {
            _hasSentRequest = result ?? true;
            _isButtonLoading = false;
          });
        },
      );
    }
  }

  Widget _buildSkeleton() {
    return Card(
      elevation: 3,
      color: const Color(0xFFFFEC3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: widget.cardHeight ?? 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 16, color: Colors.grey[300]),
                    const SizedBox(height: 6),
                    Container(width: 120, height: 12, color: Colors.grey[200]),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}