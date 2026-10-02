# Look-dev for the AF1-style shoe: four angles in a neutral studio -> out/b3d/af1/*.png
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import af1_model
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.75, 0.75, 0.74, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 0.25
shoe = af1_model.build_shoe('af1'); shoe.location = (-0.5, 0, 0)
bpy.ops.mesh.primitive_plane_add(size=20); fl = bpy.context.object
m = bpy.data.materials.new('fl'); m.use_nodes = True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.5, 0.5, 0.49, 1); fl.data.materials.append(m)
d = bpy.data.lights.new('key', 'AREA'); d.energy = 110; d.size = 2.5; k = bpy.data.objects.new('key', d); sc.collection.objects.link(k); k.location = (-1.2, -1.6, 2.2); k.rotation_euler = (math.radians(45), 0, math.radians(-35))
d2 = bpy.data.lights.new('rim', 'AREA'); d2.energy = 60; d2.size = 2; r = bpy.data.objects.new('rim', d2); sc.collection.objects.link(r); r.location = (1.4, 1.8, 1.6); r.rotation_euler = (math.radians(-50), 0, math.radians(140))
cd = bpy.data.cameras.new('c'); cd.lens = 50; cam = bpy.data.objects.new('c', cd); sc.collection.objects.link(cam); sc.camera = cam
t = bpy.data.objects.new('t', None); sc.collection.objects.link(t); t.location = (0, 0, 0.17)
c = cam.constraints.new('TRACK_TO'); c.target = t; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'out', 'b3d', 'af1'); os.makedirs(out, exist_ok=True)
for name, ang, el in (('side', -90, 0.35), ('34front', -45, 0.6), ('34back', -140, 0.65), ('top', -60, 1.4)):
    a = math.radians(ang); cam.location = (2.0 * math.cos(a), 2.0 * math.sin(a), el)
    sc.render.filepath = os.path.join(out, name + '.png'); bpy.ops.render.render(write_still=True)
print('done')
