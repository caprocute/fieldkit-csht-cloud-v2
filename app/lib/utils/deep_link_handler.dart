import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/settings/pdf_viewer.dart';

// Handles deep links to the PDF viewer or external URLs
void navigateToPdfSection(BuildContext context, String url) {
  try {
    Loggers.ui.i("Processing URL: $url");

    // Handle custom fieldkit scheme URLs
    if (url.startsWith("fieldkit/")) {
      final parts = url.split('/');
      if (parts.length >= 2) {
        String? searchQuery;
        if (parts[1] == "search" && parts.length >= 3) {
          searchQuery = parts[2];
          Loggers.ui.i("Found search query: $searchQuery");
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfViewerPage(initialPage: null, searchQuery: searchQuery),
          ),
        );
        return;
      }
    }

    // Handle standard URLs
    final Uri uri = Uri.parse(url);
    if (uri.scheme == "http" || uri.scheme == "https") {
      launchUrl(uri).then((success) {
        if (!success) {
          Loggers.ui.e("Could not launch URL: $url");
        }
      });
    } else {
      // For any other non-standard URL, try to open PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const PdfViewerPage(initialPage: null, searchQuery: null),
        ),
      );
    }
  } catch (e) {
    Loggers.ui.e("Error handling link: $e");
    // Fallback - just open the PDF viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PdfViewerPage(initialPage: null, searchQuery: null),
      ),
    );
  }
}
