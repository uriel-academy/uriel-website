#!/usr/bin/env python3
"""
Script to remove unused methods from home_page.dart
This removes large unused widget builder methods to reduce file size
"""

import re

# Methods to remove with their approximate starting lines
UNUSED_METHODS = [
    '_buildStudentsAtRiskSection',
    '_buildWeeklyActivitySection', 
    '_buildEngagementOverview',
    '_buildTimeBasedProgress',
    '_buildModernMetricCard',
    '_buildRecommendationItem',
    '_buildRecentAchievements',
    '_buildAIRecommendations',
    '_buildSmartInsights',
    '_showComingSoon',
    '_showStudentDialog',
    '_buildPerformanceAnalytics',
    '_buildDetailStat',
]

def find_method_end(lines, start_idx):
    """Find the end of a method by tracking brace nesting"""
    brace_count = 0
    in_method = False
    
    for i in range(start_idx, len(lines)):
        line = lines[i]
        
        # Count braces
        for char in line:
            if char == '{':
                brace_count += 1
                in_method = True
            elif char == '}':
                brace_count -= 1
                if in_method and brace_count == 0:
                    return i
    
    return -1

def remove_unused_methods(input_file, output_file):
    """Remove unused methods from the file"""
    
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    methods_removed = []
    lines_to_remove = set()
    
    for method_name in UNUSED_METHODS:
        # Find method declaration
        pattern = re.compile(rf'^\s+(Widget|void)\s+{re.escape(method_name)}\s*\(')
        
        for i, line in enumerate(lines):
            if pattern.match(line):
                # Find the end of this method
                end_idx = find_method_end(lines, i)
                
                if end_idx != -1:
                    # Mark all lines for removal (inclusive)
                    for j in range(i, end_idx + 1):
                        lines_to_remove.add(j)
                    
                    methods_removed.append({
                        'name': method_name,
                        'start': i + 1,
                        'end': end_idx + 1,
                        'lines': end_idx - i + 1
                    })
                    print(f"✓ Found {method_name} (lines {i+1}-{end_idx+1}, {end_idx-i+1} lines)")
                    break
    
    # Create new file without removed lines
    new_lines = [line for i, line in enumerate(lines) if i not in lines_to_remove]
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    # Print summary
    total_lines_removed = len(lines_to_remove)
    print(f"\n{'='*60}")
    print(f"SUMMARY:")
    print(f"  Methods removed: {len(methods_removed)}")
    print(f"  Lines removed: {total_lines_removed:,}")
    print(f"  Original size: {len(lines):,} lines")
    print(f"  New size: {len(new_lines):,} lines")
    print(f"  Reduction: {total_lines_removed/len(lines)*100:.1f}%")
    print(f"{'='*60}")
    
    return methods_removed

if __name__ == '__main__':
    input_file = 'lib/screens/home_page.dart'
    output_file = 'lib/screens/home_page.dart.new'
    
    print("Removing unused methods from home_page.dart...\n")
    removed = remove_unused_methods(input_file, output_file)
    
    if removed:
        print("\n✓ Done! Review the changes:")
        print(f"  Original: {input_file}")
        print(f"  Modified: {output_file}")
        print("\nTo apply changes:")
        print(f"  mv {output_file} {input_file}")
    else:
        print("\n⚠ No methods were removed")
