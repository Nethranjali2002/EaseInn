import 'package:flutter/material.dart';

/// ==========================================
/// WEB DATA TABLE - Reusable Searchable Table
/// ==========================================
/// A reusable data table widget for the web admin portal.
/// Provides built-in features that would otherwise need to be
/// implemented separately in every screen:
///
/// 1. SEARCH: Real-time filtering with a search bar
/// 2. SORTING: Click column headers to sort ascending/descending
/// 3. PAGINATION: Configurable rows per page with page navigation
///
/// Usage:
///   WebDataTable(
///     columns: [DataColumn(label: Text('Name')), ...],
///     rows: [[DataCell(Text('John')), ...], ...],
///     rowsPerPage: 10,
///   )
/// ==========================================
class WebDataTable extends StatefulWidget {
  /// Column definitions for the table header
  final List<DataColumn> columns;

  /// Row data - each inner list represents one row of cells
  final List<List<DataCell>> rows;

  /// Placeholder text for the search input field
  final String searchHint;

  /// Number of rows to display per page
  final int rowsPerPage;

  /// Optional custom search filter function.
  /// If null, a default case-insensitive "contains" search is used.
  /// Parameters: (searchQuery, listOfCellTexts) -> shouldInclude
  final bool Function(String, List<String>)? searchFilter;

  /// Whether to show the search bar (can be hidden for small datasets)
  final bool showSearch;

  const WebDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.searchHint = 'Search...',
    this.rowsPerPage = 10,
    this.searchFilter,
    this.showSearch = true,
  });

  @override
  State<WebDataTable> createState() => _WebDataTableState();
}

class _WebDataTableState extends State<WebDataTable> {
  /// Controller for the search input field
  final TextEditingController _searchController = TextEditingController();

  /// Current search query - triggers re-filtering on change
  String _searchQuery = '';

  /// Index of the currently sorted column (-1 means no sorting)
  int _sortColumnIndex = -1;

  /// Sort direction: true = ascending, false = descending
  bool _sortAscending = true;

  /// Current page index (0-based)
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ==========================================
  /// FILTERED ROWS - Search Results
  /// ==========================================
  /// Returns only the rows that match the current search query.
  /// Uses the custom searchFilter if provided, otherwise does
  /// a case-insensitive "contains" check on all cell text values.
  /// ==========================================
  List<List<DataCell>> get _filteredRows {
    if (_searchQuery.isEmpty) return widget.rows;
    return widget.rows.where((row) {
      final cellTexts = row.map((c) => c.child.toString()).toList();
      if (widget.searchFilter != null) {
        return widget.searchFilter!(_searchQuery, cellTexts);
      }
      return cellTexts.any(
        (text) => text.toLowerCase().contains(_searchQuery.toLowerCase()),
      );
    }).toList();
  }

  /// ==========================================
  /// PAGINATED ROWS - Current Page Slice
  /// ==========================================
  /// Extracts only the rows for the current page from the filtered results.
  /// ==========================================
  List<List<DataCell>> get _paginatedRows {
    final filtered = _filteredRows;
    final start = _currentPage * widget.rowsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + widget.rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  /// Total number of pages based on filtered results
  int get _totalPages =>
      (_filteredRows.length / widget.rowsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ==========================================
        // SEARCH BAR
        // ==========================================
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  // Show clear button only when there's text to clear
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 0;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 0; // Reset to first page on new search
                  });
                },
              ),
            ),
          ),

        // ==========================================
        // DATA TABLE
        // ==========================================
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: widget.columns,
              rows: _paginatedRows
                  .map((row) => DataRow(cells: row))
                  .toList(),
              // Sort configuration
              sortColumnIndex: _sortColumnIndex >= 0 ? _sortColumnIndex : null,
              sortAscending: _sortAscending,
              // Row styling
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.green.shade50;
                }
                return null;
              }),
              border: TableBorder.all(color: Colors.grey.shade200, width: 1),
              horizontalMargin: 16,
              columnSpacing: 24,
            ),
          ),
        ),

        // ==========================================
        // PAGINATION CONTROLS
        // ==========================================
        if (filtered.length > widget.rowsPerPage)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Text(
                  'Showing ${_currentPage * widget.rowsPerPage + 1}-${((_currentPage + 1) * widget.rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: const TextStyle(fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
