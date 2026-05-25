$file1 = "c:\Proje\hard_kapitalizm\lib\features\store\ui\store_detail_screen.dart"
$file2 = "c:\Proje\hard_kapitalizm\lib\features\store\ui\store_screen.dart"

function FixColors($path) {
    (Get-Content $path) -replace 'Colors\.white70', 'AppColors.textSecondary' `
                        -replace 'Colors\.white24', 'AppColors.textMuted' `
                        -replace 'Colors\.white', 'AppColors.textPrimary' `
                        -replace 'Colors\.greenAccent', 'AppColors.green' `
                        -replace 'Colors\.redAccent', 'AppColors.red' `
                        -replace 'Colors\.orangeAccent', 'AppColors.goldDark' `
                        -replace 'Colors\.black26', 'AppColors.cardBg' `
                        -replace 'Colors\.black54', 'AppColors.background' `
                        -replace "fontFamily:\s*'Inter',", "" | Set-Content $path
}

FixColors $file1
FixColors $file2

Write-Host "Colors updated successfully."
