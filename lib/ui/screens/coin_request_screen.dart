import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../../services/coin_request_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/space_background.dart';

class CoinRequestScreen extends StatefulWidget {
  const CoinRequestScreen({super.key});

  @override
  State<CoinRequestScreen> createState() => _CoinRequestScreenState();
}

class _CoinRequestScreenState extends State<CoinRequestScreen> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _message = TextEditingController();
  bool _submitting = false;
  String? _error;

  final List<int> _quickAmounts = <int>[100, 500, 1000, 5000, 10000, 50000];

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final int? amt = int.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }
    if (amt > 2000000) {
      setState(() => _error = 'Maximum request is 2,000,000 coins.');
      return;
    }

    final AuthService auth = AuthService.instance;
    if (!auth.isSignedIn) {
      setState(() => _error = 'You must be logged in to request coins.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final String? err = await CoinRequestService.instance.submitRequest(
      uid: auth.currentUser!.uid,
      email: auth.currentUser!.email ?? '',
      displayName:
          auth.currentUser!.displayName ?? auth.currentUser!.email ?? 'Player',
      amount: amt,
      message: _message.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      _amount.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! Admin will review it soon.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int myCoins = context.watch<PlayerController>().coins;
    final String uid = AuthService.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const Expanded(
                      child: Text(
                        'Request Coins',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Palette.coin.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Palette.coin.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.monetization_on,
                              color: Palette.coin, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _fmt(myCoins),
                            style: const TextStyle(
                                color: Palette.coin,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.info_outline,
                                color: Colors.blueAccent, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Request coins from the admin. '
                                'You will receive them after approval.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quick Select',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts.map((int n) {
                          final bool selected =
                              _amount.text == n.toString();
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _amount.text = n.toString()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Palette.coin.withOpacity(0.25)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? Palette.coin
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                _fmt(n),
                                style: TextStyle(
                                    color: selected
                                        ? Palette.coin
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Custom Amount',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Amount of coins',
                          labelStyle:
                              const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.monetization_on,
                              color: Palette.coin, size: 20),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Palette.coin, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _message,
                        maxLines: 3,
                        maxLength: 200,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Message (optional)',
                          labelStyle:
                              const TextStyle(color: Colors.white60),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          counterStyle:
                              const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Palette.nebulaPurple, width: 1.5),
                          ),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('Send Request',
                                  style: TextStyle(fontSize: 16)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.nebulaPurple,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // My past requests
                      const Text(
                        'My Requests',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (uid.isNotEmpty)
                        StreamBuilder<List<CoinRequest>>(
                          stream: CoinRequestService.instance
                              .listenMyRequests(uid),
                          builder: (BuildContext context,
                              AsyncSnapshot<List<CoinRequest>> snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final List<CoinRequest> list =
                                snap.data ?? <CoinRequest>[];
                            if (list.isEmpty) {
                              return const Text(
                                'No requests yet.',
                                style:
                                    TextStyle(color: Colors.white38),
                              );
                            }
                            return Column(
                              children: list
                                  .map((CoinRequest r) =>
                                      _MyRequestTile(request: r))
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request});
  final CoinRequest request;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Approved (+${_fmt(request.approvedAmount ?? request.requestedAmount)})';
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.pending;
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_fmt(request.requestedAmount)} coins requested',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (request.message.isNotEmpty)
                  Text(request.message,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (request.status == 'rejected' &&
                    request.adminNote != null &&
                    request.adminNote!.isNotEmpty)
                  Text('Reason: ${request.adminNote}',
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}
