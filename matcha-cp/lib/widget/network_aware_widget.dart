import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../screen/no_internet_screen.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  bool _isOffline = false;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none);

      if (_isOffline != isOffline && mounted) {
        setState(() => _isOffline = isOffline);
      }
    });

    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    final isOffline = result == ConnectivityResult.none;
    if (_isOffline != isOffline && mounted) {
      setState(() => _isOffline = isOffline);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isOffline ? const NoInternetScreen() : widget.child;
  }
}
