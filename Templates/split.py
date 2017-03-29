#!/usr/bin/python
# Splits `.split` file into multiple files based on `// FILE: Foo.bar` markers.
# If the file has contents before the first marker, the resulting file is named
# after the original split file.

import re
import os
import sys

def pairwise(iterable):
    gen = iter(iterable)
    return zip(gen, gen)
    
def export(name, contents):
    with open(name, "w") as f:
        f.write(contents)

argc = len(sys.argv)
assert argc >= 2, "Expected file path argument"
assert argc <= 2, "Too many arguments"
name = sys.argv[1]
stripped_name, ext = os.path.splitext(name)
assert ext == '.split', "Expected `.split` file"

with open(name, 'r') as f:
    parsed = re.compile(r'// *FILE: *([^ ]+) *\n').split(f.read())
    
    main_name = stripped_name
    main_contents = parsed.pop(0)
    if main_contents != '':
        export(main_name, main_contents)
    
    for sub_name, sub_contents in pairwise(parsed):
        export(sub_name, sub_contents)

 
