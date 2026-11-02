import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openDirections(BuildContext context, double lat, double lon) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lon',
  });
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps")));
  }
}
