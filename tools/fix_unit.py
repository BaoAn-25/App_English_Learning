path = 'lib/ui/textbook/unit_detail_screen.dart'
txt = open(path, 'r', encoding='utf-8').read()
txt = txt.replace("                  final String status = sec['status'] as String;\n", "")
txt = txt.replace("// status: ${section['status']}", "final status = section['status'] as String;")
open(path, 'w', encoding='utf-8').write(txt)
print('UnitDetailScreen fixed')

