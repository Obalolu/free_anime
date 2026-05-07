import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:free_anime/features/settings/presentation/cubit/theme_mode_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme mode'),
            subtitle: const Text('Dark mode is enforced'),
            trailing: const Icon(Icons.dark_mode),
            onTap: () => context.read<ThemeModeCubit>().enforceDarkMode(),
          ),
        ],
      ),
    );
  }
}
