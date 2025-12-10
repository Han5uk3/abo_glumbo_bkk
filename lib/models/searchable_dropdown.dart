import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:abo_glumbo_bbk/utils/search_utils.dart';

class SearchableDropdown<T extends Object> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String hintText;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.hintText,
    this.validator,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T extends Object>
    extends State<SearchableDropdown<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showDropdown = false;
  List<T> _filteredItems = [];
  final int _maxItemsToShow = 50; // Limit to prevent crashes

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.itemLabel(widget.value!) : '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newText = widget.value != null
          ? widget.itemLabel(widget.value!)
          : '';
      if (_controller.text != newText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != newText) {
            _controller.text = newText;
          }
        });
      }
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _showDropdown) {
      // Delay hiding to allow tap on items
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _showDropdown = false;
          });
        }
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items.take(_maxItemsToShow).toList();
      } else {
        _filteredItems = widget.items
            .where(
              (item) =>
                  SearchUtils.matchesSearchQuery(widget.itemLabel(item), query),
            )
            .take(_maxItemsToShow)
            .toList();
      }
      _showDropdown = _filteredItems.isNotEmpty;
    });
  }

  void _selectItem(T item) {
    setState(() {
      _controller.text = widget.itemLabel(item);
      _showDropdown = false;
    });
    _focusNode.unfocus();
    widget.onChanged(item);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: DMSansFont.textStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Use Column instead of Stack to allow dropdown to push content down
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                            _showDropdown = false;
                          });
                          widget.onChanged(null);
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        _showDropdown
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                      ),
                      onPressed: () {
                        if (_showDropdown) {
                          setState(() {
                            _showDropdown = false;
                          });
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                          _filterItems(_controller.text);
                        }
                      },
                    ),
                  ],
                ),
              ),
              validator: (value) {
                if (_controller.text.isNotEmpty &&
                    (widget.value == null ||
                        _controller.text != widget.itemLabel(widget.value!))) {
                  return "${AppLocalizations.of(context)?.pleaseSelectAValid(widget.label)}";
                }
                return widget.validator?.call(widget.value);
              },
              onChanged: (text) {
                _filterItems(text);
                if (text.isEmpty) {
                  widget.onChanged(null);
                }
              },
              onTap: () {
                _filterItems(_controller.text);
              },
            ),
            // Dropdown list appears below the field
            if (_showDropdown && _filteredItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_filteredItems.length >= _maxItemsToShow)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${AppLocalizations.of(context)?.showingResults(_maxItemsToShow)}.',
                                style: DMSansFont.textStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Flexible(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = widget.value == item;

                          return InkWell(
                            onTap: () => _selectItem(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade50
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.itemLabel(item),
                                      style: DMSansFont.textStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
