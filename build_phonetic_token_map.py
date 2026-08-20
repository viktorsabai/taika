import json
from collections import defaultdict,Counter
x=json.load(open('steps.json',encoding='utf-8'))
mp=defaultdict(Counter)
for s in x['stepsets']:
 for i in s['items']:
  p=i.get('phonetic') or ''
  for t in p.split():
   if t and t[-1] in '→↗↘': mp[t[:-1]][t[-1]]+=1
for token in ['май','кау-джай','пхут','ик','кхранг','дай','май?','чаа-чаа','ной','лэу','пэп','нунг','ау','лёй','кхой','сэп','о-кэ','чил','пен','рай','сун','нынг','сонг','саам','сии','хаа','хок','джэт','пээт','као','сип','эт','йи','рой','пхан','мыэн','лан']:
 print(token,dict(mp[token]),'best=',mp[token].most_common(1))
