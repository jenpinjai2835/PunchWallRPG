"""Original warm cafe furniture and countertop props; no interactive systems."""
import math
from geometry import Asset, ring_mesh

META={
    "slug":"sunbeam-cafe", "title":"Sunbeam Cafe",
    "tagline":"A coordinated counter, seating and serving collection",
    "description":"Twelve original cafe props with warm timber, pastry displays and a detailed espresso station. Visual models only; no ordering, cooking or interaction systems.",
    "palettes":{
        "Classic":["A96D44","523C31","D9AC77","4F9390","ADD7C5","B28B50","F5D79B","45565A","7A8889","C1CCBE","FFF1D6","C47865","7DA36E","B59CC4","9C694F","293B3D"],
        "Warm":["AA6742","54372D","DEAD73","B77C57","EDC99B","BE9353","FFE1A5","645250","99867C","D8C6B0","FFF0D7","CF7763","9AAB6E","C19BBD","AC7053","3E302D"],
        "Twilight":["907C83","423C51","C5ABB1","777AA6","BCBDD9","B9A071","F0DFBD","494958","878695","C8C5D0","F4ECED","C18994","8FA49B","AA98C5","967B81","302B3C"],
    },
    "samples":["08_Takeaway_Cup","09_Cup_And_Saucer"],
}


def _foot(a,x,y,height=.16):
    a.box("Furniture foot",(.23,.23,height),(x,y,height/2),"darkwood",.025)


def _round(a,name,rings,loc,color,sides=16):
    v,f=ring_mesh(rings,sides)
    return a.mesh(name,v,f,color,loc)


def _cup_handle(a):
    # Closed half-loop joins only the outside ceramic wall; it never crosses the drink.
    verts=[];segments=12;sides=6
    for i in range(segments+1):
        angle=-math.pi/2+math.pi*i/segments
        x=.365+.035*math.sin(angle)+.25*math.cos(angle)
        z=.455+.21*math.sin(angle)
        dx=.035*math.cos(angle)-.25*math.sin(angle);dz=.21*math.cos(angle)
        length=math.hypot(dx,dz);nx,nz=dz/length,-dx/length
        for j in range(sides):
            t=math.tau*j/sides
            verts.append((x+.065*nx*math.cos(t),.065*math.sin(t),z+.065*nz*math.cos(t)))
    faces=[tuple(range(sides-1,-1,-1))]
    for i in range(segments):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    faces.append(tuple(segments*sides+j for j in range(sides)))
    a.mesh("Cup handle",verts,faces,"teal")


def _counter():
    a=Asset("01_Service_Counter","Cafe furniture","Compact timber service counter with inset panels, a raised worktop and usable open rear shelves.")
    a.box("Plinth",(4.6,2.15,.19),(0,0,.095),"darkwood",.065)
    a.box("Front cabinet",(4.35,.22,2.12),(0,-.94,1.23),"wood",.06)
    for x in (-2.075,2.075):a.box("Cabinet end",(.2,1.95,2.12),(x,0,1.23),"wood",.06)
    a.box("Lower shelf",(4.13,1.85,.13),(0,.03,.37),"woodlight",.025)
    a.box("Rear shelf",(4.13,1.76,.13),(0,.08,1.33),"woodlight",.025)
    a.box("Shelf divider",(.13,1.78,1.73),(0,.09,1.17),"wood",.025)
    a.box("Countertop",(4.70,2.35,.24),(0,0,2.37),"cream",.085)
    for x in (-1.43,0,1.43):
        a.box("Inset front panel",(1.2,.08,1.48),(x,-1.085,1.23),"teal",.05)
        a.box("Panel upper trim",(1.04,.04,.05),(x,-1.151,1.8),"goldlight",.01)
    a.notes={"use":"Open rear shelves; wall, shelves and side panels have thickness. Front faces -Y.","dimensions":"4.7 x 2.35 footprint; worktop top Z=2.49."}
    return a


def _espresso():
    a=Asset("02_Espresso_Machine","Counter equipment","Two-group espresso unit with water tank, cup rail, gauges, attached handles and drip tray.")
    for x in (-1.13,1.13):
        for y in (-.57,.57):_foot(a,x,y)
    a.box("Base tray",(2.72,1.76,.17),(0,-.13,.245),"iron",.075)
    a.box("Main body",(2.60,1.14,1.54),(0,.16,1.055),"teal",.15)
    a.box("Top cover",(2.73,1.28,.13),(0,.17,1.89),"stonelight",.06)
    # Service face ends above the group heads; spouts project into the drip area.
    a.box("Control fascia",(2.32,.10,.48),(0,-.474,1.39),"cream",.045)
    for x in (-.73,.73):
        a.cylinder("Gauge rim",.20,.08,(x,-.56,1.44),"gold",16,(math.pi/2,0,0))
        a.cylinder("Gauge face",.155,.028,(x,-.616,1.44),"black",16,(math.pi/2,0,0))
        a.box("Gauge needle",(.035,.02,.17),(x,-.638,1.465),"goldlight",.005,rotation=(0,.34,0))
        a.cylinder("Group head",.22,.22,(x,-.50,1.01),"stonelight",12)
        a.cylinder("Portafilter shaft",.072,.59,(x,-.88,1.03),"iron",10,(math.pi/2,0,0))
        a.cylinder("Portafilter grip",.10,.35,(x,-1.20,1.03),"darkwood",10,(math.pi/2,0,0))
        a.cylinder("Twin spout",.055,.23,(x,-.56,.84),"iron",8)
    a.box("Drip plate",(2.41,.57,.075),(0,-.65,.37),"stonelight",.025)
    for x in (-.95,-.64,-.32,0,.32,.64,.95):a.box("Drip slot",(.065,.38,.022),(x,-.67,.42),"iron",.01)
    for x in (-1.23,1.23):a.box("Cup rail end",(.09,1.16,.25),(x,.17,2.00),"iron",.015)
    a.box("Cup rail back",(2.50,.09,.25),(0,.72,2.00),"iron",.015)
    a.notes={"placement":"Countertop model; lowest feet at Z=0. Front -Y. Handles are connected to group heads.","use":"Static appliance; no dispensing, steam, particles or sounds."}
    return a


def _pastry_case():
    a=Asset("03_Pastry_Display","Counter equipment","Open-front pastry display with thick roof, solid backing and two supported display levels.")
    a.box("Display base",(2.92,1.5,.22),(0,0,.11),"wood",.065)
    a.box("Display backing",(2.73,.12,1.87),(0,.64,1.12),"teal",.04)
    for x in (-1.30,1.30):
        a.box("Front upright",(.13,.15,1.88),(x,-.55,1.10),"gold",.025)
        a.box("Side rail",(.13,1.30,.13),(x,0,1.16),"gold",.02)
    a.box("Upper tray",(2.57,1.24,.11),(0,0,1.11),"cream",.035)
    a.box("Roof",(2.93,1.51,.18),(0,0,2.14),"woodlight",.065)
    for z in (.22,1.165):
        for x in (-.78,0,.78):
            _round(a,"Display bun",[(0,.27),(.14,.32),(.28,.22),(.33,.10)],(x,-.10,z),"goldlight",12)
            a.box("Bun score",(.25,.035,.032),(x,-.10,z+.32),"woodlight",.01)
    a.notes={"use":"Open front is intentional. No invisible glass is claimed; backing, shelves and roof are solid.","placement":"Countertop display; six fixed pastries are included as geometry."}
    return a


def _table():
    a=Asset("04_Round_Cafe_Table","Seating furniture","Round bistro table with a central pedestal, four low feet and a thick timber top.")
    for angle in (0,math.pi/2,math.pi,math.pi*1.5):
        a.beam("Table foot",(0,0,.18),(1.04*math.cos(angle),1.04*math.sin(angle),.10),.23,"iron",.20)
    a.cylinder("Pedestal",.16,2.1,(0,0,1.18),"iron",12)
    a.cylinder("Under-top support",.49,.18,(0,0,2.15),"iron",12)
    a.cylinder("Timber tabletop",1.46,.20,(0,0,2.34),"woodlight",24)
    a.torus("Tabletop edge",1.41,.06,(0,0,2.36),"wood",major_segments=24)
    a.notes={"dimensions":"Tabletop diameter 2.92; top Z=2.44. Static decorative furniture."}
    return a


def _chair():
    a=Asset("05_Slatted_Cafe_Chair","Seating furniture","Four-legged chair with a curved slatted back, thick padded seat and supported front rails.")
    for x in (-.52,.52):
        for y in (-.46,.46):
            a.beam("Chair leg",(x*1.15,y*1.15,.08),(x,y,1.3),.16,"wood")
    a.box("Seat base",(1.38,1.30,.16),(0,0,1.32),"wood",.055)
    a.box("Seat cushion",(1.25,1.17,.13),(0,-.01,1.455),"teal",.065)
    for x in (-.57,.57):a.beam("Back upright",(x,.49,1.26),(x,.69,2.70),.16,"wood")
    for z,y in ((1.95,.60),(2.35,.65),(2.68,.70)):
        a.box("Back slat",(1.26,.13,.20),(0,y,z),"woodlight",.045)
    for x in (-.53,.53):a.beam("Side stretcher",(x,-.48,.65),(x,.50,.65),.09,"darkwood")
    a.notes={"front":"Seat opens toward -Y; chair back faces +Y. No Seat instance or sitting behavior."}
    return a


def _menu():
    a=Asset("06_Menu_Easel","Cafe signage","Standing framed menu with abstract menu rows and an A-frame rear support.")
    for x in (-.63,.63):
        a.beam("Front easel leg",(x,-.50,.08),(x,.10,2.48),.16,"wood")
        a.beam("Rear easel leg",(x,.79,.08),(x,.11,2.35),.16,"wood")
        a.beam("Easel side brace",(x,-.31,.79),(x,.60,.79),.10,"darkwood")
    a.box("Menu backing",(1.67,.16,1.79),(0,-.18,1.75),"woodlight",.055,rotation=(-.20,0,0))
    a.box("Menu face",(1.39,.065,1.51),(0,-.285,1.771),"black",.035,rotation=(-.20,0,0))
    for z,width in ((2.26,.95),(1.97,.94),(1.70,.82),(1.43,.91)):
        y=-.285+(z-1.771)*math.tan(.20)-.041/math.cos(.20)
        a.box("Menu row",(width,.025,.055),(-.05,y,z),"cream",.012,rotation=(-.20,0,0))
    a.notes={"use":"Abstract menu lines only; no copied text, fonts, brands or ordering UI."}
    return a


def _stool():
    a=Asset("07_Counter_Stool","Seating furniture","Round upholstered stool with a broad pedestal base and a connected footrest.")
    a.cylinder("Base",.69,.14,(0,0,.07),"iron",16)
    a.cylinder("Pedestal",.13,1.74,(0,0,1.00),"iron",12)
    a.torus("Footrest",.43,.055,(0,0,.68),"gold",major_segments=16)
    for angle in (0,math.pi/2,math.pi,math.pi*1.5):
        a.beam("Footrest spoke",(0,0,.68),(.43*math.cos(angle),.43*math.sin(angle),.68),.055,"gold")
    a.cylinder("Seat rim",.69,.12,(0,0,1.89),"wood",16)
    a.cylinder("Padded seat",.66,.17,(0,0,2.02),"teal",16)
    a.notes={"use":"Static stool with attached footrest spokes; no Seat instance or sitting behavior.","dimensions":"Seat top Z=2.105; base diameter 1.38."}
    return a


def _takeaway():
    a=Asset("08_Takeaway_Cup","Serving props","Tapered takeaway cup with a closed sipping lid and a plain paper sleeve.")
    _round(a,"Cup",[(0,.30),(.05,.32),(.92,.42)],(0,0,0),"cream",16)
    _round(a,"Paper sleeve",[(.29,.36),(.32,.37),(.61,.40),(.64,.397)],(0,0,0),"wood",16)
    a.cylinder("Lid brim",.46,.07,(0,0,.955),"iron",16)
    a.cylinder("Raised lid",.39,.09,(0,0,1.035),"iron",16)
    a.box("Sipping recess",(.19,.09,.019),(0,-.22,1.09),"black",.03)
    a.notes={"use":"Closed decorative drink cup; sleeve has no logo or text."}
    return a


def _cup():
    a=Asset("09_Cup_And_Saucer","Serving props","Ceramic cup with a visible coffee surface, supported handle and a shallow saucer.")
    _round(a,"Saucer",[(0,.62),(.055,.69),(.115,.65),(.13,.46)],(0,0,0),"cream",20)
    _round(a,"Cup bowl",[(.13,.29),(.20,.34),(.64,.42),(.69,.42),(.69,.36),(.62,.355),(.24,.26)],(0,0,0),"teal",16)
    a.cylinder("Coffee surface",.351,.025,(0,0,.621),"darkwood",16)
    _cup_handle(a)
    a.notes={"use":"Bowl cavity has thickness; coffee surface closes the filled volume. Handle intersects the ceramic wall intentionally at its attachment."}
    return a


def _pastry_tray():
    a=Asset("10_Pastry_Tray","Serving props","Rounded serving tray with two scored breakfast rolls and a folded serving napkin.")
    a.box("Serving tray",(1.94,1.28,.13),(0,0,.065),"wood",.08)
    a.box("Napkin",(1.55,.99,.027),(0,0,.145),"cream",.018)
    for x in (-.44,.44):
        _round(a,"Breakfast roll",[(0,.27),(.12,.33),(.28,.23),(.33,.10)],(x,0,.16),"goldlight",12)
        for y in (-.10,.08):a.box("Roll score",(.32,.042,.026),(x,y,.466),"woodlight",.01)
    a.notes={"use":"Tray, napkin and two rolls are one static arrangement; no serving or food system."}
    return a


def _plant():
    a=Asset("11_Counter_Plant","Cafe details","Small ribbed ceramic planter with an original fan of solid succulent leaves.")
    _round(a,"Planter",[(0,.31),(.08,.36),(.70,.45),(.78,.48),(.84,.48),(.84,.39),(.72,.38)],(0,0,0),"cream",16)
    a.cylinder("Soil",.375,.10,(0,0,.735),"darkwood",12)
    for i in range(7):
        t=math.tau*i/7
        a.gem("Succulent leaf",.14,.77,(.12*math.cos(t),.12*math.sin(t),.78),"emerald",rotation=(.38*math.sin(t),-.38*math.cos(t),t))
    a.gem("Center leaf",.16,.72,(0,0,.81),"teallight")
    a.notes={"use":"Solid leaves join the soil-filled ceramic pot. Root is the flat underside of the planter."}
    return a


def _lamp():
    a=Asset("12_Pendant_Lamp","Cafe fixtures","Thick bell-shaped pendant shade with an attached cable, ceiling plate and warm diffuser.")
    _round(a,"Pendant shade",[(0,.83),(.08,.85),(.48,.46),(.58,.25),(.63,.24),(.63,.16),(.51,.17),(.08,.72)],(0,0,0),"teal",20)
    a.cylinder("Diffuser",.66,.055,(0,0,.10),"goldlight",20)
    a.cylinder("Cable",.035,1.69,(0,0,1.43),"darkwood",8)
    a.cylinder("Ceiling plate",.28,.12,(0,0,2.31),"iron",12)
    a.notes={"mount":"Hanging fixture. Root is the lowest shade edge; ceiling plate top Z=2.37. Align plate to ceiling.","use":"Decorative diffuser only; no Light instance or electrical behavior."}
    return a


def build():
    return [_counter(),_espresso(),_pastry_case(),_table(),_chair(),_menu(),
            _stool(),_takeaway(),_cup(),_pastry_tray(),_plant(),_lamp()]
