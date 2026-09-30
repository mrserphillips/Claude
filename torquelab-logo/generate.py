import math, os
OUT = os.path.dirname(os.path.abspath(__file__))
def gear(cx, cy, r_out, r_in, teeth, tip=0.38, base=0.55):
    pts=[]
    step=2*math.pi/teeth
    for i in range(teeth):
        a=i*step - math.pi/2
        for ang,r in [(a-step*base/2,r_in),(a-step*tip/2,r_out),(a+step*tip/2,r_out),(a+step*base/2,r_in)]:
            pts.append((cx+r*math.cos(ang), cy+r*math.sin(ang)))
    return "M"+" L".join(f"{x:.2f},{y:.2f}" for x,y in pts)+" Z"

G = gear(200,200,168,146,12)

# City skyline inside gear (clipped to inner circle)
sky = ("M60,262 L60,212 L86,212 L86,186 L104,186 L104,226 L122,226 L122,150 L134,150 L134,138 L146,138 L146,150 L158,150 "
       "L158,234 L174,234 L174,196 L192,178 L210,196 L210,238 L226,238 L226,122 L238,110 L250,122 L250,232 L266,232 "
       "L266,176 L292,176 L292,214 L308,214 L308,190 L340,190 L340,262 Z")
windows = []
for (x0,y0,x1,y1) in [(126,158,154,230),(230,130,246,228),(270,184,288,210)]:
    y=y0
    while y+6<y1:
        x=x0
        while x+4<=x1:
            windows.append(f'<rect x="{x}" y="{y}" width="4" height="6" rx="1"/>')
            x+=8
        y+=12
W="".join(windows)

# Wrench, drawn horizontal then rotated

def mark(tx=0, ty=0, s=1.0, ids=""):
    return f'''<g transform="translate({tx},{ty}) scale({s})">
    <path d="{G}" fill="url(#grad{ids})"/>
    <circle cx="200" cy="200" r="128" fill="#0B1233"/>
    <g clip-path="url(#inner{ids})">
      <circle cx="200" cy="200" r="128" fill="url(#night{ids})"/>
      <circle cx="152" cy="104" r="16" fill="#FF6FB5" opacity="0.9"/>
      <path d="{sky}" fill="#1B2A6B"/>
      <g fill="#FF9BD0" opacity="0.85">{W}</g>
      <rect x="60" y="262" width="280" height="80" fill="#12205A"/>
      <path d="M72,262 L328,262" stroke="url(#grad{ids})" stroke-width="4"/>
    </g>
    <g transform="translate(200,206) rotate(-42) scale(0.86)">
      <g mask="url(#jawcut{ids})">
        <path d="M-120,-14 L96,-14 L96,14 L-120,14 A14,14 0 0 1 -120,-14 Z" fill="#F4F7FF" stroke="#0B1233" stroke-width="7" stroke-linejoin="round"/>
        <circle cx="110" cy="0" r="38" fill="#F4F7FF" stroke="#0B1233" stroke-width="7"/>
        <path d="M-100,-14 L96,-14 L96,14 L-100,14 Z" fill="#F4F7FF"/>
        <path d="M-96,0 L60,0" stroke="#C9D3F5" stroke-width="5" stroke-linecap="round"/>
      </g>
      <circle cx="-118" cy="0" r="5" fill="#0B1233"/>
    </g>
    <circle cx="200" cy="200" r="128" fill="none" stroke="url(#grad{ids})" stroke-width="6"/>
  </g>'''

def defs(ids=""):
    return f'''<linearGradient id="grad{ids}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2F6BFF"/><stop offset="0.5" stop-color="#8A5CFF"/><stop offset="1" stop-color="#FF4FA3"/>
    </linearGradient>
    <linearGradient id="night{ids}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1A2F8A"/><stop offset="0.65" stop-color="#6A3FB8"/><stop offset="1" stop-color="#E0559E"/>
    </linearGradient>
    <mask id="jawcut{ids}" maskUnits="userSpaceOnUse" x="-200" y="-200" width="400" height="400">
      <rect x="-200" y="-200" width="400" height="400" fill="#fff"/>
      <path d="M108,-19 L160,-19 L160,19 L108,19 A19,19 0 0 1 108,-19 Z" fill="#000" transform="rotate(0)"/>
    </mask>
    <clipPath id="inner{ids}"><circle cx="200" cy="200" r="125"/></clipPath>'''

FONT = "font-family=\"'Montserrat','Poppins','Arial Black','Helvetica Neue',Arial,sans-serif\""

# 1) Icon only
open(os.path.join(OUT, "torquelab-icon.svg"),"w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <defs>{defs()}</defs>
  {mark()}
</svg>
''')

# 2) Horizontal lockup
open(os.path.join(OUT, "torquelab-logo.svg"),"w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 400" width="1200" height="400">
  <defs>{defs()}
    <linearGradient id="word" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#FF4FA3"/><stop offset="1" stop-color="#FF8AC6"/>
    </linearGradient>
  </defs>
  {mark(10,20,0.9)}
  <g {FONT} font-weight="900">
    <text x="400" y="230" font-size="150" letter-spacing="-4" fill="#1F4FE0">Torque<tspan fill="url(#word)">Lab</tspan></text>
    <rect x="404" y="262" width="760" height="6" rx="3" fill="url(#grad)"/>
    <text x="406" y="318" font-size="36" font-weight="700" letter-spacing="24" fill="#5A6690">CITY MECHANICS</text>
  </g>
</svg>
''')

# 3) Stacked on dark
open(os.path.join(OUT, "torquelab-logo-dark.svg"),"w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">
  <defs>{defs()}</defs>
  <rect width="800" height="800" rx="48" fill="#0B1233"/>
  {mark(220,70,0.9)}
  <g {FONT} font-weight="900" text-anchor="middle">
    <text x="400" y="560" font-size="118" letter-spacing="-3" fill="#6F9BFF">Torque<tspan fill="#FF5FAE">Lab</tspan></text>
    <rect x="180" y="592" width="440" height="5" rx="2.5" fill="url(#grad)"/>
    <text x="400" y="648" font-size="30" font-weight="700" letter-spacing="12" fill="#C9D3F5">CITY MECHANICS</text>
  </g>
</svg>
''')
