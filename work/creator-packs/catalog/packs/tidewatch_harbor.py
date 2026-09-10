"""Original modular waterfront props. Z up, front -Y, units intended studs."""
from math import cos, sin, pi
from geometry import Asset, ring_mesh

META={"slug":"tidewatch-harbor","title":"Tidewatch Harbor",
 "tagline":"Twelve coastal props for a small fishing dock and waterfront.",
 "description":"Modular docks, navigation markers and nautical equipment in a cohesive painted-timber style. Original visual models; no water, boats, fishing systems or scripts.",
 "palettes":{
  "Classic":["8B694B","41443D","C4A379","457E92","86BAC3","CBA267","F0D3A0","4B5F69","758B93","B0C3C4","EFE6CC","C86045","6D9F8B","8E86A6","A38361","283D49"],
  "Warm":["A5784F","514339","D7B786","AA7050","DCAC7A","DBB274","FFE0AB","656767","8D9691","C6CCC0","F6E7C8","B64D37","91AA79","A994A6","B89167","3C4244"],
  "Twilight":["746867","373E4C","B8AFA1","53648D","99ACD0","B7A071","E6D8BA","49556F","7B8BA2","B5C5D7","E4E7E8","AD6B76","719F9F","ABA0CB","978476","273348"]},
 "samples":["04_Mooring_Bollard","08_Rope_Coil"]}


def _a(name,desc):
    a=Asset(name,"Harbor",desc)
    a.notes={"use":"Static original waterfront prop; no runtime systems or scripts."}
    return a


def _lathe(a,name,rings,loc=(0,0,0),color="teal",sides=12):
    v,f=ring_mesh(rings,sides)
    return a.mesh(name,v,f,loc=loc,color=color)


def _panel(a,name,xz,depth,y,color="iron"):
    n=len(xz);v=[(x,y+d,z) for d in (-depth/2,depth/2) for x,z in xz]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return a.mesh(name,v,f,color=color)


def _dock():
    a=_a("01_Straight_Dock","Six-stud straight dock segment with separate boards, underdeck beams and round mooring posts.")
    for i in range(10):
        a.box(f"Deck_Board_{i}",(2.98,.582,.16),(0,(i-4.5)*.60,1.08),color="woodlight" if i%3 else "wood",bevel=.025)
    for x in (-1.23,1.23):
        a.box(f"Underdeck_Beam_{x}",(.18,5.91,.26),(x,0,.89),color="wood",bevel=.03)
        for y in (-2.66,2.66):
            a.cylinder(f"Pile_{x}_{y}",.19,1.70,(x,y,.85),color="darkwood",vertices=10)
            a.cylinder(f"Pile_Cap_{x}_{y}",.205,.08,(x,y,1.72),color="teal",vertices=10)
            a.torus(f"Mooring_Rope_{x}_{y}",.192,.038,(x,y,1.42),color="cream",major_segments=10)
    a.notes["modular"]="Deck 2.98 by 5.982 studs; use a 3 by 6-stud grid. Width matches the corner dock arms. Deck surface at Z=1.16; piles extend to root."
    return a


def _corner():
    a=_a("02_Corner_Dock","L-shaped boardwalk corner with full underside joists and six ground piles.")
    # A 6 by 6 footprint with a genuine 3 by 3 open corner.
    for j in range(10):
        y=(j-4.5)*.60
        width=5.98 if j<5 else 2.98
        center=0 if j<5 else -1.5
        a.box(f"Corner_Deck_Board_{j}",(width,.58,.16),(center,y,1.08),color="woodlight" if j%3 else "wood",bevel=.025)
    for x in (-2.7,-.25):
        a.box(f"Long_Joist_{x}",(.17,5.90,.25),(x,0,.89),color="wood",bevel=.025)
    for x in (.25,2.7):
        a.box(f"Short_Joist_{x}",(.17,2.93,.25),(x,-1.5,.89),color="wood",bevel=.025)
    for i,(x,y) in enumerate(((-2.7,-2.7),(2.7,-2.7),(2.7,-.3),(-.3,-.3),(-.3,2.7),(-2.7,2.7))):
        a.cylinder(f"Corner_Pile_{i}",.18,1.65,(x,y,.825),color="darkwood",vertices=10)
        a.cylinder(f"Blue_Pile_Cap_{i}",.20,.08,(x,y,1.69),color="teal",vertices=10)
    a.notes["modular"]="L-shaped 6 by 6-stud module with 3-stud-wide arms and deck surface Z=1.16. Rotate around Z for other corners."
    return a


def _beacon():
    a=_a("03_Navigation_Beacon","Striped harbor beacon on a stepped stone base with protected lantern and rain roof.")
    _lathe(a,"Stone_Foot",[(0,.70),(.18,.76),(.35,.58),(.47,.52)],color="stonelight")
    _lathe(a,"Beacon_Mast",[(.45,.42),(2.45,.34)],color="cream")
    for z in (.77,1.56):
        _lathe(a,f"Red_Mast_Band_{z}",[(z,.438-(z-.45)*.04),(z+.35,.438-(z-.10)*.04)],color="red")
    a.cylinder("Lantern_Balcony",.60,.13,(0,0,2.49),color="iron",vertices=12)
    a.cylinder("Amber_Lens",.35,.66,(0,0,2.86),color="goldlight",vertices=12)
    for i in range(6):
        t=i*pi/3
        a.beam(f"Lens_Guard_{i}",(.42*cos(t),.42*sin(t),2.54),(.42*cos(t),.42*sin(t),3.23),.052,color="iron")
    _lathe(a,"Rain_Roof",[(3.20,.55),(3.30,.58),(3.65,.12)],color="teal")
    a.gem("Roof_Finial",.09,.23,(0,0,3.60),color="gold")
    return a


def _bollard():
    a=_a("04_Mooring_Bollard","Rounded T-shaped mooring bollard on a four-bolt deck mounting plate.")
    a.box("Deck_Plate",(1.34,.98,.14),(0,0,.07),color="iron",bevel=.09)
    _lathe(a,"Bollard_Stem",[(.13,.26),(.61,.23),(.80,.31)],color="teal")
    a.box("Mooring_Crossbar",(1.05,.44,.25),(0,0,.78),color="teal",bevel=.11)
    for x in (-.46,.46):
        for y in (-.30,.30):
            a.cylinder(f"Mounting_Bolt_{x}_{y}",.062,.05,(x,y,.16),color="gold",vertices=6)
    return a


def _buoy():
    a=_a("05_Channel_Buoy","Faceted red-and-cream channel buoy with an open safety frame and top marker.")
    _lathe(a,"Buoy_Float",[(0,.31),(.15,.64),(.37,.82),(.64,.66),(.76,.40)],color="red")
    _lathe(a,"White_Float_Band",[(.29,.77),(.37,.834),(.46,.785)],color="cream")
    a.cylinder("Marker_Mast",.087,1.43,(0,0,1.38),color="iron",vertices=10)
    for i in range(4):
        t=i*pi/2
        a.beam(f"Cage_Leg_{i}",(.40*cos(t),.40*sin(t),.68),(.24*cos(t),.24*sin(t),1.58),.048,color="red")
    a.torus("Cage_Rim",.24,.040,(0,0,1.58),color="red")
    _panel(a,"Daymark_Triangle",[(-.31,1.91),(.31,1.91),(0,2.43)],.075,0,"red")
    a.notes["placement"]="Float bottom is at root. Place at the desired water surface; no buoyancy behavior is included."
    return a


def _rods():
    a=_a("06_Fishing_Rod_Rack","Three tapered fishing rods supported by a two-tier wooden display rack.")
    for x in (-.9,.9):
        a.box(f"Rack_Foot_{x}",(.24,.69,.13),(x,0,.065),color="wood",bevel=.04)
        a.box(f"Rack_Upright_{x}",(.14,.14,2.11),(x,.10,1.11),color="woodlight",bevel=.025)
    for z in (.28,1.43):
        a.box(f"Cradle_{z}",(2.03,.23,.16),(0,0,z),color="teal",bevel=.04)
    for i,x in enumerate((-.60,0,.60)):
        a.beam(f"Rod_Grip_{i}",(x,0,.36),(x,0,1.11),.11,color="leather")
        a.beam(f"Rod_Lower_{i}",(x,0,1.04),(x+.14,0,2.49),.045,color="woodlight")
        a.beam(f"Rod_Tip_{i}",(x+.14,0,2.49),(x+.35,0,3.33),.022,color="woodlight")
        a.cylinder(f"Reel_{i}",.15,.09,(x,-.10,.85),color="iron",vertices=10,rotation=(pi/2,0,0))
        for j,(dx,z) in enumerate(((.04,1.55),(.14,2.47),(.31,3.19))):
            a.torus(f"Line_Guide_{i}_{j}",.055,.012,(x+dx,-.02,z),color="gold",rotation=(pi/2,0,0),major_segments=8,minor_segments=4)
    return a


def _trap():
    a=_a("07_Lobster_Trap","Domed slatted lobster trap with thick bent ribs and a circular entry collar.")
    for j,y in enumerate((-.63,-.31,0,.31,.63)):
        a.box(f"Trap_Floor_{j}",(2.38,.25,.10),(0,y,.05),color="wood",bevel=.018)
    for y in (-.80,.80):
        a.box(f"Rib_Support_Rail_{y}",(2.38,.09,.10),(0,y,.09),color="wood",bevel=.015)
    for ix,x in enumerate((-1.14,-.39,.39,1.14)):
        for i in range(8):
            p,q=i*pi/8,(i+1)*pi/8
            a.beam(f"Bent_Rib_{ix}_{i}",(x,.82*cos(p),.11+.78*sin(p)),(x,.82*cos(q),.11+.78*sin(q)),.062,color="woodlight")
    for i in range(7):
        t=(i+1)*pi/8
        a.beam(f"Long_Slat_{i}",(-1.18,.82*cos(t),.11+.78*sin(t)),(1.18,.82*cos(t),.11+.78*sin(t)),.055,color="wood")
    for x in (-1.18,1.18):
        a.torus(f"Entry_Collar_{x}",.22,.038,(x,0,.40),color="cream",rotation=(0,pi/2,0))
        for i in range(5):
            t=i*pi/4
            a.beam(f"Entry_Weave_{x}_{i}",(x,.245*cos(t),.40+.245*sin(t)),(x,.78*cos(t),.12+.74*sin(t)),.033,color="woodlight")
    return a


def _rope():
    a=_a("08_Rope_Coil","Flat five-turn dock rope coil with a short loose end.")
    for i,r in enumerate((.21,.33,.45,.57,.69)):
        a.torus(f"Rope_Turn_{i}",r,.055,(0,0,.055),color="cream",major_segments=24,minor_segments=5)
    a.beam("Loose_End_A",(.70,0,.055),(.97,-.15,.055),.09,color="cream")
    a.beam("Loose_End_B",(.97,-.15,.055),(1.05,-.46,.055),.09,color="cream")
    return a


def _anchor():
    a=_a("09_Harbor_Anchor","Upright nautical anchor with broad pointed flukes and a closed attachment ring.")
    a.box("Anchor_Shank",(.18,.18,2.07),(0,0,1.20),color="iron",bevel=.035)
    a.box("Cross_Stock",(1.13,.24,.16),(0,0,1.84),color="woodlight",bevel=.05)
    a.torus("Attachment_Ring",.21,.060,(0,0,2.40),color="iron",rotation=(pi/2,0,0))
    _panel(a,"Anchor_Crown",[(-.23,.36),(0,.16),(.23,.36),(.12,.51),(-.12,.51)],.22,0)
    for side in (-1,1):
        _panel(a,f"Curved_Arm_{side}",[(0,.18),(side*.47,.28),(side*.95,.85),(side*.80,.91),(side*.37,.48),(0,.40)],.17,0)
        _panel(a,f"Pointed_Fluke_{side}",[(side*.67,.71),(side*.99,.63),(side*1.02,1.16)],.20,0)
    # Small cradle holds this display upright rather than leaving it unsupported.
    a.box("Display_Cradle",(.80,.61,.16),(0,0,.08),color="wood",bevel=.07)
    return a


def _fish_crate():
    a=_a("10_Fresh_Catch_Crate","Low dockside catch box with three sculpted fish resting on ice pieces.")
    a.box("Box_Floor",(2.13,1.40,.10),(0,0,.05),color="woodlight",bevel=.03)
    for y in (-.66,.66):
        a.box(f"Painted_Long_Wall_{y}",(2.13,.12,.49),(0,y,.30),color="teal",bevel=.03)
    for x in (-1,1):
        a.box(f"End_Wall_{x}",(.13,1.28,.49),(x,0,.30),color="woodlight",bevel=.03)
    for i in range(8):
        a.gem(f"Ice_Piece_{i}",.22,.20,((i%4-1.5)*.46,(i//4-.5)*.61,.12),color="stonelight",rotation=(0,0,i*.7))
    for i,y in enumerate((-.37,0,.37)):
        v=[(-.65,y,.38),(-.41,y-.12,.39),(.40,y-.12,.39),(.59,y,.39),(.40,y+.12,.39),(-.41,y+.12,.39),
           (-.34,y,.55),(.28,y,.51)]
        f=[(0,1,6),(1,2,7,6),(2,3,7),(3,4,7),(4,5,6,7),(5,0,6),(0,5,4,3,2,1)]
        # The tail is a separate thick prism instead of two coincident surfaces.
        a.mesh(f"Fish_Body_{i}",v,f,color="cream" if i%2 else "stonelight")
        _panel(a,f"Fish_Tail_{i}",[(-.65,.39),(-.88,.53),(-.88,.28)],.09,y,"teallight")
        a.cylinder(f"Fish_Eye_{i}",.021,.012,(.42,y-.111,.444),color="black",vertices=8,rotation=(pi/2,0,0))
    return a


def _life_ring():
    a=_a("11_Life_Ring","Flat rescue ring with four contrasting wrap bands and a continuous inner opening.")
    a.torus("Rescue_Ring",.68,.18,(0,0,.19),color="red",major_segments=24,minor_segments=8)
    for k in range(4):
        verts=[]
        for i in range(4):
            t=k*pi/2-.15+i*.10
            for j in range(8):
                s=j*pi/4
                verts.append(((.68+.19*cos(s))*cos(t),(.68+.19*cos(s))*sin(t),.19+.19*sin(s)))
        faces=[tuple(reversed(range(8))),tuple(range(24,32))]
        faces += [(i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j) for i in range(3) for j in range(8)]
        a.mesh(f"White_Wrap_{k}",verts,faces,color="cream")
    a.notes["placement"]="Supplied lying flat at ground; rotate and mount on a wall if desired."
    return a


def _ladder():
    a=_a("12_Dock_Ladder","Five-rung metal dock ladder with curved top hooks and capped side rails.")
    for x in (-.55,.55):
        a.box(f"Long_Rail_{x}",(.10,.12,2.60),(x,0,1.30),color="teal",bevel=.035)
        for i in range(6):
            p,q=i*pi/6,(i+1)*pi/6
            a.beam(f"Curved_Hook_{x}_{i}",(x,.22-.22*cos(p),2.58+.22*sin(p)),(x,.22-.22*cos(q),2.58+.22*sin(q)),.09,color="teal")
    for i,z in enumerate((.28,.76,1.24,1.72,2.20)):
        a.beam(f"Ladder_Rung_{i}",(-.56,0,z),(.56,0,z),.11,color="iron",depth=.15)
    a.notes["mount"]="Hook center height Z=2.58. Mount curved tops over a dock edge; bottom rail ends are at root."
    return a


def build():
    return [_dock(),_corner(),_beacon(),_bollard(),_buoy(),_rods(),_trap(),_rope(),_anchor(),_fish_crate(),_life_ring(),_ladder()]
