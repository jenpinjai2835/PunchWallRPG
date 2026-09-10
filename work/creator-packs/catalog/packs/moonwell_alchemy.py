"""Original vessel-rich alchemy collection, separate from the merchant fixtures."""
from math import pi, cos, sin
from geometry import Asset, ring_mesh

META = {
    "slug":"moonwell-alchemy", "title":"Moonwell Alchemy",
    "tagline":"A moonlit fantasy research workshop",
    "description":"Twelve original low-poly alchemy props with thick vessels, supported apparatus and readable work surfaces. Opaque stylized materials; no brewing systems.",
    "palettes":{
        "Classic":["5B4963","302A40","A08AAA","517E91","9ED9D5","BC9E64","F0DAB1","484B63","657380","B4C0C2","ECE5D3","AB5D78","6CA68F","9473B7","8A6C71","252A3E"],
        "Warm":["765C57","362B36","BA9C86","93734D","E0BC7D","B9914F","F5DAB2","565060","827A75","C4BEB0","F3E6C9","B56369","83A777","B585A0","98776A","2C2B39"],
        "Twilight":["4D4266","29243D","8C7EAB","706CB4","B5BCE8","9B8CBF","E1D5F3","3F4566","606584","A2ABC9","E4E3F0","A66EA2","699C9E","A087D2","77618D","20243B"]},
    "samples":["08_Mortar_and_Pestle","12_Wax_Seal_Set"]}


def _a(name,desc):
    a=Asset(name,"Alchemy",desc)
    a.notes={"use":"Static fantasy research prop; opaque vessels, no brewing logic or simulated liquid.","axes":"Z up; front -Y; ground placement."}
    return a


def _lathe(a,name,rings,loc,color="teal",sides=12):
    v,f=ring_mesh(rings,sides)
    return a.mesh(name,v,f,color,loc=loc)


def _jar(a,name,loc,scale=1,color="amethyst"):
    x,y,z=loc
    _lathe(a,name,[(0,.23*scale),(.08*scale,.30*scale),(.46*scale,.30*scale),(.59*scale,.17*scale),(.72*scale,.17*scale)],(x,y,z),color,10)
    a.cylinder(name+"_Stopper",.19*scale,.13*scale,(x,y,z+.77*scale),"woodlight",10)
    a.torus(name+"_Neck_Band",.18*scale,.032*scale,(x,y,z+.62*scale),"gold",major_segments=10)


def _bench():
    a=_a("01_Crescent_Workbench","Deep rounded research bench with a moon crest, lower books and a raised reagent ledge.")
    for x in (-1.66,1.66):
        for y in (-.79,.79):
            a.box("Foot",(.44,.44,.16),(x,y,.08),"gold",.05)
            a.beam("Taper_Leg",(x,y,.16),(x*.93,y*.93,1.62),.23,"wood")
    a.box("Lower_Shelf",(3.50,1.57,.16),(0,0,.55),"darkwood",.08)
    a.box("Deep_Worktop",(4.13,2.26,.23),(0,0,1.77),"woodlight",.18)
    a.box("Front_Apron",(3.55,.15,.29),(0,-.95,1.48),"wood",.04)
    for x in (-1.58,1.58): a.box("Ledge_Post",(.16,.17,.69),(x,.91,2.18),"wood",.025)
    a.box("Raised_Ledge",(3.46,.59,.14),(0,.90,2.52),"wood",.05)
    for x in (-1.12,1.12): _jar(a,"Ledge_Jar",(x,.90,2.60),.67,"teal")
    for x,w,h,col in ((-.86,.58,.32,"amethyst"),(-.11,.75,.44,"teal"),(.74,.68,.23,"wood")):
        a.box("Stored_Tome",(w,1.03,h),(x,0,.63+h/2),col,.04)
        a.box("Tome_Page_Edge",(w*.80,.05,h*.66),(x,-.54,.63+h/2),"cream",.01)
    a.cylinder("Moon_Crest",.18,.06,(0,-1.065,1.48),"gold",12,rotation=(pi/2,0,0))
    a.cylinder("Crescent_Inset",.143,.025,(.071,-1.10,1.54),"wood",12,rotation=(pi/2,0,0))
    return a


def _cauldron():
    a=_a("02_Tripod_Cauldron","Round thick-walled brewing pot with three splayed feet and side handles.")
    for t in (pi/6,pi*5/6,pi*3/2):
        a.cylinder("Foot_Pad",.14,.10,(.95*cos(t),.95*sin(t),.05),"iron",8)
        a.beam("Pot_Leg",(.95*cos(t),.95*sin(t),.08),(.68*cos(t),.68*sin(t),.63),.19,"iron")
    _lathe(a,"Pot_Shell",[(0,.57),(.20,.87),(.79,1.04),(1.11,.89),(1.11,.75),(.25,.67)],(0,0,.40),"iron",14)
    a.torus("Thick_Rim",.83,.083,(0,0,1.51),"gold",major_segments=14)
    a.cylinder("Brew_Surface",.73,.045,(0,0,1.22),"teal",14)
    for x in (-1.00,1.00):
        a.torus("Side_Handle",.27,.06,(x,0,1.12),"gold",rotation=(pi/2,0,0),major_segments=10)
        a.box("Handle_Lug",(.22,.22,.15),(x*.91,0,.97),"iron",.03)
    a.notes["contents"]="Removable opaque brew surface; hollow pot has an inner wall and floor."
    return a


def _distiller():
    a=_a("03_Copper_Distiller","Supported bulb retort with copper transfer pipe, condenser column and receiving flask.")
    a.box("Apparatus_Plinth",(3.35,1.77,.17),(0,0,.085),"darkwood",.10)
    for x in (-.92,.86): a.cylinder("Vessel_Base",.53,.13,(x,0,.235),"gold",10)
    _lathe(a,"Retort_Bulb",[(0,.23),(.26,.52),(.72,.61),(1.01,.42),(1.24,.14),(1.64,.14)],(-.92,0,.30),"teal",12)
    a.torus("Bulb_Support",.50,.06,(-.92,0,.57),"gold",major_segments=12)
    for y in (-.48,.48): a.beam("Retort_Leg",(-.92,y,.28),(-.92,y,.60),.09,"gold")
    a.beam("Transfer_Rise",(-.92,0,1.93),(-.69,0,2.24),.19,"gold")
    a.beam("Transfer_Arm",(-.69,0,2.24),(.83,0,2.07),.19,"gold")
    a.cylinder("Condenser",.26,1.03,(.84,0,1.59),"gold",12)
    for z in (1.15,1.36,1.57,1.78,1.99): a.torus("Cooling_Rib",.29,.045,(.84,0,z),"goldlight",major_segments=12)
    a.box("Column_Stand",(.20,.32,.99),(1.25,.07,.67),"iron",.03)
    a.beam("Column_Clamp",(1.25,.07,1.11),(.85,.07,1.11),.12,"iron")
    _jar(a,"Receiver",(.84,0,.30),.78,"amethyst")
    a.beam("Outlet",(.84,0,1.09),(.84,0,.92),.12,"gold")
    return a


def _case():
    a=_a("04_Specimen_Stand","Open specimen cabinet with two shelves, a peaked canopy and mounted curios.")
    for x in (-1.0,1.0):
        a.box("Foot",(.43,.85,.14),(x,0,.07),"darkwood",.04)
        a.box("Side_Frame",(.15,.15,2.69),(x,.27,1.48),"gold",.025)
    for z in (.31,1.38): a.box("Shelf",(2.32,.94,.14),(0,0,z),"wood",.065)
    a.box("Back_Panel",(2.01,.11,2.04),(0,.39,1.49),"darkwood",.07)
    for x in (-.55,.55):
        _jar(a,"Specimen_Jar",(x,0,.39),.74,"emerald" if x<0 else "amethyst")
        a.cylinder("Gem_Mount",.21,.10,(x,0,1.53),"gold",8)
        a.gem("Mounted_Shard",.17,.48,(x,0,1.58),"teallight")
    a.beam("Canopy_Left",(-1.17,.20,2.64),(0,.20,3.18),.18,"woodlight")
    a.beam("Canopy_Right",(0,.20,3.18),(1.17,.20,2.64),.18,"woodlight")
    return a


def _scale():
    a=_a("05_Apothecary_Balance","Countertop balance with pivot beam and two suspended thick weighing pans.")
    a.box("Scale_Base",(1.35,.80,.17),(0,0,.085),"stone",.12)
    a.cylinder("Upright",.11,1.67,(0,0,1.0),"gold",10)
    a.cylinder("Beam_Pivot",.16,.22,(0,0,1.88),"goldlight",10,rotation=(pi/2,0,0))
    a.box("Balance_Beam",(2.51,.13,.14),(0,0,1.90),"gold",.03)
    for x in (-1.02,1.02):
        _lathe(a,"Pan",[(0,.26),(.10,.42),(.19,.47),(.19,.40),(.07,.25)],(x,0,.79),"gold",10)
        for y in (-.31,.31): a.beam("Pan_Suspension",(x,y,.95),(x,0,1.89),.045,"gold")
    a.box("Pointer",(.05,.05,.49),(0,-.10,1.57),"teal",.012)
    return a


def _bookstand():
    a=_a("06_Open_Tome_Stand","Inclined open folio on a braced lectern, with thick covers and blank cream pages.")
    a.box("Lectern_Base",(1.37,1.10,.17),(0,0,.085),"wood",.06)
    a.beam("Lectern_Stem",(0,.14,.17),(0,.14,1.07),.24,"wood")
    a.beam("Reading_Brace",(0,-.34,.85),(0,.39,1.30),.17,"wood")
    a.box("Book_Board",(1.77,1.22,.12),(0,0,1.14),"woodlight",.04,rotation=(.31,0,0))
    for s in (-1,1):
        a.box("Folio_Cover",(.85,1.07,.09),(s*.42,-.03,1.255),"amethyst",.035,rotation=(.31,s*.08,0))
        a.box("Blank_Page_Block",(.73,.96,.13),(s*.40,-.051,1.35),"cream",.03,rotation=(.31,s*.08,0))
    a.box("Spine",(.13,1.10,.17),(0,-.047,1.34),"gold",.035,rotation=(.31,0,0))
    a.notes["text"]="Blank pages for localization; no spells or protected artwork are baked in."
    return a


def _reagents():
    a=_a("07_Reagent_Caddy","Portable two-step reagent organizer with five differently sized stoppered bottles.")
    a.box("Bottom_Tray",(2.25,1.50,.16),(0,0,.08),"wood",.065)
    a.box("Rear_Riser",(2.08,.59,.29),(0,.42,.29),"darkwood",.04)
    for x,col in ((-.72,"emerald"),(0,"amethyst"),(.72,"teal")): _jar(a,"Rear_Reagent",(x,.42,.435),.75,col)
    for x,col in ((-.42,"teallight"),(.42,"red")): _jar(a,"Front_Reagent",(x,-.34,.16),.67,col)
    for x in (-1.12,1.12): a.box("Carry_End",(.12,1.40,.36),(x,0,.32),"woodlight",.05)
    return a


def _mortar():
    a=_a("08_Mortar_and_Pestle","Thick stone mortar with a rounded pestle resting across its rim.")
    _lathe(a,"Mortar",[(0,.39),(.11,.55),(.60,.65),(.73,.58),(.73,.44),(.19,.31)],(0,0,0),"stonelight",12)
    a.cylinder("Foot_Ring",.44,.10,(0,0,.05),"stone",12)
    a.beam("Pestle_Shaft",(-.58,0,.79),(.48,0,.81),.19,"stone")
    a.cylinder("Pestle_Head",.22,.31,(.46,0,.81),"stonelight",10,rotation=(0,pi/2,0))
    return a


def _scrolls():
    a=_a("09_Scroll_Cradle","Two rolled folios in a low crossed wooden cradle with decorative cord bands.")
    for x in (-.66,.66):
        a.box("Cradle_Foot",(.25,.81,.12),(x,0,.06),"wood",.03)
        for s in (-1,1): a.beam("Cradle_Arm",(x,0,.16),(x,s*.49,.65),.12,"woodlight")
    for y in (-.18,.18):
        a.cylinder("Rolled_Folio",.18,1.68,(0,y,.60),"cream",12,rotation=(0,pi/2,0))
        for x in (-.51,.51): a.torus("Cord_Band",.184,.022,(x,y,.60),"gold",rotation=(0,pi/2,0),major_segments=12)
    return a


def _herbs():
    a=_a("10_Herb_Drying_Frame","Freestanding tripod drying frame with two hanging bundles of broad leaves.")
    for x,y in ((-.89,-.60),(.89,-.60),(0,.86)):
        a.cylinder("Foot_Collar",.13,.12,(x,y,.06),"wood",8)
        a.beam("Tripod",(x,y,.08),(0,0,2.63),.17,"wood")
    a.beam("Crossbar",(-1.05,0,2.13),(1.05,0,2.13),.13,"woodlight")
    for x in (-.62,.62):
        a.beam("Tie",(x,0,2.13),(x,0,1.81),.065,"leather")
        for dx in (-.13,0,.13):
            a.beam("Herb_Stem",(x,0,1.91),(x+dx,-.02,1.11),.035,"emerald")
            for z in (1.32,1.54):
                a.gem("Broad_Leaf",.11,.32,(x+dx,-.04,z),"emerald",rotation=(0,.60 if dx>0 else -.60,0))
    return a


def _focus():
    a=_a("11_Prism_Focus","Horizontal research prism secured between two brass cradle brackets.")
    a.box("Focus_Base",(1.89,1.04,.15),(0,0,.075),"stone",.11)
    for x in (-.63,.63):
        a.box("Cradle_Pillar",(.17,.33,.64),(x,0,.43),"gold",.025)
        a.torus("Prism_Clamp",.32,.054,(x,0,.76),"gold",rotation=(0,pi/2,0),major_segments=6)
    a.cylinder("Long_Prism",.28,1.72,(0,0,.76),"teallight",6,rotation=(0,pi/2,0))
    return a


def _seal():
    a=_a("12_Wax_Seal_Set","Desk seal with carved handle, wax puck and small spoon on a rounded tray.")
    a.box("Seal_Tray",(1.38,1.0,.10),(0,0,.05),"woodlight",.12)
    a.cylinder("Seal_Foot",.23,.14,(-.29,.05,.17),"gold",10)
    _lathe(a,"Carved_Handle",[(0,.16),(.16,.11),(.33,.17),(.48,.14)],(-.29,.05,.24),"wood",10)
    a.cylinder("Wax_Puck",.20,.10,(.34,.12,.15),"red",10)
    a.cylinder("Spoon_Bowl",.12,.055,(.29,-.29,.135),"gold",10)
    a.beam("Spoon_Handle",(.29,-.29,.14),(-.32,-.29,.14),.055,"gold")
    return a


def build():
    return [_bench(),_cauldron(),_distiller(),_case(),_scale(),_bookstand(),
            _reagents(),_mortar(),_scrolls(),_herbs(),_focus(),_seal()]
