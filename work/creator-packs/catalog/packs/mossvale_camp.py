"""Original forest expedition props. All dimensions are intended studs."""
from math import cos, sin, pi
from geometry import Asset, ring_mesh

META = {
    "slug": "mossvale-camp", "title": "Mossvale Camp",
    "tagline": "A complete forest expedition campsite in twelve useful props.",
    "description": "Original stylized camping equipment, shelter and trail details. Visual models only; no survival systems or scripts.",
    "palettes": {
        "Classic": ["785339", "3A352D", "B78A54", "647B45", "A0B66D", "BF8D46", "EACE87", "475352", "7B8074", "ACAF9A", "E7D9B3", "CD6745", "819C51", "8A769D", "A76D42", "26332D"],
        "Warm": ["875638", "463128", "CE9B60", "A36A3E", "D9AA69", "C69348", "F0D69C", "5B5148", "8B7C69", "BCAF90", "F0DCB7", "B34D36", "84964D", "A37B8D", "A8734C", "352B27"],
        "Twilight": ["665448", "30303B", "A08A72", "526A7D", "92B5C6", "B59969", "E6D7A9", "414E62", "727D91", "A6B1BF", "DDDCCB", "B36C6B", "729489", "9B83B6", "8D7060", "252E3B"]},
    "samples": ["10_Trail_Canteen", "12_Round_Camp_Mat"]}


def _asset(name, description):
    a = Asset(name, "Camp", description)
    a.notes = {"use": "Static visual prop; place root on terrain. No runtime behavior included."}
    return a


def _panel(a, name, xz, depth, y, color="teal"):
    n = len(xz)
    verts = [(x, y - depth / 2, z) for x, z in xz] + [(x, y + depth / 2, z) for x, z in xz]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return a.mesh(name, verts, faces, color=color)


def _lathe(a, name, rings, loc=(0, 0, 0), color="cream", sides=12):
    verts, faces = ring_mesh(rings, sides)
    return a.mesh(name, verts, faces, loc=loc, color=color)


def _tent():
    a = _asset("01_Ridge_Tent", "Open-front ridge tent with thick canvas, timber frame, pegs and guy ropes.")
    a.box("Groundsheet", (4.30, 4.10, .09), (0, 0, .045), color="leather", bevel=.035)
    for y in (-1.93, 1.93):
        for side in (-1, 1):
            a.beam(f"A_Frame_{side}_{y}", (side * 2.03, y, .08), (0, y, 3.05), .105, color="woodlight")
    a.beam("Ridgepole", (0, -2.22, 3.05), (0, 2.18, 3.05), .12, color="wood")
    for side in (-1, 1):
        # Four-corner solid canvas slabs create an actual accessible interior.
        verts = [(side * 2.18, -2.07, .10), (side * 2.18, 2.07, .10), (0, 2.07, 3.12), (0, -2.07, 3.12),
                 (side * 2.10, -2.07, .10), (side * 2.10, 2.07, .10), (0, 2.07, 3.02), (0, -2.07, 3.02)]
        a.mesh(f"Thick_Canvas_Slope_{side}", verts,
               [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)], color="teal")
        _panel(a, f"Rolled_Entry_Flap_{side}", [(side * 2.06,.13),(side * 1.44,.13),(side * .33,2.56)], .09, -2.09, "teallight")
        for y in (-1.65, 1.65):
            peg = (side * 2.66, y, .09)
            a.beam(f"Guy_Rope_{side}_{y}", (side * 1.25, y, 1.45), peg, .035, color="cream")
            a.box(f"Ground_Peg_{side}_{y}", (.12,.12,.22), (peg[0],peg[1],.11), color="woodlight", bevel=.018)
    _panel(a, "Rear_Canvas", [(-2.10,.10),(2.10,.10),(0,3.05)], .08, 2.02, "teal")
    a.notes["interior"] = "Open front, complete rear panel and floor; roof canvas is 0.08–0.10 studs thick."
    return a


def _kitchen():
    a = _asset("02_Field_Kitchen", "Timber expedition kitchen with lower shelf, hanging hollow pot and preparation surface.")
    for x in (-1.52,1.52):
        for y in (-.65,.65):
            a.box(f"Leg_{x}_{y}", (.16,.16,2.05), (x,y,1.025), color="wood", bevel=.025)
    for i in range(5):
        a.box(f"Counter_Plank_{i}", (.65,1.65,.14), ((i-2)*.66,0,2.07), color="woodlight", bevel=.025)
        a.box(f"Shelf_Plank_{i}", (.61,1.40,.11), ((i-2)*.63,0,.57), color="wood", bevel=.018)
    for x in (-1.5,1.5):
        a.beam(f"Hanging_Post_{x}", (x,.62,1.99), (x,.62,3.55), .14, color="wood")
    a.beam("Hanging_Rail", (-1.68,.62,3.51), (1.68,.62,3.51), .16, color="woodlight")
    _lathe(a,"Hollow_Cookpot",[(0,.24),(.08,.39),(.43,.50),(.52,.51),(.52,.43),(.11,.31)],(-.62,.45,2.48),"iron")
    a.torus("Pot_Bail", .46,.035,(-.62,.45,3.03),color="iron",rotation=(pi/2,0,0))
    a.beam("Suspension_Link",(-.62,.62,3.47),(-.62,.45,3.46),.055,color="iron")
    a.box("Cutting_Board",(.93,.63,.07),(.65,-.18,2.175),color="cream",bevel=.08)
    _lathe(a,"Flask",[(0,.19),(.37,.20),(.47,.09),(.60,.09)],(.85,.43,2.14),"teal",10)
    a.cylinder("Flask_Cork",.10,.10,(.85,.43,2.79),color="woodlight",vertices=8)
    return a


def _fire():
    a = _asset("03_Stone_Campfire", "Eight-stone campfire with crossed logs and solid stylized flame shapes.")
    for i in range(8):
        t = 2*pi*i/8
        a.gem(f"Hearth_Stone_{i}",.35,.34,(cos(t)*1.12,sin(t)*1.12,0),color="stone",rotation=(0,0,t))
    for x,y,angle in ((0,-.16,pi/3),(0,.16,-pi/3)):
        a.cylinder(f"Firewood_{angle}",.19,1.66,(x,y,.24),color="wood",vertices=10,rotation=(pi/2,0,angle))
    for i,(x,y,h) in enumerate(((-.24,0,.83),(.20,.15,1.16),(.30,-.30,.64))):
        a.gem(f"Outer_Flame_{i}",.32,h,(x,y,.32),color="red")
        a.gem(f"Gold_Flame_{i}",.19,h*.63,(x,y-.22,.35),color="goldlight")
    a.notes["effect"] = "Opaque static flame geometry; no lights, particles or damage scripts."
    return a


def _bedroll():
    a = _asset("04_Rolled_Bedroll", "Travel blanket with rounded rolled end, sewn edge and two fastening straps.")
    a.box("Unfurled_Blanket",(1.90,1.73,.12),(0,-.36,.06),color="teal",bevel=.06)
    a.box("Blanket_Inner",(1.68,1.52,.045),(0,-.43,.135),color="teallight",bevel=.04)
    a.cylinder("Blanket_Roll",.43,1.92,(0,.50,.462),color="teal",vertices=12,rotation=(0,pi/2,0))
    for x in (-.58,.58):
        a.torus(f"Strap_{x}",.427,.035,(x,.5,.462),color="leather",rotation=(0,pi/2,0))
    for x in (-.967,.967):
        a.cylinder(f"Cream_Roll_End_{x}",.335,.017,(x,.5,.462),color="cream",vertices=12,rotation=(0,pi/2,0))
        a.torus(f"Roll_Spiral_{x}",.20,.025,(x*1.01,.5,.462),color="teal",rotation=(0,pi/2,0))
    return a


def _backpack():
    a = _asset("05_Trail_Backpack", "Canvas rucksack with front pocket, rear shoulder straps and blanket roll.")
    a.box("Sack_Body",(1.26,.75,1.54),(0,0,.77),color="teal",bevel=.16)
    a.box("Top_Flap",(1.31,.80,.28),(0,-.01,1.46),color="teallight",bevel=.13)
    a.box("Front_Pocket",(.87,.22,.57),(0,-.45,.49),color="leather",bevel=.10)
    for x in (-.35,.35):
        a.box(f"Front_Strap_{x}",(.105,.055,1.21),(x,-.423,.94),color="woodlight",bevel=.025)
        a.box(f"Buckle_{x}",(.20,.065,.19),(x,-.459,1.08),color="gold",bevel=.04)
        a.beam(f"Shoulder_Upper_{x}",(x,.37,1.35),(x,.62,.83),.11,color="leather")
        a.beam(f"Shoulder_Lower_{x}",(x,.62,.83),(x,.37,.24),.11,color="leather")
    a.cylinder("Top_Blanket",.22,1.42,(0,0,1.80),color="cream",vertices=12,rotation=(0,pi/2,0))
    for x in (-.44,.44):
        a.torus(f"Bed_Strapping_{x}",.215,.025,(x,0,1.80),color="leather",rotation=(0,pi/2,0))
    return a


def _woodpile():
    a = _asset("06_Woodpile_Rack", "Six cut logs supported on a compact timber firewood rack.")
    for y in (-.64,.64):
        a.box(f"Ground_Rail_{y}",(2.85,.19,.17),(0,y,.085),color="darkwood",bevel=.03)
        for x in (-1.31,1.31):
            a.box(f"Rack_Stake_{x}_{y}",(.15,.15,1.53),(x,y,.765),color="woodlight",bevel=.03)
    for i,(y,z) in enumerate(((-.45,.42),(0,.42),(.45,.42),(-.23,.84),(.23,.84),(0,1.25))):
        a.cylinder(f"Log_{i}",.24,2.61,(0,y,z),color="wood",vertices=10,rotation=(0,pi/2,0))
        for x in (-1.313,1.313):
            a.cylinder(f"Cut_End_{i}_{x}",.192,.017,(x,y,z),color="woodlight",vertices=10,rotation=(0,pi/2,0))
    return a


def _sign():
    a = _asset("07_Trail_Signpost", "Freestanding two-direction trail marker with arrow silhouettes and inset route marks.")
    a.gem("Stone_Foot",.51,.33,(0,0,0),color="stone")
    a.box("Trail_Post",(.23,.23,3.30),(0,0,1.65),color="wood",bevel=.035)
    _panel(a,"Right_Arrow",[(-.83,2.42),(.82,2.42),(1.16,2.67),(.82,2.92),(-.83,2.92)],.14,-.17,"woodlight")
    _panel(a,"Left_Arrow",[(.79,1.67),(-.71,1.67),(-1.02,1.92),(-.71,2.17),(.79,2.17)],.14,-.17,"teal")
    for x,z,c in ((-.48,2.67,"teal"),(.44,1.92,"cream")):
        a.box(f"Route_Mark_{z}",(.18,.022,.18),(x,-.253,z),color=c,bevel=.02,rotation=(0,pi/4,0))
    return a


def _bench():
    a = _asset("08_Split_Log_Bench", "Half-log bench with a flat cut seat and two sturdy timber cradles.")
    for x in (-.90,.90):
        a.box(f"Bench_Foot_{x}",(.30,.84,.43),(x,0,.215),color="wood",bevel=.05)
    n=10
    yz=[(.42*cos(i*pi/n),.75-.42*sin(i*pi/n)) for i in range(n+1)]
    verts=[(x,y,z) for x in (-1.48,1.48) for y,z in yz]
    faces=[tuple(reversed(range(n+1))),tuple(range(n+1,2*n+2))]
    faces += [(i,(i+1)%(n+1),(i+1)%(n+1)+n+1,i+n+1) for i in range(n+1)]
    a.mesh("Half_Log",verts,faces,color="wood")
    a.box("Cut_Seat",(2.89,.80,.045),(0,0,.7675),color="woodlight",bevel=.025)
    return a


def _lantern():
    a = _asset("09_Camp_Lantern", "Portable round camping lantern with a protected warm lens and carry handle.")
    _lathe(a,"Lantern_Foot",[(0,.40),(.10,.45),(.22,.34)],color="teal")
    _lathe(a,"Warm_Lens",[(.20,.28),(.72,.29),(.87,.21)],color="goldlight")
    for i in range(4):
        t=i*pi/2
        a.beam(f"Guard_{i}",(.31*cos(t),.31*sin(t),.20),(.31*cos(t),.31*sin(t),.83),.045,color="iron")
    _lathe(a,"Rain_Cap",[(.83,.35),(.92,.42),(1.03,.20)],color="teal")
    a.torus("Carry_Handle",.25,.035,(0,0,1.19),color="iron",rotation=(pi/2,0,0))
    return a


def _canteen():
    a = _asset("10_Trail_Canteen", "Flat round expedition canteen with cork neck, leather shoulder loop and brass cap.")
    a.box("Flat_Foot",(.58,.29,.12),(0,0,.06),color="teal",bevel=.05)
    a.cylinder("Canteen_Body",.57,.34,(0,0,.60),color="teal",vertices=12,rotation=(pi/2,0,0))
    a.cylinder("Front_Inset",.42,.025,(0,-.185,.60),color="teallight",vertices=12,rotation=(pi/2,0,0))
    a.box("Neck",(.25,.25,.33),(0,0,1.18),color="teal",bevel=.04)
    a.cylinder("Screw_Cap",.19,.12,(0,0,1.405),color="gold",vertices=10)
    a.torus("Shoulder_Loop",.67,.035,(0,.05,.73),color="leather",rotation=(pi/2,0,0))
    return a


def _sack():
    a = _asset("11_Supply_Sack", "Soft-sided faceted provisions sack with gathered collar and rope knot.")
    _lathe(a,"Sack",[(0,.34),(.18,.51),(.78,.59),(1.17,.44),(1.32,.21),(1.49,.27)],color="cream")
    a.torus("Tied_Cord",.21,.045,(0,0,1.32),color="leather")
    a.gem("Rope_Knot",.085,.11,(.20,-.06,1.29),color="leather",rotation=(pi/2,0,0))
    a.beam("Cord_Tail",(.22,-.06,1.32),(.34,-.17,1.02),.035,color="leather")
    return a


def _mat():
    a = _asset("12_Round_Camp_Mat", "Round woven ground mat with concentric stitched edging.")
    a.cylinder("Woven_Mat",1.02,.06,(0,0,.03),color="cream",vertices=24)
    for radius,color in ((.96,"teal"),(.88,"woodlight"),(.79,"teal")):
        a.torus(f"Stitched_Ring_{radius}",radius,.018,(0,0,.069),color=color,major_segments=24,minor_segments=4)
    return a


def build():
    return [_tent(),_kitchen(),_fire(),_bedroll(),_backpack(),_woodpile(),
            _sign(),_bench(),_lantern(),_canteen(),_sack(),_mat()]
