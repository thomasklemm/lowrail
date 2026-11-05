import re,sys
base,new,committed,out=sys.argv[1:5]
RL='"graphql-c_parser/ext/graphql_c_parser_ext/lexer.rl"'
SELF='"graphql-c_parser/ext/graphql_c_parser_ext/lexer.c"'
def rlrefs(lines): return [int(m.group(1)) for l in lines for m in [re.match(r'#line (\d+) '+re.escape(RL),l)] if m]
B=open(base).read().split('\n'); N=open(new).read().split('\n'); C=open(committed).read().split('\n')
assert rlrefs(B)==rlrefs(C), "committed rl refs differ from base"
newrefs=rlrefs(N); assert len(newrefs)==len(rlrefs(B))
s='\n'.join(C)
reps=[("\tFLOAT,\n","\tFLOAT_LITERAL,\n"),("\tINPUT,\n","\tINPUT_LITERAL,\n"),("\tINT,\n","\tINT_LITERAL,\n"),
("\t\tcase INT:\n","\t\tcase INT_LITERAL:\n"),("\t\tcase FLOAT:\n","\t\tcase FLOAT_LITERAL:\n")]
for a,b in reps:
    assert s.count(a)==1,(a,s.count(a)); s=s.replace(a,b)
for a,b,n in [("emit(INT, ts","emit(INT_LITERAL, ts",3),("emit(FLOAT, ts","emit(FLOAT_LITERAL, ts",2),("emit(INPUT, ts","emit(INPUT_LITERAL, ts",1)]:
    assert s.count(a)==n,(a,s.count(a)); s=s.replace(a,b)
m=re.search(r'\n(\t+)STATIC_VALUE_TOKEN\(INPUT, "input"\)\n',s); assert m; ind=m.group(1)
s=s.replace(m.group(0),'\n',1)
a='\n'+ind+'case TYPE_LITERAL:\n'; assert s.count(a)==1
s=s.replace(a,'\n'+ind+'case INPUT_LITERAL:\n'+ind+'token_sym = ID2SYM(rb_intern("INPUT"));\n'+ind+'token_content = GraphQLTokenStringINPUT;\n'+ind+'break;'+a,1)
L=s.split('\n'); it=iter(newrefs)
for i,l in enumerate(L):
    if re.match(r'#line \d+ '+re.escape(RL),l): L[i]='#line %d %s'%(next(it),RL)
    elif re.match(r'#line \d+ '+re.escape(SELF),l): L[i]='#line %d %s'%(i+2,SELF)
open(out,'w').write('\n'.join(L))
