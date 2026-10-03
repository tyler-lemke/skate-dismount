"""Original STAIR//WRECK asset kit. Run through Blender MCP background executor."""
import bpy, math, os
from mathutils import Vector
ROOT='/Users/tyler/Documents/GitHub/stair-dismount'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.name='STAIR_WRECK_Asset_Studio'
scene.unit_settings.system='METRIC'
M={}
colors={'ink':(0.025,0.047,0.065,1),'mint':(.28,.95,.66,1),'orange':(1,.24,.055,1),'yellow':(1,.76,.12,1),'white':(.87,.93,.91,1),'steel':(.24,.34,.39,1),'rubber':(.025,.032,.035,1),'blue':(.07,.29,.47,1),'wood':(.49,.25,.10,1),'pink':(.91,.12,.43,1),'skin':(.74,.43,.28,1)}
for k,c in colors.items():
    m=bpy.data.materials.new(k); m.diffuse_color=c; m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=c; bs.inputs['Roughness'].default_value=.65
    if k=='steel': bs.inputs['Metallic'].default_value=.65
    M[k]=m
made=[]; exports={}
def material(o,k): o.data.materials.append(M[k]); made.append(o); return o
def box(name,loc,size,mat,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Crafted edges','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return material(o,mat)
def sphere(name,loc,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return material(o,mat)
def cylinder(name,loc,r,depth,mat,rot=(0,0,0),vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rot); o=bpy.context.object; o.name=name
    bevel=o.modifiers.new('Rim bevel','BEVEL'); bevel.width=.02; bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return material(o,mat)
def text(name,string,loc,size,mat,rotation=(math.pi/2,0,0)):
    bpy.ops.object.text_add(location=loc,rotation=rotation); o=bpy.context.object; o.name=name; o.data.body=string; o.data.size=size; o.data.align_x='CENTER'; o.data.extrude=.003
    o.data.materials.append(M[mat]); bpy.ops.object.convert(target='MESH'); made.append(bpy.context.object); return o
def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in made: o.select_set(True)
    p=os.path.join(ROOT,'assets/models',name+'.glb')
    bpy.ops.export_scene.gltf(filepath=p,export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    collection=bpy.data.collections.new(name); scene.collection.children.link(collection)
    for o in made:
        for c in list(o.users_collection): c.objects.unlink(o)
        collection.objects.link(o)
    exports[name]={'objects':len(made),'bytes':os.path.getsize(p)}
    # Keep the editable originals on a shelf in the .blend, out of exports.
    offset=len(exports)*4
    for o in made: o.location.x+=offset
    made.clear()
box('Maple deck',(0,0,0),(.76,1.65,.115),'wood',.09)
box('Grip tape',(0,0,.066),(.72,1.55,.026),'ink',.07)
box('Deck signature',(0,-.30,.083),(.60,.11,.012),'mint',.01)
for y in (-.53,.53):
    box('Truck hanger',(0,y,-.11),(.64,.15,.12),'steel')
    for x in (-.39,.39): cylinder('Soft urethane wheel',(x,y,-.15),.14,.13,'yellow',(0,math.pi/2,0))
export('skateboard')
box('Jacket torso',(0,0,0),(.65,.40,.70),'mint',.10)
box('Shoulder yoke',(0,0,.24),(.70,.42,.18),'ink',.045)
box('Jacket zipper',(0,-.207,0),(.018,.018,.60),'white',.005)
box('Chest patch',(.18,-.218,.13),(.17,.02,.15),'orange',.01)
box('Back protector',(0,.23,-.02),(.43,.16,.51),'ink',.05)
box('Belt',(0,0,-.34),(.64,.42,.08),'ink')
export('rider_torso')
box('Shorts',(0,0,0),(.54,.39,.30),'ink',.06)
export('rider_pelvis')
sphere('Face',(0,-.015,-.02),(.22,.205,.245),'skin')
sphere('Certified helmet',(0,.015,.075),(.26,.24,.245),'orange')
box('Dark visor',(0,-.218,.025),(.37,.05,.12),'ink',.04)
box('Helmet stripe',(0,-.02,.30),(.085,.29,.025),'white',.012)
export('rider_head')
box('Sleeve',(0,0,0),(.22,.23,.36),'mint',.07)
box('Elbow pad',(0,.06,-.13),(.23,.25,.14),'ink',.04)
export('rider_upper_arm')
box('Gloved forearm',(0,0,0),(.18,.19,.34),'skin',.06)
box('Wrist guard',(0,0,-.12),(.20,.21,.13),'ink',.04)
export('rider_forearm')
box('Trouser leg',(0,0,0),(.235,.27,.44),'ink',.05)
box('Knee pad',(0,-.145,-.14),(.22,.065,.15),'steel',.025)
export('rider_thigh')
box('Sock',(0,0,.035),(.19,.21,.34),'white',.035)
box('Sneaker',(0,-.09,-.17),(.26,.46,.20),'ink',.05)
box('Sole',(0,-.09,-.265),(.27,.47,.045),'mint',.015)
export('rider_shin')
cylinder('Drum shell',(0,0,0),.40,1.03,'orange',vertices=24)
for z in (-.44,.0,.44): cylinder('Rolled steel hoop',(0,0,z),.421,.055,'steel',vertices=24)
cylinder('Barrel lid',(0,0,.519),.37,.014,'ink',vertices=24)
box('Warning patch',(0,-.395,0),(.35,.025,.34),'yellow')
text('Flammable icon','!',(0,-.416,-.11),.34,'ink')
export('barrel')
box('Crate core',(0,0,0),(1.04,1.04,1.04),'wood')
for z in (-.39,0,.39):
    for y in (-.535,.535): box('Wood slat',(0,y,z),(1.07,.05,.17),'yellow',.013)
for x in (-.43,.43): box('Steel band',(x,0,0),(.08,1.10,1.10),'steel',.008)
text('Cargo stencil','UP',(0,-.57,-.12),.29,'ink')
export('crate')
box('Road cone base',(0,0,-.36),(.66,.66,.10),'rubber')
bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.25,radius2=.065,depth=.75,location=(0,0,.055)); material(bpy.context.object,'orange')
cylinder('Reflector',(0,0,.14),.158,.16,'white')
export('cone')
box('Domino slab',(0,0,0),(.92,.26,2.12),'mint',.06)
box('Domino front',(0,-.145,0),(.80,.035,1.99),'ink',.035)
box('Center divider',(0,-.17,0),(.75,.012,.025),'mint',.004)
for x,z in [(-.20,.62),(.20,.28),(-.20,-.30),(.20,-.62)]: sphere('Domino pip',(x,-.178,z),(.065,.018,.065),'white')
export('domino')
box('Market cart bed',(0,0,-.05),(1.35,1.10,.16),'steel')
for x in (-.64,.64): box('Cart sides',(x,0,.24),(.07,1.10,.55),'pink')
for y in (-.51,.51): box('Cart ends',(0,y,.24),(1.3,.07,.55),'pink')
for x in (-.57,.57):
    for y in (-.38,.38): cylinder('Caster',(x,y,-.27),.17,.14,'rubber',(0,math.pi/2,0))
for x,y in [(-.35,-.2),(.05,.19),(.38,-.18)]: sphere('Oversized citrus',(x,y,.40),(.25,.25,.25),'yellow')
export('cart')
box('Vehicle chassis',(0,0,-.20),(1.85,3.30,.52),'yellow',.13)
box('Cabin',(0,.18,.34),(1.65,1.78,.75),'yellow',.15)
box('Windshield',(0,-.73,.40),(1.49,.05,.48),'ink')
box('Rear glass',(0,1.08,.40),(1.47,.05,.46),'ink')
for x in (-.85,.85): box('Side windows',(x,.16,.43),(.035,1.49,.43),'blue')
for x in (-.94,.94):
    for y in (-1.05,1.08): cylinder('Tire',(x,y,-.37),.38,.20,'rubber',(0,math.pi/2,0)); cylinder('Hub',(x*1.115,y,-.37),.21,.023,'steel',(0,math.pi/2,0))
for x in (-.61,.61): box('Headlight',(x,-1.68,-.10),(.38,.055,.19),'white')
box('Bumper',(0,-1.68,-.32),(1.75,.12,.15),'steel')
box('Roof taxi',(0,.05,.82),(.63,.34,.20),'ink')
text('Taxi label','TAXI',(0,-.13,.765),.13,'yellow')
export('taxi')
box('Barrier panel',(0,0,.10),(1.66,.18,.78),'orange')
for x in (-.53,0,.53):
    b=box('Reflective stripe',(x,-.104,.10),(.22,.018,.70),'white'); b.rotation_euler.y=-.30
for x in (-.58,.58): box('Barrier foot',(x,0,-.47),(.24,.72,.13),'ink')
export('barrier')
# Studio overview has all editable source objects and a readable asset index.
scene.world=bpy.data.worlds.new('Studio')
scene.world.color=(.06,.08,.10)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender/stair_wreck_assets.blend'))
result={'status':'ok','exports':exports,'blend':os.path.join(ROOT,'blender/stair_wreck_assets.blend'),'asset_count':len(exports)}
