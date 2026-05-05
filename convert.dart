import 'dart:io';

void main() {
  final file = File('lib/features/home/ui/home_screen.dart');
  var code = file.readAsStringSync();

  if (!code.contains('flutter_screenutil.dart')) {
    code = code.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter_screenutil/flutter_screenutil.dart';");
  }

  code = code.replaceAll(RegExp(r'const\s+(EdgeInsets|SizedBox|TextStyle|Icon|Padding|Container|BorderRadius|Radius)'), r'\1');
  code = code.replaceAll(RegExp(r'const\s+BoxDecoration'), 'BoxDecoration');
  code = code.replaceAll(RegExp(r'const\s+Text\('), 'Text(');
  code = code.replaceAll(RegExp(r'const\s+Row\('), 'Row(');
  code = code.replaceAll(RegExp(r'const\s+Column\('), 'Column(');
  code = code.replaceAll(RegExp(r'const\s+SliverGridDelegateWithFixedCrossAxisCount'), 'SliverGridDelegateWithFixedCrossAxisCount');

  code = code.replaceAllMapped(RegExp(r'fontSize:\s*([0-9.]+),?'), (m) => 'fontSize: ${m[1]}.sp,');
  code = code.replaceAllMapped(RegExp(r'width:\s*([0-9.]+),?'), (m) => 'width: ${m[1]}.w,');
  code = code.replaceAllMapped(RegExp(r'height:\s*([0-9.]+),?'), (m) => 'height: ${m[1]}.h,');
  code = code.replaceAllMapped(RegExp(r'size:\s*([0-9.]+),?'), (m) => 'size: ${m[1]}.sp,');
  code = code.replaceAllMapped(RegExp(r'radius:\s*([0-9.]+),?'), (m) => 'radius: ${m[1]}.r,');
  code = code.replaceAllMapped(RegExp(r'BorderRadius\.circular\(([0-9.]+)\)'), (m) => 'BorderRadius.circular(${m[1]}.r)');
  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.all\(([0-9.]+)\)'), (m) => 'EdgeInsets.all(${m[1]}.w)');
  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.symmetric\(\s*horizontal:\s*([0-9.]+),\s*vertical:\s*([0-9.]+),?\s*\)'), (m) => 'EdgeInsets.symmetric(horizontal: ${m[1]}.w, vertical: ${m[2]}.h)');
  
  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.symmetric\(\s*vertical:\s*([0-9.]+),?\s*\)'), (m) => 'EdgeInsets.symmetric(vertical: ${m[1]}.h)');
  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.symmetric\(\s*horizontal:\s*([0-9.]+),?\s*\)'), (m) => 'EdgeInsets.symmetric(horizontal: ${m[1]}.w)');
  
  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.only\(([^)]+)\)'), (m) {
    var inner = m[1]!;
    inner = inner.replaceAllMapped(RegExp(r'(left|right|top|bottom):\s*([0-9.]+)'), (m2) {
      return '${m2[1]}: ${m2[2]}${(m2[1] == 'top' || m2[1] == 'bottom') ? '.h' : '.w'}';
    });
    return 'EdgeInsets.only($inner)';
  });

  code = code.replaceAllMapped(RegExp(r'EdgeInsets\.fromLTRB\(([0-9.]+),\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\)'), (m) => 'EdgeInsets.fromLTRB(${m[1]}.w, ${m[2]}.h, ${m[3]}.w, ${m[4]}.h)');
  code = code.replaceAllMapped(RegExp(r'crossAxisSpacing:\s*([0-9.]+),?'), (m) => 'crossAxisSpacing: ${m[1]}.w,');
  code = code.replaceAllMapped(RegExp(r'mainAxisSpacing:\s*([0-9.]+),?'), (m) => 'mainAxisSpacing: ${m[1]}.h,');
  code = code.replaceAllMapped(RegExp(r'blurRadius:\s*([0-9.]+)'), (m) => 'blurRadius: ${m[1]}.r');

  code = code.replaceAll('.w.w', '.w');
  code = code.replaceAll('.h.h', '.h');
  code = code.replaceAll('.sp.sp', '.sp');
  code = code.replaceAll('.r.r', '.r');

  file.writeAsStringSync(code);
}
