"""Original cozy farm equipment and crops; Z-up, front -Y, ground origin."""
from math import cos, sin, pi
from geometry import Asset, ring_mesh

META = {"slug":"harvest-homestead", "title":"Harvest Homestead",
 "tagline":"Twelve original props for a warm and readable farming scene.",
 "description":"Raised beds, farm equipment and sculpted crops with complete supports and usable dimensions. Visual models only; no farming, growth or economy scripts.",
 "palettes":{
  "Classic":["936645","4C382C","CFAD70","6C9160","A9C67C","D6A24A","F4D898","596762","7D8580","B7BBB0","F0E1B9","D87938","5C8F4C","977F9E","AF7754","2D382D"],
  "Warm":["A26942","543A2C","DAB57D","A88A4E","D8BC78","DAA650","FFE0A0","6C6860","8C8377","C0B7A5","F5E3BA","C56933","82994E","AD8292","B58058","3D392B"],
  "Twilight":["7A665D","3B3942","B5A391","698393","A2BDCA","BC9B65","EFDCAB","536675","7A8996","B1BEC3","E2E2D5","B87960","739787","9D8AB6","A2806E","2B3844"]},
 "samples":["09_Carrot_Bundle","10_Farm_Rake"]}


def _a(name,desc):
    a=Asset(name,"Farm",desc)
    a.notes={"use":"Static original visual model. Root sits at ground; no runtime scripts."}
    return a


def _lathe(a,name,rings,loc=(0,0,0),color="teal",sides=12):
    v,f=ring_mesh(rings,sides)
    return a.mesh(name,v,f,loc=loc,color=color)


def _panel(a,name,xy,zmin,zmax,color="wood",role="Body"):
    n=len(xy);v=[(x,y,z) for z in (zmin,zmax) for x,y in xy]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return a.mesh(name,v,f,color=color,role=role)


def _leaf(a,name,loc,height=.55,radius=.11,angle=0):
    return a.gem(name,radius,height,loc,color="emerald",rotation=(.45*cos(angle),.45*sin(angle),angle))


def _bed():
    a=_a("01_Raised_Garden_Bed","A raised timber bed filled with three rows of broad-leaf seedlings.")
    for x in (-1.82,1.82):
        for y in (-1.17,1.17):
            a.box(f"Corner_{x}_{y}",(.20,.20,.86),(x,y,.43),color="wood",bevel=.035)
    for z in (.23,.59):
        for y in (-1.18,1.18):
            a.box(f"Long_Board_{y}_{z}",(3.78,.13,.30),(0,y,z),color="woodlight",bevel=.027)
        for x in (-1.83,1.83):
            a.box(f"End_Board_{x}_{z}",(.13,2.26,.30),(x,0,z),color="woodlight",bevel=.025)
    a.box("Soil_Volume",(3.5,2.14,.46),(0,0,.48),color="darkwood",bevel=.07)
    for ix,x in enumerate((-1.2,0,1.2)):
        for iy,y in enumerate((-.65,0,.65)):
            for j in range(3):
                _leaf(a,f"Leaf_{ix}_{iy}_{j}",(x,y,.70),.53,.13,j*2*pi/3)
    a.notes["dimensions"]="Raised bed outer timber footprint 3.84 by 2.54 studs. Soil and crops are included."
    return a


def _scarecrow():
    a=_a("02_Friendly_Scarecrow","Straw-hatted scarecrow on a braced ground post with patched tunic and straw hands.")
    a.box("Ground_Post",(.23,.23,3.05),(0,0,1.525),color="wood",bevel=.04)
    for side in (-1,1):
        a.beam(f"Ground_Brace_{side}",(side*.45,0,.07),(0,0,.89),.14,color="woodlight")
    _panel(a,"Tunic",[(-.53,-.24),(.53,-.24),(.41,.24),(-.41,.24)],1.30,2.33,"teal")
    for side in (-1,1):
        a.beam(f"Outstretched_Sleeve_{side}",(side*.40,0,2.19),(side*1.08,0,2.39),.30,color="teal",depth=.36)
        for j in range(3):
            a.beam(f"Straw_Hand_{side}_{j}",(side*1.04,-.02,2.39),(side*(1.31+.05*j),(j-1)*.065,2.40+(j-1)*.07),.045,color="goldlight")
    _lathe(a,"Canvas_Head",[(0,.20),(.12,.33),(.53,.33),(.66,.22)],(0,0,2.40),"cream")
    a.cylinder("Hat_Brim",.67,.11,(0,0,3.07),color="gold",vertices=14)
    _lathe(a,"Hat_Crown",[(0,.37),(.27,.31),(.43,.16)],(0,0,3.10),"goldlight")
    a.torus("Hat_Ribbon",.352,.045,(0,0,3.20),color="leather",major_segments=14)
    for x in (-.12,.12):
        a.cylinder(f"Button_Eye_{x}",.035,.025,(x,-.319,2.79),color="black",vertices=8,rotation=(pi/2,0,0))
    a.gem("Carrot_Nose",.07,.19,(0,-.32,2.69),color="red",rotation=(pi/2,0,0))
    a.box("Tunic_Patch",(.23,.025,.24),(.19,-.256,1.65),color="goldlight",bevel=.025,rotation=(0,.13,0))
    a.box("Neck_Scarf",(.67,.56,.16),(0,0,2.40),color="red",bevel=.07)
    return a


def _pump():
    a=_a("03_Irrigation_Pump","Hand pump on a stone footing, with long operating lever and downward outlet.")
    a.box("Stone_Pad",(1.47,1.28,.18),(0,0,.09),color="stonelight",bevel=.10)
    _lathe(a,"Pump_Housing",[(0,.42),(.14,.43),(.25,.25),(1.47,.25),(1.58,.35)],(0,0,.18),"teal")
    a.box("Lever_Clevis",(.50,.31,.22),(0,0,1.83),color="iron",bevel=.04)
    a.beam("Long_Lever",(-.08,0,1.88),(1.05,0,2.47),.115,color="iron")
    a.beam("Wood_Grip",(.93,0,2.40),(1.21,0,2.55),.18,color="woodlight")
    a.beam("Outlet_Pipe",(0,-.16,1.36),(0,-.68,1.30),.18,color="teal")
    a.beam("Downward_Nozzle",(0,-.68,1.31),(0,-.77,1.04),.18,color="teal")
    a.cylinder("Nozzle_Opening",.065,.014,(0,-.774,1.028),color="black",vertices=10,rotation=(pi-.322,0,0))
    return a


def _barrow():
    a=_a("04_Garden_Wheelbarrow","One-wheel timber wheelbarrow with flared hollow steel pan and rear parking legs.")
    a.box("Pan_Floor",(1.22,1.52,.12),(0,-.06,.97),color="teal",bevel=.05)
    # Slanted thick walls: lower rectangle and broader upper rectangle.
    corners=[(-.62,-.84),(.62,-.84),(.62,.70),(-.62,.70)]
    top=[(-.89,-1.03),(.89,-1.03),(.89,.90),(-.89,.90)]
    for i in range(4):
        j=(i+1)%4
        v=[(*corners[i],.99),(*corners[j],.99),(*top[j],1.59),(*top[i],1.59),
           (corners[i][0]*.93,corners[i][1]*.93,1.00),(corners[j][0]*.93,corners[j][1]*.93,1.00),
           (top[j][0]*.95,top[j][1]*.95,1.59),(top[i][0]*.95,top[i][1]*.95,1.59)]
        a.mesh(f"Flared_Pan_Wall_{i}",v,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],color="teal")
    for x in (-.54,.54):
        a.beam(f"Chassis_Handle_{x}",(x,-1.21,.62),(x,1.94,1.05),.14,color="woodlight")
        a.beam(f"Grip_{x}",(x,1.64,1.01),(x,2.03,1.06),.19,color="wood")
        a.beam(f"Parking_Leg_{x}",(x,.63,.88),(x,.88,.06),.12,color="iron")
    a.cylinder("Wheel_Axle",.085,1.28,(0,-1.24,.58),color="iron",rotation=(0,pi/2,0))
    a.torus("Wheel_Tire",.47,.11,(0,-1.24,.58),color="darkwood",rotation=(0,pi/2,0))
    for i in range(8):
        t=i*pi/4
        a.beam(f"Wheel_Spoke_{i}",(0,-1.24,.58),(0,-1.24+.44*cos(t),.58+.44*sin(t)),.065,color="woodlight")
    a.cylinder("Wheel_Hub",.14,.27,(0,-1.24,.58),color="teal",rotation=(0,pi/2,0))
    a.notes["interior"]="Hollow flared pan has four solid walls and a separate floor. Static wheel and handles."
    return a


def _hay():
    a=_a("05_Round_Hay_Bale","Round cut hay bale with concentric straw face rings and two binding straps.")
    a.cylinder("Hay_Core",.63,1.72,(0,0,.67),color="goldlight",vertices=14,rotation=(0,pi/2,0))
    for x in (-.87,.87):
        for j,r in enumerate((.18,.33,.48,.60)):
            a.torus(f"Straw_End_{x}_{j}",r,.025,(x,0,.67),color="gold",rotation=(0,pi/2,0),major_segments=14)
    for x in (-.52,.52):
        a.torus(f"Binding_{x}",.635,.035,(x,0,.67),color="leather",rotation=(0,pi/2,0),major_segments=14)
    return a


def _watering():
    a=_a("06_Watering_Can","Open watering can with broad curved handle, long angled spout and perforated rose.")
    _lathe(a,"Hollow_Can",[(0,.37),(.10,.45),(.90,.46),(1.04,.40),(1.04,.33),(.13,.33)],color="teal")
    a.torus("Carry_Handle",.49,.055,(.30,0,.88),color="iron",rotation=(pi/2,0,0))
    a.beam("Long_Spout",(-.34,0,.25),(-1.12,0,1.10),.16,color="teal")
    a.cylinder("Watering_Rose",.24,.10,(-1.16,0,1.17),color="gold",vertices=12,rotation=(0,-pi/4,0))
    for i in range(5):
        t=2*pi*i/5
        a.cylinder(f"Rose_Hole_{i}",.026,.011,(-1.20+.105*cos(t),.145*sin(t),1.209+.105*cos(t)),color="black",vertices=6,rotation=(0,-pi/4,0))
    return a


def _seeds():
    a=_a("07_Seed_Packet_Display","Three illustrated seed packets in an angled timber countertop display.")
    a.box("Display_Base",(2.08,.82,.14),(0,0,.07),color="wood",bevel=.05)
    a.box("Rear_Support",(2.02,.13,1.33),(0,.30,.76),color="woodlight",bevel=.03)
    a.box("Front_Lip",(2.13,.12,.28),(0,-.39,.23),color="teal",bevel=.03)
    for i,x in enumerate((-.66,0,.66)):
        a.box(f"Seed_Packet_{i}",(.56,.20,1.15),(x,0,.725),color="cream",bevel=.04)
        a.box(f"Packet_Header_{i}",(.55,.022,.18),(x,-.116,1.14),color="teal",bevel=.025)
        a.gem(f"Seed_Illustration_{i}",.12,.29,(x,-.13,.79),color="red" if i==0 else "emerald",rotation=(pi/2,0,0))
    return a


def _pumpkins():
    a=_a("08_Pumpkin_Cluster","Three ribbed pumpkins with individual stems and short trailing vines.")
    for index,(x,y,r,h) in enumerate(((-.45,.18,.50,.78),(.43,.29,.39,.62),(.21,-.40,.32,.50))):
        sides=16; levels=[(0,.32),(.12,.84),(.45,1),(.80,.88),(1,.32)]
        v=[(x+r*s*cos(2*pi*i/sides)*(1 if i%2==0 else .88),y+r*s*sin(2*pi*i/sides)*(1 if i%2==0 else .88),h*z) for z,s in levels for i in range(sides)]
        f=[tuple(reversed(range(sides))),tuple(range(4*sides,5*sides))]
        f += [(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for j in range(4) for i in range(sides)]
        a.mesh(f"Ribbed_Pumpkin_{index}",v,f,color="red")
        a.beam(f"Pumpkin_Stem_{index}",(x,y,h-.02),(x+.08,y,h+.17),.08,color="wood")
        _leaf(a,f"Pumpkin_Leaf_{index}",(x,y,h),.25,.10,index)
    return a


def _carrots():
    a=_a("09_Carrot_Bundle","Three sculpted carrots with leafy tops and a single binding band.")
    for i,x in enumerate((-.22,0,.22)):
        a.gem(f"Carrot_{i}",.16,.86,(x,0,.87),color="red",rotation=(pi,0,0))
        for j in range(3):
            _leaf(a,f"Carrot_Leaf_{i}_{j}",(x,0,.87),.48,.065,j*2*pi/3)
    a.box("Bundle_Binding",(.71,.08,.12),(0,-.159,.55),color="leather",bevel=.03)
    a.notes["placement"]="Upright harvest bundle; carrot tips finish 0.01 studs above root."
    return a


def _rake():
    a=_a("10_Farm_Rake","Nine-tooth garden rake with broad painted head and a rounded timber handle.")
    a.box("Rake_Head",(1.43,.16,.17),(0,0,.34),color="teal",bevel=.035)
    for i in range(9):
        a.box(f"Rake_Tooth_{i}",(.066,.14,.29),((i-4)*.157,0,.145),color="iron",bevel=.02)
    a.cylinder("Handle",.072,2.51,(0,0,1.61),color="woodlight",vertices=10)
    a.cylinder("Grip_Ferrule",.093,.24,(0,0,2.88),color="teal",vertices=10)
    return a


def _seedlings():
    a=_a("11_Seedling_Tray","Six-cell propagation tray with separate soil plugs and small sprouts.")
    a.box("Tray_Base",(2.08,1.30,.09),(0,0,.045),color="teal",bevel=.04)
    for i,x in enumerate((-.66,0,.66)):
        for j,y in enumerate((-.32,.32)):
            _lathe(a,f"Planting_Cell_{i}_{j}",[(0,.22),(.29,.27),(.31,.25)],(x,y,.09),"darkwood",8)
            _leaf(a,f"Sprout_Left_{i}_{j}",(x,y,.40),.32,.075,.4)
            _leaf(a,f"Sprout_Right_{i}_{j}",(x,y,.40),.28,.075,3.5)
    return a


def _gate():
    a=_a("12_Farm_Gate","Timber farm gate with diagonal brace, hinges and a separate gate pivot.")
    for x in (-1.85,1.85):
        a.box(f"Gatepost_{x}",(.27,.31,2.42),(x,0,1.21),color="wood",bevel=.04)
        a.gem(f"Post_Cap_{x}",.22,.22,(x,0,2.39),color="woodlight",rotation=(0,0,pi/4))
    for x in (-1.52,1.52):
        a.box(f"Gate_Stile_{x}",(.18,.16,1.76),(x,-.05,1.25),color="woodlight",bevel=.03,role="Gate")
    for z in (.50,1.26,2.0):
        a.box(f"Gate_Rail_{z}",(3.2,.16,.20),(0,-.05,z),color="woodlight",bevel=.03,role="Gate")
    a.beam("Diagonal_Brace",(-1.43,-.17,.57),(1.43,-.17,1.93),.13,color="teal",role="Gate")
    for z in (.69,1.86):
        a.cylinder(f"Hinge_{z}",.085,.22,(-1.70,-.05,z),color="iron",vertices=10)
    a.box("Latch",(.31,.11,.11),(1.63,-.17,1.58),color="iron",bevel=.02,role="Gate")
    a.pivot("Gate",(-1.70,-.05,0))
    a.notes["assembly"]="Separate Gate role pivots on the left hinge about local Z; no animation supplied. Post spacing is 3.7 studs."
    return a


def build():
    return [_bed(),_scarecrow(),_pump(),_barrow(),_hay(),_watering(),_seeds(),_pumpkins(),_carrots(),_rake(),_seedlings(),_gate()]
