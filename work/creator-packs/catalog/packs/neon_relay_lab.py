"""Original grounded science-fiction utility props; visual geometry only."""
import math
from geometry import Asset, ring_mesh

META = {
    "slug": "neon-relay-lab", "title": "Neon Relay Lab",
    "tagline": "Consoles, power equipment and laboratory utilities",
    "description": "Twelve original science-fiction room props with complete housings and supports. No power, scanning or interaction systems.",
    "palettes": {
        "Classic": ["516175","202A3B","8D9DAD","18A6AD","8EF7E5","E8AE4E","FFE6A8","344253","667A8C","BCCBD2","E8EEF1","EA685A","76CE9F","9E86DD","53667A","101926"],
        "Warm": ["67595A","302932","B19C8F","C65B3F","FFC790","D7AC59","FFE6B4","413845","807079","D6C2B6","F5EADC","DF7860","9AB388","BB86C7","745E63","201C2A"],
        "Twilight": ["515270","25223D","9098BA","735BCC","C5A8FF","E0A859","FFE1AC","35324D","686A91","B6BADA","E6E4F3","EC7D9C","70CEB3","A58BE8","5C5279","17152A"],
    },
    "samples": ["07_Data_Tablet", "08_Battery_Canister"],
}


def _base(a, size, top=.18):
    a.box("Footplate", (size[0], size[1], top), (0, 0, top/2), "iron", .055)


def _front(a, name, x, y, z, w, h, color="teal"):
    a.box(name, (w, .055, h), (x, y, z), color, .018)


def _bolt(a, x, y, z):
    a.cylinder("Fastener", .055, .045, (x, y, z), "gold", 8, (math.pi/2, 0, 0))


def _console():
    a = Asset("01_Command_Console", "Control equipment", "Wide console with sloped screen housing, solid rear cabinet and supported command deck.")
    _base(a, (3.7, 2.25))
    a.box("Lower cabinet", (3.3, 1.7, 1.1), (0, .05, .73), "wood", .1)
    # Extruded side profile supplies thickness to the sloping display housing.
    yz = [(-.78,1.25),(.72,1.25),(.72,3.15),(.30,3.15),(-.55,2.1)]
    verts=[(x,y,z) for x in (-1.62,1.62) for y,z in yz]
    n=len(yz); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    a.mesh("Display enclosure",verts,faces,"wood")
    angle=-math.atan2(.85,1.05)
    a.box("Display bezel",(2.95,.13,1.36),(0,-.177,2.65),"black",.035,rotation=(angle,0,0))
    a.box("Display face",(2.57,.06,1.06),(0,-.237,2.698),"teal",.02,rotation=(angle,0,0))
    a.box("Command deck",(3.55,.83,.19),(0,-.99,1.32),"iron",.05)
    for x in (-1.24,-.93,-.62,-.31,0,.31):
        a.box("Raised key",(.19,.19,.07),(x,-1.08,1.45),"cream",.02)
    a.cylinder("Control dial",.18,.09,(1.06,-1.07,1.46),"gold",12)
    for x in (-1.26,0,1.26):
        _front(a,"Access panel",x,-.824,.79,.75,.55,"darkwood")
    for z in (.48,.68,.88):
        a.box("Rear vent",(2.58,.065,.05),(0,.935,z),"iron",.012)
    a.notes={"front":"Controls face -Y; housing and deck are solid.","use":"Static console; screen and buttons have no behavior."}
    return a


def _reactor():
    a=Asset("02_Reactor_Cell","Power equipment","Contained power cylinder with radial braces, nested collars and a bolted base.")
    a.cylinder("Foundation",1.18,.24,(0,0,.12),"iron",12)
    a.cylinder("Lower housing",1.03,.5,(0,0,.49),"wood",12)
    a.cylinder("Inner cell",.73,2.10,(0,0,1.78),"teal",12)
    for z in (.88,1.7,2.52):
        a.torus("Cell band",.765,.07,(0,0,z),"teallight",major_segments=12)
    for i in range(4):
        t=math.tau*i/4+math.pi/4;x,y=.9*math.cos(t),.9*math.sin(t)
        a.box("Containment strut",(.19,.19,2.45),(x,y,1.85),"iron",.035)
    a.cylinder("Upper housing",1.03,.4,(0,0,3.03),"wood",12)
    a.cylinder("Crown cap",.8,.21,(0,0,3.335),"gold",12)
    a.box("Top handle bridge",(1.2,.22,.18),(0,0,3.73),"iron",.025)
    for x in (-.48,.48):a.box("Handle upright",(.2,.22,.3),(x,0,3.57),"iron",.025)
    a.notes={"use":"Static decorative power unit; no lights, physics or power system."}
    return a


def _server():
    a=Asset("03_Server_Tower","Storage equipment","Freestanding server housing with removable-looking drawer fronts and rear cooling slats.")
    _base(a,(2.35,1.95))
    a.box("Cabinet shell",(2.15,1.7,3.8),(0,0,2.05),"wood",.09)
    _front(a,"Recessed face",0,-.88,2.07,1.86,3.42,"darkwood")
    for i in range(5):
        z=.69+i*.66
        _front(a,"Server drawer",0,-.937,z,1.58,.47,"iron")
        _front(a,"Drawer handle",-.34,-.977,z,.69,.065,"stonelight")
        _front(a,"Status LED",.58,-.980,z,.12,.13,"teallight")
        a.box("Rear slat",(1.6,.06,.09),(0,.88,z),"darkwood",.012)
    a.notes={"placement":"Grounded freestanding cabinet; front faces -Y."}
    return a


def _beacon():
    a=Asset("04_Signal_Beacon","Communications","Antenna tower with supported angled receiver, structural mast and base electronics.")
    _base(a,(1.95,1.8),.23)
    a.box("Equipment foot",(1.5,1.3,.63),(0,0,.545),"wood",.08)
    a.cylinder("Mast",.18,2.85,(0,0,2.245),"iron",10)
    a.cylinder("Mast collar",.31,.2,(0,0,1.00),"gold",10)
    a.beam("Receiver arm",(0,0,2.79),(0,-.68,3.16),.16,"iron")
    # Solid dish silhouette with nested face; no paper-thin plane.
    a.cylinder("Receiver shell",.76,.20,(0,-.66,3.20),"woodlight",12,(math.pi/2-.22,0,0))
    a.cylinder("Receiver face",.60,.07,(0,-.782,3.227),"teal",12,(math.pi/2-.22,0,0))
    a.cylinder("Feed tip",.15,.34,(0,-.94,3.26),"gold",10,(math.pi/2-.22,0,0))
    _front(a,"Base display",0,-.678,.56,.82,.28,"teallight")
    a.notes={"use":"Decorative communications mast; receiver is supported by the rear arm."}
    return a


def _scanner():
    a=Asset("05_Specimen_Scanner","Lab equipment","Open-sided scanning arch with a raised specimen tray and a connected upper sensor.")
    _base(a,(2.7,2.05),.22)
    for x in (-1.06,1.06):
        a.box("Arch upright",(.3,1.30,2.22),(x,.18,1.28),"wood",.05)
        _front(a,"Upright stripe",x,-.501,1.47,.11,1.6,"teal")
    a.box("Arch lintel",(2.42,1.30,.34),(0,.18,2.46),"wood",.055)
    a.box("Sensor strip",(1.65,.72,.13),(0,.15,2.235),"teallight",.025)
    a.cylinder("Turntable pedestal",.72,.26,(0,-.1,.35),"iron",16)
    a.cylinder("Specimen plate",.91,.12,(0,-.1,.54),"gold",16)
    a.gem("Specimen",.28,.64,(0,-.1,.60),"teal")
    a.notes={"use":"Specimen is a fixed decorative part; no scanning system."}
    return a


def _vent():
    a=Asset("06_Service_Vent","Room utilities","Thick square vent frame with enclosed back and five recessed cooling blades.")
    a.box("Back plate",(2.5,.20,2.65),(0,.11,1.325),"darkwood",.04)
    for x in (-1.16,1.16):a.box("Side frame",(.22,.38,2.65),(x,0,1.325),"wood",.035)
    for z in (.11,2.54):a.box("Horizontal frame",(2.15,.38,.22),(0,0,z),"wood",.035)
    for i in range(5):
        a.box("Louvre blade",(2.03,.27,.18),(0,-.05,.48+i*.43),"stonelight",.025,rotation=(.24,0,0))
    for x in (-1.16,1.16):
        for z in (.12,2.53):_bolt(a,x,-.216,z)
    a.notes={"mount":"Wall mounted; local root is the lower center of the frame. Back surface Y=0.21.","size":"2.5 wide by 2.65 high; closed backing plate."}
    return a


def _tablet():
    a=Asset("07_Data_Tablet","Desk props","Portable wedge-backed data display with a thick bezel and physical lower controls.")
    _base(a,(1.32,.90),.12)
    a.beam("Rear support",(0,.23,.12),(0,.23,.87),.25,"iron",.30)
    angle=-.24
    a.box("Tablet shell",(1.38,.17,1.08),(0,-.02,.80),"wood",.06,rotation=(angle,0,0))
    a.box("Screen inset",(1.13,.055,.76),(0,-.118,.824),"teal",.025,rotation=(angle,0,0))
    for x in (-.36,0,.36):
        a.box("Lower control",(.13,.055,.06),(x,-.226,.39),"teallight",.015,rotation=(angle,0,0))
    a.notes={"use":"Standalone decorative desktop display; supplied support is part of the model."}
    return a


def _battery():
    a=Asset("08_Battery_Canister","Small power props","Compact ribbed utility battery with a protected top terminal and a carrying grip.")
    a.cylinder("Bottom cap",.49,.16,(0,0,.08),"iron",12)
    a.cylinder("Cell casing",.42,1.25,(0,0,.775),"teal",12)
    for z in (.36,.72,1.08):a.torus("Protective band",.445,.045,(0,0,z),"wood",major_segments=12)
    a.cylinder("Upper cap",.49,.16,(0,0,1.48),"iron",12)
    a.cylinder("Terminal",.18,.14,(0,0,1.63),"gold",10)
    for x in (-.32,.32):a.box("Grip support",(.12,.18,.39),(x,0,1.695),"wood",.02)
    a.box("Grip bridge",(.76,.18,.12),(0,0,1.89),"wood",.025)
    a.notes={"use":"Grounded decorative battery with attached protective grip; no energy or inventory behavior."}
    return a


def _spool():
    a=Asset("09_Cable_Spool","Room utilities","Horizontal service cable reel with an axle held by two pedestals.")
    _base(a,(2.0,1.5),.18)
    for x in (-.77,.77):a.box("Axle pedestal",(.22,.62,.87),(x,0,.595),"wood",.055)
    a.cylinder("Axle",.13,1.85,(0,0,.95),"gold",10,(0,math.pi/2,0))
    a.cylinder("Cable drum",.49,1.09,(0,0,.95),"darkwood",16,(0,math.pi/2,0))
    for x in (-.56,.56):a.cylinder("Reel flange",.69,.12,(x,0,.95),"teal",12,(0,math.pi/2,0))
    for x in (-.38,-.19,0,.19,.38):a.torus("Cable coil",.495,.047,(x,0,.95),"iron",rotation=(0,math.pi/2,0),major_segments=16)
    a.notes={"support":"Both axle ends are embedded in the two grounded pedestals."}
    return a


def _conduit():
    a=Asset("10_Floor_Conduit","Modular room details","Three-stud utility floor plate with a low protective conduit cover and hazard markings.")
    _base(a,(3.0,2.2),.14)
    a.box("Conduit cover",(2.72,.70,.36),(0,0,.30),"wood",.11)
    for x in (-1.0,-.5,0,.5,1.0):a.box("Top stripe",(.18,.66,.035),(x,0,.498),"gold",.01)
    for y in (-.79,.79):a.box("Edge rail",(2.72,.13,.09),(0,y,.18),"stonelight",.02)
    a.notes={"modular":"Tile footprint 3.0 x 2.2 studs; origin at lower center. Decorative cover, no cable routing logic."}
    return a


def _tools():
    a=Asset("11_Technician_Dock","Lab equipment","Desktop service rack with a cradled probe, driver and closed utility pocket.")
    _base(a,(2.0,1.14),.16)
    a.box("Dock rear",(1.87,.20,1.78),(0,.32,1.02),"wood",.05)
    a.box("Dock shelf",(1.85,.85,.18),(0,-.06,.36),"iron",.04)
    for x,z in ((-.57,1.22),(.04,1.18)):
        a.box("Tool clip",(.33,.37,.17),(x,.03,1.20),"gold",.025)
        a.cylinder("Driver handle",.15,.59,(x,-.12,.82),"teal",10)
        a.cylinder("Driver shaft",.065,.47,(x,-.12,1.35),"stonelight",8)
        a.cylinder("Driver tip",.11,.20,(x,-.12,1.65),"iron",8)
    a.box("Closed utility box",(.47,.53,.88),(.62,-.01,.89),"woodlight",.06)
    _front(a,"Pocket stripe",.62,-.303,1.00,.29,.075,"teallight")
    a.notes={"use":"Two fixed service tools held by rack clips. No removable tools or interaction scripts."}
    return a


def _pylon():
    a=Asset("12_Status_Pylon","Room utilities","Three-segment indicator mast on a broad utility base.")
    _base(a,(1.26,1.05),.18)
    a.box("Mast",(.26,.30,2.34),(0,.08,1.35),"iron",.035)
    a.box("Indicator back",(.92,.41,1.73),(0,0,2.09),"wood",.06)
    for z,color in ((1.57,"emerald"),(2.07,"gold"),(2.57,"red")):
        _front(a,"Indicator bezel",0,-.227,z,.68,.37,"darkwood")
        _front(a,"Indicator face",0,-.274,z,.5,.22,color)
    a.notes={"use":"Static color indicators; no lights or status scripting."}
    return a


def build():
    return [_console(),_reactor(),_server(),_beacon(),_scanner(),_vent(),
            _tablet(),_battery(),_spool(),_conduit(),_tools(),_pylon()]
