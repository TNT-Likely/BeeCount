import 'package:flutter/material.dart';

typedef SearchableDropdownItemBuilder<T> = Widget Function(T item);
typedef SearchableDropdownFilter<T> = bool Function(T item, String query);
typedef SearchableDropdownLabelExtractor<T> = String Function(T item);

class SearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final SearchableDropdownItemBuilder<T> itemBuilder;
  final SearchableDropdownFilter<T> filter;
  final SearchableDropdownLabelExtractor<T> labelExtractor;
  final String hintText;
  final bool enabled;
  final Widget? prefixIcon;
  
  const SearchableDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
    required this.filter,
    required this.labelExtractor,
    this.value,
    this.hintText = '请选择',
    this.enabled = true,
    this.prefixIcon,
  });
  
  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _closeDropdown();
    super.dispose();
  }
  
  void _openDropdown() {
    if (_isOpen || !widget.enabled) return;
    
    _isOpen = true;
    _searchController.clear();
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
  
  void _closeDropdown() {
    if (!_isOpen) return;
    
    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _focusNode.unfocus();
  }
  
  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: '搜索...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                Flexible(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      final query = value.text.toLowerCase();
                      final filteredItems = widget.items.where((item) => 
                        widget.filter(item, query)
                      ).toList();
                      
                      if (filteredItems.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('无匹配项', textAlign: TextAlign.center),
                        );
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return InkWell(
                            onTap: () {
                              widget.onChanged(item);
                              _closeDropdown();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: widget.itemBuilder(item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
          color: widget.enabled 
            ? Theme.of(context).colorScheme.surface 
            : Theme.of(context).colorScheme.surface.withOpacity(0.5),
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                widget.value != null 
                  ? widget.labelExtractor(widget.value as T)
                  : widget.hintText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.value != null 
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Icon(
              _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: widget.enabled 
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}