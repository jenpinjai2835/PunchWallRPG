"""Eight original rewards and gathering props. No imported meshes or scripts."""
import math
from geometry import Asset, ring_mesh


def coin(a, label, loc, radius=.5, role="Body", rotation=(0, 0, 0)):
    a.cylinder(label, radius, .12, loc, "gold", 12, rotation, role)
    if rotation == (0, 0, 0):
        a.cylinder(label+"_Rim", radius*.76, .022, (loc[0],loc[1],loc[2]+.071), "goldlight", 12, role=role)
        a.box(label+"_Mint", (.28,.28,.034), (loc[0],loc[1],loc[2]+.094), "gold", .015, (0,0,math.pi/4), role)


def build():
    assets = []
    a=Asset("09_Coin_Stack", "Rewards", "Three stacks of faceted mint coins with raised diamond stamps.")
    for j,(x,y,n) in enumerate(((-.42,.15,5),(.38,.22,3),(.25,-.5,1))):
        for k in range(n):
            coin(a,f"Stack{j}_Coin{k}",(x,y,.06+k*.125),.46)
    assets.append(a)

    a=Asset("10_Coin_Pouch", "Rewards", "Faceted leather purse, folded neck, brass cord and spilled coins.")
    v,f=ring_mesh([(0,.38),(.13,.63),(.65,.72),(1.04,.48),(1.22,.26),(1.46,.39)],10)
    a.mesh("LeatherPurse",v,f,"leather")
    a.torus("TieCord",.275,.05,(0,0,1.24),"gold",major_segments=10)
    a.beam("CordTailL",(.2,-.24,1.24),(.3,-.47,.91),.045,"gold")
    a.beam("CordTailR",(.2,-.24,1.24),(.51,-.4,1.03),.045,"gold")
    a.box("DiamondSeal",(.3,.10,.3),(0,-.706,.6),"gold",.025,(0,math.pi/4,0))
    coin(a,"SpilledCoinA",(.59,-.45,.065),.32)
    coin(a,"SpilledCoinB",(.8,-.03,.065),.28)
    assets.append(a)

    a=Asset("11_Cut_Gem", "Rewards", "Large cut gem with six broad, readable facets and a brass setting.")
    a.cylinder("Setting",.62,.13,(0,0,.065),"gold",12)
    a.gem("Gemstone",.58,1.18,(0,0,.13),"teal")
    for i in range(3):
        ang=i*math.tau/3
        a.beam("Claw"+str(i),(.53*math.cos(ang),.53*math.sin(ang),.12),
               (.52*math.cos(ang),.52*math.sin(ang),.46),.075,"goldlight")
    assets.append(a)

    a=Asset("12_Crystal_Cluster", "Gathering", "Three asymmetric crystal spires rooted in a faceted stone outcrop.")
    v,f=ring_mesh([(0,.68),(.15,.95),(.37,.72)],7)
    a.mesh("RockFoot",v,f,"stone")
    a.gem("TallCrystal",.38,1.83,(-.18,.12,.26),"teal",(0,-.1,.12))
    a.gem("SideCrystal",.3,1.15,(.42,.02,.24),"teallight",(0,.22,.45))
    a.gem("FrontCrystal",.24,.85,(-.18,-.52,.18),"teallight",(.16,-.14,0))
    assets.append(a)

    a=Asset("13_Ore_Node", "Gathering", "Broad layered boulder with exposed golden mineral seams.")
    v,f=ring_mesh([(0,.83),(.24,1.15),(.86,1.06),(1.27,.7),(1.48,.22)],9)
    v=[(x*(1+.12*math.sin(i*2.1)),y*.8,z) for i,(x,y,z) in enumerate(v)]
    a.mesh("FacetedBoulder",v,f,"stone")
    for i,(loc,r,h,rot) in enumerate([((-.65,-.39,.46),.3,.73,(.32,-.28,0)),
                                    ((.32,-.62,.52),.26,.72,(.22,.22,0)),
                                    ((.25,.05,1.16),.33,.64,(0,.21,.3))]):
        a.gem("GoldSeam"+str(i),r,h,loc,"gold",rot)
    assets.append(a)

    a=Asset("14_Alchemy_Bottle", "Rewards", "Opaque stylized potion flask with a cork, collar and diamond label.")
    v,f=ring_mesh([(0,.32),(.11,.54),(.67,.57),(1.02,.23),(1.23,.23)],12)
    a.mesh("PotionFlask",v,f,"teal")
    a.cylinder("BrassNeck",.265,.1,(0,0,1.2),"gold",12)
    a.cylinder("Cork",.2,.24,(0,0,1.35),"woodlight",10)
    a.box("Label",(.48,.045,.48),(0,-.557,.56),"cream",.035,(0,math.pi/4,0))
    a.box("LabelGem",(.2,.065,.2),(0,-.59,.56),"gold",.015,(0,math.pi/4,0))
    assets.append(a)

    a=Asset("15_Reward_Medallion", "Rewards", "Upright sun medallion with a central jewel and a self-standing plinth.")
    a.box("Foot",(1.52,.75,.2),(0,0,.1),"iron",.07)
    a.box("BrassFoot",(1.31,.61,.08),(0,0,.24),"gold",.025)
    a.cylinder("Medal",.77,.18,(0,0,1.04),"gold",16,(math.pi/2,0,0))
    a.cylinder("EnamelFace",.6,.2,(0,-.015,1.04),"teal",16,(math.pi/2,0,0))
    # Flat extruded eight-point seal faces toward the viewer.
    outline=[]
    for i in range(16):
        ang=i*math.tau/16
        r=.47 if i%2==0 else .25
        outline.append((r*math.cos(ang),r*math.sin(ang)))
    verts=[(x,y,z) for y in (-.14,-.18) for x,z in outline]
    faces=[tuple(range(15,-1,-1)),tuple(range(16,32))]
    faces += [(i,(i+1)%16,(i+1)%16+16,i+16) for i in range(16)]
    a.mesh("SunSeal",verts,faces,"goldlight",(0,0,1.04))
    a.box("SealJewel",(.27,.07,.27),(0,-.21,1.04),"teallight",.02,(0,math.pi/4,0))
    assets.append(a)

    a=Asset("16_Upgrade_Hammer", "Tools", "A chunky display hammer with an iron head, brass faces and wrapped handle.")
    a.box("Handle",(.28,.34,1.8),(0,0,1.04),"wood",.055)
    for i in range(5):
        a.box("Grip"+str(i),(.36,.41,.12),(0,0,.29+i*.17),"leather",.04)
    a.box("Pommel",(.45,.48,.2),(0,0,.12),"gold",.05)
    a.box("HammerHead",(1.55,.72,.72),(0,0,2.0),"iron",.12)
    for s in (-1,1):
        a.box("StrikingFace"+str(s),(.17,.83,.84),(s*.8,0,2.0),"gold",.065)
    a.box("Inlay",(.38,.055,.38),(0,-.382,2.0),"teal",.025,(0,math.pi/4,0))
    a.notes={"interaction":"Static display prop; no Tool, damage or upgrade script included."}
    assets.append(a)
    return assets
