import sys
import glob

def polish_style():
    files = glob.glob('/Users/kupolak/Desktop/praca_inzynierska_tex/*.tex')
    replacements = {
        'okres czasu': 'okres',
        'fakt, że': 'to, że',
        'na dzień dzisiejszy': 'obecnie',
        'w miesiącu': 'w',
        'akwen wodny': 'akwen',
        'poprawić na lepsze': 'poprawić'
    }
    
    for path in files:
        with open(path, 'r', encoding='utf-8') as f:
            c = f.read()
        
        changed = False
        for old, new in replacements.items():
            if old in c:
                c = c.replace(old, new)
                changed = True
        
        if changed:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(c)
            print(f"Polished style in {path}")

polish_style()
