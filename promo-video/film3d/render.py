# Render frames of film3d/scene.blend with Cycles.
#   python film3d/render.py --frames 0-599 [--step 1] [--pct 100] [--samples 20] [--out out/b3d/frames] [--force]
# Frames that already exist are skipped, so an interrupted render resumes where it stopped.
import bpy, os, sys, json, time, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser(); ap.add_argument('--frames', default='0-599'); ap.add_argument('--list', default='')
ap.add_argument('--step', type=int, default=1); ap.add_argument('--pct', type=int, default=100); ap.add_argument('--samples', type=int, default=0)
ap.add_argument('--out', default=os.path.join(HERE, '..', 'out', 'b3d', 'frames')); ap.add_argument('--force', action='store_true')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, 'scene.blend'))
sc = bpy.context.scene; meta = json.load(open(os.path.join(HERE, 'scene.json')))
sc.render.resolution_percentage = a.pct
if a.samples: sc.cycles.samples = a.samples
os.makedirs(a.out, exist_ok=True)
frames = [int(x) for x in a.list.split(',')] if a.list else list(range(int(a.frames.split('-')[0]), int(a.frames.split('-')[1]) + 1, a.step))
SEQ = {name: (lo, hi, d) for name, (lo, hi, d) in meta['seq'].items()}
def set_textures(f):
    for name, (lo, hi, d) in SEQ.items():
        m = bpy.data.materials[name]; img = m.node_tree.nodes[m['tex']].image
        path = os.path.join(d, '%04d.jpg' % min(max(f, lo), hi))
        if img.filepath != path: img.filepath = path; img.reload()
for f in frames:
    path = os.path.join(a.out, '%04d.png' % f)
    if os.path.exists(path) and not a.force: continue
    sc.frame_set(f)
    for s, e, cam in meta['cams']:
        if s <= f <= e: sc.camera = bpy.data.objects[cam]
    set_textures(f)
    sc.render.filepath = path; t = time.time()
    bpy.ops.render.render(write_still=True)
    print(f'FRAME {f} {time.time() - t:.1f}s', flush=True)
