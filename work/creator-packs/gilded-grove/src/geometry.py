"""Original, deterministic geometry helpers for Gilded Grove. Blender 4.5+."""
import math
import bpy
import bmesh
from mathutils import Vector

PALETTES = {
    "Teal": ["704C35", "352C2D", "A8794C", "147F86", "58CECA", "D6A54D", "FFE2A1", "333D4C", "627079", "A6B6B7", "F1E2C2", "BE5941", "62B982", "9872D7", "9C684A", "202934"],
    "Ember": ["704C35", "352C2D", "A8794C", "AC4B32", "F8A05A", "D6A54D", "FFE2A1", "333D4C", "627079", "A6B6B7", "F1E2C2", "BE5941", "62B982", "9872D7", "9C684A", "202934"],
    "Amethyst": ["704C35", "352C2D", "A8794C", "674D91", "BD93EF", "D6A54D", "FFE2A1", "333D4C", "627079", "A6B6B7", "F1E2C2", "BE5941", "62B982", "9872D7", "9C684A", "202934"],
}
COLOR_KEYS = "wood darkwood woodlight teal teallight gold goldlight iron stone stonelight cream red emerald amethyst leather black".split()


def linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rgba(code):
    return tuple(linear(int(code[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def material(key):
    if key not in COLOR_KEYS:
        raise ValueError(f"Unknown palette material: {key}")
    name = "GG_" + key
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        color = rgba(PALETTES["Teal"][COLOR_KEYS.index(key)])
        m.diffuse_color = color
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.55
        bsdf.inputs["Metallic"].default_value = 0.0
    return m


class Asset:
    def __init__(self, name, category, description):
        self.name = name
        self.category = category
        self.description = description
        self.objects = []
        self.pivots = {"Body": (0, 0, 0)}
        self.notes = {}

    def _finish(self, obj, name, color, role, bevel=0):
        obj.name = self.name + "__" + name
        obj["gg_asset"] = self.name
        obj["gg_role"] = role
        obj.data.materials.append(material(color))
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel > 0:
            mod = obj.modifiers.new("Crafted edge", "BEVEL")
            mod.width = bevel
            mod.segments = 1
            mod.affect = "EDGES"
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # Flat polygon normals deliberately preserve the low-poly art direction.
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
        self.objects.append(obj)
        obj.select_set(False)
        return obj

    def box(self, name, size_xyz, loc_xyz, color="wood", bevel=0.04,
            rotation=(0, 0, 0), role="Body"):
        if min(size_xyz) <= 0:
            raise ValueError(f"Non-positive box size: {name}")
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc_xyz, rotation=rotation)
        obj = bpy.context.object
        obj.scale = size_xyz
        return self._finish(obj, name, color, role, min(bevel, min(size_xyz) * 0.24))

    def cylinder(self, name, radius, depth, loc, color="gold", vertices=12,
                 rotation=(0, 0, 0), role="Body"):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                            depth=depth, location=loc, rotation=rotation)
        return self._finish(bpy.context.object, name, color, role)

    def mesh(self, name, verts, faces, color="wood", loc=(0, 0, 0),
             rotation=(0, 0, 0), role="Body"):
        data = bpy.data.meshes.new(self.name + "__" + name)
        data.from_pydata(verts, [], faces)
        data.update()
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(data)
        bm.free()
        obj = bpy.data.objects.new(data.name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = loc
        obj.rotation_euler = rotation
        bpy.ops.object.select_all(action="DESELECT")
        return self._finish(obj, name, color, role)

    def gem(self, name, radius, height, loc, color="teal", rotation=(0, 0, 0), role="Body"):
        sides = 6
        verts = []
        for z, r in ((0, radius * .72), (height * .22, radius), (height * .72, radius * .7)):
            verts.extend((r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides), z) for i in range(sides))
        verts.append((0, 0, height))
        faces = [tuple(reversed(range(sides)))]
        for level in range(2):
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((level * sides + i, level * sides + j, (level + 1) * sides + j, (level + 1) * sides + i))
        faces.extend((12 + i, 12 + (i + 1) % sides, 18) for i in range(sides))
        return self.mesh(name, verts, faces, color, loc, rotation, role)

    def torus(self, name, major_radius, minor_radius, loc, color="gold", rotation=(0, 0, 0),
              role="Body", major_segments=12, minor_segments=4):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.mesh.primitive_torus_add(major_segments=major_segments,
            minor_segments=minor_segments, major_radius=major_radius,
            minor_radius=minor_radius, location=loc, rotation=rotation)
        return self._finish(bpy.context.object, name, color, role)

    def beam(self, name, start, end, width, color="wood", depth=None, role="Body"):
        direction = Vector(end) - Vector(start)
        if direction.length <= 0:
            raise ValueError(f"Zero length beam: {name}")
        obj = self.box(name, (width, depth or width, direction.length),
                       (Vector(start) + Vector(end)) / 2, color, bevel=min(width * .12, .035), role=role)
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
        return obj

    def pivot(self, role, loc):
        self.pivots[role] = tuple(loc)


def bounds(objects):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return [min(v[i] for v in pts) for i in range(3)], [max(v[i] for v in pts) for i in range(3)]


def ring_mesh(rings, sides=12):
    """Closed, flat-shaded lathe around Z. rings is list[(height, radius)]."""
    verts = [(r * math.cos(i * math.tau / sides), r * math.sin(i * math.tau / sides), z)
             for z, r in rings for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    for level in range(len(rings) - 1):
        faces.extend((level*sides+i, level*sides+(i+1)%sides,
                      (level+1)*sides+(i+1)%sides, (level+1)*sides+i) for i in range(sides))
    faces.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    return verts, faces
