import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

class PdfViewerPage extends StatefulWidget {
  final String? initialPage;
  final String? searchQuery;

  const PdfViewerPage({super.key, this.initialPage, this.searchQuery});

  @override
  PdfViewerPageState createState() => PdfViewerPageState();
}

class PdfViewerPageState extends State<PdfViewerPage> {
  final controller = PdfViewerController();
  late final textSearcher = PdfTextSearcher(controller);
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final searchController = TextEditingController();
  bool isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinking();
    if (widget.initialPage != null) {
      _navigateToPage(widget.initialPage!);
    }
    if (widget.searchQuery != null) {
      Future.delayed(const Duration(seconds: 2), () {
        _searchContent(widget.searchQuery!);
      });
    }
  }

  Future<void> _initDeepLinking() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.pathSegments.isNotEmpty) {
        final type = uri.pathSegments[0];
        final value = uri.pathSegments[1];

        if (type == 'page') {
          _navigateToPage(value);
        } else if (type == 'search') {
          _searchContent(value);
        }
      }
    });
  }

  Future<void> _navigateToPage(String page) async {
    try {
      final pageNumber = int.parse(page);
      if (pageNumber > 0) {
        await controller.goToPage(pageNumber: pageNumber);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .errorNavigatingToPage(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _searchContent(String query) async {
    try {
      final decodedQuery = Uri.decodeComponent(query);
      textSearcher.startTextSearch(decodedQuery);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.errorSearching(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    textSearcher.removeListener(_onSearchUpdate);
    textSearcher.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      textSearcher.resetTextSearch();
    } else {
      textSearcher.startTextSearch(query, caseInsensitive: true);
    }
    setState(() {});
  }

  void _onSearchUpdate() {
    setState(() {});
  }

  void _toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (!isSearchVisible) {
        searchController.clear();
        textSearcher.resetTextSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final hasResults = textSearcher.hasMatches;
    final currentIndex = textSearcher.currentIndex ?? 0;
    final totalMatches = textSearcher.matches.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.offlineProductGuide),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSearchVisible)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: localizations.enterSearchTerm,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                          tooltip: localizations.search,
                          onPressed: hasResults
                              ? () => textSearcher.goToPrevMatch()
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          tooltip: localizations.search,
                          onPressed: hasResults
                              ? () => textSearcher.goToNextMatch()
                              : null,
                        ),
                        if (hasResults)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              '$currentIndex/$totalMatches',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: PdfViewer.asset(
              localizations.localeName == 'es'
                  ? 'resources/pdfs/2022_FieldKit-Product-Guide-Spanish-LatAm.pdf'
                  : 'resources/pdfs/2022_FieldKit-Product-Guide-English.pdf',
              controller: controller,
              params: PdfViewerParams(
                pagePaintCallbacks: [textSearcher.pageTextMatchPaintCallback],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
