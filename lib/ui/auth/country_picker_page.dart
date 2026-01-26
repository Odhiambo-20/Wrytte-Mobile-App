import 'package:flutter/material.dart';
import 'package:wrytte/utils/countries.dart';

class CountryPickerPage extends StatefulWidget {
  const CountryPickerPage({super.key});

  @override
  State<CountryPickerPage> createState() => _CountryPickerPageState();
}

class _CountryPickerPageState extends State<CountryPickerPage> {
  final TextEditingController _search = TextEditingController();
  late List<Country> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = countries; // from countries.dart
    _search.addListener(_applyFilter);
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? countries
              : countries
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(q) ||
                        c.isoCode.toLowerCase().contains(q) ||
                        c.dialCode.contains(q),
                  )
                  .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a country'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _filtered[i];
          return ListTile(
            leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
            title: Text(c.name),
            trailing: Text(
              '+${c.dialCode}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => Navigator.pop(context, c),
          );
        },
      ),
    );
  }
}
