import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MatchCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<bool> Function()? onConnect;
  final VoidCallback onChat;
  final bool isConnected;
  final bool hasSentRequest;
  final bool isLoading;

  const MatchCard({
    super.key,
    required this.user,
    required this.onConnect,
    required this.onChat,
    this.isConnected = false,
    this.hasSentRequest = false,
    this.isLoading = false,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
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
  void didUpdateWidget(MatchCard oldWidget) {
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
    if (widget.isLoading) {
      return _buildSkeleton();
    }
    final name = widget.user['name'] ?? 'Unknown';
    final matchScore = widget.user['matchScore'] ?? 0;
    final skills = (widget.user['skills'] as List<dynamic>?)?.join(', ') ?? '';
    final gender = widget.user['gender'] ?? 'NONE';
    final interests = (widget.user['interests'] as List<dynamic>?)?.join(', ') ?? 'NONE';
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepPurple[100],
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$matchScore% Match',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Skills: $skills',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Gender: $gender',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Interests: $interests',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _isConnected
                            ? ElevatedButton.icon(
                                key: const ValueKey('chat'),
                                onPressed: widget.onChat,
                                icon: const Icon(Icons.chat, size: 18),
                                label: const Text('Chat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              )
                            : _hasSentRequest
                                ? ElevatedButton.icon(
                                    key: const ValueKey('requested'),
                                    onPressed: null,
                                    icon: const Icon(Icons.hourglass_top, size: 18),
                                    label: const Text('Requested'),
                                    style: ElevatedButton.styleFrom(
                                      disabledBackgroundColor: Colors.grey[400],
                                      disabledForegroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  )
                                : _isButtonLoading
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
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 12,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}