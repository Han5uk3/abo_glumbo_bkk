import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchableDropdown<T extends Object> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T extends Object>
    extends State<SearchableDropdown<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.itemLabel(widget.value!) : '',
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newText = widget.value != null
          ? widget.itemLabel(widget.value!)
          : '';
      if (_controller.text != newText) {
        // Schedule the text update after the current frame to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != newText) {
            _controller.text = newText;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<T>(
              textEditingController: _controller,
              focusNode: _focusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (_showAll) {
                  return widget.items;
                }
                if (textEditingValue.text.isEmpty) {
                  return const Iterable.empty();
                }
                return widget.items.where((T option) {
                  return widget
                      .itemLabel(option)
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: widget.itemLabel,
              onSelected: (value) {
                setState(() {
                  _showAll = false;
                });
                widget.onChanged(value);
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_drop_down),
                          focusNode: FocusNode(
                            skipTraversal: true,
                            canRequestFocus: false,
                          ),
                          onPressed: () {
                            if (_showAll) {
                              setState(() {
                                _showAll = false;
                              });
                            } else {
                              setState(() {
                                _showAll = true;
                              });
                              focusNode.requestFocus();
                              // Force update to trigger options builder
                              final text = textEditingController.text;
                              textEditingController.text = '$text ';
                              textEditingController.text = text;
                            }
                          },
                        ),
                      ),
                      validator: (value) {
                        if (textEditingController.text.isNotEmpty &&
                            (widget.value == null ||
                                textEditingController.text !=
                                    widget.itemLabel(widget.value!))) {
                          return "No ${widget.label} selected";
                        }
                        return widget.validator?.call(widget.value);
                      },
                      onChanged: (text) {
                        if (_showAll) {
                          setState(() {
                            _showAll = false;
                          });
                        }
                        if (text.isEmpty) {
                          widget.onChanged(null);
                        }
                      },
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: 200,
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final T option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  widget.itemLabel(option),
                                  style: GoogleFonts.dmSans(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
