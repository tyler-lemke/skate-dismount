"""Render exact runtime Godot geometry and Control bounds with Blender Cycles.
These are validation previews, not captures from Godot's native renderer.
"""
import bpy,json,math,os
from mathutils import Matrix,Vector
ROOT='/Users/tyler/Documents/GitHub/stair-dismount'
SCENE_FILE=globals().get('SCENE_FILE',ROOT+'/builds/scene_1_menu.json')
data=json.load(open(SCENE_FILE))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.name='Godot_Runtime_Validation'
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
materials={};meshes={}
def material(color,emission=0,metallic=0,roughness=.75,vertex_color=False):
    key=tuple(color)+(emission,metallic,roughness,vertex_color)
    if key not in materials:
        m=bpy.data.materials.new('Runtime material');m.diffuse_color=tuple(color);m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=tuple(color);bs.inputs['Roughness'].default_value=roughness;bs.inputs['Metallic'].default_value=metallic
        if vertex_color:
            attr=m.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='RuntimeColor';m.node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
        if emission:bs.inputs['Emission Color'].default_value=tuple(color);bs.inputs['Emission Strength'].default_value=emission*.5
        materials[key]=m
    return materials[key]
for key,surfaces in data['meshes'].items():
    verts=[];faces=[];ids=[];colors=[]
    for i,surface in enumerate(surfaces):
        offset=len(verts);verts.extend(surface['vertices']);faces.extend(tuple(j+offset for j in f) for f in surface['faces']);ids.extend([i]*len(surface['faces']))
        colors.extend(surface.get('vertex_colors') or [surface['color']]*len(surface['vertices']))
    mesh=bpy.data.meshes.new(key);mesh.from_pydata(verts,[],faces);mesh.update()
    for surface in surfaces:mesh.materials.append(material(surface['color'],surface['emission'],surface.get('metallic',0),surface.get('roughness',.75),bool(surface.get('vertex_colors'))))
    attribute=mesh.color_attributes.new(name='RuntimeColor',type='FLOAT_COLOR',domain='CORNER')
    for loop in mesh.loops:attribute.data[loop.index].color=colors[loop.vertex_index]
    for poly,i in zip(mesh.polygons,ids):poly.material_index=i;poly.use_smooth=surfaces[i]['smooth']
    meshes[key]=mesh
for i,instance in enumerate(data['instances']):
    if 'mesh' in instance:
        o=bpy.data.objects.new('Runtime_%04d'%i,meshes[instance['mesh']]);scene.collection.objects.link(o);o.matrix_world=C@Matrix(instance['matrix'])
    else:
        curve=bpy.data.curves.new('Runtime sign','FONT');curve.body=instance['text'];curve.size=instance['size'];curve.align_x='CENTER';curve.align_y='CENTER';curve.materials.append(material(instance['color'],.2))
        o=bpy.data.objects.new('Runtime sign',curve);scene.collection.objects.link(o);o.matrix_world=C@Matrix(instance['matrix'])
camdata=bpy.data.cameras.new('Runtime camera');camera=bpy.data.objects.new('Runtime camera',camdata);scene.collection.objects.link(camera);camera.matrix_world=C@Matrix(data['camera']);scene.camera=camera
camdata.lens=36/(2*math.tan(math.radians(data['fov'])/2))*(data['height']/data['width']);camdata.clip_end=300
scene.world=bpy.data.worlds.new('Runtime ambient');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=tuple(data['background']);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
sun_data=bpy.data.lights.new('Runtime directional','SUN');sun_data.energy=2.0;sun_data.angle=.08
sun=bpy.data.objects.new('Runtime directional',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(math.radians(40),math.radians(-20),math.radians(-35))
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.cycles.device='CPU'
scene.render.resolution_x=data['width'];scene.render.resolution_y=data['height'];scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
# GUI is drawn from the Godot Control tree on a transparent orthographic layer.
ui=bpy.data.scenes.new('Runtime_Control_Layout');ui.render.engine='CYCLES';ui.cycles.samples=1;ui.render.film_transparent=True;ui.cycles.use_denoising=False
ui.render.resolution_x=data['width'];ui.render.resolution_y=data['height'];ui.render.resolution_percentage=100
ui.view_settings.view_transform='Standard'
uicamdata=bpy.data.cameras.new('UI camera');uicam=bpy.data.objects.new('UI camera',uicamdata);ui.collection.objects.link(uicam);uicam.location=(720,450,2000);uicamdata.type='ORTHO';uicamdata.ortho_scale=1440;uicamdata.clip_end=4000;ui.camera=uicam
try:font=bpy.data.fonts.load('/System/Library/Fonts/Supplemental/Arial.ttf')
except:font=None
try:bold=bpy.data.fonts.load('/System/Library/Fonts/Supplemental/Arial Bold.ttf')
except:bold=font
ui_mats={}
def ui_mat(color):
    k=tuple(color)
    if k not in ui_mats:
        m=bpy.data.materials.new('UI');m.use_nodes=True;nodes=m.node_tree.nodes;nodes.clear()
        out=nodes.new('ShaderNodeOutputMaterial');em=nodes.new('ShaderNodeEmission');em.inputs[0].default_value=tuple(((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in color[:3])+(color[3],);em.inputs[1].default_value=1
        if color[3]<1:
            transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=color[3];m.node_tree.links.new(transparent.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0])
        else:m.node_tree.links.new(em.outputs[0],out.inputs[0])
        ui_mats[k]=m
    return ui_mats[k]
def rect(x,y,w,h,color,z,radius=8):
    radius=min(radius,w/2,h/2);verts=[]
    for cx,cy,start in [(x+radius,y+radius,math.pi),(x+w-radius,y+radius,math.pi*1.5),(x+w-radius,y+h-radius,0),(x+radius,y+h-radius,math.pi*.5)]:
        for step in range(7):
            a=start+step*math.pi/12;verts.append((cx+math.cos(a)*radius,900-(cy+math.sin(a)*radius),z))
    mesh=bpy.data.meshes.new('Control rect');mesh.from_pydata(verts,[],[tuple(range(len(verts)))]);mesh.materials.append(ui_mat(color));o=bpy.data.objects.new('Control rect',mesh);ui.collection.objects.link(o)
def text(body,x,y,w,h,size,color,z,center=False):
    curve=bpy.data.curves.new('Control text','FONT');curve.body=body;curve.size=size*1.34;curve.align_y='TOP_BASELINE';curve.align_x='CENTER' if center else 'LEFT';curve.space_line=1.05
    if font:curve.font=bold if size>30 else font
    curve.materials.append(ui_mat(color));o=bpy.data.objects.new('Control text',curve);ui.collection.objects.link(o)
    lines=body.count('\n')+1
    # Godot Label vertically centers its font box by default.
    baseline_y=y+(h-lines*size*1.2)/2+size*.98
    o.location=(x+w/2 if center else x,900-baseline_y,z)
for i,item in enumerate(data['gui']):
    x,y=item['pos'];w,h=item['size'];z=i*.08
    if item['type']=='panel':rect(x,y,w,h,item['color'],z,item['radius'])
    elif item['type']=='button':
        rect(x,y,w,h,item['color'],z,8);text(item['text'],x+18,y,w-36,h,item['font'],item['text_color'],z+.01,item['center'])
    elif item['type']=='text':text(item['text'],x,y,w,h,item['font'],item['color'],z,item['center'])
    else:
        rect(x,y,w,h,[.04,.10,.14,1],z,4)
        if item['value']>0:rect(x,y,w*item['value'],h,item['color'],z+.01,4)
# Watermark makes the validation method explicit in every image.
text('BLENDER VALIDATION / GODOT RUNTIME SCENE',20,885,1200,14,9,[.65,.75,.78,1],100)
path=ROOT+'/docs/screenshots/level_%d_%s_validation.png'%(data['level']+1,data['mode'])
bpy.context.window.scene=scene;scene.render.filepath=path.replace('.png','_world.png');bpy.ops.render.render(write_still=True)
bpy.context.window.scene=ui;ui.render.filepath=path.replace('.png','_ui.png');bpy.ops.render.render(write_still=True)
# Composite the two validation render layers without depending on a native GPU compositor.
import subprocess
p=subprocess.run(['/opt/homebrew/bin/ffmpeg','-loglevel','error','-y','-i',path.replace('.png','_world.png'),'-i',path.replace('.png','_ui.png'),'-filter_complex','[0:v][1:v]overlay=0:0:format=auto','-frames:v','1',path],capture_output=True,text=True,timeout=30)
if p.returncode: raise RuntimeError(p.stderr)
result={'status':'ok','screenshot':path,'runtime_meshes':len(data['instances']),'mode':data['mode'],'validation_renderer':'Blender Cycles; exact Godot runtime geometry and Control bounds'}
