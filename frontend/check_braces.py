import sys

def check_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    stack = []
    for i, line in enumerate(lines):
        line_num = i + 1
        for j, char in enumerate(line):
            # Ignore characters inside strings, comments, etc? For a quick check just count { } 
            # We assume the file is reasonably formatted.
            if char == '{':
                stack.append(line_num)
            elif char == '}':
                if not stack:
                    print(f"Error: Closed too many braces at line {line_num}!")
                    break
                opened_at = stack.pop()
                if len(stack) == 1:
                    print(f"Class/Level 1 closed at line {line_num} (Opened at {opened_at})")
    
    if stack:
        print(f"Unclosed braces remaining! Opened at: {stack}")

check_braces('c:/Users/Manjuu/Downloads/Artas_web/flutter_client/lib/main.dart')
