import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'nice_dialog.dart';

// ---------------------------------------------------------------------
// Shared "are you sure you want to leave the app?" confirmation for any
// tappable phone/website/email field (attraction/restaurant contact info,
// embassy, emergency numbers, ...). Before this, some of these fields
// jumped straight to the dialer/browser/mail app on a single tap with no
// confirmation at all, and others (attraction's phone/website) weren't
// even tappable — this gives every one of them the same
// "tap -> confirm -> jump" behaviour instead.
// ---------------------------------------------------------------------
enum ContactAction { call, website, email }

Future<void> confirmAndLaunch(BuildContext context, ContactAction action, String value) async {
  if (value.trim().isEmpty) return;
  final (title, confirmLabel, icon) = switch (action) {
    ContactAction.call => ('Call this number?', 'Call', Icons.call_outlined),
    ContactAction.website => ('Open this website?', 'Open', Icons.language_outlined),
    ContactAction.email => ('Send an email?', 'Email', Icons.email_outlined),
  };
  final confirmed = await showNiceConfirmDialog(
    context: context,
    title: title,
    message: value,
    confirmLabel: confirmLabel,
    icon: icon,
  );
  if (!confirmed || !context.mounted) return;
  final uri = switch (action) {
    ContactAction.call => Uri(scheme: 'tel', path: value),
    ContactAction.email => Uri(scheme: 'mailto', path: value),
    ContactAction.website => Uri.parse(value.startsWith('http') ? value : 'https://$value'),
  };
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that")));
  }
}
