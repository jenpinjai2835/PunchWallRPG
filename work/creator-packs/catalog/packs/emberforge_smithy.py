"""Original compact blacksmith workshop geometry. Z up; customer side -Y."""
from math import pi, cos, sin
from geometry import Asset, ring_mesh

META = {
    "slug": "emberforge-smithy", "title": "Emberforge Smithy",
    "tagline": "A complete fireside metalworking corner",
    "description": "Twelve original low-poly forge and smithing props with supported mechanisms. Visual models only; no crafting systems or fire effects.",
    "palettes": {
        "Classic": ["75503B","332B2A","A27A51","B84D32","F39444","AE7B43","E7BC78","404651","686264","ABA198","DED1B4","B8392E","64816B","705978","78513C","252830"],
        "Warm": ["81543B","352827","B08854","CF5E30","FFB95E","B18542","F3D391","493F42","756762","BAAC96","F2DEC0","BB4931","778D5F","806174","8C5A41","2B2930"],
        "Twilight": ["63516B","302C40","92849A","7864B4","A79EE8","9581B5","D7C0E8","384359","535E76","929DB1","D5D3E5","9B5C8B","719B91","826ABB","69567D","212A3B"]},
    "samples": ["06_Ingot_Stack", "09_Casting_Mould"]}


def _a(name, description):
    a = Asset(name, "Smithing", description)
    a.notes = {"use": "Static visual prop; no heat, crafting, damage or animated mechanism.", "axes": "Ground Z=0; front -Y."}
    return a


def _lathe(a, name, rings, loc, color="iron", sides=12):
    verts, faces = ring_mesh(rings, sides)
    return a.mesh(name, verts, faces, color, loc=loc)


def _forge():
    a = _a("01_Hearth_Forge", "Stepped masonry hearth with recessed coal bed, open fire mouth and tapered chimney.")
    a.box("Hearth_Slab", (4.6,3.2,.30),(0,0,.15),"stone",.08)
    a.box("Hearth_Step", (3.3,1.0,.24),(0,-1.29,.4),"stonelight",.055)
    for x in (-1.70,1.70):
        for z in (.69,1.27,1.85):
            a.box("Hearth_Pier", (.75,2.48,.54),(x,.17,z),"stone",.065)
    a.box("Rear_Masonry", (2.76,.60,1.78),(0,1.1,1.2),"stone",.06)
    a.box("Coal_Pan", (2.71,1.65,.20),(0,-.04,.90),"iron",.06)
    for x in (-.87,-.29,.29,.87):
        for y in (-.51,.01,.53):
            a.gem("Banked_Coal",.32,.28,(x,y,1.0),"black")
    for x,h in ((-.67,.60),(0,.87),(.66,.51)):
        a.gem("Ember_Flame",.22,h,(x,-.09,1.13),"teallight")
    a.box("Hood_Lintel", (4.0,2.65,.33),(0,.18,2.24),"stonelight",.07)
    # A closed sloping hood over the open fire mouth.
    v=[(-2,-1.14,2.40),(2,-1.14,2.40),(2,1.50,2.40),(-2,1.50,2.40),
       (-.68,-.37,3.63),(.68,-.37,3.63),(.68,.99,3.63),(-.68,.99,3.63)]
    a.mesh("Tapered_Hood",v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"stone")
    for z in (3.77,4.28,4.79):
        a.box("Chimney_Block", (1.35,1.36,.48),(0,.31,z),"stone",.04)
    a.box("Chimney_Crown", (1.65,1.67,.20),(0,.31,5.12),"stonelight",.05)
    a.box("Flue_Dark_Inset", (1.10,1.10,.04),(0,.31,5.235),"black",.02)
    for x in (-.80,.80):
        a.box("Hood_Strap", (.14,.08,.86),(x,-.852,2.90),"iron",.025,rotation=(-.559,0,0))
    return a


def _anvil():
    a=_a("02_Horn_Anvil", "Faceted horn anvil secured to a banded heavy timber stump.")
    _lathe(a,"Stump",[(0,.81),(.17,.92),(1.04,.80),(1.17,.86)],(0,0,0),"wood",10)
    for z in (.18,.97): a.torus("Stump_Band",.85,.075,(0,0,z),"iron",major_segments=10)
    a.box("Anvil_Foot",(1.70,.98,.20),(0,0,1.28),"iron",.04)
    a.box("Anvil_Waist",(.69,.65,.57),(0,0,1.64),"iron",.07)
    a.box("Anvil_Face",(1.67,.85,.31),(0,0,2.07),"stonelight",.055)
    a.mesh("Tapered_Horn",[(.74,-.40,1.94),(.74,.40,1.94),(.74,.40,2.21),(.74,-.40,2.21),
                            (1.85,-.055,2.01),(1.85,.055,2.01),(1.85,.055,2.13),(1.85,-.055,2.13)],
           [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"iron")
    a.box("Heel",(.47,.72,.22),(-1.02,0,2.10),"iron",.035)
    a.box("Hardy_Hole_Recess",(.18,.18,.02),(-1.03,0,2.225),"black",.01)
    for x in (-.66,.66): a.box("Hold_Down",(.14,.15,.38),(x,-.39,1.24),"gold",.025)
    return a


def _quench():
    a=_a("03_Quench_Tank", "Broad riveted cooling trough with thick rim and opaque water surface.")
    a.box("Tank_Floor",(2.64,1.54,.17),(0,0,.20),"iron",.06)
    for x in (-1.29,1.29): a.box("End_Wall",(.17,1.54,1.27),(x,0,.81),"iron",.045)
    for y in (-.73,.73): a.box("Long_Wall",(2.48,.17,1.27),(0,y,.81),"iron",.045)
    for x in (-1.06,1.06):
        a.box("Foot",(.42,1.33,.23),(x,0,.115),"darkwood",.045)
        for y in (-.84,.84):
            for z in (.44,1.12): a.cylinder("Rivet",.064,.045,(x,y,z),"gold",8,rotation=(pi/2,0,0))
    for y in (-.76,.76): a.box("Rim",(2.85,.22,.17),(0,y,1.48),"stonelight",.035)
    for x in (-1.33,1.33): a.box("End_Rim",(.22,1.69,.17),(x,0,1.48),"stonelight",.035)
    a.box("Still_Water",(2.34,1.27,.055),(0,0,1.21),"emerald",.02)
    a.notes["water"]="Opaque visual insert; no fluid simulation."
    return a


def _bellows():
    a=_a("04_Foot_Bellows", "Wedge leather bellows with walnut pressure boards and a short brass nozzle.")
    for z in (.12,.64):
        a.mesh("Pressure_Board",[(-.85,-1,z),(.85,-1,z),(.35,1,z),(-.35,1,z),(-.85,-1,z+.15),(.85,-1,z+.15),(.35,1,z+.15),(-.35,1,z+.15)],
               [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"woodlight")
    for z,w in ((.31,1),(.44,1.04),(.57,1)):
        a.mesh("Leather_Pleat",[(-.78*w,-.94,z-.075),(.78*w,-.94,z-.075),(.31,.91,z-.075),(-.31,.91,z-.075),
                                (-.82*w,-.94,z+.075),(.82*w,-.94,z+.075),(.34,.91,z+.075),(-.34,.91,z+.075)],
               [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"leather")
    for x in (-.60,.60): a.box("Foot",(.25,.60,.20),(x,-.61,.1),"darkwood",.03)
    a.cylinder("Nozzle",.17,.72,(0,1.14,.47),"gold",10,rotation=(pi/2,0,0))
    a.box("Pedal_Grip",(1.13,.22,.09),(0,-.67,.83),"iron",.02)
    a.notes["assembly"]="Nozzle points +Y toward a forge. Bellows is a static closed assembly."
    return a


def _grinder():
    a=_a("05_Treadle_Grindstone", "Large vertical grindstone on a braced wooden frame with axle bearings and foot treadle.")
    for x in (-.66,.66):
        for y in (-.66,.66):
            a.box("Leg_Shoe",(.30,.34,.14),(x*1.4,y,.07),"iron",.025)
            a.beam("Splayed_Leg",(x*1.4,y,0.10),(x,y,1.76),.23,"wood")
        a.box("Bearing_Beam",(.32,1.67,.24),(x,0,1.72),"woodlight",.04)
        a.box("Axle_Bearing",(.30,.42,.42),(x,0,1.99),"iron",.05)
    a.cylinder("Stone_Wheel",1.08,.67,(0,0,2.03),"stonelight",16,rotation=(0,pi/2,0))
    a.cylinder("Axle",.12,1.96,(0,0,2.03),"iron",10,rotation=(0,pi/2,0))
    a.cylinder("Hub",.25,.12,(.39,0,2.03),"gold",10,rotation=(0,pi/2,0))
    a.box("Treadle",(.59,1.38,.16),(0,-.29,.25),"woodlight",.04)
    a.box("Lower_Frame_Crossbar",(1.79,.27,.19),(0,.62,.29),"wood",.025)
    a.cylinder("Treadle_Hinge",.11,1.78,(0,.39,.27),"iron",10,rotation=(0,pi/2,0))
    a.beam("Treadle_Link_Pin",(-.77,-.34,.27),(0,-.34,.27),.10,"iron")
    a.beam("Treadle_Rod",(-.77,-.34,.27),(-.77,.14,1.76),.10,"iron")
    a.beam("Crank",(-.77,0,2.03),(-.77,.14,1.76),.13,"iron")
    a.box("Tool_Rest",(.71,.28,.13),(0,-1.00,1.71),"iron",.025)
    a.beam("Rest_Support",(.68,-.54,1.65),(0,-.96,1.66),.14,"iron")
    return a


def _ingots():
    a=_a("06_Ingot_Stack", "Five tapered cast ingots arranged in a compact two-layer stockpile.")
    for z, xs in ((.15,(-.68,0,.68)),(.43,(-.34,.34))):
        for x in xs:
            a.mesh("Ingot",[(-.29,-.62,-.13),(.29,-.62,-.13),(.29,.62,-.13),(-.29,.62,-.13),
                            (-.23,-.53,.13),(.23,-.53,.13),(.23,.53,.13),(-.23,.53,.13)],
                   [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"gold",loc=(x,0,z-.02))
    a.notes["contents"]="Five individual ingot forms, exported as one visual stockpile."
    return a


def _tongs():
    a=_a("07_Smith_Tongs", "Long crossed blacksmith tongs with distinct bowed jaws, resting flat.")
    for s in (-1,1):
        a.beam("Handle",(s*.40,-1.45,.10),(-s*.08,.10,.10),.12,"iron")
        a.beam("Jaw_Neck",(-s*.08,.10,.10),(s*.36,.69,.10),.12,"iron")
        a.beam("Jaw_Tip",(s*.36,.69,.10),(s*.16,1.02,.10),.12,"iron")
        a.box("Leather_Grip",(.16,.64,.16),(s*.31,-1.14,.10),"leather",.025,rotation=(0,0,s*.22))
    a.cylinder("Pivot_Pin",.13,.19,(0,.05,.095),"gold",10)
    return a


def _rack():
    a=_a("08_Smith_Tool_Rack", "Standing tool rail carrying a mallet, straight chisel and short poker.")
    for x in (-1.02,1.02):
        a.box("Sled_Foot",(.45,1.26,.18),(x,0,.09),"wood",.04)
        a.box("Upright",(.19,.19,2.68),(x,.28,1.43),"wood",.03)
    for z in (.56,2.43): a.box("Tool_Rail",(2.35,.22,.19),(0,.28,z),"woodlight",.03)
    for x in (-.69,0,.69):
        a.beam("Hook",(x,.18,2.38),(x,-.17,2.38),.09,"iron")
        a.cylinder("Tool_Handle",.065,1.16,(x,-.10,1.66),"woodlight",8)
    a.box("Mallet_Head",(.57,.30,.30),(-.69,-.10,2.32),"iron",.04)
    a.box("Chisel_Head",(.17,.18,.47),(0,-.10,2.28),"stonelight",.025)
    a.beam("Poker_Bend",(.69,-.10,2.20),(.86,-.1,2.43),.11,"iron")
    return a


def _mould():
    a=_a("09_Casting_Mould", "Heavy rectangular casting mould with a recessed sword-blank impression.")
    a.box("Mould_Block",(2.56,1.1,.30),(0,0,.15),"stone",.06)
    for y in (-.39,.39): a.box("Mould_Rail",(2.48,.20,.20),(0,y,.40),"stonelight",.035)
    for x in (-1.14,1.14): a.box("Mould_End",(.20,.66,.20),(x,0,.40),"stonelight",.025)
    a.box("Cast_Channel",(1.74,.18,.025),(-.13,0,.32),"black",.02)
    a.box("Pour_Basin",(.31,.39,.035),(.83,0,.325),"black",.07)
    return a


def _coal():
    a=_a("10_Coal_Scuttle", "Low open metal fuel basket with a reinforced carrying handle and coal lumps.")
    _lathe(a,"Scuttle_Shell",[(0,.51),(.13,.68),(.80,.83),(.87,.83),(.87,.73),(.20,.59)],(0,0,0),"iron",10)
    for x,y,h in ((-.34,-.20,.35),(.28,-.23,.30),(0,.28,.43)):
        a.gem("Coal",.35,h,(x,y,.32),"black")
    a.torus("Carry_Handle",.66,.07,(0,0,1.15),"gold",rotation=(pi/2,0,0),major_segments=10)
    return a


def _shield():
    a=_a("11_Forge_Heat_Shield", "Freestanding riveted spark screen with stable angled feet.")
    for x in (-.82,.82):
        a.box("Foot",(.30,1.18,.17),(x,0,.085),"iron",.035)
        a.box("Stile",(.13,.16,2.09),(x,0,1.18),"iron",.025)
    a.box("Shield_Plate",(1.59,.10,1.71),(0,0,1.25),"stone",.10)
    for z in (.41,2.05): a.box("Shield_Rail",(1.77,.19,.13),(0,0,z),"iron",.025)
    for x in (-.64,.64):
        for z in (.65,1.88): a.cylinder("Rivet",.075,.06,(x,-.09,z),"gold",8,rotation=(pi/2,0,0))
    return a


def _blank():
    a=_a("12_Forged_Blade_Blank", "Unsharpened sword casting with a square tang, resting on a small cooling block.")
    a.box("Cooling_Block",(1.15,1.50,.17),(0,0,.085),"stone",.06)
    a.mesh("Blade_Blank",[(-.25,-.95,.18),(.25,-.95,.18),(.25,.79,.18),(0,1.28,.18),(-.25,.79,.18),
                          (-.25,-.95,.30),(.25,-.95,.30),(.25,.79,.30),(0,1.28,.30),(-.25,.79,.30)],
           [(0,4,3,2,1),(5,6,7,8,9),(0,1,6,5),(1,2,7,6),(2,3,8,7),(3,4,9,8),(4,0,5,9)],"stonelight")
    a.box("Square_Tang",(.19,.59,.12),(0,-1.20,.24),"iron",.02)
    return a


def build():
    return [_forge(),_anvil(),_quench(),_bellows(),_grinder(),_ingots(),
            _tongs(),_rack(),_mould(),_coal(),_shield(),_blank()]
