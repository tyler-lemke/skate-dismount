"""Reproducible original SKATE DISMOUNT hero, deck and cab. Blender 5+, no downloads.
Run: blender --background --python blender/build_hero_assets.py
Godot forward +Z = Blender -Y; metric asset origins match the collision proxies.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene; scene.name='Hero_Asset_Studio'; scene.unit_settings.system='METRIC'
COLORS={'skin':(.58,.29,.16,1),'mint':(.075,.55,.37,1),'dark':(.024,.043,.065,1),'orange':(1,.22,.035,1),'cream':(.86,.88,.77,1),'rubber':(.015,.021,.026,1),'steel':(.29,.36,.39,1),'yellow':(.98,.62,.025,1),'glass':(.045,.14,.21,1),'white':(.95,.91,.75,1),'red':(.7,.018,.025,1),'wood':(.51,.24,.07,1)}
mats={}
def mat(name,color):
 m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=color; p.inputs['Roughness'].default_value=.55
 if 'steel' in name: p.inputs['Metallic'].default_value=.75
 if 'glass' in name: p.inputs['Metallic'].default_value=.35; p.inputs['Roughness'].default_value=.16
 mats[name]=m; return m
for n,c in COLORS.items(): mat(n,c)
def assign(o,m): o.data.materials.append(mats[m] if isinstance(m,str) else m); return o
def smooth(o):
 for p in o.data.polygons:p.use_smooth=True
 return o
def sphere(name,loc,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=loc); o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); assign(o,m); return smooth(o)
def box(name,loc,size,m,r=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 b=o.modifiers.new('Rounded manufactured edges','BEVEL'); b.width=r;b.segments=3; bpy.ops.object.modifier_apply(modifier=b.name); assign(o,m); return smooth(o)
def cyl(name,loc,r,depth,m):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=loc,rotation=(0,math.pi/2,0));o=bpy.context.object;o.name=name;assign(o,m);return smooth(o)
def join(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
def export(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models',name+'.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_animations=False,export_skins=True,export_morph=True,export_extras=True)
 collection=bpy.data.collections.new(name);scene.collection.children.link(collection)
 for o in objects:
  for c in list(o.users_collection): c.objects.unlink(o)
  collection.objects.link(o)
 return collection
# Bone names match the eleven physical frames. Rest arms are separated from the torso
# except at the shoulders, so remeshing cannot create welded underarm webs.
# Runtime maps these rest frames directly onto the unchanged rigid-body centers.
centers={'torso':(0,0,1.35),'pelvis':(0,0,.9),'head':(0,0,1.99),'arm_l':(-.56,0,1.34),'arm_r':(.56,0,1.34),'fore_l':(-.64,-.08,1.01),'fore_r':(.64,-.08,1.01),'thigh_l':(-.18,.10,.61),'thigh_r':(.18,-.13,.61),'shin_l':(-.18,.10,.23),'shin_r':(.18,-.13,.23)}
scales={'torso':(.32,.215,.40),'pelvis':(.29,.205,.22),'head':(.215,.205,.26),'arm_l':(.132,.138,.26),'arm_r':(.132,.138,.26),'fore_l':(.12,.125,.25),'fore_r':(.12,.125,.25),'thigh_l':(.16,.175,.30),'thigh_r':(.16,.175,.30),'shin_l':(.125,.135,.24),'shin_r':(.125,.135,.24)}
parts=[sphere('volume_'+k,v,scales[k],'skin') for k,v in centers.items()]
# Neck and shoulder bridges make a genuinely connected deforming surface.
parts += [sphere('neck',(0,0,1.75),(.14,.14,.23),'skin')]
for s in (-1,1): parts.append(sphere('shoulder_bridge',(s*.39,0,1.55),(.27,.15,.15),'skin'))
body=join(parts,'HeroSkin'); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
r=body.modifiers.new('Continuous tailored surface','REMESH');r.mode='VOXEL';r.voxel_size=.026;r.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=r.name)
s=body.modifiers.new('Sculpt smoothing','SMOOTH');s.factor=.7;s.iterations=4;bpy.ops.object.modifier_apply(modifier=s.name)
d=body.modifiers.new('Game topology','DECIMATE');d.ratio=.48;bpy.ops.object.modifier_apply(modifier=d.name)
# Cut garment seams before assigning materials: no voxel-shaped color boundaries.
bm=bmesh.new();bm.from_mesh(body.data)
for z in (.40,.78,1.08,1.125,1.15,1.19,1.72):
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,z),plane_no=(0,0,1),clear_inner=False,clear_outer=False)
bm.to_mesh(body.data);bm.free();body.data.update()
body.data.materials.clear()
regions=list(centers)
for k in regions:
 color='mint' if k=='torso' or k.startswith('arm_') else ('dark' if k=='pelvis' or k.startswith('thigh_') else ('cream' if k.startswith('shin_') else 'skin'))
 body.data.materials.append(mat(k+'__'+color,COLORS[color]))
seam_indices={}
for k,label in [('arm_l','cuff'),('arm_r','cuff'),('torso','hem')]:
 seam_indices[k]=len(body.data.materials);body.data.materials.append(mat(k+'__'+label,COLORS['dark']))
def dist(point,k):
 c=Vector(centers[k]);half={'torso':.23,'head':.12,'pelvis':.09}.get(k,.12); q=c.copy();q.z=max(c.z-half,min(c.z+half,point.z));return (point-q).length
def region_at(point):
 side='l' if point.x<0 else 'r'
 if point.z>1.72:return 'head'
 if abs(point.x)>(.34 if point.z>1.15 else .37) and point.z>.65:return ('arm_' if point.z>1.15 else 'fore_')+side
 if point.z>1.08:return 'torso'
 if point.z>.78:return 'pelvis'
 return ('thigh_' if point.z>.40 else 'shin_')+side
for p in body.data.polygons:
 center=sum((body.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
 region=region_at(center);p.material_index=regions.index(region)
 if (region.startswith('arm_') and center.z<1.19) or (region=='torso' and center.z<1.125):p.material_index=seam_indices[region]
# UVs remain continuous within each island; damage is modulated spatially, never replaces clothing.
bpy.context.view_layer.objects.active=body;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
arm=bpy.data.armatures.new('WreckAnatomy');rig=bpy.data.objects.new('HeroRig',arm);scene.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);body.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
for k,c in centers.items():
 b=arm.edit_bones.new(k);b.head=c;b.tail=Vector(c)+Vector((0,0,.20))
parents={'torso':'pelvis','head':'torso','arm_l':'torso','arm_r':'torso','fore_l':'arm_l','fore_r':'arm_r','thigh_l':'pelvis','thigh_r':'pelvis','shin_l':'thigh_l','shin_r':'thigh_r'}
for k,p in parents.items():arm.edit_bones[k].parent=arm.edit_bones[p]
bpy.ops.object.mode_set(mode='OBJECT')
def bind(o,key=None):
 if key:
  g=o.vertex_groups.new(name=key);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 else:
  groups={k:o.vertex_groups.new(name=k) for k in regions}
  for v in o.data.vertices:
   region=region_at(v.co)
   if 1.40<v.co.z<1.72 and abs(v.co.x)>.24:
    side='l' if v.co.x<0 else 'r';t=max(0,min(1,(abs(v.co.x)-.27)/.25));w=t*t*(3-2*t)
    groups['torso'].add([v.index],1-w,'REPLACE');groups['arm_'+side].add([v.index],w,'REPLACE');continue
   side=region[-1] if region[-1] in ('l','r') else ('l' if v.co.x<0 else 'r')
   neighbors={'pelvis':['torso','thigh_l','thigh_r'],'head':['torso'],'arm_l':['torso','fore_l'],'arm_r':['torso','fore_r'],'fore_l':['arm_l'],'fore_r':['arm_r'],'thigh_l':['pelvis','shin_l'],'thigh_r':['pelvis','shin_r'],'shin_l':['thigh_l'],'shin_r':['thigh_r']}
   allowed=[region]+neighbors.get(region,[])
   if region.startswith('arm_') and v.co.z<1.43:allowed=[region,'fore_'+side]
   if region=='torso':
    allowed=['torso','pelvis'] if v.co.z<1.4 else ['torso','head']
   ranked=sorted(((dist(v.co,k),k) for k in allowed))[:3]
   weights=[math.exp(-((dd-ranked[0][0])/.075)*2) for dd,k in ranked]; total=sum(weights)
   for (dd,k),w in zip(ranked,weights):groups[k].add([v.index],w/total,'REPLACE')
 mod=o.modifiers.new('Eleven physical regions','ARMATURE');mod.object=rig;o.parent=rig
bind(body)
hero=[rig,body]
def detail(o,k):
 # Every detail retains its own material and is rigidly skinned to its anatomical region.
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bind(o,k);hero.append(o);o.select_set(False);return o
# Original street rider: open-face orange helmet, expressive face, collar, pads and stitched sneakers.
detail(sphere('HelmetShell',(0,.025,2.12),(.25,.23,.19),'orange'),'head')
detail(box('HelmetCenterStripe',(0,.025,2.292),(.055,.25,.018),'cream',.008),'head')
for x in (-.09,.09):
 detail(sphere('EyeSocket',(x,-.190,2.025),(.042,.012,.024),'dark'),'head')
 detail(sphere('Eye',(x,-.206,2.027),(.022,.006,.014),'white'),'head')
 detail(sphere('Pupil',(x,-.215,2.027),(.010,.004,.012),'dark'),'head')
 detail(box('UpperLid',(x,-.213,2.042),(.047,.010,.012),'skin',.004),'head')
 detail(box('Brow',(x,-.20,2.074),(.082,.021,.018),'dark',.008),'head')
 detail(sphere('Ear',(x*2.4,0,1.99),(.043,.047,.07),'skin'),'head')
for sign in (-1,1):
 for y,z in [(-.075,2.278),(.015,2.300),(.10,2.278)]:
  detail(box('HelmetVent',(sign*.12,y,z),(.029,.065,.006),'dark',.012),'head')
 curve=bpy.data.curves.new('HelmetStrap','CURVE');curve.dimensions='3D';curve.bevel_depth=.011;curve.bevel_resolution=3;sp=curve.splines.new('POLY');sp.points.add(3)
 for pt,co in zip(sp.points,[(sign*.226,-.035,2.08),(sign*.225,-.025,1.95),(sign*.14,-.10,1.81),(sign*.06,-.115,1.79)]):pt.co=(*co,1)
 obj=bpy.data.objects.new('HelmetStrap',curve);scene.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.convert(target='MESH');detail(assign(bpy.context.object,'dark'),'head')
detail(sphere('Nose',(0,-.217,1.981),(.035,.05,.04),'skin'),'head')
detail(box('Smile',(0,-.20,1.917),(.084,.015,.017),'dark',.007),'head')
detail(sphere('Collar',(0,0,1.71),(.155,.15,.075),'dark'),'torso')
detail(box('JacketZip',(0,-.216,1.43),(.014,.018,.35),'cream',.005),'torso')
detail(box('ChestPatch',(.17,-.203,1.48),(.13,.025,.095),'orange',.012),'torso')
for side in ('l','r'):
 c=Vector(centers['fore_'+side]);detail(box('Glove_'+side,c+Vector((0,-.012,-.225)),(.185,.14,.155),'dark',.052),'fore_'+side)
 for finger in range(4):
  xoff=(finger-1.5)*.044
  detail(sphere('Finger_'+side,c+Vector((xoff,-.028,-.318)),(.022,.043,.051-abs(finger-1.5)*.007),'skin'),'fore_'+side)
  detail(box('Knuckle_'+side,c+Vector((xoff,-.085,-.23)),(.030,.025,.041),'steel',.009),'fore_'+side)
 detail(sphere('Thumb_'+side,c+Vector((.09 if side=='l' else -.09,-.03,-.2)),(.037,.045,.065),'skin'),'fore_'+side)
 detail(box('WristGuard_'+side,c+Vector((0,.01,-.13)),(.20,.18,.085),'dark',.035),'fore_'+side)
 c=Vector(centers['thigh_'+side]);detail(sphere('KneePad_'+side,c+Vector((0,-.145,-.12)),(.115,.046,.10),'steel'),'thigh_'+side)
 c=Vector(centers['shin_'+side]);detail(box('Shoe_'+side,c+Vector((0,-.07,-.17)),(.27,.43,.15),'dark',.065),'shin_'+side)
 detail(box('ToeCap_'+side,c+Vector((0,-.246,-.18)),(.245,.085,.11),'rubber',.034),'shin_'+side)
 detail(box('HeelPanel_'+side,c+Vector((0,.10,-.17)),(.23,.044,.10),'orange',.016),'shin_'+side)
 detail(box('Sole_'+side,c+Vector((0,-.07,-.246)),(.28,.45,.04),'cream',.018),'shin_'+side)
 for z in (-.18,-.12,-.06):detail(box('Lace_'+side,c+Vector((0,z,-.093)),(.17,.018,.018),'cream',.008),'shin_'+side)
hero_col=export('hero',hero)
# Curved laminated deck: custom ring surface, raised nose and tail, separate mechanical trucks/wheels.
board=[];verts=[];faces=[]
deck_stations=[-.83,-.82,-.79,-.74,-.60,-.35,0,.35,.60,.74,.79,.82,.83]
for y in deck_stations:
 width=.37*math.sqrt(max(.0004,1-(abs(y)/.83)**8));lift=max(0,(abs(y)-.55))**2*1.5
 for x,z in [(-width,-.035),(-width,.035),(width,.035),(width,-.035)]:verts.append((x,y,z+lift))
for row in range(len(deck_stations)-1):
 for c in range(4):faces.append((row*4+c,row*4+(c+1)%4,(row+1)*4+(c+1)%4,(row+1)*4+c))
last=(len(deck_stations)-1)*4;faces.extend([(3,2,1,0),(last,last+1,last+2,last+3)])
mesh=bpy.data.meshes.new('PressedMaple');mesh.from_pydata(verts,[],faces);deck=bpy.data.objects.new('Deck',mesh);scene.collection.objects.link(deck);assign(deck,'wood');assign(deck,'dark')
for p in mesh.polygons:p.material_index=1 if p.normal.z>.5 else 0
board.append(deck)
for y in (-.52,.52):
 board += [box('TruckBase',(0,y,-.07),(.25,.20,.055),'steel',.02),box('Hanger',(0,y,-.13),(.65,.075,.075),'steel',.03)]
 for x in (-.36,.36):board +=[cyl('Wheel',(x,y,-.155),.115,.12,'cream'),cyl('WheelBearing',(x*1.18,y,-.155),.044,.013,'steel')]
board.append(box('GripSignature',(0,-.24,.04),(.56,.065,.014),'orange',.01));board_col=export('skateboard',board)
# Compact cab, same 1.85 x 3.3 envelope, forward Blender -Y / Godot +Z.
taxi=[]
bodycab=join([box('Sill',(0,0,-.23),(1.79,3.28,.47),'yellow',.18),box('Hood',(0,-1.07,.025),(1.72,1.02,.24),'yellow',.14),box('Trunk',(0,1.2,.02),(1.72,.77,.27),'yellow',.12),box('Cabin',(0,.12,.33),(1.52,1.69,.69),'yellow',.24)],'Body')
bpy.context.view_layer.objects.active=bodycab;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bodycab.shape_key_add(name='Basis');cr=bodycab.shape_key_add(name='Crumple')
for v in cr.data:
 front=max(0,min(1,(-v.co.y-.45)/1.2));v.co.y+=front*.42;v.co.z+=front*(.14*math.sin(v.co.x*9)-.08);v.co.x*=1+front*.04
bodycab['damage_blend_shape']='Crumple';taxi.append(bodycab)
taxi +=[box('Windshield',(0,-.715,.40),(1.30,.035,.38),'glass',.09),box('RearGlass',(0,.96,.42),(1.27,.035,.35),'glass',.08)]
for x in (-.77,.77):
 taxi.append(box('SideGlass',(x,.12,.44),(.025,1.25,.33),'glass',.08))
 taxi.append(box('Pillar',(x,.12,.46),(.048,.09,.42),'yellow',.018))
 taxi.append(box('DoorHandle',(x*1.17,.34,.03),(.04,.16,.04),'steel',.015))
 taxi.append(box('Mirror',(x*1.17,-.55,.30),(.18,.18,.10),'yellow',.045))
 for y,label in [(-1.04,'F'),(1.06,'R')]:
  parent=bpy.data.objects.new('Wheel_'+label+('L' if x<0 else 'R'),None);scene.collection.objects.link(parent);parent.location=(x*1.19,y,-.37);taxi.append(parent)
  for obj in [cyl('Tire',(0,0,0),.36,.19,'rubber'),cyl('Alloy',(math.copysign(.105,x),0,0),.22,.02,'steel'),cyl('Hub',(math.copysign(.119,x),0,0),.065,.026,'dark')]:obj.parent=parent;taxi.append(obj)
for x in (-.61,.61):
 taxi += [box('Headlamp',(x,-1.657,-.005),(.38,.025,.15),'white',.045),box('BrakeLamp',(x,1.65,-.015),(.34,.026,.16),'red',.025)]
taxi +=[box('FrontBumper',(0,-1.65,-.29),(1.64,.13,.11),'steel',.04),box('Grille',(0,-1.665,-.11),(.57,.025,.12),'dark',.025),box('TaxiSign',(0,.04,.77),(.56,.27,.17),'cream',.045)]
taxi_col=export('taxi',taxi)
# Editable organized originals, all at true export origin. Visibility switches for inspection.
board_col.hide_render=True;taxi_col.hide_render=True
world=bpy.data.worlds.new('Soft studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.10,.14,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5;scene.world=world
for loc,power,size in [((3,-4,5),750,4),((-3,-1,3),500,3),((1,3,4),900,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-5,2.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32;scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender/hero.blend'))
result={'hero_vertices':len(body.data.vertices),'hero_bones':len(arm.bones),'exports':['hero','skateboard','taxi'],'source':'blender/hero.blend'}
print(json.dumps(result))
