import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../../services/coin_request_service.dart';
import '../../systems/player_controller.dart';
import '../../services/cloud_save_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _tab = 0; // 0 = requests, 1 = send

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A),
        foregroundColor: Colors.white,
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: <Widget>[
              _TabChip(
                label: 'Requests',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _TabChip(
                label: 'Send Coins',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AdminBalance(),
          ),
        ],
      ),
      body: _tab == 0 ? const _RequestsTab() : const _SendTab(),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin balance chip shown in AppBar
// ---------------------------------------------------------------------------

class _AdminBalance extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final int coins = context.watch<PlayerController>().coins;
    return Row(
      children: <Widget>[
        const Icon(Icons.monetization_on, color: Palette.coin, size: 18),
        const SizedBox(width: 4),
        Text(
          _fmt(coins),
          style: const TextStyle(
              color: Palette.coin, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Pending coin requests
// ---------------------------------------------------------------------------

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Only the admin account can manage requests.',
            style: TextStyle(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<List<CoinRequest>>(
      stream: CoinRequestService.instance.listenPendingRequests(),
      builder:
          (BuildContext context, AsyncSnapshot<List<CoinRequest>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }
        final List<CoinRequest> requests = snap.data ?? <CoinRequest>[];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text('No pending requests',
                    style: TextStyle(color: Colors.white60, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (BuildContext ctx, int i) =>
              _RequestCard(request: requests[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.request});
  final CoinRequest request;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _processing = false;

  Future<void> _approve() async {
    final TextEditingController amtCtrl = TextEditingController(
        text: widget.request.requestedAmount.toString());

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Approve Request',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
                'Sending to: ${widget.request.displayName}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Coins to send',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.green),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final int amount = int.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _processing = true);
    final String? err = await CoinRequestService.instance.approveRequest(
      requestId: widget.request.id,
      targetUid: widget.request.uid,
      coinsToSend: amount,
      adminUid: AuthService.instance.currentUser!.uid,
    );
    if (!mounted) return;
    setState(() => _processing = false);

    // Refresh admin's local coin balance from cloud
    if (err == null) {
      _syncAdminBalance(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sent $amount coins to ${widget.request.displayName}'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject() async {
    final TextEditingController noteCtrl = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Reject Request',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Reason (optional)',
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    final String? err = await CoinRequestService.instance.rejectRequest(
      requestId: widget.request.id,
      adminNote: noteCtrl.text,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoinRequest r = widget.request;
    return Card(
      color: const Color(0xFF1A1A3A),
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Palette.nebulaPurple,
                  child: Text(
                    r.displayName.isNotEmpty
                        ? r.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(r.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(r.email,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Palette.coin.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Palette.coin.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.monetization_on,
                          color: Palette.coin, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _fmt(r.requestedAmount),
                        style: const TextStyle(
                            color: Palette.coin,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (r.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r.message,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _timeAgo(r.createdAt),
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
            if (_processing)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Send coins directly
// ---------------------------------------------------------------------------

class _SendTab extends StatefulWidget {
  const _SendTab();

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!AuthService.instance.isAdmin) {
      setState(() => _error = 'Only admin can send coins.');
      return;
    }
    final int? amt = int.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter the recipient email.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final String? targetUid =
        await CoinRequestService.instance.findUidByEmail(_email.text);
    if (!mounted) return;

    if (targetUid == null) {
      setState(() {
        _loading = false;
        _error = 'No account found with email: ${_email.text.trim()}';
      });
      return;
    }

    final String? err =
        await CoinRequestService.instance.sendCoinsToUser(
      targetUid: targetUid,
      amount: amt,
      adminUid: AuthService.instance.currentUser!.uid,
    );
    if (!mounted) return;

    if (err == null) {
      _syncAdminBalance(context);
      setState(() {
        _loading = false;
        _success = 'Sent $amt coins to ${_email.text.trim()}';
        _email.clear();
        _amount.clear();
      });
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Send Coins to Player',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the player\'s email address and the amount of coins to send.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Player Email', Icons.email_outlined),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
                'Amount', Icons.monetization_on_outlined),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_success != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_success!,
                style: const TextStyle(color: Colors.greenAccent)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _send,
              icon: const Icon(Icons.send),
              label: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Coins',
                      style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.coin,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            'Admin Account',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            AuthService.instance.currentUser?.email ?? '—',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'UID: ${AuthService.instance.currentUser?.uid ?? '—'}',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Palette.coin, width: 1.5),
        ),
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Palette.nebulaPurple
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
    );
  }
}

void _syncAdminBalance(BuildContext context) {
  final PlayerController player = context.read<PlayerController>();
  CloudSaveService.instance.pull().then((data) {
    if (data != null) player.mergeFromCloud(data);
  });
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

String _timeAgo(DateTime dt) {
  final Duration diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
