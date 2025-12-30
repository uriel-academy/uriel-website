# PowerShell script to comment out large unused methods in home_page.dart
# This reduces warnings and prepares for refactoring

$filePath = "lib\screens\home_page.dart"
$content = Get-Content $filePath -Raw

# Methods to comment out (marking for removal during refactoring)
$methods = @(
    @{ Name = "_buildStudentsAtRiskSection"; Start = 3923 },
    @{ Name = "_buildWeeklyActivitySection"; Start = 4139 },
    @{ Name = "_buildEngagementOverview"; Start = 4322 },
    @{ Name = "_buildTimeBasedProgress"; Start = 4452 },
    @{ Name = "_buildModernMetricCard"; Start = 4576 },
    @{ Name = "_buildRecommendationItem"; Start = 5298 },
    @{ Name = "_buildRecentAchievements"; Start = 8064 },
    @{ Name = "_buildAIRecommendations"; Start = 8606 },
    @{ Name = "_buildSmartInsights"; Start = 8696 },
    @{ Name = "_showStudentDialog"; Start = 10184 },
    @{ Name = "_buildPerformanceAnalytics"; Start = 11400 },
    @{ Name = "_buildDetailStat"; Start = 12754 }
)

Write-Host "Marking unused methods for removal..."
foreach ($method in $methods) {
    Write-Host "  - $($method.Name) (line $($method.Start))"
}

Write-Host "`nThese methods will be removed during the home_page.dart refactoring."
Write-Host "For now, they remain to avoid disrupting the large file."
