"""Original Gilded Grove shop fixtures. Z is up; customer side is -Y."""

from math import cos, sin, pi

from geometry import Asset


def _frustum(a, name, lower, upper, height, loc, color, sides=8):
    """Closed, flat-shaded polygonal taper, with outward-facing surfaces."""
    verts = []
    phase = pi / 4 if sides == 4 else pi / 8
    for radius, z in ((lower, -height / 2), (upper, height / 2)):
        verts.extend((radius * cos(2 * pi * i / sides + phase),
                      radius * sin(2 * pi * i / sides + phase), z)
                     for i in range(sides))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces.extend((i, (i + 1) % sides, (i + 1) % sides + sides, i + sides)
                 for i in range(sides))
    return a.mesh(name, verts, faces, color=color, loc=loc)


def _diamond(a, name, size, loc, color="gold", role="Body"):
    return a.box(name, (size, 0.055, size), loc, color=color,
                 bevel=0.025, rotation=(0, pi / 4, 0), role=role)


def _finial(a, name, loc, scale=1.0):
    x, y, z = loc
    a.cylinder(name + "_Collar", 0.16 * scale, 0.10 * scale,
               (x, y, z), color="gold", vertices=8)
    a.gem(name + "_Bud", 0.17 * scale, 0.30 * scale,
          (x, y, z + 0.05 * scale), color="teal")


def _merchant_stall():
    a = Asset("17_Merchant_Stall", "Shop Fixtures",
              "Open merchant counter with a striped sloping canopy and framed walnut panels.")
    for x in (-2.50, 2.50):
        for y in (-1.05, 1.05):
            top = 4.63 if y < 0 else 5.18
            a.box("Stone_Foot", (0.48, 0.48, 0.18), (x, y, 0.09), "stone", 0.055)
            a.box("Canopy_Post", (0.23, 0.23, top - 0.18), (x, y, (top + 0.18) / 2), "wood", 0.035)
            a.box("Post_Foot_Collar", (0.29, 0.29, 0.13), (x, y, 0.32), "gold", 0.025)
            a.box("Post_Top_Collar", (0.29, 0.29, 0.12), (x, y, top - 0.04), "gold", 0.025)
            _finial(a, "Canopy_Finial", (x, y, top + 0.03), 0.72)
    # Uncluttered customer opening; counter panels use true raised joinery.
    for x in (-1.96, -0.98, 0, 0.98, 1.96):
        a.box("Counter_Plank", (0.955, 0.12, 1.23), (x, -1.10, 1.02), "wood", 0.025)
    for z in (0.37, 1.65):
        a.box("Counter_Rail", (5.17, 0.24, 0.16), (0, -1.12, z), "darkwood", 0.035)
    for x in (-2.4, 2.4):
        a.box("Corner_Stile", (0.18, 0.22, 1.47), (x, -1.15, 1.0), "darkwood", 0.025)
        a.box("Side_Panel", (0.12, 1.95, 1.23), (x, 0, 1.02), "wood", 0.025)
        a.beam("Side_Diagonal", (x, -0.85, 0.53), (x, 0.85, 1.5), 0.15, "woodlight")
        for z in (0.36, 1.64):
            a.box("Side_Rail", (0.22, 2.11, 0.14), (x, 0, z), "darkwood", 0.025)
    for y in (-0.93, -0.38):
        a.box("Countertop_Board", (5.56, 0.54, 0.19), (0, y, 1.82), "woodlight", 0.045)
    a.box("Counter_Edge_Brass", (5.43, 0.035, 0.045), (0, -1.222, 1.79), "gold", 0.012)
    a.box("Front_Teal_Inset", (1.47, 0.06, 0.73), (0, -1.191, 1.02), "teal", 0.10)
    _diamond(a, "Counter_Crest", 0.32, (0, -1.244, 1.02))
    for x in (-2.50, 2.50):
        a.beam("Roof_Rafter", (x, -1.4, 4.47), (x, 1.4, 5.12), 0.18, "darkwood")
        a.beam("Post_Knee_Brace", (x, 1.03, 3.93), (x, 0.26, 4.73), 0.14, "woodlight")
    for y, z in ((-1.36, 4.51), (1.36, 5.14)):
        a.box("Roof_Crossbar", (5.72, 0.18, 0.18), (0, y, z), "darkwood", 0.03)
    # Separate cloth strips share edges and form a faceted, shallow-sag canopy.
    for i in range(7):
        x0, x1 = -3 + i * 6 / 7, -3 + (i + 1) * 6 / 7
        profiles = ((-1.5, 4.56), (-0.25, 4.80), (1.5, 5.25))
        verts = [(x, y, z) for x in (x0, x1) for y, z in profiles]
        verts += [(x, y, z - 0.045) for x, y, z in verts]
        faces = [(0, 3, 4, 1), (1, 4, 5, 2), (6, 7, 10, 9),
                 (7, 8, 11, 10), (0, 1, 2, 8, 7, 6),
                 (3, 9, 10, 11, 5, 4), (0, 6, 9, 3), (2, 5, 11, 8)]
        col = "teal" if i % 2 == 0 else "cream"
        a.mesh("Canopy_Stripe", verts, faces, col)
        # Chunky chamfered pennant hem, readable from a distant game camera.
        xm = (x0 + x1) / 2
        a.mesh("Canopy_Pennant", [(-0.405, 0, 0), (0.405, 0, 0),
                                  (0.35, 0, -0.30), (0, 0, -0.40),
                                  (-0.35, 0, -0.30), (-0.405, 0.06, 0),
                                  (0.405, 0.06, 0), (0.35, 0.06, -0.30),
                                  (0, 0.06, -0.40), (-0.35, 0.06, -0.30)],
               [(0, 4, 3, 2, 1), (5, 6, 7, 8, 9), (0, 1, 6, 5),
                (1, 2, 7, 6), (2, 3, 8, 7), (3, 4, 9, 8), (4, 0, 5, 9)],
               col, loc=(xm, -1.5, 4.58))
    a.notes = {"placement": "Front faces -Y. Rear opening remains clear for a vendor.",
               "design": "Seven original cloth stripes; no baked text or third-party assets."}
    return a


def _upgrade_station():
    a = Asset("18_Upgrade_Station", "Shop Fixtures",
              "Walnut artificer bench with a brass upgrade ring, gem cradle and side crank.")
    for x in (-1.64, 1.64):
        for y in (-0.66, 0.66):
            a.box("Bench_Leg", (0.32, 0.33, 1.40), (x, y, 0.70), "darkwood", 0.055)
            a.box("Brass_Shoe", (0.36, 0.37, 0.16), (x, y, 0.10), "gold", 0.03)
        a.box("End_Stretcher", (0.23, 1.67, 0.17), (x, 0, 0.42), "wood", 0.035)
    a.box("Low_Stretcher", (3.30, 0.24, 0.23), (0, 0.40, 0.42), "wood", 0.04)
    for y in (-0.58, 0, 0.58):
        a.box("Worktop_Plank", (4.15, 0.56, 0.24), (0, y, 1.48), "woodlight", 0.045)
    a.box("Front_Apron", (3.62, 0.13, 0.31), (0, -0.74, 1.21), "teal", 0.04)
    for x in (-1.65, 1.65):
        _diamond(a, "Apron_Pin", 0.10, (x, -0.83, 1.21))
    # A thick ring in the XZ plane is visibly a mechanism, not a shop canopy.
    a.box("Mechanism_Base", (1.60, 0.87, 0.21), (0, 0.23, 1.71), "iron", 0.09)
    a.box("Mechanism_Upright", (0.38, 0.36, 1.14), (0, 0.54, 2.28), "iron", 0.06)
    a.torus("Upgrade_Ring", 1.04, 0.16, (0, 0.35, 3.14), "gold",
            rotation=(pi / 2, 0, 0), major_segments=12, minor_segments=4)
    a.torus("Inner_Teal_Ring", 0.88, 0.055, (0, 0.34, 3.14), "teal",
            rotation=(pi / 2, 0, 0), major_segments=12, minor_segments=4)
    for i in range(8):
        t = 2 * pi * i / 8
        a.box("Ring_Tooth", (0.28, 0.25, 0.29),
              (1.14 * cos(t), 0.35, 3.14 + 1.14 * sin(t)),
              "goldlight", 0.035, rotation=(0, pi / 2 - t, 0))
    a.cylinder("Cradle_Platform", 0.52, 0.12, (0, -0.10, 1.92), "gold", vertices=8)
    a.gem("Upgrade_Crystal", 0.44, 0.90, (0, -0.10, 1.97), "teal")
    for x in (-0.48, 0.48):
        a.beam("Crystal_Claw", (x, -0.10, 1.9), (x * 0.68, -0.1, 2.33), 0.105, "gold")
    # A bench-mounted bearing physically supports the side wheel and its axle.
    a.box("Bearing_Foot", (0.56, 0.57, 0.10), (1.36, 0.31, 1.65), "iron", 0.035)
    a.box("Bearing_Upright", (0.28, 0.31, 0.60), (1.36, 0.31, 1.99), "iron", 0.04)
    a.cylinder("Bearing_Collar", 0.24, 0.32, (1.36, 0.31, 2.26), "gold",
               rotation=(0, pi / 2, 0), vertices=8)
    a.cylinder("Handwheel_Axle", 0.17, 0.35, (1.36, 0.31, 2.26), "iron",
               rotation=(0, pi / 2, 0))
    a.torus("Handwheel", 0.37, 0.08, (1.56, 0.31, 2.26), "gold",
            rotation=(0, pi / 2, 0), major_segments=10, minor_segments=4)
    for t in (0, pi / 2):
        a.beam("Wheel_Spoke", (1.56, 0.31 - 0.32 * cos(t), 2.26 - 0.32 * sin(t)),
               (1.56, 0.31 + 0.32 * cos(t), 2.26 + 0.32 * sin(t)), 0.075, "gold")
    a.cylinder("Crank_Grip", 0.085, 0.25, (1.7, 0.60, 2.26), "darkwood",
               rotation=(0, pi / 2, 0), vertices=8)
    a.box("Tool_Tray", (0.69, 0.68, 0.09), (-1.31, -0.03, 1.645), "iron", 0.04)
    a.cylinder("Tray_Ingot", 0.17, 0.16, (-1.31, -0.03, 1.77), "goldlight", vertices=6)
    a.notes = {"design": "Visual fixture only; upgrade logic and effects are intentionally absent."}
    return a


def _reward_pedestal():
    a = Asset("19_Reward_Pedestal", "Shop Fixtures",
              "Octagonal stepped stone reward plinth with brass inlays and a faceted teal gem.")
    a.cylinder("Foundation", 1.27, 0.22, (0, 0, 0.11), "stone", vertices=8)
    a.cylinder("Step", 1.06, 0.20, (0, 0, 0.30), "stonelight", vertices=8)
    a.cylinder("Base_Inlay", 0.88, 0.09, (0, 0, 0.43), "gold", vertices=8)
    _frustum(a, "Tapered_Column", 0.78, 0.59, 1.35, (0, 0, 1.14), "stone")
    for i in range(4):
        t = 2 * pi * i / 4
        a.beam("Column_Inlay", (0.71 * cos(t), 0.71 * sin(t), 0.58),
               (0.56 * cos(t), 0.56 * sin(t), 1.70), 0.07, "gold")
    a.cylinder("Capital_Band", 0.71, 0.13, (0, 0, 1.87), "gold", vertices=8)
    _frustum(a, "Flared_Capital", 0.66, 0.93, 0.23, (0, 0, 2.03), "stonelight")
    a.cylinder("Top_Rim", 0.96, 0.11, (0, 0, 2.20), "gold", vertices=8)
    a.cylinder("Teal_Display_Cushion", 0.79, 0.085, (0, 0, 2.29), "teal", vertices=8)
    a.gem("Reward_Crystal", 0.52, 1.03, (0, 0, 2.33), "teallight")
    for i in range(3):
        t = 2 * pi * i / 3 + pi / 6
        a.beam("Gem_Claw", (0.65 * cos(t), 0.65 * sin(t), 2.30),
               (0.43 * cos(t), 0.43 * sin(t), 2.64), 0.10, "gold")
    a.notes = {"placement": "Eight-sided foundation; clear centreline for reward placement."}
    return a


def _hanging_shop_sign():
    a = Asset("20_Hanging_Shop_Sign", "Shop Fixtures",
              "Blank octagonal walnut sign with brass border, twin hangers and wall bracket.")
    a.box("Wall_Mount", (0.26, 0.38, 2.88), (-1.36, 0.12, 1.44), "darkwood", 0.045)
    for z in (0.26, 2.63):
        a.box("Mount_Band", (0.31, 0.42, 0.12), (-1.36, 0.12, z), "gold", 0.025)
    a.box("Bracket_Arm", (2.81, 0.24, 0.23), (-0.1, 0.12, 2.79), "wood", 0.04)
    a.beam("Bracket_Brace", (-1.30, 0.12, 1.77), (-0.43, 0.12, 2.74), 0.18, "wood")
    a.box("Bracket_Tip", (0.14, 0.32, 0.40), (1.26, 0.12, 2.80), "gold", 0.035)
    a.cylinder("Sign_Brass_Frame", 1.00, 0.18, (0.1, 0.08, 1.37), "gold",
               vertices=8, rotation=(pi / 2, 0, 0))
    a.cylinder("Sign_Walnut_Face", 0.91, 0.21, (0.1, 0.08, 1.37), "wood",
               vertices=8, rotation=(pi / 2, 0, 0))
    # Two face-to-face panels make this suitable for a two-sided storefront.
    for y in (-0.038, 0.198):
        a.box("Blank_Label_Field", (1.09, 0.025, 0.53), (0.1, y, 1.40), "teal", 0.08)
    _diamond(a, "Small_Crest", 0.14, (0.1, -0.058, 0.88))
    for x in (-0.47, 0.67):
        a.torus("Suspension_Link", 0.125, 0.035, (x, 0.08, 2.52), "gold",
                rotation=(pi / 2, 0, 0), major_segments=8, minor_segments=4)
        a.box("Hanging_Strap", (0.085, 0.10, 0.44), (x, 0.08, 2.24), "iron", 0.02)
    a.notes = {"placement": "Mount the vertical bracket flush to a wall or post.",
               "label": "Add localized text to either teal face; no lettering baked into mesh."}
    return a


def _lantern_post():
    a = Asset("21_Lantern_Post", "Shop Fixtures",
              "Freestanding market lantern with stone foot, curved wood bracket and brass cage.")
    a.cylinder("Stone_Foot", 0.56, 0.24, (-0.55, 0, 0.12), "stone", vertices=8)
    _frustum(a, "Foot_Cap", 0.43, 0.29, 0.22, (-0.55, 0, 0.35), "stonelight")
    a.box("Timber_Post", (0.24, 0.24, 4.01), (-0.55, 0, 2.45), "darkwood", 0.04)
    for z in (0.55, 3.60, 4.44):
        a.box("Post_Band", (0.31, 0.31, 0.13), (-0.55, 0, z), "gold", 0.025)
    a.beam("Arm_Rise", (-0.55, 0, 4.37), (-0.04, 0, 4.66), 0.21, "wood")
    a.beam("Arm_Reach", (-0.04, 0, 4.66), (0.98, 0, 4.66), 0.21, "wood")
    a.beam("Bracket_Support", (-0.54, 0, 3.71), (0.40, 0, 4.59), 0.12, "gold")
    _finial(a, "Post_Finial", (-0.55, 0, 4.60), 0.75)
    a.torus("Lantern_Hook", 0.13, 0.042, (0.96, 0, 4.46), "iron",
            rotation=(pi / 2, 0, 0), major_segments=8, minor_segments=4)
    a.cylinder("Lantern_Roof_Neck", 0.11, 0.13, (0.96, 0, 4.24), "gold", vertices=8)
    _frustum(a, "Lantern_Roof", 0.65, 0.12, 0.35, (0.96, 0, 4.00), "teal", sides=4)
    a.box("Lantern_Canopy_Rim", (0.91, 0.91, 0.11), (0.96, 0, 3.80), "gold", 0.03)
    a.box("Warm_Light_Core", (0.52, 0.52, 0.73), (0.96, 0, 3.35), "cream", 0.05)
    for x in (-0.35, 0.35):
        for y in (-0.35, 0.35):
            a.box("Lantern_Cage", (0.08, 0.08, 0.87), (0.96 + x, y, 3.34), "gold", 0.018)
    a.box("Lantern_Base", (0.84, 0.84, 0.13), (0.96, 0, 2.87), "gold", 0.035)
    _frustum(a, "Lantern_Lower_Cap", 0.19, 0.59, 0.20, (0.96, 0, 2.71), "teal", sides=4)
    a.gem("Lantern_Drop", 0.13, 0.22, (0.96, 0, 2.62), "gold", rotation=(pi, 0, 0))
    a.notes = {"lighting": "Opaque warm core; add a PointLight in Studio if desired."}
    return a


def _display_shelf():
    a = Asset("22_Display_Shelf", "Shop Fixtures",
              "Open three-tier walnut merchandise shelf with teal side braces and a brass crest.")
    for x in (-1.50, 1.50):
        for y in (-0.53, 0.53):
            a.box("Upright", (0.18, 0.18, 3.45), (x, y, 1.725), "darkwood", 0.035)
            a.box("Foot_Cap", (0.23, 0.23, 0.14), (x, y, 0.09), "gold", 0.022)
        a.beam("Side_Brace", (x, -0.53, 0.48), (x, 0.53, 2.41), 0.115, "teal")
        a.beam("Side_Cross_Brace", (x, 0.53, 0.48), (x, -0.53, 2.41), 0.115, "teal")
    for z in (0.30, 1.39, 2.48):
        for y in (-0.36, 0, 0.36):
            a.box("Shelf_Board", (3.34, 0.35, 0.14), (0, y, z), "woodlight", 0.035)
        a.box("Shelf_Front_Lip", (3.33, 0.09, 0.18), (0, -0.555, z - 0.015), "wood", 0.025)
        a.box("Shelf_Brass_Inlay", (2.99, 0.028, 0.035), (0, -0.614, z + 0.017), "gold", 0.009)
        a.box("Shelf_Back_Rail", (3.15, 0.10, 0.17), (0, 0.53, z + 0.16), "wood", 0.025)
    a.box("Header", (3.23, 0.18, 0.30), (0, 0.53, 3.29), "wood", 0.045)
    a.box("Header_Teal_Field", (1.23, 0.045, 0.21), (0, 0.414, 3.29), "teal", 0.06)
    _diamond(a, "Shelf_Crest", 0.17, (0, 0.371, 3.29))
    a.notes = {"placement": "Three usable surfaces at Z 0.37, 1.46 and 2.55; open back."}
    return a


def _market_fence():
    a = Asset("23_Market_Fence", "Shop Fixtures",
              "Four-unit repeatable walnut market fence with teal diamond centre and brass caps.")
    for x in (-1.86, 1.86):
        a.box("Post", (0.28, 0.30, 1.55), (x, 0, 0.775), "darkwood", 0.035)
        a.box("Post_Base", (0.28, 0.38, 0.15), (x, 0, 0.075), "stone", 0.035)
        a.box("Post_Cap", (0.28, 0.34, 0.11), (x, 0, 1.59), "gold", 0.025)
    for z in (0.41, 1.17):
        a.box("Horizontal_Rail", (3.61, 0.20, 0.17), (0, 0, z), "wood", 0.035)
    for x in (-1.02, 0, 1.02):
        a.box("Upright_Picket", (0.17, 0.16, 0.92), (x, 0.03, 0.80), "woodlight", 0.025)
    a.beam("Left_Diagonal", (-1.68, -0.115, 0.46), (-0.06, -0.115, 1.12), 0.115, "wood")
    a.beam("Right_Diagonal", (0.06, -0.115, 1.12), (1.68, -0.115, 0.46), 0.115, "wood")
    _diamond(a, "Fence_Teal_Crest", 0.40, (0, -0.245, 0.84), "teal")
    _diamond(a, "Fence_Brass_Centre", 0.15, (0, -0.29, 0.84), "gold")
    a.notes = {"grid": "Exactly 4 units wide. Translate by 4 units along X to tile."}
    return a


def _portal_arch():
    a = Asset("24_Portal_Arch", "Shop Fixtures",
              "Open walk-through stone arch with segmented voussoirs, brass keys and teal crown.")
    for x in (-2.42, 2.42):
        first_piece = len(a.objects)
        a.box("Pillar_Foot", (1.12, 1.34, 0.28), (x, 0, 0.14), "stone", 0.08)
        a.box("Pillar_Step", (0.99, 1.13, 0.20), (x, 0, 0.38), "stonelight", 0.055)
        for i in range(4):
            a.box("Pillar_Block", (0.81, 0.94, 0.83), (x, 0, 0.93 + i * 0.87),
                  "stone" if i % 2 == 0 else "stonelight", 0.055)
        a.box("Pillar_Gold_Capital", (0.97, 1.07, 0.16), (x, 0, 4.09), "gold", 0.035)
        a.box("Pillar_Teal_Inlay", (0.15, 0.05, 2.34), (x, -0.501, 2.21), "teal", 0.025)
        _diamond(a, "Pillar_Crest", 0.23, (x, -0.556, 3.57), "gold")
        role = "LeftPillar" if x < 0 else "RightPillar"
        for obj in a.objects[first_piece:]:
            obj["gg_role"] = role
        a.pivot(role, (x, 0, 0))
    # Radial stone blocks around a genuinely empty semicircular opening.
    arch_first_piece = len(a.objects)
    inner, outer, spring = 2.01, 2.84, 4.09
    for i in range(11):
        lo = i * pi / 11 + 0.009
        hi = (i + 1) * pi / 11 - 0.009
        verts = [(r * cos(t), y, spring + r * sin(t))
                 for y in (-0.49, 0.49) for r, t in
                 ((inner, lo), (outer, lo), (outer, hi), (inner, hi))]
        faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
                 (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        a.mesh("Arch_Voussoir", verts, faces, "stonelight" if i % 2 else "stone")
        t = (lo + hi) / 2
        if i in (1, 3, 7, 9):
            a.box("Arch_Brass_Key", (0.13, 0.06, 0.57),
                  (2.43 * cos(t), -0.53, spring + 2.43 * sin(t)),
                  "gold", 0.025, rotation=(0, pi / 2 - t, 0))
    a.box("Crown_Frame", (0.76, 0.17, 0.76), (0, -0.58, 6.45), "gold", 0.075,
          rotation=(0, pi / 4, 0))
    a.box("Crown_Gem", (0.51, 0.19, 0.51), (0, -0.69, 6.45), "teal", 0.09,
          rotation=(0, pi / 4, 0))
    for obj in a.objects[arch_first_piece:]:
        obj["gg_role"] = "ArchTop"
    a.pivot("ArchTop", (0, 0, spring))
    a.notes = {"clearance": "Open centre 4.02 units wide below the curved top; no portal plane.",
               "placement": "Stone feet on Z 0. Visual arch only; teleport logic is not included."}
    return a


def build():
    """Return the eight independently exportable, original shop fixture assets."""
    return [_merchant_stall(), _upgrade_station(), _reward_pedestal(),
            _hanging_shop_sign(), _lantern_post(), _display_shelf(),
            _market_fence(), _portal_arch()]
