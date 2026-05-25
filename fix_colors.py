import re

filepath = r'c:\Proje\hard_kapitalizm\lib\features\store\ui\store_detail_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Safe color replacements
content = content.replace('Colors.white', 'AppColors.textPrimary')
content = content.replace('Colors.white70', 'AppColors.textSecondary')
content = content.replace('Colors.white24', 'AppColors.textMuted')
content = content.replace('Colors.greenAccent', 'AppColors.green')
content = content.replace('Colors.redAccent', 'AppColors.red')
content = content.replace('Colors.orangeAccent', 'AppColors.goldDark')
content = content.replace('Colors.black26', 'AppColors.cardBg')
content = content.replace('Colors.black54', 'AppColors.background')
content = content.replace("fontFamily: 'Inter',", "")
content = content.replace('color: AppColors.textPrimary.withValues', 'color: Colors.white.withValues') # Revert this specific case if it breaks withValues
# Since AppColors are just const Color, .withValues() works on them in Flutter > 3.22. Wait, withOpacity is deprecated, withValues is new. Color supports withValues.

# Replace TextStyle with AppTextStyles where obvious
content = re.sub(r'TextStyle\(\s*color:\s*AppColors\.textPrimary,\s*fontSize:\s*20\.sp,\s*fontWeight:\s*FontWeight\.w900,?', r'AppTextStyles.h1.copyWith(fontSize: 20.sp, fontWeight: FontWeight.w900', content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Colors updated successfully in store_detail_screen.dart")
