import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme.dart';

/// Opens PayPal's (sandbox) approval page for one order inside the app.
/// PayPal's web checkout flow always needs a return_url/cancel_url to send
/// the browser back to once the payer approves or cancels; since a WebView
/// can't host a real HTTPS endpoint, the Cloud Function (functions/paypal.js)
/// uses the custom scheme voyaapp://paypal-return / voyaapp://paypal-cancel
/// instead, and this page's NavigationDelegate intercepts them before the
/// WebView ever actually tries (and fails) to load an unknown scheme.
///
/// Pops `true` if the traveller approved (PayPal bounced to the return
/// scheme), `false` on cancel or on closing the sheet manually -- the caller
/// (PayPalService.payWithPayPal) still has to call captureOrder itself:
/// approval alone does not move any money.
class PayPalCheckoutPage extends StatefulWidget {
  final String approveUrl;
  const PayPalCheckoutPage({super.key, required this.approveUrl});

  @override
  State<PayPalCheckoutPage> createState() => _PayPalCheckoutPageState();
}

class _PayPalCheckoutPageState extends State<PayPalCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('voyaapp://paypal-return')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('voyaapp://paypal-cancel')) {
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approveUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.navy),
          title: const Text(
            'PayPal',
            style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
