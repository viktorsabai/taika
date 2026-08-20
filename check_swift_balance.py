from pathlib import Path
import sys

def stripped(src):
    out=[]; i=0; state='code'
    while i<len(src):
        c=src[i]; n=src[i+1] if i+1<len(src) else ''
        if state=='code':
            if c=='/' and n=='/': state='line'; out += [' ',' ']; i += 2; continue
            if c=='/' and n=='*': state='block'; out += [' ',' ']; i += 2; continue
            if c=='"': state='string'; out.append(' '); i += 1; continue
            out.append(c); i += 1; continue
        if state=='line':
            out.append('\n' if c=='\n' else ' ')
            if c=='\n': state='code'
            i += 1; continue
        if state=='block':
            if c=='*' and n=='/': out += [' ',' ']; i += 2; state='code'; continue
            out.append('\n' if c=='\n' else ' '); i += 1; continue
        if state=='string':
            if c=='\\': out += [' ',' ']; i += 2; continue
            if c=='"': state='code'
            out.append('\n' if c=='\n' else ' '); i += 1
    return ''.join(out)

for name in sys.argv[1:]:
    raw=Path(name).read_text()
    s=stripped(raw)
    print(name)
    for op,cl in [('(',')'),('[',']'),('{','}')]:
        print(op+cl, s.count(op)-s.count(cl))
        if s.count(op)!=s.count(cl):
            stack=[]
            for line_no,line in enumerate(s.splitlines(),1):
                for col,ch in enumerate(line,1):
                    if ch==op: stack.append((line_no,col))
                    elif ch==cl and stack: stack.pop()
            print('unclosed tail', stack[-5:])
