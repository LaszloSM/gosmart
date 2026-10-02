"""Ensambla el prototipo: inyecta el sprite de íconos (Phosphor, MIT) y el QR pre-generado.

Genera:
  gosmart-guajira.html  cuerpo para publicar como artifact (sin doctype)
  index.html            página independiente para abrir en el navegador
"""
from pathlib import Path

here = Path(__file__).parent
src = (here / "src" / "app.html").read_text(encoding="utf-8")
sprite = (here / "src" / "sprite.svg").read_text(encoding="utf-8")
qr = (here / "src" / "qr.svg").read_text(encoding="utf-8")
body = src.replace("%%SPRITE%%", sprite).replace("%%QR%%", qr)
(here / "gosmart-guajira.html").write_text(body, encoding="utf-8")
(here / "index.html").write_text(
    '<!doctype html>\n<html lang="es">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
    '</head>\n<body>\n' + body + "\n</body>\n</html>\n",
    encoding="utf-8",
)
print("ok", len(body))
