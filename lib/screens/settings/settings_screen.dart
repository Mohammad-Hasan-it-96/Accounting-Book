import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('دفتر حسابات'),
            subtitle: Text('الإصدار 1.0.0'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('حول التطبيق'),
            subtitle: const Text(
                'تطبيق محاسبة عربي يعمل بدون إنترنت\nبنية: SQLite + Provider'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

