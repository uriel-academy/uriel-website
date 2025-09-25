import 'package:flutter/material.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool notificationsEnabled = true;
  bool maintenanceMode = false;
  String theme = 'Light';
  String selectedLanguage = 'English';
  Color brandingColor = const Color(0xFF1A1E3F);
  String? logoPath;
  String emailTemplate = 'Welcome to Uriel Academy!';
  bool googleIntegration = false;
  bool zoomIntegration = false;
  DateTime? scheduledMaintenance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Settings'),
        backgroundColor: brandingColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Branding: Logo upload and color picker
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Upload Logo'),
              subtitle: logoPath != null ? Text(logoPath!) : const Text('No logo selected'),
              trailing: ElevatedButton(
                child: const Text('Choose'),
                onPressed: () {
                  // Mock: Pick logo from assets
                  setState(() {
                    logoPath = 'assets/uriel_logo2.png';
                  });
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Branding Color'),
              subtitle: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: brandingColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
              ),
              trailing: ElevatedButton(
                child: const Text('Pick'),
                onPressed: () {
                  // Mock: Toggle between two colors
                  setState(() {
                    brandingColor = brandingColor == const Color(0xFF1A1E3F)
                        ? const Color(0xFFD62828)
                        : const Color(0xFF1A1E3F);
                  });
                },
              ),
            ),
            const Divider(),
            // Email Templates
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Template'),
              subtitle: Text(emailTemplate),
              trailing: ElevatedButton(
                child: const Text('Edit'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final controller = TextEditingController(text: emailTemplate);
                      return AlertDialog(
                        title: const Text('Edit Email Template'),
                        content: TextField(
                          controller: controller,
                          maxLines: 4,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                emailTemplate = controller.text;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            // Integrations
            SwitchListTile(
              title: const Text('Google Integration'),
              value: googleIntegration,
              onChanged: (val) {
                setState(() {
                  googleIntegration = val;
                });
              },
              secondary: const Icon(Icons.cloud),
            ),
            SwitchListTile(
              title: const Text('Zoom Integration'),
              value: zoomIntegration,
              onChanged: (val) {
                setState(() {
                  zoomIntegration = val;
                });
              },
              secondary: const Icon(Icons.video_call),
            ),
            const Divider(),
            // Multi-language support
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: Text(selectedLanguage),
              trailing: DropdownButton<String>(
                value: selectedLanguage,
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'French', child: Text('French')),
                  DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedLanguage = val;
                    });
                  }
                },
              ),
            ),
            const Divider(),
            // Scheduled maintenance
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Schedule Maintenance'),
              subtitle: scheduledMaintenance != null
                  ? Text('Scheduled for: ${scheduledMaintenance!.toLocal()}')
                  : const Text('No maintenance scheduled'),
              trailing: ElevatedButton(
                child: const Text('Pick Date'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      scheduledMaintenance = picked;
                    });
                  }
                },
              ),
            ),
            const Divider(),
            // Existing settings
            SwitchListTile(
              title: const Text('Enable Notifications'),
              value: notificationsEnabled,
              onChanged: (val) {
                setState(() {
                  notificationsEnabled = val;
                });
              },
              secondary: const Icon(Icons.notifications),
            ),
            SwitchListTile(
              title: const Text('Maintenance Mode'),
              value: maintenanceMode,
              onChanged: (val) {
                setState(() {
                  maintenanceMode = val;
                });
              },
              secondary: const Icon(Icons.build),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Theme'),
              subtitle: Text(theme),
              trailing: DropdownButton<String>(
                value: theme,
                items: const [
                  DropdownMenuItem(value: 'Light', child: Text('Light')),
                  DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'System', child: Text('System')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      theme = val;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandingColor,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
