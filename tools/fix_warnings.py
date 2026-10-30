import re

# 1. home_screen.dart
path = 'lib/ui/home/home_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("import '../textbook/textbook_screen.dart';\n", '')
txt = txt.replace("import '../theme/app_tokens.dart';\n", '')
open(path, 'w', encoding='utf-8').write(txt)

# 2. topic_list_screen.dart
path = 'lib/ui/vocab/topic_list_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("import '../home/home_screen.dart';\n", '')
open(path, 'w', encoding='utf-8').write(txt)

# 3. onboarding_schedule_screen.dart
path = 'lib/ui/onboarding/onboarding_schedule_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("activeColor: const Color(0xFF2563EB),", "activeThumbColor: const Color(0xFF2563EB),")
open(path, 'w', encoding='utf-8').write(txt)

# 4. textbook_hub_screen.dart
path = 'lib/ui/textbook/textbook_hub_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("separatorBuilder: (_, __) => const SizedBox(height: 10),", "separatorBuilder: (ctx, i) => const SizedBox(height: 10),")
txt = txt.replace("final bool isDownloaded = unit['isDownloaded'] as bool;", "// isDownloaded: ${unit['isDownloaded']}")
open(path, 'w', encoding='utf-8').write(txt)

# 5. unit_detail_screen.dart
path = 'lib/ui/textbook/unit_detail_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("separatorBuilder: (_, __) => const SizedBox(height: 10),", "separatorBuilder: (ctx, i) => const SizedBox(height: 10),")
txt = txt.replace("final String status = section['status'] as String;", "// status: ${section['status']}")
open(path, 'w', encoding='utf-8').write(txt)

# 6. reading_study_screen.dart
path = 'lib/ui/textbook/reading_study_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
old_dialog = """    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cỡ chữ bài đọc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [14.0, 16.0, 18.0, 20.0].map((size) {
              return RadioListTile<double>(
                title: Text('${size.toInt()} pt', style: TextStyle(fontSize: size)),
                value: size,
                groupValue: _fontSize,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _fontSize = val);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );"""

new_dialog = """    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cỡ chữ bài đọc'),
          children: [14.0, 16.0, 18.0, 20.0].map((size) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _fontSize = size);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _fontSize == size ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 12),
                    Text('${size.toInt()} pt', style: TextStyle(fontSize: size)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );"""
txt = txt.replace(old_dialog, new_dialog)
open(path, 'w', encoding='utf-8').write(txt)

print('Cleaned successfully')

