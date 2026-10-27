"""Prepara el export web para Cloudflare Pages (límite de 25 MiB por archivo).

Uso (después de exportar a build/web):
  python3 tools/prepare_cloudflare.py
  npx wrangler pages deploy build/cloudflare --project-name dijimones

Copia build/web a build/cloudflare, parte index.wasm (~40 MB) en pedazos de 20 MB y agrega a index.html
un fetch que, cuando Godot pide index.wasm, baja los pedazos y los une en el navegador.
Los pedazos terminan en .wasm para que Cloudflare los sirva comprimidos (~10 MB en total).
"""
import os
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "build", "web")
DST = os.path.join(ROOT, "build", "cloudflare")
PART = 20 * 1024 * 1024

SHIM = """<script>
// Cloudflare Pages no acepta archivos de más de 25 MiB: index.wasm está partido y se une acá.
(function () {
  const parts = %s;
  const realFetch = window.fetch;
  window.fetch = function (input, init) {
    const url = typeof input === "string" ? input : input.url;
    if (url && /index\\.wasm(\\?|$)/.test(url)) {
      return Promise.all(parts.map((p) => realFetch(p).then((r) => r.arrayBuffer()))).then((bufs) => {
        const total = bufs.reduce((n, b) => n + b.byteLength, 0);
        const out = new Uint8Array(total);
        let offset = 0;
        for (const b of bufs) { out.set(new Uint8Array(b), offset); offset += b.byteLength; }
        return new Response(out, { headers: { "Content-Type": "application/wasm", "Content-Length": String(total) } });
      });
    }
    return realFetch.apply(this, arguments);
  };
})();
</script>
"""

HEADERS = """/*
  Cache-Control: public, max-age=300
/*.wasm
  Content-Type: application/wasm
"""


def main():
    if os.path.exists(DST):
        shutil.rmtree(DST)
    shutil.copytree(SRC, DST)
    wasm = os.path.join(DST, "index.wasm")
    data = open(wasm, "rb").read()
    names = []
    for k in range(0, len(data), PART):
        name = "index.part%d.wasm" % (k // PART)
        with open(os.path.join(DST, name), "wb") as fh:
            fh.write(data[k:k + PART])
        names.append(name)
    os.remove(wasm)
    html_path = os.path.join(DST, "index.html")
    html = open(html_path, encoding="utf-8").read()
    shim = SHIM % ("[" + ", ".join('"%s"' % n for n in names) + "]")
    html = html.replace("<head>", "<head>\n" + shim, 1)
    open(html_path, "w", encoding="utf-8").write(html)
    open(os.path.join(DST, "_headers"), "w").write(HEADERS)
    biggest = max(os.path.getsize(os.path.join(DST, f)) for f in os.listdir(DST))
    print("listo:", DST, "| pedazos:", names, "| archivo más grande: %.1f MiB" % (biggest / 1048576))


if __name__ == "__main__":
    main()
