# SoleCraftPH 20 s 3D promo: builds the whole Blender scene from code and saves film3d/scene.blend.
# python film3d/build_scene.py     (uses the bpy module from .venv-blender)
#
# 30 fps, 96 BPM: one beat = 18.75 frames, one bar = 75 frames (2.5 s), eight bars.
#   bar 1   f0–74     dark stage: size tiles flip to SOLD OUT, the Kayano goes grey
#   bar 2   f75–149   white studio: 3D wordmark drops in, the phone rises
#   bar 3–5 f150–374  the phone unfolds into floating app screens; the camera flies past each one
#   bar 6   f375–449  a laptop opens on the website, phone beside it
#   bar 7   f450–524  six real pairs in acrylic blocks on plinths
#   bar 8   f525–599  dark stage: wordmark rises, Kayano block, rim light
import bpy, bmesh, math, os, json, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import af1_model
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, 'assets')
FONT_DISPLAY = os.path.join(HERE, 'fonts', 'BebasNeue-Regular.ttf')
FONT_UI = os.path.join(HERE, 'fonts', 'Inter-SemiBold.ttf')
FPS, BEAT, BAR = 30, 18.75, 75
rad = math.radians

def lin(hexs):
    h = hexs.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)
INK, BLAZE, PAPER, STONE, GRAPHITE = lin('#111111'), lin('#E2412A'), lin('#FAF9F6'), lin('#EDEAE3'), lin('#1D1D1C')

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS; sc.frame_start = 0; sc.frame_end = 599
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 20; sc.cycles.use_adaptive_sampling = True; sc.cycles.adaptive_threshold = 0.03
sc.cycles.use_denoising = True; sc.cycles.denoiser = 'OPENIMAGEDENOISE'
sc.cycles.max_bounces = 6; sc.cycles.diffuse_bounces = 2; sc.cycles.glossy_bounces = 3; sc.cycles.transmission_bounces = 6; sc.cycles.transparent_max_bounces = 8
sc.cycles.caustics_reflective = False; sc.cycles.caustics_refractive = False; sc.cycles.blur_glossy = 1.0
sc.render.use_persistent_data = True
sc.render.use_motion_blur = True; sc.render.motion_blur_shutter = 0.5
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

# ---------------------------------------------------------------- helpers
def link(ob):
    bpy.context.scene.collection.objects.link(ob); return ob

def mat(name, color, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_strength=0.0, transmission=0.0, ior=1.45, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = color; b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal; b.inputs['Coat Weight'].default_value = coat
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Transmission Weight'].default_value = transmission; b.inputs['IOR'].default_value = ior
    if emit is not None: b.inputs['Emission Color'].default_value = emit; b.inputs['Emission Strength'].default_value = emit_strength
    return m

def img_mat(name, path, emit=1.0, alpha=False, rough=0.35, coat=0.0, sat_key=False, seq=False, screen=False):
    """Image material. Screens are emissive (true colours under any light) with a thin glossy layer."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; N = nt.nodes
    b = N['Principled BSDF']
    tex = N.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(path); tex.interpolation = 'Cubic'
    tex.extension = 'CLIP'
    col = tex.outputs['Color']
    if sat_key:
        hs = N.new('ShaderNodeHueSaturation'); hs.name = 'HS'; nt.links.new(col, hs.inputs['Color']); col = hs.outputs['Color']
    if screen:
        b.inputs['Base Color'].default_value = (0, 0, 0, 1); b.inputs['Coat Weight'].default_value = 0.6; b.inputs['Coat Roughness'].default_value = 0.08
    else:
        nt.links.new(col, b.inputs['Base Color'])
    nt.links.new(col, b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = emit
    b.inputs['Roughness'].default_value = rough
    if not screen: b.inputs['Coat Weight'].default_value = coat
    if alpha:
        nt.links.new(tex.outputs['Alpha'], b.inputs['Alpha'])
    m['tex'] = tex.name
    return m

def rounded_box(name, sx, sy, sz, r, segs=6, materials=(), loc=(0, 0, 0)):
    """Box with rounded edges (bmesh bevel), smooth faces and sharp flat-to-flat edges."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co.x *= sx; v.co.y *= sy; v.co.z *= sz
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(r, sx / 2 - 1e-4, sy / 2 - 1e-4, sz / 2 - 1e-4), segments=segs, profile=0.5, affect='EDGES')
    for f in bm.faces: f.smooth = True
    for e in bm.edges:
        if e.is_manifold and e.calc_face_angle(0) > rad(40): e.smooth = False
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc
    for m in materials: me.materials.append(m)
    return ob

def plane(name, w, h, m, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    vs = [bm.verts.new((x * w / 2, y * h / 2, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
    for l, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): l[uv].uv = (u, v)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc; ob.rotation_euler = rot; me.materials.append(m)
    return ob

def upright(name, w, h, m, loc=(0, 0, 0), rz=0.0):
    """A plane standing up and facing -Y (towards the cameras)."""
    return plane(name, w, h, m, loc, (rad(90), 0, rz))

FONTS = {}
def text(name, body, size, m, font=FONT_DISPLAY, extrude=0.0, bevel=0.0, align='LEFT', valign='TOP_BASELINE', loc=(0, 0, 0), rot=(rad(90), 0, 0)):
    if font not in FONTS: FONTS[font] = bpy.data.fonts.load(font)
    cu = bpy.data.curves.new(name, 'FONT'); cu.body = body; cu.font = FONTS[font]; cu.size = size
    cu.extrude = extrude; cu.bevel_depth = bevel; cu.bevel_resolution = 2; cu.align_x = align; cu.align_y = valign
    cu.materials.append(m)
    ob = link(bpy.data.objects.new(name, cu)); ob.location = loc; ob.rotation_euler = rot
    return ob

def empty(name, loc=(0, 0, 0)):
    ob = link(bpy.data.objects.new(name, None)); ob.location = loc; return ob

def key(ob, path, frame, value, interp='BEZIER', easing='AUTO', index=-1):
    """Insert a keyframe; value may be a scalar for an indexed channel or a tuple for the whole vector."""
    target = ob
    if index >= 0:
        getattr(target, path)[index] = value
    else:
        setattr(target, path, value)
    target.keyframe_insert(path, frame=frame, index=index)
    fc = None
    ad = target.animation_data
    for c in ad.action.fcurves if ad and ad.action else []:
        if c.data_path == path and (index < 0 or c.array_index == index):
            for kp in c.keyframe_points:
                if abs(kp.co.x - frame) < 1e-3: kp.interpolation = interp; kp.easing = easing

def keys(ob, path, seq, index=-1, interp='BEZIER', easing='AUTO'):
    for f, v in seq: key(ob, path, f, v, interp, easing, index)

def ease_in_last(ob, kind='BACK', easing='EASE_OUT', paths=None):
    for fc in ob.animation_data.action.fcurves:
        if paths and fc.data_path not in paths: continue
        if len(fc.keyframe_points) >= 2:
            k = fc.keyframe_points[-2]; k.interpolation = kind; k.easing = easing

def node_key(socket, frame, value, interp='BEZIER'):
    socket.default_value = value; socket.keyframe_insert('default_value', frame=frame)

def sun(name, energy, angle, rot, color=(1, 1, 1)):
    d = bpy.data.lights.new(name, 'SUN'); d.energy = energy; d.angle = rad(angle); d.color = color
    ob = link(bpy.data.objects.new(name, d)); ob.rotation_euler = rot; return ob

def area(name, energy, size, loc, target, color=(1, 1, 1), shape='RECTANGLE', size_y=None):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = color; d.shape = shape
    if size_y: d.size_y = size_y
    ob = link(bpy.data.objects.new(name, d)); ob.location = loc
    t = empty(name + '.aim', target); c = ob.constraints.new('TRACK_TO'); c.target = t; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
    return ob

def spot(name, energy, loc, target, size=40, blend=0.6, color=(1, 1, 1), radius=0.5):
    d = bpy.data.lights.new(name, 'SPOT'); d.energy = energy; d.spot_size = rad(size); d.spot_blend = blend; d.color = color; d.shadow_soft_size = radius
    ob = link(bpy.data.objects.new(name, d)); ob.location = loc
    t = empty(name + '.aim', target); c = ob.constraints.new('TRACK_TO'); c.target = t; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
    return ob

CAMS = []
def camera(name, lens, path, aim, start, end):
    """Camera that eases along `path` [(frame, loc)] while looking at `aim` [(frame, loc)]."""
    cd = bpy.data.cameras.new(name); cd.lens = lens; cd.clip_start = 0.05; cd.clip_end = 400
    ob = link(bpy.data.objects.new(name, cd)); t = empty(name + '.aim')
    c = ob.constraints.new('TRACK_TO'); c.target = t; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
    keys(ob, 'location', path); keys(t, 'location', aim)
    CAMS.append((start, end, ob)); m = sc.timeline_markers.new(name, frame=start); m.camera = ob
    return ob

# ---------------------------------------------------------------- materials
M_FLOOR_DARK = mat('floor_dark', lin('#0B0B0B'), rough=0.3, spec=0.5)
M_GRAPHITE = mat('graphite', GRAPHITE, rough=0.32, coat=0.6)
M_BLAZE = mat('blaze', BLAZE, rough=0.38, coat=0.3)
M_INK = mat('ink', INK, rough=0.3, coat=0.4)
M_PAPER_EMIT = mat('paper_emit', PAPER, rough=0.5, emit=PAPER, emit_strength=0.35)
M_PAPER_GLOW = mat('paper_glow', PAPER, rough=0.45, emit=PAPER, emit_strength=0.75)
M_PAPER = mat('paper', PAPER, rough=0.85)
M_CYC = mat('cyclorama', lin('#F4F2EE'), rough=0.95, spec=0.2)
M_PHONE_BODY = mat('phone_body', lin('#151515'), rough=0.22, metal=0.85, coat=0.8)
M_PHONE_GLASS = mat('phone_glass', lin('#0A0A0A'), rough=0.08, coat=1.0)
M_LENS = mat('lens', lin('#050505'), rough=0.05, coat=1.0, spec=1.0)
M_ALU = mat('alu', lin('#D6D2C9'), rough=0.3, metal=0.9)
M_ACRYLIC = mat('acrylic', (1, 1, 1, 1), rough=0.02, transmission=1.0, ior=1.49, spec=0.5)
M_PLINTH = mat('plinth', lin('#E9E5DD'), rough=0.6)
M_WHITE_CARD = mat('card_white', (1, 1, 1, 1), rough=0.35, coat=0.6)

# ---------------------------------------------------------------- world: dark for bars 1 and 8, studio white between
world = bpy.data.worlds.new('world'); sc.world = world; world.use_nodes = True
bg = world.node_tree.nodes['Background']
for f, col, st in ((0, lin('#0A0A0A'), 0.2), (74, lin('#0A0A0A'), 0.2), (75, (1, 1, 1, 1), 0.42), (524, (1, 1, 1, 1), 0.42), (525, lin('#0A0A0A'), 0.2)):
    node_key(bg.inputs['Color'], f, col); node_key(bg.inputs['Strength'], f, st)
for fc in world.node_tree.animation_data.action.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = 'CONSTANT'

# ================================================================ bar 1: dark stage (x = -200)
H = Vector((-200, 0, 0))
plane('floor_dark', 300, 300, M_FLOOR_DARK, loc=(H.x, 40, 0))
tiles = []
for i, label in enumerate(['7', '8', '9', '10', '11', '12']):
    x = H.x + 1.9 + (i - 2.5) * 0.78
    t = rounded_box(f'tile_{label}', 0.64, 0.16, 0.64, 0.12, materials=[M_GRAPHITE], loc=(x, 0, -1.0))
    num_m = M_PAPER_EMIT if label != '9' else mat('num9', PAPER, rough=0.5, emit=PAPER, emit_strength=0.35)
    n = text(f'num_{label}', label, 0.3, num_m, font=FONT_UI, extrude=0.008, align='CENTER', valign='CENTER', loc=(0, -0.086, 0)); n.parent = t
    plate = rounded_box(f'back_{label}', 0.6, 0.01, 0.6, 0.1, materials=[M_BLAZE], loc=(0, 0.082, 0)); plate.parent = t
    so = text(f'sold_{label}', 'SOLD\nOUT', 0.2, M_PAPER_EMIT, extrude=0.004, align='CENTER', valign='CENTER', loc=(0, 0.09, 0), rot=(rad(90), 0, rad(180))); so.parent = t
    so.data.space_line = 0.8
    rise = 12 + i * 2
    keys(t, 'location', [(rise, (x, 0, -0.8)), (rise + 10, (x, 0, 0.32))]); ease_in_last(t, 'BACK')
    tiles.append((t, label, num_m))
# "your size" lights the 9 in blaze, then 9, 10 and 8 flip to SOLD OUT on the beats
num9 = tiles[2][2].node_tree.nodes['Principled BSDF']
node_key(num9.inputs['Emission Color'], 27, PAPER); node_key(num9.inputs['Emission Color'], 29, BLAZE)
node_key(num9.inputs['Base Color'], 27, PAPER); node_key(num9.inputs['Base Color'], 29, BLAZE)
for idx, f in ((2, 47), (3, 56), (1, 66)):
    t = tiles[idx][0]
    keys(t, 'rotation_euler', [(f, (0, 0, 0)), (f + 9, (0, 0, rad(180)))])
    ease_in_last(t, 'BACK', paths=('rotation_euler',))
# the hero: a 3D white court sneaker (AF1 style) floating and turning; it drains to grey when the sizes sell out
def shoe_rig(prefix, scale):
    pivot = empty(prefix + '_pivot'); shoe = af1_model.build_shoe(prefix)
    shoe.parent = pivot; shoe.location = (-0.5 * scale, 0, -0.2 * scale); shoe.scale = (scale, scale, scale)
    return pivot, shoe
def grey_out(shoe, f0, f1):
    for name in shoe['materials']:
        nt = bpy.data.materials[name].node_tree; b = nt.nodes['Principled BSDF']; sock = b.inputs['Base Color']
        if sock.is_linked: sock = sock.links[0].from_node.inputs['A']
        c = tuple(sock.default_value); g = sum(c[:3]) / 3 * 0.45
        node_key(sock, f0, c); node_key(sock, f1, (g, g, g, 1))
hero, hero_shoe = shoe_rig('hero', 3.0)
keys(hero, 'location', [(0, (H.x + 4.6, 1.0, 2.4)), (16, (H.x + 2.1, 1.0, 1.45)), (74, (H.x + 2.0, 1.0, 1.55))])
keys(hero, 'rotation_euler', [(0, (rad(12), rad(-14), rad(-110))), (16, (rad(8), rad(-6), rad(-58))), (74, (rad(6), rad(-4), rad(-40)))])
grey_out(hero_shoe, 47, 55)
glow = area('hook_glow', 420, 3.0, (H.x + 2.1, 3.0, 3.6), (H.x + 2.1, 0, 1.7), color=BLAZE[:3], shape='DISK')
keys(glow.data, 'energy', [(0, 0), (10, 420), (47, 420), (56, 60)])
spot('hook_key', 2200, (H.x - 2.5, -5, 6), (H.x + 1.8, 0, 0.3), size=55, blend=0.8, radius=0.8)
area('hook_fill', 120, 6, (H.x + 6, -6, 3), (H.x + 2, 0, 0.6))
camera('cam_hook', 42, [(0, (H.x + 0.6, -9.6, 1.9)), (74, (H.x + 0.9, -7.9, 1.6))], [(0, (H.x + 0.6, 0, 0.95)), (74, (H.x + 0.9, 0, 0.95))], 0, 74)

# ================================================================ bars 2–7: white studio (x = 0 … 30)
def cyclorama(x0, x1, y0, y_curve, r, top):
    me = bpy.data.meshes.new('cyclorama'); bm = bmesh.new()
    prof = [(y0, 0.0)] + [(y_curve + r * math.sin(a), r - r * math.cos(a)) for a in [i * (math.pi / 2) / 16 for i in range(17)]] + [(y_curve + r, top)]
    rows = []
    for x in (x0, x1): rows.append([bm.verts.new((x, y, z)) for y, z in prof])
    for j in range(len(prof) - 1):
        f = bm.faces.new((rows[0][j], rows[1][j], rows[1][j + 1], rows[0][j + 1])); f.smooth = True
    bm.to_mesh(me); bm.free(); ob = link(bpy.data.objects.new('cyclorama', me)); me.materials.append(M_CYC); return ob
cyclorama(-14, 44, -30, 6, 5, 18)
sun_ob = sun('studio_sun', 3.2, 12, (rad(42), rad(-18), rad(-28)))
for f, e in ((0, 0.0), (74, 0.0), (75, 2.1), (524, 2.1), (525, 0.0)): key(sun_ob.data, 'energy', f, e, interp='CONSTANT')
area('studio_soft', 700, 12, (8, -10, 9), (8, 2, 0))
area('studio_rim', 300, 8, (8, 9, 6), (8, 0, 1))

# ---- 3D wordmark
def wordmark(prefix, mats, loc, size=1.5):
    parts, x = [], 0.0
    for word, m in zip(('SOLE', 'CRAFT', 'PH'), mats):
        ob = text(f'{prefix}_{word}', word, size, m, extrude=0.11, bevel=0.012, loc=(0, 0, 0))
        bpy.context.view_layer.update(); w = ob.dimensions.x
        parts.append((ob, x)); x += w + size * 0.045
    for ob, ox in parts: ob.location = (loc[0] + ox - x / 2, loc[1], loc[2])
    return parts, x
WM, wm_w = wordmark('wm', (M_INK, M_BLAZE, M_INK), (-3.2, 0, 0))
for i, (ob, ox) in enumerate(WM):
    f = 76 + i * 9
    base = ob.location.copy()
    keys(ob, 'location', [(f, (base.x, base.y, 5.5)), (f + 12, tuple(base))]); ease_in_last(ob, 'BOUNCE')

# ---- the phone (and the two panels folded inside it)
PH_W, PH_D, PH_H = 0.78, 0.085, 1.64
SCR_W, SCR_H = 0.722, 0.722 * 760 / 340
def phone_model(name, screen_mat, loc, back=True):
    body = rounded_box(name, PH_W, PH_D, PH_H, 0.1, segs=8, materials=[M_PHONE_BODY], loc=loc)
    glass = rounded_box(name + '_glass', PH_W - 0.012, 0.004, PH_H - 0.012, 0.094, materials=[M_PHONE_GLASS], loc=(0, -PH_D / 2 - 0.001, 0)); glass.parent = body
    scr = upright(name + '_screen', SCR_W, SCR_H, screen_mat, loc=(0, -PH_D / 2 - 0.0035, 0)); scr.parent = body
    if back:
        bump = rounded_box(name + '_bump', 0.26, 0.02, 0.36, 0.07, materials=[M_PHONE_GLASS], loc=(-0.2, PH_D / 2 + 0.008, 0.56)); bump.parent = body
        for dz in (0.08, -0.08):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.055, depth=0.03, location=(-0.2, PH_D / 2 + 0.02, 0.56 + dz), rotation=(rad(90), 0, 0))
            l = bpy.context.object; l.data.materials.append(M_LENS); l.parent = body; l.location = (-0.2, PH_D / 2 + 0.02, 0.56 + dz)
        logo = upright(name + '_logo', 0.34, 0.34, img_mat(name + '_logo_m', os.path.join(A, 'logo.png'), emit=0.6, alpha=True), loc=(0, PH_D / 2 + 0.001, -0.05), rz=rad(180)); logo.parent = body
    return body, scr

m_phone = img_mat('phone_screen', os.path.join(HERE, 'seq', 'phone', '0060.jpg'), emit=1.0, rough=0.25, screen=True)
m_panelA = img_mat('panelA_screen', os.path.join(HERE, 'seq', 'panelA', '0140.jpg'), emit=1.0, rough=0.25, screen=True)
m_panelC = img_mat('panelC_screen', os.path.join(A, '07-order-detail.png'), emit=1.0, rough=0.25, screen=True)
P0 = Vector((4.6, 0.9, 1.15))
phone, _ = phone_model('phone', m_phone, tuple(P0))
panelA, _ = phone_model('panelA', m_panelA, tuple(P0), back=False)
panelC, _ = phone_model('panelC', m_panelC, tuple(P0), back=False)
# phone rises out of the floor, turns to face us, then unfolds
keys(phone, 'location', [(96, tuple(P0 + Vector((0, 0, -2.6)))), (120, tuple(P0))])
keys(phone, 'rotation_euler', [(96, (0, 0, rad(-55))), (122, (0, 0, rad(-22))), (140, (0, 0, rad(-14))), (158, (0, 0, rad(-10)))])
SPREAD = 1.3
for p, side, f0 in ((panelA, -1, 152), (panelC, 1, 156)):
    keys(p, 'location', [(96, tuple(P0 + Vector((0, 0, -2.6)))), (120, tuple(P0)),
                         (f0, tuple(P0)), (f0 + 16, tuple(P0 + Vector((side * SPREAD, 0.42, 0))))])
    keys(p, 'scale', [(f0, (0.94, 0.94, 0.94)), (f0 + 16, (1, 1, 1))])
    keys(p, 'rotation_euler', [(96, (0, 0, rad(-55))), (122, (0, 0, rad(-22))), (140, (0, 0, rad(-14))), (f0, (0, 0, rad(-10))), (f0 + 16, (0, 0, rad(-16 if side < 0 else -6)))])
for ob, f in ((panelA, 228), (phone, 300)):
    loc = ob.matrix_world.translation.copy()
    fc_loc = [fc for fc in ob.animation_data.action.fcurves if fc.data_path == 'location']
    end = tuple(fc.evaluate(f) for fc in sorted(fc_loc, key=lambda c: c.array_index))
    keys(ob, 'location', [(f, end), (f + 16, (end[0], end[1], end[2] - 2.8))])
    for fc in fc_loc: fc.keyframe_points[-2].interpolation = 'BACK'; fc.keyframe_points[-2].easing = 'EASE_IN'; fc.keyframe_points[-2].back = 1.2

# notifications: three real rows fly out of panel C towards the camera on the beats
NOTE_W, NOTE_H = 0.9, 0.9 * 62 / 300
PC = P0 + Vector((SPREAD, 0.42, 0))
for i, f in enumerate((319, 338, 356)):
    card = rounded_box(f'note{i}', NOTE_W + 0.04, 0.03, NOTE_H + 0.04, 0.05, materials=[M_WHITE_CARD], loc=tuple(PC))
    face = upright(f'note{i}_face', NOTE_W, NOTE_H, img_mat(f'note{i}_m', os.path.join(A, f'note{i}.png'), emit=1.0, rough=0.3, screen=True), loc=(0, -0.0155, 0)); face.parent = card
    end = PC + Vector((0.86, -0.6 - i * 0.05, 0.4 - i * 0.34))
    card.scale = (0.001, 0.001, 0.001)
    keys(card, 'location', [(f - 1, tuple(PC + Vector((0, 0.05, 0.1)))), (f + 10, tuple(end))])
    keys(card, 'scale', [(f - 1, (0.001, 0.001, 0.001)), (f + 10, (1, 1, 1))])
    keys(card, 'rotation_euler', [(f - 1, (0, 0, 0)), (f + 10, (rad(4), 0, rad(-18)))])
    ease_in_last(card, 'BACK')

# studio camera: wordmark → phone → panel A → phone (checkout) → panel C
SA, SB = P0 + Vector((-SPREAD, 0.42, 0)), P0
camera('cam_studio', 36,
       [(75, (-6.6, -10.5, 1.6)), (106, (-5.6, -9.7, 1.45)), (128, (2.6, -7.6, 1.6)), (150, (3.3, -6.1, 1.4)),
        (178, (SA.x - 1.55, SA.y - 4.0, 1.35)), (222, (SA.x - 1.4, SA.y - 3.7, 1.3)),
        (242, (SB.x - 1.55, SB.y - 4.0, 1.35)), (296, (SB.x - 1.4, SB.y - 3.7, 1.3)),
        (318, (PC.x - 1.5, PC.y - 4.9, 1.4)), (374, (PC.x - 1.35, PC.y - 4.6, 1.35))],
       [(75, (-3.6, 0, 1.0)), (106, (-3.3, 0, 0.95)), (128, (P0.x - 0.6, P0.y, 1.15)), (150, (P0.x - 0.2, P0.y, 1.15)),
        (178, (SA.x - 0.78, SA.y, 1.15)), (222, (SA.x - 0.78, SA.y, 1.13)),
        (242, (SB.x - 0.78, SB.y, 1.15)), (296, (SB.x - 0.78, SB.y, 1.13)),
        (318, (PC.x - 0.7, PC.y - 0.3, 1.1)), (374, (PC.x - 0.65, PC.y - 0.3, 1.08))], 75, 374)

# ---- bar 6: laptop opens on the website, phone with the Bag beside it (x = 13)
L0 = Vector((13, 0.6, 0))
lap = empty('laptop', tuple(L0)); lap.rotation_euler = (0, 0, rad(-18))
base = rounded_box('lap_base', 2.6, 1.75, 0.07, 0.03, segs=4, materials=[M_ALU], loc=(0, 0, 0.035)); base.parent = lap
kb = plane('lap_keys', 2.5, 1.68, img_mat('keys_m', os.path.join(A, 'keyboard.png'), emit=0.0, rough=0.4), loc=(0, 0, 0.0705)); kb.parent = lap
hinge = empty('lap_hinge', (0, 0.86, 0.07)); hinge.parent = lap
lid = rounded_box('lap_lid', 2.6, 0.05, 1.72, 0.03, segs=4, materials=[M_ALU], loc=(0, 0.025, 0.86)); lid.parent = hinge
bezel = rounded_box('lap_bezel', 2.56, 0.004, 1.68, 0.025, segs=3, materials=[M_PHONE_GLASS], loc=(0, -0.002, 0.86)); bezel.parent = hinge
lcd = upright('lap_screen', 2.44, 2.44 * 800 / 1280, img_mat('lap_screen_m', os.path.join(A, 'desktop.png'), emit=1.0, rough=0.2, screen=True), loc=(0, -0.0045, 0.88)); lcd.parent = hinge
keys(hinge, 'rotation_euler', [(378, (rad(90), 0, 0)), (402, (rad(-16), 0, 0))])
ease_in_last(hinge, 'BACK')
m_bag = img_mat('bag_screen', os.path.join(A, '02-bag.png'), emit=1.0, rough=0.25, screen=True)
phone2, _ = phone_model('phone2', m_bag, (L0.x + 1.65, L0.y - 0.9, 1.0))
phone2.rotation_euler = (0, 0, rad(-26))
keys(phone2, 'location', [(384, (L0.x + 1.65, L0.y - 0.9, -1.4)), (404, (L0.x + 1.65, L0.y - 0.9, 0.95))])
camera('cam_laptop', 38, [(375, (L0.x + 0.6, L0.y - 6.9, 2.4)), (449, (L0.x - 2.4, L0.y - 6.5, 1.9))],
       [(375, (L0.x - 0.5, L0.y, 0.95)), (449, (L0.x - 0.7, L0.y, 0.95))], 375, 449)

# ---- bar 7: six real pairs in acrylic blocks (x = 26)
D0 = Vector((26, 1.5, 0))
order = ['kayano', 'pegasus', 'metcon', 'ghost', 'clifton', 'af1']
for i, k in enumerate(order):
    a = rad(-30 + i * 12); cx = D0.x + 7.0 * math.sin(a); cy = D0.y + 7.0 * (1 - math.cos(a))
    pl = rounded_box(f'plinth_{k}', 1.0, 0.8, 0.75, 0.04, segs=3, materials=[M_PLINTH], loc=(cx, cy, 0.375)); pl.rotation_euler.z = a
    blk = rounded_box(f'block_{k}', 0.92, 0.32, 0.7, 0.04, segs=4, materials=[M_ACRYLIC], loc=(cx, cy, 1.1)); blk.rotation_euler.z = a
    img = bpy.data.images.load(os.path.join(A, 'shoes', f'{k}.png')); asp = img.size[1] / img.size[0]
    pr = upright(f'print_{k}', 0.84, 0.84 * asp, img_mat(f'print_{k}_m', img.filepath, emit=0.2, alpha=True, rough=0.5), loc=(0, 0, 0)); pr.parent = blk
    f = 459 + i * 9
    keys(blk, 'location', [(f, (cx, cy, 4.2)), (f + 12, (cx, cy, 1.1))])
    ease_in_last(blk, 'BOUNCE')
camera('cam_blocks', 36, [(450, (D0.x - 4.4, D0.y - 6.0, 1.75)), (524, (D0.x + 0.4, D0.y - 6.4, 1.7))],
       [(450, (D0.x - 2.8, D0.y + 1.0, 1.45)), (524, (D0.x + 1.4, D0.y + 1.0, 1.45))], 450, 524)

# ================================================================ bar 8: dark finale (x = -200, y = 60)
F0 = Vector((-200, 60, 0))
WM2, wm2_w = wordmark('wm2', (M_PAPER_GLOW, M_BLAZE, M_PAPER_GLOW), (F0.x - 1.5, F0.y, 0), size=1.3)
for i, (ob, ox) in enumerate(WM2):
    f = 528 + i * 5; base = ob.location.copy()
    keys(ob, 'location', [(f, (base.x, base.y, -1.6)), (f + 14, tuple(base))])
    ease_in_last(ob, 'BACK')
fpl = rounded_box('fin_plinth', 2.0, 1.3, 0.8, 0.05, segs=3, materials=[M_GRAPHITE], loc=(F0.x + 2.9, F0.y + 0.4, 0.4))
fin, fin_shoe = shoe_rig('fin', 2.3)
keys(fin, 'location', [(525, (F0.x + 2.9, F0.y + 0.4, 0.8 + 0.46))])
keys(fin, 'rotation_euler', [(525, (0, 0, rad(-150))), (599, (0, 0, rad(-48)))])
keys(fpl, 'rotation_euler', [(525, (0, 0, rad(-120))), (599, (0, 0, rad(-30)))])
area('fin_rim', 520, 2.5, (F0.x + 2.9, F0.y + 2.6, 3.8), (F0.x + 2.9, F0.y, 1.3), color=BLAZE[:3], shape='DISK')
area('fin_rim2', 260, 4, (F0.x - 1.5, F0.y + 3.0, 4.0), (F0.x - 1.5, F0.y, 0.6), color=BLAZE[:3], shape='DISK')
spot('fin_key', 1800, (F0.x - 1.0, F0.y - 6, 6), (F0.x + 0.8, F0.y, 0.6), size=70, blend=0.9, radius=1.0)
camera('cam_finale', 40, [(525, (F0.x - 0.3, F0.y - 12.6, 1.9)), (599, (F0.x - 0.1, F0.y - 11.4, 1.7))],
       [(525, (F0.x - 0.3, F0.y, 1.05)), (599, (F0.x - 0.1, F0.y, 1.05))], 525, 599)

# ---------------------------------------------------------------- per-frame metadata for render.py and the overlay
meta = {'cams': [(s, e, ob.name) for s, e, ob in CAMS],
        'seq': {'phone_screen': [60, 380, os.path.join(HERE, 'seq', 'phone')], 'panelA_screen': [140, 300, os.path.join(HERE, 'seq', 'panelA')]},
        'anchors': {'wm2': [WM2[0][0].name, wm2_w]}}
with open(os.path.join(HERE, 'scene.json'), 'w') as fh: json.dump(meta, fh, indent=1)
sc.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'scene.blend'))
print('built scene.blend')
