# A white leather low-top court sneaker in the Air Force 1 style, modelled from code (no Nike marks).
# build_shoe(prefix) returns an empty that parents the whole shoe; the shoe is 1.0 long along +X
# (heel at x = 0, toe at x = 1), stands on z = 0 and is centred on y = 0.
import bpy, bmesh, math
from mathutils import Vector

def _hermite(ctrl, u):
    """Smooth curve through (u, v) control points (Catmull-Rom tangents, clamped at the ends)."""
    if u <= ctrl[0][0]: return ctrl[0][1]
    if u >= ctrl[-1][0]: return ctrl[-1][1]
    i = max(j for j in range(len(ctrl) - 1) if ctrl[j][0] <= u)
    (u0, v0), (u1, v1) = ctrl[i], ctrl[i + 1]
    def tan(k):
        a, b = ctrl[max(k - 1, 0)], ctrl[min(k + 1, len(ctrl) - 1)]
        return (b[1] - a[1]) / (b[0] - a[0]) if b[0] != a[0] else 0.0
    h = u1 - u0; t = (u - u0) / h; m0, m1 = tan(i) * h, tan(i + 1) * h
    t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * v0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * v1 + (t3 - t2) * m1

# footprint half-width, centre line, sole and upper profiles (all as fractions of the shoe length)
W_CTRL = [(0, 0.0), (0.008, 0.05), (0.03, 0.095), (0.08, 0.118), (0.2, 0.124), (0.42, 0.128), (0.6, 0.158),
          (0.74, 0.168), (0.85, 0.16), (0.92, 0.137), (0.965, 0.1), (0.99, 0.045), (1.0, 0.0)]
H_CTRL = [(0, 0.15), (0.025, 0.215), (0.08, 0.232), (0.2, 0.238), (0.36, 0.236), (0.43, 0.215), (0.52, 0.183),
          (0.62, 0.148), (0.72, 0.115), (0.82, 0.1), (0.9, 0.086), (0.96, 0.064), (1.0, 0.025)]
W = lambda u: _hermite(W_CTRL, u)
H = lambda u: _hermite(H_CTRL, u)
Yc = lambda u: 0.03 * (u - 0.35) ** 2 - 0.004
Zb = lambda u: 0.012 * max(0.0, (0.1 - u) / 0.1) ** 2 + 0.065 * max(0.0, (u - 0.66) / 0.34) ** 2.1
T = lambda u: 0.112 - 0.022 * u
Zt = lambda u: Zb(u) + T(u)
P_EXP = lambda u: 0.55 + 0.25 * max(0.0, (u - 0.75) / 0.25)

def upper_pt(u, th, off=0.0):
    """Point on the upper: u along the shoe, th from 0 (lateral) over the top to pi (medial)."""
    a = W(u) * 0.955 - 0.003
    s = max(math.sin(th), 0.0)
    y = Yc(u) + a * math.cos(th) * (1 + 0.05 * s)
    z = Zt(u) - 0.012 + H(u) * s ** P_EXP(u)
    p = Vector((u, y, z))
    if off:
        e = 1e-3
        du = (Vector((u + e, *upper_yz(u + e, th))) - Vector((u - e, *upper_yz(u - e, th))))
        dt = (Vector((u, *upper_yz(u, th + e))) - Vector((u, *upper_yz(u, th - e))))
        n = dt.cross(du); n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
        p += n * off
    return p

def upper_yz(u, th):
    a = W(u) * 0.955 - 0.003; s = max(math.sin(th), 0.0)
    return (Yc(u) + a * math.cos(th) * (1 + 0.05 * s), Zt(u) - 0.012 + H(u) * s ** P_EXP(u))

def _u(s):  # denser sampling at heel and toe
    return 0.5 - 0.5 * math.cos(math.pi * s)

# ---------------------------------------------------------------- materials
def _leather(name, color, rough=0.42, bump=0.06, perforated=False):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; N = nt.nodes
    b = N['Principled BSDF']; b.inputs['Base Color'].default_value = color; b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = 0.12; b.inputs['Coat Roughness'].default_value = 0.3
    tc = N.new('ShaderNodeTexCoord')
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 420; nz.inputs['Detail'].default_value = 6
    nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = bump
    nt.links.new(nz.outputs['Fac'], bp.inputs['Height']); nt.links.new(bp.outputs['Normal'], b.inputs['Normal'])
    if perforated:   # toe-box perforation dots
        vo = N.new('ShaderNodeTexVoronoi'); vo.inputs['Scale'].default_value = 70; vo.inputs['Randomness'].default_value = 0.0
        nt.links.new(tc.outputs['Object'], vo.inputs['Vector'])
        lt = N.new('ShaderNodeMath'); lt.operation = 'LESS_THAN'; lt.inputs[1].default_value = 0.16
        nt.links.new(vo.outputs['Distance'], lt.inputs[0])
        mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.inputs['A'].default_value = color; mx.inputs['B'].default_value = (0.22, 0.22, 0.21, 1)
        nt.links.new(lt.outputs[0], mx.inputs['Factor']); nt.links.new(mx.outputs['Result'], b.inputs['Base Color'])
        bp2 = N.new('ShaderNodeBump'); bp2.inputs['Strength'].default_value = 0.4; bp2.invert = True
        nt.links.new(lt.outputs[0], bp2.inputs['Height']); nt.links.new(bp.outputs['Normal'], bp2.inputs['Normal'])
        nt.links.new(bp2.outputs['Normal'], b.inputs['Normal'])
    return m

def _plain(name, color, rough=0.5, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = color
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    return m

# ---------------------------------------------------------------- geometry helpers
def _obj(name, me, parent, mats):
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    for m in mats: me.materials.append(m)
    ob.parent = parent; return ob

def _grid(name, pts, parent, mats, cyclic_v=False, smooth=True):
    """pts[i][j] -> quad mesh."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    V = [[bm.verts.new(p) for p in row] for row in pts]
    nj = len(pts[0])
    for i in range(len(pts) - 1):
        for j in range(nj - (0 if cyclic_v else 1)):
            j2 = (j + 1) % nj
            try:
                f = bm.faces.new((V[i][j], V[i + 1][j], V[i + 1][j2], V[i][j2])); f.smooth = smooth
            except ValueError: pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    bm.to_mesh(me); bm.free()
    return _obj(name, me, parent, mats)

def _solidify(ob, thickness, offset=-1.0, mat_off=0, rim=True):
    m = ob.modifiers.new('solid', 'SOLIDIFY'); m.thickness = thickness; m.offset = offset
    m.material_offset = mat_off; m.material_offset_rim = mat_off; m.use_rim = rim; m.use_even_offset = True
    return m

def _tube(name, pts, radius, parent, mat, cyclic=False, flat=1.0):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = radius; cu.bevel_resolution = 4
    cu.resolution_u = 6; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts): p.co = (q.x, q.y, q.z, 1)
    sp.use_cyclic_u = cyclic; sp.use_smooth = True
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(ob); ob.parent = parent
    return ob

# ---------------------------------------------------------------- the shoe
def build_shoe(prefix, accent=(0.7605, 0.0529, 0.0232, 1)):
    root = bpy.data.objects.new(prefix, None); bpy.context.scene.collection.objects.link(root)
    WHITE = (0.74, 0.74, 0.72, 1)
    M = {
        'upper': _leather(prefix + '_leather', WHITE),
        'panel': _leather(prefix + '_panel', (0.76, 0.76, 0.745, 1), rough=0.36),
        'toe': _leather(prefix + '_toe', WHITE, perforated=True),
        'lining': _plain(prefix + '_lining', (0.62, 0.62, 0.6, 1), rough=0.8),
        'sole': _leather(prefix + '_sole', (0.78, 0.775, 0.75, 1), rough=0.55, bump=0.03),
        'insole': _plain(prefix + '_insole', (0.16, 0.16, 0.155, 1), rough=0.8),
        'groove': _plain(prefix + '_groove', (0.55, 0.55, 0.53, 1), rough=0.6),
        'lace': _leather(prefix + '_lace', (0.78, 0.78, 0.76, 1), rough=0.75, bump=0.15),
        'accent': _leather(prefix + '_accent', accent, rough=0.4),
    }
    root['materials'] = [m.name for m in M.values()]

    # --- cupsole: the footprint extruded, with a bulging sidewall and a stitch groove
    NS = 110
    outline = [(_u(i / (NS - 1)), +1) for i in range(NS)] + [(_u(i / (NS - 1)), -1) for i in range(NS - 2, 0, -1)]
    def fp(u, side): return Vector((u, Yc(u) + side * W(u), 0))
    ring = [fp(u, s) for u, s in outline]
    normals = []
    for k in range(len(ring)):
        a, b = ring[k - 1], ring[(k + 1) % len(ring)]
        t = (b - a); n = Vector((t.y, -t.x, 0)); n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 0))
        if n.dot(ring[k] - Vector((ring[k].x, Yc(ring[k].x), 0))) < 0: n = -n
        normals.append(n)
    LV = [(0.0, -0.012), (0.06, -0.002), (0.28, 0.003), (0.48, 0.002), (0.5, -0.0025), (0.52, 0.002), (0.78, 0.003), (0.95, 0.0), (1.0, -0.004)]
    me = bpy.data.meshes.new(prefix + '_sole'); bm = bmesh.new()
    rings = []
    for f, ro in LV:
        rings.append([bm.verts.new(ring[k] + normals[k] * ro + Vector((0, 0, Zb(outline[k][0]) + f * T(outline[k][0])))) for k in range(len(ring))])
    n = len(ring)
    for i in range(len(rings) - 1):
        for k in range(n):
            fa = bm.faces.new((rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k])); fa.smooth = True
            fa.material_index = 1 if (i == 4 or i == 3) else 0   # the groove band reads as a darker stitch line
    bot = bm.faces.new(list(reversed(rings[0]))); bot.material_index = 0
    top = bm.faces.new(rings[-1]); top.material_index = 2
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(me); bm.free()
    sole = _obj(prefix + '_sole', me, root, [M['sole'], M['groove'], M['insole']])

    # --- upper: lofted cross-sections, ankle opening cut out of the top
    NU, NT = 150, 72
    us = [_u(0.002 + 0.996 * i / (NU - 1)) for i in range(NU)]
    ths = [math.pi * j / (NT - 1) for j in range(NT)]
    pts = [[upper_pt(u, th) for th in ths] for u in us]
    up = _grid(prefix + '_upper', pts, root, [M['upper'], M['lining']])
    CX, RX, RY = 0.205, 0.178, 0.098
    inside = lambda x, y: ((x - CX) / RX) ** 2 + ((y - Yc(x)) / RY) ** 2 < 1.0
    bm = bmesh.new(); bm.from_mesh(up.data)
    kill = [f for f in bm.faces if inside(f.calc_center_median().x, f.calc_center_median().y) and f.calc_center_median().z > Zt(f.calc_center_median().x) + 0.06]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    rim = [e for e in bm.edges if e.is_boundary and e.verts[0].co.z > 0.2 and e.verts[1].co.z > 0.2]
    rim_pts = sorted({v.co.copy().freeze() for e in rim for v in e.verts}, key=lambda p: math.atan2(p.y - Yc(p.x), p.x - CX))
    bm.to_mesh(up.data); bm.free()
    _solidify(up, 0.014, 1.0, mat_off=1)
    sub = up.modifiers.new('sub', 'SUBSURF'); sub.levels = 1; sub.render_levels = 1

    # padded collar around the opening
    rp = [Vector(p) for p in rim_pts]
    for _ in range(6):
        rp = [(rp[i - 1] + rp[i] * 2 + rp[(i + 1) % len(rp)]) / 4 for i in range(len(rp))]
    rp = [p + Vector((0, 0, 0.004)) for p in rp]
    _tube(prefix + '_collar', rp, 0.024, root, M['upper'], cyclic=True)

    # --- overlay panels (each a thin shell just off the upper)
    def panel(name, u0, u1, th_rng, off, mat, nu=60, nt=24, thick=0.007):
        rows = []
        for i in range(nu):
            u = u0 + (u1 - u0) * i / (nu - 1); t0, t1 = th_rng(u)
            rows.append([upper_pt(u, t0 + (t1 - t0) * j / (nt - 1), off) for j in range(nt)])
        ob = _grid(prefix + '_' + name, rows, root, [mat, M['lining']]); _solidify(ob, thick, 0.0)
        bv = ob.modifiers.new('bevel', 'BEVEL'); bv.width = 0.0025; bv.segments = 2; bv.limit_method = 'ANGLE'
        return ob
    inv = lambda k, u: math.asin(min(1.0, k ** (1 / P_EXP(u))))
    # toe cap with perforations
    rows = []
    for j in range(44):
        th = math.pi * j / 43; u0 = 0.865 - 0.085 * math.sin(th) ** 1.5
        rows.append([upper_pt(u0 + (0.985 - u0) * i / 39, th, 0.004) for i in range(40)])
    tc = _grid(prefix + '_toecap', rows, root, [M['toe'], M['lining']]); _solidify(tc, 0.007, 0.0)
    tc.modifiers.new('bevel', 'BEVEL').width = 0.0025
    # mudguard: a low band along both sides from mid-foot to the toe cap
    for side, nm in ((0, 'mud_l'), (1, 'mud_m')):
        panel(nm, 0.4, 0.84, (lambda u, s=side: (0.0, inv(0.1 + 0.3 * math.sin(0.5 * math.pi * (u - 0.4) / 0.44), u)) if s == 0 else (math.pi - inv(0.1 + 0.3 * math.sin(0.5 * math.pi * (u - 0.4) / 0.44), u), math.pi)), 0.0045, M['panel'])
    # heel counter wrapping the back, and the accent heel tab
    for side, nm in ((0, 'heel_l'), (1, 'heel_m')):
        panel(nm, 0.022, 0.3, (lambda u, s=side: (0.0, min(1.45, inv(max(0.06, 0.7 * (1 - (u / 0.3) ** 1.6)), u))) if s == 0 else (math.pi - min(1.45, inv(max(0.06, 0.7 * (1 - (u / 0.3) ** 1.6)), u)), math.pi)), 0.0045, M['accent'])
    # eyestays either side of the laces
    for side, nm in ((0, 'eye_l'), (1, 'eye_m')):
        panel(nm, 0.4, 0.67, (lambda u, s=side: (math.pi / 2 - 0.95, math.pi / 2 - 0.42) if s == 0 else (math.pi / 2 + 0.42, math.pi / 2 + 0.95)), 0.005, M['panel'], nu=40, nt=10)

    # --- tongue: a padded slab rising out of the throat and leaning back over the opening
    tr = []
    for i in range(30):
        t = i / 29; x = 0.43 - 0.13 * t
        zc = Zt(x) - 0.012 + H(x) + 0.004 + 0.05 * t ** 1.4
        b = 0.078 + 0.006 * math.sin(math.pi * t)
        tr.append([Vector((x - 0.01 * (j / 10 - 1) ** 2, Yc(x) + b * (j / 10 - 1), zc - 0.03 * (j / 10 - 1) ** 2)) for j in range(21)])
    tg = _grid(prefix + '_tongue', tr, root, [M['upper'], M['lining']]); _solidify(tg, 0.026, 1.0, mat_off=1)
    tg.modifiers.new('sub', 'SUBSURF').levels = 2
    # SoleCraft tongue label
    lab = []
    for i in range(6):
        t = 0.55 + 0.3 * i / 5; x = 0.43 - 0.13 * t; zc = Zt(x) - 0.012 + H(x) + 0.004 + 0.05 * t ** 1.4 + 0.003
        lab.append([Vector((x, Yc(x) + 0.032 * (j / 3 - 1), zc - 0.03 * (0.032 / 0.07 * (j / 3 - 1)) ** 2)) for j in range(7)])
    _grid(prefix + '_label', lab, root, [M['accent']])

    # --- laces, criss-crossed between the eyestays
    rows = [0.425 + 0.045 * i for i in range(6)]
    def lace_pt(x, side, lift):
        th = math.pi / 2 - side * 0.62
        p = upper_pt(x, th, 0.012 + lift); return p
    for i in range(len(rows) - 1):
        for k, (s0, s1) in enumerate(((1, -1), (-1, 1))):
            a, b = rows[i], rows[i + 1]; seg = []
            for j in range(12):
                t = j / 11; x = a + (b - a) * t; side = s0 + (s1 - s0) * t
                p = lace_pt(x, side, 0.0); p.z += 0.012 * math.sin(math.pi * t) + 0.004 * k
                seg.append(p)
            _tube(f'{prefix}_lace{i}{k}', seg, 0.0085, root, M['lace'])
    # top bar and short tails at the last eyelets
    _tube(prefix + '_lace_top', [lace_pt(rows[0], s, 0.004) for s in (1, 0.5, 0, -0.5, -1)], 0.0085, root, M['lace'])
    for s in (1, -1):
        p0 = lace_pt(rows[0], s * 0.9, 0.006)
        _tube(f'{prefix}_tail{s}', [p0, p0 + Vector((-0.03, s * 0.02, 0.025)), p0 + Vector((-0.07, s * 0.05, 0.0)), p0 + Vector((-0.1, s * 0.09, -0.06))], 0.0085, root, M['lace'])
    return root
