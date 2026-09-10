"""Original amusement-room props with no branded graphics or game systems."""
import math
from geometry import Asset, ring_mesh

META = {
    "slug": "starfall-arcade", "title": "Starfall Arcade",
    "tagline": "Original cabinets, amusement fixtures and room details",
    "description": "Twelve original arcade room props with physical controls, colorful display art and complete supports. Static visual models only; no playable games, vending, rewards or interactions.",
    "palettes": {
        "Classic": ["585278", "27243C", "A19CCA", "486FC3", "85DDED", "EFAD50", "FFE9AB", "45435D", "77768B", "C2C2D7", "F1EDF8", "EC7796", "86CDA9", "A98BDD", "766382", "161827"],
        "Warm": ["785266", "392433", "C19BAD", "C57046", "FFD69B", "DCA545", "FFF1B8", "5D434D", "93747D", "D6BDC2", "FFF0E7", "DC7488", "ABC287", "BA8BBE", "866171", "261921"],
        "Twilight": ["535679", "25263F", "979FCB", "7666C7", "C3B4F4", "DBAD69", "FFE9BE", "414461", "727C9D", "B9C4DC", "EEEDF7", "D786B4", "83C6BB", "A4A0E4", "696683", "181A2D"],
    },
    "samples": ["08_Gamepad_Stand", "09_Prize_Capsule"],
}


def _face(a, name, size, loc, color, bevel=.025):
    return a.box(name, (size[0], .06, size[1]), loc, color, bevel)


def _side_profile(a, name, width, yz, color):
    count = len(yz)
    verts = [(x, y, z) for x in (-width/2, width/2) for y, z in yz]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count*2))]
    faces += [(i, (i+1) % count, (i+1) % count + count, i + count) for i in range(count)]
    return a.mesh(name, verts, faces, color)


def _star(a, name, radius, center, color="goldlight", depth=.055):
    # Five-point original geometric badge extruded with a closed front and back.
    x, y, z = center
    contour = [(x + math.sin(i*math.pi/5)*(radius if i % 2 == 0 else radius*.44),
                z + math.cos(i*math.pi/5)*(radius if i % 2 == 0 else radius*.44)) for i in range(10)]
    verts = [(px, y + dy, pz) for dy in (-depth/2, depth/2) for px, pz in contour]
    faces = [tuple(range(9, -1, -1)), tuple(range(10, 20))]
    faces += [(i, (i+1) % 10, (i+1) % 10 + 10, i+10) for i in range(10)]
    a.mesh(name, verts, faces, color)


def _cabinet():
    a = Asset("01_Comet_Arcade_Cabinet", "Arcade cabinets", "Classic sloping arcade cabinet with connected controls, original star display and a thick marquee.")
    a.box("Plinth", (2.3, 1.85, .18), (0, 0, .09), "iron", .055)
    _side_profile(a, "Cabinet housing", 2.13,
                  [(-.80,.17),(.78,.17),(.78,4.01),(-.61,4.01),(-.61,3.57),(-.27,3.27),(-.44,2.00),(-.92,1.92),(-.92,1.63),(-.80,1.63)], "wood")
    # Screen plane slopes back at the top, following the cabinet profile.
    angle = -.133
    a.box("Screen bezel", (1.92,.12,1.16), (0,-.408,2.64), "black", .045, rotation=(angle,0,0))
    a.box("Screen", (1.63,.045,.88), (0,-.475,2.65), "teal", .025, rotation=(angle,0,0))
    for x, z, w in [(-.47,2.81,.12),(.39,2.92,.10),(.55,2.46,.12),(-.1,2.37,.1)]:
        y = -.475 + (z-2.65)*math.tan(.133) - .041
        a.box("Display pixel", (w,.024,w), (x,y,z), "teallight", .01, rotation=(angle,0,0))
    a.box("Control deck", (2.22,.61,.14), (0,-.76,1.97), "teal", .045)
    a.cylinder("Joystick socket", .18,.10,(-.54,-.79,2.09), "iron", 12)
    a.cylinder("Joystick stem", .06,.28,(-.54,-.79,2.26), "stonelight", 8)
    a.gem("Joystick grip", .16,.25,(-.54,-.79,2.34), "red")
    for x,y in ((.29,-.83),(.64,-.67),(.65,-.97)):
        a.cylinder("Action button", .12,.07,(x,y,2.075), "goldlight", 12)
    _face(a,"Marquee frame",(2.20,.41),(0,-.630,3.79),"iron")
    _face(a,"Marquee insert",(1.97,.27),(0,-.679,3.79),"amethyst")
    _star(a,"Marquee star",.107,(0,-.722,3.79))
    _face(a,"Lower accent",(1.77,.55),(0,-.824,.80),"darkwood")
    _face(a,"Token face",(.51,.30),(0,-.826,1.30),"iron")
    _face(a,"Token slot",(.28,.045),(0,-.874,1.33),"black",.006)
    for z in (.60,.80,1.00):
        a.box("Rear cooling slat", (1.44,.05,.06),(0,.819,z),"darkwood",.01)
    a.notes = {"front":"Controls and display face -Y. Complete rear cabinet; no game branding.","use":"Static screen artwork and fixed controls; no playable arcade system."}
    return a


def _pinball():
    a = Asset("02_Orbit_Pinball_Table", "Arcade cabinets", "Four-legged pinball display with framed playing field, bumpers, flippers and a raised score panel.")
    for x in (-.88,.88):
        for y in (-1.45,1.40):
            a.beam("Splayed leg", (x*1.08,y*1.05,.08),(x,y,1.92),.19,"iron")
            a.box("Pinball level foot",(.27,.27,.12),(x*1.08,y*1.05,.06),"iron",.012)
    a.box("Playing cabinet", (2.23,3.64,.53),(0,0,1.86),"wood",.075)
    a.box("Playing field", (1.90,3.28,.08),(0,0,2.16),"teal",.025)
    for x in (-1.06,1.06):
        a.box("Side rail",(.13,3.67,.20),(x,0,2.18),"gold",.025)
    for y in (-1.77,1.77):
        a.box("End rail",(2.16,.13,.20),(0,y,2.18),"gold",.025)
    for x,y in ((-.50,.73),(.49,.73),(0,.04)):
        a.cylinder("Bumper foot",.20,.13,(x,y,2.265),"iron",12)
        a.cylinder("Bumper cap",.29,.11,(x,y,2.385),"red",12)
    for x, angle in ((-.42,-.32),(.42,.32)):
        a.box("Flipper",(.55,.16,.08),(x,-1.18,2.235),"cream",.065,rotation=(0,0,angle))
        a.cylinder("Flipper pivot",.09,.04,(x + (-.18 if x<0 else .18),-1.12,2.29),"gold",10)
    a.cylinder("Ball", .12,.13,(.59,-.44,2.265),"stonelight",12)
    a.box("Backbox",(2.22,.32,1.38),(0,1.60,2.81),"wood",.075)
    _face(a,"Score bezel",(1.91,.92),(0,1.413,2.90),"black")
    _face(a,"Score face",(1.61,.64),(0,1.363,2.90),"amethyst")
    _star(a,"Orbit score emblem",.19,(0,1.323,2.90))
    for x in (-.60,.60): _face(a,"Score dash",(.23,.06),(x,1.323,2.90),"teallight",.01)
    a.cylinder("Launch plunger",.085,.25,(.73,-1.90,1.92),"stonelight",10,(math.pi/2,0,0))
    a.notes={"use":"Open playing field is deliberate. All bumpers, flippers and ball are fixed visual geometry; no simulation.","placement":"Four flat foot pads contact Z=0 beneath the splayed legs. Front and plunger face -Y."}
    return a


def _racer():
    a = Asset("03_Vector_Racing_Seat", "Arcade cabinets", "Grounded racing station with bucket-style seat, pedal deck, steering wheel and supported display.")
    a.box("Platform",(2.55,4.2,.20),(0,0,.10),"iron",.10)
    a.box("Pedal ramp",(1.52,1.05,.14),(0,-1.05,.32),"wood",.05,rotation=(.12,0,0))
    for x in (-.34,.34):a.box("Pedal",(.30,.52,.07),(x,-1.06,.43),"stonelight",.025,rotation=(.12,0,0))
    a.box("Seat pedestal",(1.03,.95,.82),(0,1.06,.57),"wood",.075)
    a.box("Seat cushion",(1.43,1.24,.24),(0,.96,1.06),"teal",.10)
    a.box("Seat back",(1.43,.24,1.53),(0,1.56,1.80),"teal",.12,rotation=(.14,0,0))
    for x in (-.76,.76):a.box("Seat bolster",(.20,.92,.53),(x,1.07,1.25),"woodlight",.085)
    for x in (-.90,.90):a.beam("Console support",(x,-.85,.20),(x,-.95,1.65),.19,"iron")
    a.box("Dashboard",(2.14,.56,.35),(0,-.88,1.69),"wood",.075)
    # Steering wheel faces the seated player (+Y), connected to dashboard by column.
    a.cylinder("Steering column",.095,.47,(0,-.42,1.77),"iron",12,(math.pi/2,0,0))
    a.torus("Steering rim",.43,.065,(0,-.17,1.77),"darkwood",rotation=(math.pi/2,0,0),major_segments=16,minor_segments=6)
    a.cylinder("Steering hub",.12,.12,(0,-.17,1.77),"gold",12,(math.pi/2,0,0))
    for angle in (math.pi/2, math.pi*7/6,math.pi*11/6):
        a.beam("Wheel spoke",(0,-.17,1.77),(.42*math.cos(angle),-.17,1.77+.42*math.sin(angle)),.07,"gold")
    a.box("Display pedestal",(.32,.36,1.15),(0,-1.25,2.07),"iron",.04)
    a.box("Display housing",(2.18,.24,1.38),(0,-1.27,2.95),"wood",.07)
    a.box("Display face",(1.90,.06,1.10),(0,-1.125,2.95),"black",.035)
    a.box("Track horizon",(1.63,.025,.08),(0,-1.085,3.17),"teallight",.01)
    for x in (-.48,.48):
        a.box("Track side",(.10,.025,.63),(x,-1.085,2.77),"teal",.018,rotation=(0,-.28 if x<0 else .28,0))
    # Present the screen toward the pack's -Y front, with the seat facing the screen.
    from mathutils import Quaternion
    turn=Quaternion((0,0,1),math.pi)
    for obj in a.objects:
        orientation=obj.rotation_quaternion.copy() if obj.rotation_mode=='QUATERNION' else obj.rotation_euler.to_quaternion()
        obj.location.x=-obj.location.x;obj.location.y=-obj.location.y
        obj.rotation_mode='QUATERNION';obj.rotation_quaternion=turn@orientation
    a.notes={"orientation":"Display faces -Y toward the seat; the seated player faces +Y. Enter the station from either side.","use":"Static wheel, pedals and display; no Seat, VehicleSeat or driving scripts."}
    return a


def _crane():
    a = Asset("04_Prize_Crane_Machine", "Amusement fixtures", "Open-front prize crane with a supported overhead trolley, fixed claw and three geometric prizes.")
    a.box("Base",(2.44,1.99,.18),(0,0,.09),"iron",.06)
    a.box("Lower cabinet",(2.27,1.82,1.22),(0,0,.79),"teal",.085)
    for x in (-1.04,1.04):
        for y in (-.79,.79):a.box("Corner column",(.15,.15,2.15),(x,y,2.43),"gold",.025)
    a.box("Rear panel",(1.98,.12,1.94),(0,.80,2.42),"wood",.04)
    a.box("Prize floor",(2.11,1.64,.10),(0,0,1.45),"cream",.03)
    a.box("Roof",(2.44,1.99,.27),(0,0,3.61),"amethyst",.085)
    a.box("Trolley track",(1.95,.18,.16),(0,0,3.415),"iron",.025)
    a.box("Trolley",(.43,.41,.17),(.24,0,3.28),"woodlight",.045)
    a.cylinder("Claw cable",.033,.62,(.24,0,2.905),"iron",8)
    a.cylinder("Claw hub",.13,.16,(.24,0,2.52),"gold",10)
    for angle in (0,math.tau/3,2*math.tau/3):
        x,y=math.cos(angle),math.sin(angle)
        a.beam("Claw arm",(.24+x*.09,y*.09,2.48),(.24+x*.30,y*.30,2.17),.065,"iron")
        a.beam("Claw tip",(.24+x*.30,y*.30,2.17),(.24+x*.19,y*.19,2.10),.065,"iron")
    for x,y,color in ((-.62,-.31,"red"),(.46,.31,"teal"),(.53,-.44,"amethyst")):
        a.box("Prize cube",(.49,.47,.46),(x,y,1.73),color,.09)
        _star(a,"Prize badge",.14,(x,y-.255,1.75))
    _face(a,"Prize hatch",(.93,.48),(0,-.932,.66),"darkwood")
    _face(a,"Hatch lower lip",(.99,.09),(0,-.980,.39),"goldlight",.018)
    a.notes={"use":"Front and sides are intentionally open; no glass, crane movement or rewards system.","support":"Trolley joins roof track; cable supports claw. Prizes rest on the thick floor."}
    return a


def _tokens():
    a = Asset("05_Token_Exchange_Kiosk", "Amusement fixtures", "Compact change station with a broad base, inset instructions and an open collection tray.")
    a.box("Foot",(1.62,1.32,.18),(0,0,.09),"iron",.055)
    a.box("Cabinet",(1.43,1.13,2.56),(0,0,1.44),"wood",.10)
    a.box("Top cap",(1.55,1.26,.19),(0,0,2.785),"teal",.065)
    _face(a,"Instruction panel",(1.12,.73),(0,-.588,2.18),"black")
    for z,width in ((2.35,.69),(2.14,.83),(1.96,.49)):
        _face(a,"Instruction line",(width,.06),(0,-.640,z),"goldlight",.01)
    _face(a,"Payment bezel",(.66,.24),(0,-.588,1.53),"stonelight")
    _face(a,"Coin slot",(.04,.16),(0,-.636,1.53),"black",.005)
    _face(a,"Outlet opening",(.95,.43),(0,-.588,.85),"darkwood")
    a.box("Collection floor",(.94,.48,.10),(0,-.78,.64),"gold",.02)
    for x in (-.42,.42):a.box("Collection side",(.10,.48,.20),(x,-.78,.76),"gold",.015)
    a.box("Collection front",(.94,.10,.20),(0,-.98,.76),"gold",.015)
    a.notes={"use":"Decorative change station and empty tray; no currency, purchases or vending."}
    return a


def _rhythm():
    a = Asset("06_Rhythm_Pad", "Amusement fixtures", "Four-panel rhythm platform with a rear safety rail and connected center divider.")
    a.box("Platform",(3.08,3.08,.22),(0,0,.11),"iron",.08)
    for x,y,color in ((-.70,-.70,"teal"),(.70,-.70,"red"),(-.70,.70,"red"),(.70,.70,"teal")):
        a.box("Foot panel",(1.24,1.24,.075),(x,y,.2575),color,.04)
        # Raised simple directional chevron made from two supported strips.
        for sign in (-1,1):
            a.box("Panel chevron",(.14,.48,.025),(x+sign*.135,y,.309),"cream",.025,rotation=(0,0,sign*.64))
    for x in (-1.33,1.33):
        a.cylinder("Rail foot",.17,.10,(x,1.22,.27),"gold",12)
        a.cylinder("Rail post",.075,2.22,(x,1.22,1.40),"stonelight",10)
    a.cylinder("Rail bridge",.075,2.66,(0,1.22,2.51),"stonelight",10,(0,math.pi/2,0))
    a.notes={"use":"Static four-panel platform; no dance recognition, animations, music or controls.","dimensions":"3.08 x 3.08 platform footprint; entrance -Y."}
    return a


def _jukebox():
    a = Asset("07_Comet_Jukebox", "Room equipment", "Rounded-top jukebox silhouette with ribbed grille, decorative speaker and a physical selection panel.")
    # Closed extruded arch cross-section in XZ, so the rear is complete.
    outline=[(-.97,.16),(.97,.16),(.97,2.22)]
    outline += [(.97*math.cos(i*math.pi/12),2.22+.97*math.sin(i*math.pi/12)) for i in range(1,13)]
    verts=[(x,y,z) for y in (-.48,.48) for x,z in outline]
    n=len(outline); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    a.mesh("Arched cabinet",verts,faces,"wood")
    a.box("Plinth",(2.10,1.16,.19),(0,0,.095),"iron",.055)
    for x in (-.82,.82):a.box("Light column",(.14,.09,2.11),(x,-.515,1.34),"teal",.045)
    _face(a,"Speaker inset",(1.29,1.20),(0,-.506,.95),"black")
    for x in (-.50,-.25,0,.25,.50):a.box("Speaker rib",(.07,.08,1.08),(x,-.561,.95),"gold",.014)
    _face(a,"Selection bezel",(1.42,.49),(0,-.505,1.95),"iron")
    for x in (-.47,-.16,.16,.47):_face(a,"Selection key",(.20,.25),(x,-.554,1.95),"cream")
    a.cylinder("Upper speaker",.53,.10,(0,-.52,2.61),"teal",20,(math.pi/2,0,0))
    a.cylinder("Speaker ring",.38,.08,(0,-.59,2.61),"iron",16,(math.pi/2,0,0))
    _star(a,"Comet emblem",.24,(0,-.657,2.61))
    a.notes={"use":"Decorative jukebox; no audio, music licensing or playlist system."}
    return a


def _gamepad():
    a = Asset("08_Gamepad_Stand", "Countertop details", "Display gamepad on an attached cradle with original angular grips and raised controls.")
    a.box("Display base",(1.72,1.02,.14),(0,0,.07),"iron",.065)
    a.box("Stand stem",(.32,.30,.54),(0,.19,.38),"gold",.04)
    a.box("Cradle",(1.29,.40,.16),(0,0,.66),"woodlight",.055)
    a.box("Gamepad center",(1.46,.30,.57),(0,-.01,.94),"teal",.10)
    for x in (-.70,.70):
        a.box("Gamepad grip",(.39,.38,.76),(x,-.03,.83),"teal",.13,rotation=(0,-.21 if x<0 else .21,0))
    for size in ((.34,.085),(.085,.34)):_face(a,"Direction cross",size,(-.43,-.183,1.01),"black",.014)
    for x,z in ((.34,.99),(.56,1.10),(.56,.88)):
        a.cylinder("Face button",.075,.065,(x,-.186,z),"goldlight",10,(math.pi/2,0,0))
    a.notes={"use":"Original unbranded static gamepad display; geometry is mounted on its cradle."}
    return a


def _capsule():
    a = Asset("09_Prize_Capsule", "Countertop details", "Two-tone faceted prize capsule with a thick seam band and a closed display foot.")
    for name,rings,color in (
        ("Lower shell",[(.12,.26),(.22,.43),(.51,.51),(.55,.51)],"teal"),
        ("Upper shell",[(.55,.51),(.79,.44),(.96,.25),(1.01,.10)],"amethyst")):
        verts,faces=ring_mesh(rings,16)
        a.mesh(name,verts,faces,color)
    a.cylinder("Seam band",.528,.07,(0,0,.55),"gold",16)
    a.cylinder("Flat foot",.28,.16,(0,0,.08),"iron",12)
    _star(a,"Capsule emblem",.18,(0,-.451,.75),"goldlight",.07)
    a.notes={"use":"Closed original geometric capsule; no randomized rewards, opening mechanism or character content."}
    return a


def _queue():
    a = Asset("10_Queue_Barrier", "Room details", "Three-stud queue module with two grounded posts, a thick horizontal strap and end caps.")
    for x in (-1.50,1.50):
        a.cylinder("Post foot",.40,.13,(x,0,.065),"iron",12)
        a.cylinder("Post",.075,1.62,(x,0,.94),"stonelight",10)
        a.cylinder("Post head",.14,.20,(x,0,1.84),"gold",12)
    a.box("Queue strap",(3.0,.065,.25),(0,0,1.78),"teal",.02)
    a.notes={"modular":"Post centers are 3.0 studs apart; total footprint 3.8 x 0.8. Ground root is halfway between posts.","use":"Static barrier; no collision or queue logic implied."}
    return a


def _tickets():
    a = Asset("11_Ticket_Dispenser", "Countertop details", "Compact ticket counter with a supported folded ticket strip and framed status panel.")
    a.box("Base",(1.44,1.21,.14),(0,0,.07),"iron",.065)
    a.box("Housing",(1.26,.94,1.08),(0,.03,.68),"wood",.085)
    a.box("Top cap",(1.38,1.09,.12),(0,.03,1.28),"teal",.055)
    _face(a,"Status bezel",(.92,.34),(0,-.48,.99),"black")
    for x in (-.29,0,.29):_face(a,"Status digit",(.12,.20),(x,-.52,.99),"teallight",.01)
    _face(a,"Ticket slot",(.75,.14),(0,-.48,.61),"iron")
    a.box("Ticket strip",(.49,.70,.035),(0,-.77,.595),"cream",.01)
    a.box("Bent ticket tail",(.49,.035,.37),(0,-1.102,.393),"cream",.01)
    a.box("Ticket catch tray",(.73,.92,.09),(0,-.72,.165),"gold",.02)
    for y in (-.62,-.85,-1.05):a.box("Ticket mark",(.29,.036,.016),(0,y,.6205),"red",.007)
    a.notes={"use":"Thick fixed ticket strip rests above collection tray; no printing or reward system."}
    return a


def _scoreboard():
    a = Asset("12_Wall_Scoreboard", "Room fixtures", "Wall display with three abstract score rows, star emblem and complete rear mounting spacers.")
    a.box("Display housing",(2.91,.27,1.90),(0,0,.95),"wood",.085)
    _face(a,"Inner bezel",(2.65,1.63),(0,-.161,.95),"iron")
    _face(a,"Score screen",(2.39,1.37),(0,-.212,.95),"black")
    for z in (.55,.93,1.31):
        _face(a,"Score label",(.80,.07),(-.54,-.254,z),"teal",.01)
        for x in (.21,.54,.87):_face(a,"Score digit",(.16,.21),(x,-.254,z),"goldlight",.01)
    for x in (-1.14,1.14):a.box("Rear mounting spacer",(.28,.20,1.0),(x,.20,.95),"iron",.04)
    a.notes={"mount":"Wall fixture; front -Y, rear spacers terminate Y=0.30. Root at lower housing edge Z=0.","use":"Static abstract score strokes; no leaderboard, live scores or fonts."}
    return a


def build():
    return [_cabinet(), _pinball(), _racer(), _crane(), _tokens(), _rhythm(),
            _jukebox(), _gamepad(), _capsule(), _queue(), _tickets(), _scoreboard()]
