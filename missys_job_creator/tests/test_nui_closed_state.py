from pathlib import Path

root = Path(__file__).resolve().parents[1]
html = (root / 'web' / 'index.html').read_text(encoding='utf-8')
css = (root / 'web' / 'styles.css').read_text(encoding='utf-8')
js = (root / 'web' / 'app.js').read_text(encoding='utf-8')

assert 'style="display: none;"' in html, 'NUI root must be hidden inline before external CSS/JS load'
assert 'background-color: rgba(0, 0, 0, 0) !important' in css, 'html/body must force transparent FiveM NUI canvas'
assert 'color-scheme: dark' not in css, 'root color-scheme must not request a dark page canvas while UI is closed'
assert "app.style.display = 'none'" in js, 'close/hide messages must explicitly remove the fullscreen NUI root'
assert "app.style.display = 'grid'" in js, 'open messages must explicitly restore the fullscreen NUI root'

print('PASS: closed NUI cannot paint an opaque fullscreen layer')
