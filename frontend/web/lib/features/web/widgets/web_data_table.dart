import 'package:flutter/material.dart';

class WebDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<List<DataCell>> rows;
  final String searchHint;
  final int rowsPerPage;
  final bool Function(String, List<String>)? searchFilter;
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _sortColumnIndex = -1;
  bool _sortAscending = true;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  List<List<DataCell>> get _paginatedRows {
    final filtered = _filteredRows;
    final start = _currentPage * widget.rowsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + widget.rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredRows.length / widget.rowsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    _currentPage = 0;
                  });
                },
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: widget.columns.length > 1
                        ? ((constraints.maxWidth - 48) / widget.columns.length).clamp(16.0, 160.0)
                        : 24.0,
                    columns: widget.columns.asMap().entries.map((entry) {
                      final col = entry.value;
                      return DataColumn(
                        label: col.label,
                        numeric: col.numeric,
                        onSort: col.onSort != null
                            ? (index, ascending) {
                                setState(() {
                                  _sortColumnIndex = index;
                                  _sortAscending = ascending;
                                });
                              }
                            : null,
                      );
                    }).toList(),
                    rows: _paginatedRows
                        .map((cells) => DataRow(cells: cells))
                        .toList(),
                    sortColumnIndex:
                        _sortColumnIndex >= 0 ? _sortColumnIndex : null,
                    sortAscending: _sortAscending,
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade50),
                    dataRowColor:
                        WidgetStateProperty.all(Colors.white),
                    border: TableBorder(
                      horizontalInside:
                          BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing ${filtered.isEmpty ? 0 : _currentPage * widget.rowsPerPage + 1}-${((_currentPage + 1) * widget.rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  '${_currentPage + 1} / ${_totalPages == 0 ? 1 : _totalPages}',
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
          ],
        ),
      ],
    );
  }
}
