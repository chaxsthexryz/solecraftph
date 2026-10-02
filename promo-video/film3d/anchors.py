# Project 3D points to screen pixels for the overlay: where the finale wordmark sits in each frame.
import bpy, os, json
from bpy_extras.object_utils import world_to_camera_view
HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, 'scene.blend'))
sc = bpy.context.scene; out = {}
for f in range(525, 600):
    sc.frame_set(f); cam = bpy.data.objects['cam_finale']
    sole, ph = bpy.data.objects['wm2_SOLE'], bpy.data.objects['wm2_PH']
    bb = lambda ob: [ob.matrix_world @ __import__('mathutils').Vector(c) for c in ob.bound_box]
    pts = bb(sole) + bb(ph)
    px = [world_to_camera_view(sc, cam, p) for p in pts]
    xs = [p.x * 1920 for p in px]; ys = [(1 - p.y) * 1080 for p in px]
    out[f] = {'left': min(xs), 'right': max(xs), 'top': min(ys), 'bottom': max(ys)}
json.dump(out, open(os.path.join(HERE, 'anchors.json'), 'w'), indent=0)
print('anchors', out[599])
