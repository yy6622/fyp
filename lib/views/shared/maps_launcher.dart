import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------
// Opens turn-by-turn directions to a real lat/lon in Google Maps — the
// "Get Directions" button on Near By's place cards and detail page.
// Uses Google's own cross-platform "Maps URLs" scheme
// (google.com/maps/dir/?api=1&destination=...), not the paid Maps/
// Directions API: this is a plain link, so it works with no API key,
// opening the Google Maps app when it's installed or Google Maps in the
// browser otherwise, exactly like tapping a Google Maps link anywhere
// else would.
// ---------------------------------------------------------------------
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
