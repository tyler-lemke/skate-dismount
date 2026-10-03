"""Synthesized original soundtrack and SFX. No samples or dependencies."""
import math,random,wave,struct,os
random.seed(81)
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE=22050

def write(name,samples,loop=False):
    peak=max(.001,max(abs(x) for x in samples)); gain=min(.9/peak,1)
    with wave.open(os.path.join(ROOT,'assets/audio',name+'.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,x*gain))*32767)) for x in samples))
    with open(os.path.join(ROOT,'assets/audio',name+'.wav.import'),'w') as f:
        f.write('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\nsource_file="res://assets/audio/'+name+'.wav"\n\n[params]\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode='+('2' if loop else '0')+'\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n')

def sfx(name,duration):
    out=[];phase=0
    for i in range(int(duration*RATE)):
        t=i/RATE;n=random.uniform(-1,1)
        if name=='blast': v=(n*.7+math.sin(t*75)*.35)*math.exp(-t*4)*(1-math.exp(-t*120))
        elif name=='impact': v=(n*.42+math.sin(t*math.tau*(90-40*t))*.65)*math.exp(-t*22)
        elif name=='clack': v=(n*.55+math.sin(t*1700)*.2)*math.exp(-t*38)
        elif name=='boost':
            phase+=math.tau*(150+t*950)/RATE;v=(math.sin(phase)*.42+n*.13)*math.sin(math.pi*t/duration)
        elif name=='launch': v=math.sin(math.tau*(330+660*t)*t)*.4*math.sin(math.pi*t/duration)
        else:
            note=[440,554.37,659.25,880][min(3,int(t/.14))];v=math.sin(math.tau*note*t)*.3*math.exp(-(t%.14)*12)*(1-t/duration)
        out.append(v)
    write(name,out)
for k,d in [('blast',1.6),('impact',.28),('clack',.18),('boost',.8),('launch',.5),('finish',1.0)]:sfx(k,d)
roll=[]; smooth=0
for i in range(RATE*2):
    smooth=smooth*.86+random.uniform(-1,1)*.14
    roll.append(smooth*.4+math.sin(i/RATE*math.tau*45)*.07)
write('roll',roll,True)
# Sixteen bars of driving breakbeat in D minor. Exact loop boundary.
bpm=138; beat=60/bpm; total=beat*64
notes=[73.416,65.406,87.307,65.406]
arp=[293.665,349.228,440,523.251,440,349.228,261.626,349.228]
track=[]
for i in range(int(total*RATE)):
    t=i/RATE;b=t/beat;sub=b%1;bar=int(b/4);bass=notes[(bar//4)%4]
    bassenv=math.exp(-sub*4);v=(math.sin(math.tau*bass*t)+.2*math.sin(math.tau*bass*2*t))*.15*bassenv
    # kick on every beat, snare on 2/4, syncopated hats
    kt=sub*beat;v+=math.sin(math.tau*(48*kt+12*(1-math.exp(-kt*36))))*math.exp(-kt*20)*.44
    if int(b)%4 in (1,3): v+=random.uniform(-1,1)*math.exp(-kt*25)*.23
    ht=(b*2%1)*beat*.5;v+=random.uniform(-1,1)*math.exp(-ht*95)*.08
    at=(b*2%1)*beat*.5;freq=arp[int(b*2)%8]*([1,1,.89,1][(bar//4)%4]);v+=math.sin(math.tau*freq*t)*math.exp(-at*13)*.055
    track.append(v)
write('cascade',track,True)
print('Generated 8 original WAV assets')
