"""Editable, original designer hats. Run using Blender MCP's headless executor."""
import bpy, math, os
ROOT='/Users/tyler/Documents/GitHub/stair-dismount'
scene=bpy.context.scene
made=[]
def mat(name,color):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    return m
ink=mat('Hat ink',(.03,.06,.085));mint=mat('Hat mint',(.30,.96,.67));paper=mat('Hat paper',(.95,.93,.80));orange=mat('Hat orange',(1,.26,.065));gold=mat('Hat brass',(1,.68,.15))
def finish(o,material):o.data.materials.append(material);made.append(o);return o
def cylinder(name,r,depth,z,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=depth,location=(0,0,z));o=bpy.context.object;o.name=name
    mod=o.modifiers.new('Soft edge','BEVEL');mod.width=.012;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,material)
def poly(name,verts,faces,material):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);return finish(o,material)
def export(name):
    if name in bpy.data.collections:
        for o in list(bpy.data.collections[name].objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(bpy.data.collections[name])
    bpy.ops.object.select_all(action='DESELECT')
    for o in made:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models',name+'.glb'),export_format='GLB',use_selection=True,export_apply=True)
    col=bpy.data.collections.new(name);scene.collection.children.link(col)
    for o in made:
        for c in list(o.users_collection):c.objects.unlink(o)
        col.objects.link(o);o.location.x+=68+len(bpy.data.collections)*2
    made.clear()
cylinder('Clockwork brim',.37,.045,.02,ink);cylinder('Clockwork crown',.25,.43,.245,ink);cylinder('Mint ribbon',.259,.08,.12,mint)
for a in range(8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.045,location=(.26*math.cos(a*math.pi/4),.26*math.sin(a*math.pi/4),.18));finish(bpy.context.object,gold)
export('hat_clockwork')
cylinder('Crane resting pad',.17,.025,.01,ink)
poly('Origami body',[(-.1,0,.09),(.1,0,.09),(0,-.17,.19),(0,.18,.25),(0,0,.36)],[(0,1,2),(0,1,3),(0,2,4),(1,2,4),(0,3,4),(1,3,4)],paper)
for side in [-1,1]:poly('Folded wing',[(0,-.10,.19),(0,.17,.25),(side*.66,.08,.39),(side*.30,-.09,.15)],[(0,1,2),(0,2,3)],paper)
poly('Crane neck',[(0,-.12,.20),(.045,-.13,.22),(0,-.24,.48),(-.045,-.23,.45),(0,-.36,.42)],[(0,1,2),(0,2,3),(2,3,4)],gold)
export('hat_crane')
cylinder('Traffic crown base',.32,.055,.03,ink)
bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.22,radius2=.035,depth=.55,location=(0,0,.32));finish(bpy.context.object,orange)
cylinder('Reflective hat stripe',.137,.08,.31,paper)
export('hat_cone')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender/stair_wreck_assets.blend'))
result={'status':'ok','hats':['hat_clockwork','hat_crane','hat_cone']}
