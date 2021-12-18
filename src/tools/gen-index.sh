#!/bin/bash

echo '<!doctype html><html><body><table><tr><th>File Name</th><th>SVG</th><th>TVG</th></tr>'

for tvg in *.tvg ; do
  base="${tvg%.tvg}"
  echo "<tr><th>${tvg}</th><th><img loading=\"lazy\" src=\"${base}.svg\"></th><th><img loading=\"lazy\" src=\"${base}.render.png\"></th></tr>"
done

echo '</table></body></html>'