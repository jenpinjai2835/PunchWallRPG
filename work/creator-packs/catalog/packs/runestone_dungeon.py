"""Original pointed stone architecture and dungeon dressing; Z up, front -Y."""
from math import pi, cos, sin
from geometry import Asset, ring_mesh

META={
    "slug":"runestone-dungeon", "title":"Runestone Dungeon",
    "tagline":"Pointed gateways and modular ancient stonework",
    "description":"Twelve original low-poly dungeon architecture and dressing models. Grid modules, an open pointed doorway and a removable sarcophagus lid; no traps or gameplay systems.",
    "palettes":{
        "Classic":["665546","302F35","92806C","408E8E","89CAC5","AA915F","E0CC97","41434C","646C73","9EA9AB","D9D5BE","97554E","699076","797098","7D675A","222B33"],
        "Warm":["765642","352B2C","AF8B62","AF783D","E9BA6B","AE874D","EDC78B","4C4547","837063","B8A68C","EBDBC0","AD5940","8A9164","94737D","946F50","2F2D32"],
        "Twilight":["534A66","282A3B","90839F","6B68AF","B0A9E9","9783B4","D8C6EE","363F59","555E7D","929FBE","D4D9E9","8B5F91","62969B","8B72C6","756082","1D263A"]},
    "samples":["03_Flagstone_Tile","10_Broken_Column"]}


def _a(name,desc):
    a=Asset(name,"Dungeon",desc)
    a.notes={"use":"Static architecture or dressing. No collision, trap, flame or interaction logic is included.","axes":"Z up; front -Y; ground origin."}
    return a


def _lathe(a,name,rings,loc,color="stone",sides=8):
    v,f=ring_mesh(rings,sides)
    return a.mesh(name,v,f,color,loc=loc)


def _prism(a,name,outline,lo,hi,color="stone",role="Body"):
    n=len(outline)
    v=[(x,y,z) for z in (lo,hi) for x,y in outline]
    f=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return a.mesh(name,v,f,color,role=role)


def _rune(a,name,x,y,z,size=.3,color="teal",role="Body"):
    a.box(name+"_Stem",(.055,.045,size),(x,y,z),color,.009,role=role)
    a.beam(name+"_Stroke",(x,y,z),(x+size*.40,y,z+size*.32),.05,color,role=role)
    a.beam(name+"_Foot",(x-size*.38,y,z-size*.35),(x,y,z-size*.08),.05,color,role=role)


def _doorway():
    a=_a("01_Pointed_Gateway","Tall open pointed entrance with angular crown, distinct side pillars and a runic keystone.")
    for s,role in ((-1,"LeftPier"),(1,"RightPier")):
        x=s*2.0
        a.box("Pier_Foot",(.98,1.32,.24),(x,0,.12),"stonelight",.055,role=role)
        for z in (.71,1.54,2.37):
            a.box("Pier_Block",(.79,1.0,.79),(x,0,z),"stone",.06,role=role)
        a.box("Spring_Stone",(.99,1.16,.23),(x,0,2.94),"stonelight",.045,role=role)
        _rune(a,"Pier_Rune",x,-.535,1.68,.63,role=role)
        a.pivot(role,(x,0,0))
    # Two solid angular crown pieces make a pointed opening, distinct from a round arch.
    profile=[(-2.39,3.03),(-1.71,4.86),(0,6.04),(0,5.13),(-1.06,4.40),(-1.59,3.03)]
    for s in (-1,1):
        p=[(s*x,z) for x,z in profile]
        n=len(p); v=[(x,y,z) for y in (-.52,.52) for x,z in p]
        f=[tuple(reversed(range(n))),tuple(range(n,n*2))]
        f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        a.mesh("Angular_Crown",v,f,"stone",role="Crown")
        for x,z,ang in ((s*1.77,3.70,s*.37),(s*.80,5.08,s*.95)):
            a.box("Crown_Joint",(.075,1.065,.79),(x,0,z),"stonelight",.015,rotation=(0,ang,0),role="Crown")
    a.box("Keystone",(.47,1.15,.91),(0,0,5.59),"stonelight",.06,role="Crown")
    _rune(a,"Key_Rune",0,-.61,5.56,.49,role="Crown")
    a.pivot("Crown",(0,0,3.03))
    a.notes["assembly"]="Three role meshes preserve the opening. Clear lower opening 3.18 units; full footprint width4.98."
    return a


def _wall():
    a=_a("02_Masonry_Wall","Four-unit modular wall with staggered masonry, skirting and cap stones.")
    a.box("Mortar_Core",(3.96,.49,3.80),(0,0,1.99),"darkwood",.02)
    for row in range(5):
        widths=(1.3,1.3,1.3) if row%2==0 else (.64,1.3,1.3,.64)
        x=-1.97
        for j,w in enumerate(widths):
            a.box("Masonry_Block",(w-.02,.65,.64),(x+w/2,0,.57+row*.67),"stone" if (row+j)%3 else "stonelight",.055)
            x+=w+.01
    a.box("Skirting",(4,.80,.24),(0,0,.12),"stonelight",.045)
    a.box("Wall_Cap",(4,.81,.23),(0,0,3.885),"stonelight",.045)
    a.notes["grid"]="4-unit X repeat; overall height4.0 and depth0.81."
    return a


def _floor():
    a=_a("03_Flagstone_Tile","Four-by-four floor module with nine irregularly spaced beveled flagstones.")
    a.box("Tile_Bed",(4,4,.12),(0,0,.06),"darkwood",.025)
    for i,x in enumerate((-1.34,0,1.34)):
        for j,y in enumerate((-1.34,0,1.34)):
            a.box("Flagstone",(1.29,1.29,.17),(x,y,.205),"stone" if (i+j)%2 else "stonelight",.06)
    a.notes["grid"]="Exactly4×4 units. Place adjacent tile origins4units apart; top Z0.29."
    return a


def _pillar():
    a=_a("04_Octagonal_Pillar","Tall fluted octagonal support with stepped base and broad square capital.")
    a.box("Pillar_Plinth",(1.51,1.51,.25),(0,0,.125),"stone",.08)
    _lathe(a,"Octagonal_Base",[(0,.72),(.23,.72),(.36,.53)],(0,0,.25),"stonelight")
    _lathe(a,"Column_Shaft",[(0,.52),(2.59,.48),(2.70,.56)],(0,0,.60),"stone")
    for t in (pi/4,pi*3/4,pi*5/4,pi*7/4):
        a.beam("Flute",(.51*cos(t),.51*sin(t),.79),(.48*cos(t),.48*sin(t),3.07),.055,"darkwood")
    _lathe(a,"Capital_Bell",[(0,.55),(.25,.76)],(0,0,3.30),"stonelight")
    a.box("Abacus",(1.65,1.65,.22),(0,0,3.66),"stone",.065)
    return a


def _brazier():
    a=_a("05_Tripod_Brazier","Iron fire bowl on three crossed feet with faceted coals and stylized flame forms.")
    for t in (0,2*pi/3,4*pi/3):
        a.cylinder("Foot_Pad",.12,.10,(.75*cos(t),.75*sin(t),.05),"iron",8)
        a.beam("Splayed_Leg",(.75*cos(t),.75*sin(t),.08),(.42*cos(t),.42*sin(t),1.11),.14,"iron")
    _lathe(a,"Fire_Bowl",[(0,.26),(.33,.74),(.47,.86),(.54,.86),(.54,.74),(.20,.35)],(0,0,.95),"iron",12)
    for x,y in ((-.25,-.23),(.27,-.12),(0,.29)):
        a.gem("Coal",.28,.22,(x,y,1.20),"black")
    for x,h in ((-.29,.56),(.13,.86),(.41,.39)):
        a.gem("Flame",.19,h,(x,0,1.40),"teallight")
    a.torus("Bowl_Rim",.82,.055,(0,0,1.48),"gold",major_segments=12)
    return a


def _sarcophagus():
    a=_a("06_Stone_Sarcophagus","Thick-walled tapered stone coffin with a separate lift-off lid and geometric relief.")
    outline=[(-.73,-1.68),(.73,-1.68),(.91,.69),(.56,1.54),(-.56,1.54),(-.91,.69)]
    _prism(a,"Foot_Slab",[(x*1.12,y*1.05) for x,y in outline],0,.22,"stonelight")
    n=len(outline)
    # Outer floor, outer rim, inner rim and interior floor form a closed thick shell.
    v=[]
    for sc,z in ((1,.22),(1,1.20),(.81,1.20),(.81,.43)):
        v.extend((x*sc,y*sc,z) for x,y in outline)
    f=[tuple(reversed(range(n))),tuple(range(n*3,n*4))]
    for level in range(3): f.extend((level*n+i,level*n+(i+1)%n,(level+1)*n+(i+1)%n,(level+1)*n+i) for i in range(n))
    a.mesh("Thick_Casket",v,f,"stone")
    _prism(a,"Lift_Off_Lid",[(x*1.08,y*1.04) for x,y in outline],1.205,1.43,"stonelight",role="Lid")
    a.box("Lid_Spine",(.15,2.45,.09),(0,-.02,1.465),"gold",.02,role="Lid")
    a.box("Relief_Crossbar",(.95,.15,.095),(0,.30,1.465),"gold",.02,role="Lid")
    a.box("Head_Gem",(.34,.42,.16),(0,.94,1.51),"teal",.08,role="Lid")
    a.pivot("Lid",(0,0,1.205))
    a.notes["lid"]="Two roles. Lid lifts vertically; no hinge or animation is included."
    return a


def _altar():
    a=_a("07_Ritual_Altar","Wide offering altar with inset front runes and a stepped stone offering dish.")
    a.box("Altar_Base",(3.22,1.70,.22),(0,0,.11),"stone",.09)
    for x in (-1.06,1.06):
        a.box("Altar_Support",(.67,1.12,1.13),(x,0,.78),"stone",.09)
        a.box("Support_Capital",(.87,1.25,.16),(x,0,1.37),"stonelight",.045)
    a.box("Altar_Table",(3.46,1.87,.26),(0,0,1.57),"stonelight",.08)
    a.box("Front_Frieze",(2.99,.10,.38),(0,-.70,1.21),"stone",.04)
    for x in (-.72,0,.72): _rune(a,"Frieze_Rune",x,-.77,1.22,.28)
    _lathe(a,"Offering_Dish",[(0,.38),(.11,.57),(.21,.64),(.21,.51),(.09,.34)],(0,0,1.70),"gold",10)
    return a


def _portcullis():
    a=_a("08_Iron_Grate","Three-unit freestanding iron grate panel with thick perimeter and pointed lower bars.")
    for x in (-1.42,1.42): a.box("Frame_Stile",(.16,.24,3.48),(x,0,1.74),"iron",.025)
    for z in (.19,1.39,2.47,3.42): a.box("Cross_Rail",(2.85,.19,.13),(0,0,z),"iron",.02)
    for x in (-1.03,-.51,0,.51,1.03):
        a.box("Vertical_Bar",(.10,.11,3.20),(x,0,1.81),"iron",.018)
        a.gem("Bar_Point",.08,.22,(x,0,.22),"gold",rotation=(pi,0,0))
    a.notes["assembly"]="3-unit overall width. Mount in a doorway or recess; static grate, no opening mechanism."
    return a


def _sconce():
    a=_a("09_Wall_Sconce","Wall-mounted stone backplate with a supported iron cup and faceted torch flame.")
    a.box("Wall_Plate",(.64,.16,1.59),(0,.28,.795),"stone",.09)
    for z in (.25,1.31): a.cylinder("Anchor",.095,.09,(0,.16,z),"gold",8,rotation=(pi/2,0,0))
    a.beam("Cup_Bracket",(0,.19,.55),(0,-.40,.88),.15,"iron")
    _lathe(a,"Torch_Cup",[(0,.16),(.20,.29),(.36,.35),(.36,.28),(.15,.13)],(0,-.39,.85),"iron",10)
    a.cylinder("Fuel_Core",.19,.12,(0,-.39,1.16),"black",10)
    a.gem("Flame",.22,.66,(0,-.39,1.22),"teallight")
    a.notes["mount"]="Backplate rear plane Y0.36; attach to a wall. No PointLight or particle effect included."
    return a


def _broken():
    a=_a("10_Broken_Column","Jagged column stump and two fallen stone fragments for ruined corners.")
    a.box("Broken_Base",(1.52,1.52,.20),(-.25,0,.10),"stonelight",.07)
    sides=8; r=.55
    heights=(1.01,1.20,1.09,.90,1.02,.83,1.12,.95)
    v=[(r*cos(i*pi/4)-.25,r*sin(i*pi/4),.20) for i in range(sides)]
    v.extend((r*cos(i*pi/4)-.25,r*sin(i*pi/4),heights[i]) for i in range(sides))
    v.append((-.25,0,1.0))
    f=[tuple(reversed(range(sides)))]
    f.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
    f.extend((8+i,8+(i+1)%sides,16) for i in range(sides))
    a.mesh("Jagged_Stump",v,f,"stone")
    for x,y,z,col in ((.83,-.57,.23,"stone"),(.95,.47,.16,"stonelight")):
        a.gem("Fallen_Fragment",.34,z*2,(x,y,0),col,rotation=(0,0,.38))
    return a


def _steps():
    a=_a("11_Three_Stone_Steps","Compact three-step stair module with carved edge strips and complete underside.")
    for i in range(3):
        z=(i+1)*.34
        a.box("Stone_Step",(3.0,.85,z),(0,-.85+i*.84,z/2),"stone",.06)
        a.box("Tread_Nose",(2.95,.13,.07),(0,-1.24+i*.84,z-.035),"stonelight",.02)
    a.notes["grid"]="3units wide, rise0.34 and run0.84 per tread; total rise1.02."
    return a


def _obelisk():
    a=_a("12_Rune_Obelisk","Compact pointed boundary marker with inset glowing-color runes and a stone socket.")
    a.box("Socket",(1.18,1.12,.22),(0,0,.11),"stonelight",.08)
    a.mesh("Obelisk",[(-.36,-.32,.22),(.36,-.32,.22),(.36,.32,.22),(-.36,.32,.22),
                       (-.30,-.27,2.15),(.30,-.27,2.15),(.30,.27,2.15),(-.30,.27,2.15),(0,0,2.67)],
           [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8)],"stone")
    for z in (.70,1.21,1.72): _rune(a,"Marker_Rune",0,-.322+(.027*(z-.22)),z,.31)
    return a


def build():
    return [_doorway(),_wall(),_floor(),_pillar(),_brazier(),_sarcophagus(),
            _altar(),_portcullis(),_sconce(),_broken(),_steps(),_obelisk()]
