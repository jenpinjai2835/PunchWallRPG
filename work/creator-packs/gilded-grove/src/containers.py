"""Eight original Gilded Grove containers; Z up, front -Y, ground Z=0.

Every storage volume is built from walls and a floor.  Opening/removing a Lid
therefore reveals a usable interior, not a solid decorative cube.  Geometry is
authored here without imported models, textures, fonts, or executable behavior.
"""

from math import cos, sin, pi, sqrt

from geometry import Asset


def _prism(a, name, polygon_yz, xmin, xmax, color, role="Body"):
    """Solid polygon extruded along X, useful for arched end boards."""
    n = len(polygon_yz)
    verts = [(xmin, y, z) for y, z in polygon_yz]
    verts += [(xmax, y, z) for y, z in polygon_yz]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n)
              for i in range(n)]
    return a.mesh(name, verts, faces, color=color, role=role)


def _ring(a, name, radius, thickness, zmin, zmax, color="gold", n=12,
          role="Body", phase=0.0):
    """Flat broad metal hoop, with genuine open center."""
    verts = []
    for z, r in ((zmin, radius), (zmax, radius),
                 (zmin, radius - thickness), (zmax, radius - thickness)):
        verts += [(r * cos(phase + i * 2 * pi / n),
                   r * sin(phase + i * 2 * pi / n), z) for i in range(n)]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces += [(i, j, n + j, n + i),
                  (2 * n + j, 2 * n + i, 3 * n + i, 3 * n + j),
                  (n + i, n + j, 3 * n + j, 3 * n + i),
                  (j, i, 2 * n + i, 2 * n + j)]
    return a.mesh(name, verts, faces, color=color, role=role)


def _rect_walls(a, width, depth, zmin, zmax, color="wood", thickness=0.14,
                planks=3, prefix="Body"):
    """Horizontal board walls around an empty rectangular volume."""
    dz = (zmax - zmin) / planks
    a.box(prefix + "_Floor", (width, depth, 0.14),
          (0, 0, zmin + 0.07), color="darkwood", bevel=0.025)
    for i in range(planks):
        z = zmin + (i + 0.5) * dz
        c = "woodlight" if color == "wood" and i == 1 else color
        for side in (-1, 1):
            label = "Front" if side == -1 else "Back"
            a.box(f"{prefix}_{label}_Board_{i + 1}",
                  (width, thickness, dz - 0.016),
                  (0, side * (depth - thickness) / 2, z), color=c,
                  bevel=0.025)
            label = "Left" if side == -1 else "Right"
            a.box(f"{prefix}_{label}_Board_{i + 1}",
                  (thickness, depth - 2 * thickness, dz - 0.016),
                  (side * (width - thickness) / 2, 0, z), color=color,
                  bevel=0.025)


def _rect_trim(a, name, width, depth, z, color="gold", thickness=0.08,
               height=0.10, role="Body"):
    for y, label in ((-depth / 2, "Front"), (depth / 2, "Back")):
        a.box(f"{name}_{label}", (width + thickness, thickness, height),
              (0, y, z), color=color, bevel=0.018, role=role)
    for x, label in ((-width / 2, "Left"), (width / 2, "Right")):
        a.box(f"{name}_{label}", (thickness, depth - thickness, height),
              (x, 0, z), color=color, bevel=0.018, role=role)


def _arch_lid(a, width, depth, base, rise, color="teal", segments=8):
    """Segmented thick half-ellipse shell with matching solid end boards."""
    radius = depth / 2
    for i in range(segments):
        p, q = i * pi / segments, (i + 1) * pi / segments
        section = [(radius * cos(p), base + rise * sin(p)),
                   (radius * cos(q), base + rise * sin(q)),
                   ((radius - 0.10) * cos(q), base + (rise - 0.10) * sin(q)),
                   ((radius - 0.10) * cos(p), base + (rise - 0.10) * sin(p))]
        _prism(a, f"Lid_Curved_Plank_{i + 1}", section,
               -width / 2, width / 2,
               "teallight" if color == "teal" and i in (2, 5) else color,
               role="Lid")
        for sign in (-1, 1):
            x = sign * width * 0.33
            outer = [((radius + 0.025) * cos(p), base + (rise + 0.025) * sin(p)),
                     ((radius + 0.025) * cos(q), base + (rise + 0.025) * sin(q)),
                     (radius * cos(q), base + rise * sin(q)),
                     (radius * cos(p), base + rise * sin(p))]
            _prism(a, f"Lid_Band_{sign}_{i + 1}", outer,
                   x - 0.070, x + 0.070, "gold", role="Lid")
    cap = [(radius * cos(i * pi / segments), base + rise * sin(i * pi / segments))
           for i in range(segments + 1)]
    _prism(a, "Lid_Left_End", cap, -width / 2, -width / 2 + 0.10,
           "darkwood", role="Lid")
    _prism(a, "Lid_Right_End", cap, width / 2 - 0.10, width / 2,
           "darkwood", role="Lid")
    _rect_trim(a, "Lid_Rim", width, depth, base, height=0.085, role="Lid")
    a.pivot("Lid", (0, depth / 2, base))


def _feet(a, width, depth, height=0.22):
    for ix in (-1, 1):
        for iy in (-1, 1):
            a.box(f"Foot_{ix}_{iy}", (0.32, 0.32, height),
                  (ix * (width / 2 - 0.22), iy * (depth / 2 - 0.20),
                   height / 2), color="darkwood", bevel=0.06)


def _latch(a, y, z, height=0.38):
    a.box("Lock_Escutcheon", (0.32, 0.095, height), (0, y, z),
          color="gold", bevel=0.045)
    a.box("Lock_Keyhole", (0.045, 0.010, height * 0.27),
          (0, y - 0.052, z - 0.025), color="black", bevel=0.01)
    a.cylinder("Lock_Keyhole_Round", 0.048, 0.012,
               (0, y - 0.056, z + 0.025), color="black", vertices=8,
               rotation=(pi / 2, 0, 0))


def _wayfarer():
    a = Asset("01_Wayfarer_Chest", "Containers",
              "Hollow walnut adventurer chest with teal barrel lid and brass straps.")
    _feet(a, 3.0, 1.90)
    _rect_walls(a, 3.0, 1.90, 0.18, 1.44, planks=3)
    _rect_trim(a, "Base_Band", 3.02, 1.92, 0.27, color="darkwood", height=0.18)
    _rect_trim(a, "Body_Rim", 3.02, 1.92, 1.39, height=0.09)
    for x in (-1.03, 1.03):
        a.box(f"Front_Strap_{x}", (0.14, 0.045, 1.10),
              (x, -0.967, 0.85), color="gold", bevel=0.018)
        a.cylinder(f"Hinge_{x}", 0.085, 0.34, (x, 0.97, 1.47),
                   color="iron", rotation=(0, pi / 2, 0))
    _arch_lid(a, 3.05, 1.98, 1.47, 0.64)
    _latch(a, -1.02, 1.22)
    a.box("Lid_Latch_Tongue", (0.115, 0.10, 0.18),
          (0, -1.04, 1.48), color="goldlight", bevel=0.018, role="Lid")
    for x in (-1.54, 1.54):
        a.torus(f"Carry_Ring_{x}", 0.19, 0.04, (x, 0, 1.05),
                color="iron", rotation=(0, pi / 2, 0))
    a.notes = {"interior": "Empty rectangular body and curved shell lid.",
               "animation": "Lid pivot is on the rear hinge; rotate local X to open."}
    return a


def _royal():
    a = Asset("02_Royal_Chest", "Containers",
              "Tall jewel-front royal strongbox, stepped feet and a faceted crown lid.")
    _feet(a, 2.65, 1.92, 0.30)
    _rect_walls(a, 2.65, 1.92, 0.27, 1.72, color="teal", planks=2)
    _rect_trim(a, "Lower_Skirt", 2.78, 2.05, 0.36, color="gold", height=0.20)
    _rect_trim(a, "Lower_Shadow", 2.69, 1.96, 0.53, color="darkwood", height=0.08)
    _rect_trim(a, "Upper_Cornice", 2.78, 2.05, 1.65, height=0.16)
    for x in (-1.27, 1.27):
        for y in (-0.91, 0.91):
            a.box(f"Corner_Pilaster_{x}_{y}", (0.20, 0.20, 1.11),
                  (x, y, 1.02), color="darkwood", bevel=0.04)
            a.box(f"Corner_Capital_{x}_{y}", (0.27, 0.27, 0.14),
                  (x, y, 1.50), color="gold", bevel=0.04)
    _arch_lid(a, 2.82, 2.10, 1.75, 0.86, segments=6)
    a.box("Royal_Seal_Backing", (0.61, 0.10, 0.61), (0, -1.015, 1.08),
          color="gold", bevel=0.045, rotation=(0, pi / 4, 0))
    a.gem("Royal_Emerald", 0.235, 0.22, (0, -1.11, 1.08),
          color="emerald", rotation=(pi / 2, 0, 0))
    a.box("Lid_Central_Strap", (0.21, 0.07, 0.30), (0, -1.08, 1.83),
          color="goldlight", bevel=0.025, role="Lid")
    a.box("Crown_Base", (0.68, 0.38, 0.09), (0, 0, 2.61),
          color="gold", bevel=0.035, role="Lid")
    for i, x in enumerate((-0.24, 0, 0.24)):
        a.gem(f"Crown_Finial_{i}", 0.085, 0.20 if i != 1 else 0.30,
              (x, 0, 2.75), color="goldlight", role="Lid")
    for x in (-0.94, 0.94):
        a.cylinder(f"Rear_Hinge_{x}", 0.085, 0.30, (x, 1.05, 1.75),
                   color="gold", rotation=(0, pi / 2, 0))
    a.notes = {"animation": "Lid contains crown, shell and front tongue; rear hinge pivot."}
    return a


def _shipping():
    a = Asset("03_Shipping_Crate", "Containers",
              "Free sample: braced shipping crate with removable plank top and hollow body.")
    _rect_walls(a, 2.30, 1.95, 0.08, 1.86, color="wood", planks=4)
    for x in (-1.09, 1.09):
        for y in (-0.93, 0.93):
            a.box(f"Corner_Post_{x}_{y}", (0.21, 0.21, 1.96),
                  (x, y, 0.98), color="darkwood", bevel=0.04)
    for z in (0.18, 1.72):
        _rect_trim(a, f"Teal_Rail_{z}", 2.34, 1.99, z,
                   color="teal", thickness=0.12, height=0.22)
    a.beam("Front_Diagonal_Brace", (-0.90, -1.045, 0.35),
           (0.90, -1.045, 1.57), 0.20, color="woodlight", depth=0.085)
    a.beam("Right_Diagonal_Brace", (1.215, -0.74, 0.35),
           (1.215, 0.74, 1.57), 0.18, color="woodlight", depth=0.085)
    for i in range(5):
        a.box(f"Lid_Plank_{i + 1}", (0.452, 1.99, 0.12),
              ((i - 2) * 0.462, 0, 1.93), color="wood", bevel=0.025, role="Lid")
    for y in (-0.65, 0.65):
        a.box(f"Lid_Batten_{y}", (2.36, 0.19, 0.10), (0, y, 2.035),
              color="teal", bevel=0.025, role="Lid")
    for x in (-0.93, 0.93):
        for z in (0.19, 1.72):
            a.cylinder(f"Front_Fastener_{x}_{z}", 0.045, 0.026,
                       (x, -1.062, z), color="gold", vertices=6,
                       rotation=(pi / 2, 0, 0))
    a.pivot("Lid", (0, 0, 1.87))
    a.notes = {"sample": "Included in the free three-model sampler.",
               "animation": "Lift Lid vertically; this top is removable, not hinged."}
    return a


def _open_crate():
    a = Asset("04_Open_Crate", "Containers",
              "Low slatted market crate with actual open handholds and a cream merchant plaque.")
    w, d = 2.80, 1.85
    a.box("Floor", (w - 0.20, d - 0.20, 0.16), (0, 0, 0.13),
          color="wood", bevel=0.025)
    for x in (-1.30, 1.30):
        for y in (-0.83, 0.83):
            a.box(f"Corner_{x}_{y}", (0.20, 0.20, 1.34),
                  (x, y, 0.67), color="darkwood", bevel=0.04)
    for i, z in enumerate((0.34, 0.70, 1.06)):
        for side in (-1, 1):
            a.box(f"Long_Slat_{side}_{i}", (w, 0.12, 0.27),
                  (0, side * 0.875, z), color="teal" if i == 2 else "woodlight",
                  bevel=0.025)
            if i < 2:
                a.box(f"End_Slat_{side}_{i}", (0.12, d - 0.25, 0.27),
                      (side * 1.34, 0, z), color="wood", bevel=0.025)
    for x in (-1.34, 1.34):
        a.box(f"Handhold_Upper_{x}", (0.12, 1.63, 0.17),
              (x, 0, 1.255), color="teal", bevel=0.035)
        for y in (-0.60, 0.60):
            a.box(f"Handhold_End_{x}_{y}", (0.12, 0.43, 0.31),
                  (x, y, 1.12), color="teal", bevel=0.035)
    a.box("Merchant_Plaque", (0.68, 0.06, 0.38), (0, -0.968, 0.72),
          color="cream", bevel=0.04)
    a.box("Plaque_Diamond", (0.16, 0.025, 0.16), (0, -1.007, 0.72),
          color="gold", bevel=0.025, rotation=(0, pi / 4, 0))
    a.notes = {"interior": "Open slatted crate; end handholds are genuine geometry openings."}
    return a


def _barrel():
    a = Asset("05_Merchant_Barrel", "Containers",
              "Twelve shaped walnut staves, broad brass hoops and a removable flat lid.")
    levels = [(0.0, 0.71), (0.25, 0.82), (1.16, 0.94),
              (2.05, 0.82), (2.30, 0.71)]
    n = 12
    for i in range(n):
        p, q = i * 2 * pi / n + 0.006, (i + 1) * 2 * pi / n - 0.006
        verts = []
        for z, radius in levels:
            verts += [(radius * cos(p), radius * sin(p), z),
                      (radius * cos(q), radius * sin(q), z),
                      ((radius - 0.105) * cos(p), (radius - 0.105) * sin(p), z),
                      ((radius - 0.105) * cos(q), (radius - 0.105) * sin(q), z)]
        faces = [(0, 2, 3, 1), (16, 17, 19, 18)]
        for j in range(4):
            k = j * 4
            faces += [(k, k + 1, k + 5, k + 4),
                      (k + 3, k + 2, k + 6, k + 7),
                      (k + 2, k, k + 4, k + 6),
                      (k + 1, k + 3, k + 7, k + 5)]
        a.mesh(f"Shaped_Stave_{i + 1}", verts, faces,
               color="woodlight" if i % 4 == 0 else "wood")
    a.cylinder("Interior_Base", 0.68, 0.14, (0, 0, 0.11),
               color="darkwood", vertices=12)
    for name, radius, lo, hi in (("Lower_Hoop", 0.84, 0.25, 0.40),
                                 ("Upper_Hoop", 0.84, 1.90, 2.05)):
        _ring(a, name, radius + 0.025, 0.065, lo, hi, color="gold", n=12)
    _ring(a, "Belly_Sash", 0.963, 0.06, 1.04, 1.24, color="teal", n=12)
    _ring(a, "Rim", 0.733, 0.10, 2.25, 2.34, color="darkwood", n=12)
    a.cylinder("Lid_Wood", 0.671, 0.095, (0, 0, 2.325),
               color="woodlight", vertices=12, role="Lid")
    for x in (-0.29, 0.29):
        a.box(f"Lid_Batten_{x}", (0.13, 1.12, 0.055), (x, 0, 2.397),
              color="teal", bevel=0.022, role="Lid")
    a.cylinder("Bung", 0.14, 0.06, (0, 0, 2.403),
               color="darkwood", vertices=8, role="Lid")
    a.pivot("Lid", (0, 0, 2.28))
    a.notes = {"animation": "Lift Lid vertically to expose the stave-built hollow interior."}
    return a


def _coffer():
    a = Asset("06_Coin_Coffer", "Containers",
              "Small octagonal teal coin strongbox with a brass collar and garnet seal.")
    n, phase = 8, pi / 8
    a.cylinder("Foot_Plinth", 1.05, 0.20, (0, 0, 0.10),
               color="darkwood", vertices=n, rotation=(0, 0, phase))
    a.cylinder("Interior_Floor", 0.94, 0.12, (0, 0, 0.25),
               color="wood", vertices=n, rotation=(0, 0, phase))
    _ring(a, "Octagonal_Walls", 1.02, 0.14, 0.24, 1.14,
          color="teal", n=n, phase=phase)
    _ring(a, "Lower_Gold_Rim", 1.05, 0.08, 0.26, 0.38,
          n=n, phase=phase)
    _ring(a, "Upper_Gold_Rim", 1.075, 0.12, 1.04, 1.17,
          n=n, phase=phase)
    a.cylinder("Lid_Lower_Tier", 1.085, 0.14, (0, 0, 1.26),
               color="gold", vertices=n, rotation=(0, 0, phase), role="Lid")
    a.cylinder("Lid_Teal_Inlay", 0.96, 0.14, (0, 0, 1.37),
               color="teal", vertices=n, rotation=(0, 0, phase), role="Lid")
    a.cylinder("Seal_Setting", 0.27, 0.055, (0, 0, 1.475),
               color="goldlight", vertices=8, role="Lid")
    a.gem("Garnet_Seal", 0.21, 0.20, (0, 0, 1.54), color="red", role="Lid")
    _latch(a, -0.99, 1.05, 0.33)
    a.pivot("Lid", (0, 0.97, 1.20))
    a.notes = {"animation": "Rear Lid pivot supplied; coin coffer body has a usable empty cavity."}
    return a


def _tray():
    a = Asset("07_Display_Tray", "Containers",
              "Shallow brass-edged jeweler tray with cream lining and raised side handles.")
    _feet(a, 2.85, 1.88, 0.12)
    _rect_walls(a, 2.85, 1.88, 0.09, 0.44,
                color="teal", thickness=0.13, planks=1)
    a.box("Cream_Velvet_Liner", (2.51, 1.53, 0.035), (0, 0, 0.249),
          color="cream", bevel=0.025)
    _rect_trim(a, "Brass_Lip", 2.88, 1.91, 0.44, height=0.07,
               thickness=0.065)
    for x in (-1.51, 1.51):
        for y in (-0.33, 0.33):
            a.beam(f"Handle_Stanchion_{x}_{y}", (x * 0.93, y, 0.34),
                   (x, y, 0.70), 0.075, color="gold")
        a.beam(f"Handle_Grip_{x}", (x, -0.33, 0.70), (x, 0.33, 0.70),
               0.095, color="gold")
    a.notes = {"interior": "Empty lined tray supplied ready for displaying other pack items."}
    return a


def _cart():
    a = Asset("08_Treasure_Cart", "Containers",
              "Two-wheeled market handcart with spoked wheels, hollow plank bed and pull shafts.")
    _rect_walls(a, 2.30, 2.34, 0.71, 1.65, color="wood", planks=3)
    _rect_trim(a, "Cart_Top_Rail", 2.38, 2.42, 1.65,
               color="teal", height=0.17, thickness=0.14)
    for x in (-1.04, 1.04):
        a.box(f"Bed_Chassis_{x}", (0.16, 2.62, 0.20),
              (x, 0.04, 0.66), color="darkwood", bevel=0.035)
        a.beam(f"Pull_Shaft_{x}", (x, -0.68, 0.77),
               (x * 0.86, -2.65, 1.02), 0.13, color="darkwood")
        a.beam(f"Pull_Grip_{x}", (x * 0.86, -2.49, 1.00),
               (x * 0.86, -2.79, 1.04), 0.16, color="teal")
        a.beam(f"Parking_Leg_{x}", (x, -0.80, 0.72),
               (x, -0.98, 0.08), 0.11, color="iron")
    a.cylinder("Axle", 0.12, 3.12, (0, 0.31, 0.765),
               color="iron", vertices=12, rotation=(0, pi / 2, 0))
    for x, label in ((-1.45, "Wheel_Left"), (1.45, "Wheel_Right")):
        a.torus(label + "_Tire", 0.665, 0.10, (x, 0.31, 0.765),
                color="darkwood", rotation=(0, pi / 2, 0),
                role=label, major_segments=12, minor_segments=4)
        a.torus(label + "_Iron_Band", 0.68, 0.075, (x, 0.31, 0.765),
                color="iron", rotation=(0, pi / 2, 0),
                role=label, major_segments=12, minor_segments=4)
        for i in range(8):
            t = i * 2 * pi / 8
            a.beam(f"{label}_Spoke_{i + 1}", (x, 0.31, 0.765),
                   (x, 0.31 + 0.63 * cos(t), 0.765 + 0.63 * sin(t)),
                   0.09, color="woodlight", role=label)
        a.cylinder(label + "_Hub", 0.20, 0.28, (x, 0.31, 0.765),
                   color="teal", vertices=12, rotation=(0, pi / 2, 0), role=label)
        a.cylinder(label + "_Hub_Pin", 0.075, 0.32, (x, 0.31, 0.765),
                   color="gold", vertices=8, rotation=(0, pi / 2, 0), role=label)
        a.pivot(label, (x, 0.31, 0.765))
    a.box("Front_Cart_Plaque", (0.64, 0.055, 0.33), (0, -1.23, 1.32),
          color="cream", bevel=0.03)
    a.box("Cart_Plaque_Seal", (0.13, 0.025, 0.13), (0, -1.27, 1.32),
          color="gold", bevel=0.02, rotation=(0, pi / 4, 0))
    a.notes = {"animation": "Each Wheel role has its own axle-center pivot, local X axis.",
               "interior": "Empty bed; pull shafts and parking feet are static decoration."}
    return a


def build():
    """Return the eight authored container assets in catalogue order."""
    return [_wayfarer(), _royal(), _shipping(), _open_crate(),
            _barrel(), _coffer(), _tray(), _cart()]
