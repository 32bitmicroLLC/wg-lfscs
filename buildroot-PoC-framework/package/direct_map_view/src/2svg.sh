#!/bin/sh

log=${1:?usage: $0 kernel.log > out.svg}
PAGE_SIZE=${PAGE_SIZE:-4096}

input_pfn=$(sed -n 's/.*input_pfn=\([0-9][0-9]*\).*/\1/p' "$log" | head -n 1)
checked_pfn=$(sed -n 's/.*checked_pfn=\([0-9][0-9]*\).*/\1/p' "$log" | head -n 1)

range_start=$(sed -n 's/.*scanning \[\([^ ]*\) - .*/\1/p' "$log" | head -n 1)
range_end=$(sed -n 's/.*scanning \[[^ ]* - \([^)]*\)).*/\1/p' "$log" | head -n 1)

slab_cache=$(sed -n 's/.*slab \([^ ]*\) start .*/\1/p' "$log" | head -n 1)
slab_start=$(sed -n 's/.*slab [^ ]* start \([^ ]*\) pointer .*/\1/p' "$log" | head -n 1)
ptr_offset=$(sed -n 's/.*pointer offset \([0-9][0-9]*\) size .*/\1/p' "$log" | head -n 1)
obj_size=$(sed -n 's/.* size \([0-9][0-9]*\).*/\1/p' "$log" | head -n 1)

candidate=$(sed -n 's/.*nearest candidate object at \([^,]*\),.*/\1/p' "$log" | head -n 1)
candidate_off_hex=$(sed -n 's/.*offset \(0x[0-9a-fA-F][0-9a-fA-F]*\) into PFN.*/\1/p' "$log" | head -n 1)

hex2dec()
{
    awk -v h="$1" '
    BEGIN {
        h = tolower(h)
        sub(/^0x/, "", h)
        n = 0
        for (i = 1; i <= length(h); i++) {
            c = substr(h, i, 1)
            d = index("0123456789abcdef", c) - 1
            n = n * 16 + d
        }
        print n
    }'
}

addr_page_off()
{
    low=$(echo "$1" | sed 's/.*\(...\)$/\1/')
    hex2dec "$low"
}

slab_off=$(addr_page_off "$slab_start")
candidate_off=$(hex2dec "$candidate_off_hex")
slab_end_off=$((slab_off + obj_size))

page_w=640
page_h=120
left_x=60
page_y=90
right_x=$((left_x + page_w))

slab_w=$((page_w * obj_size / PAGE_SIZE))
[ "$slab_w" -lt 1 ] && slab_w=1

slab_x=$((left_x + page_w * slab_off / PAGE_SIZE))

if [ $((slab_x + slab_w)) -gt $((left_x + page_w)) ]; then
    slab_x=$((left_x + page_w - slab_w))
fi

candidate_x=$((left_x + page_w * candidate_off / PAGE_SIZE))

cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="1420" height="300" viewBox="0 0 1420 300">
<style>
text { font-family: monospace; font-size: 13px; fill: #111; }
.title { font-size: 18px; font-weight: bold; }
.page { fill: #f8f8f8; stroke: #111; stroke-width: 2; }
.user { fill: #e8f1ff; stroke: #111; stroke-width: 2; }
.slab { fill: #ffd88a; stroke: #a65f00; stroke-width: 2; }
.probe { stroke: #c00; stroke-width: 2; }
</style>

<text x="60" y="35" class="title">PFN slab probe</text>
<text x="60" y="58">PAGE_SIZE=$PAGE_SIZE, slab=$obj_size bytes, rendered width=$slab_w px</text>

<rect x="$left_x" y="$page_y" width="$page_w" height="$page_h" class="page"/>
<rect x="$right_x" y="$page_y" width="$page_w" height="$page_h" class="user"/>

<text x="$left_x" y="82">PFN $checked_pfn kernel object page</text>
<text x="$right_x" y="82">PFN $input_pfn userspace page</text>

<rect x="$slab_x" y="$page_y" width="$slab_w" height="$page_h" class="slab"/>

<line x1="$candidate_x" y1="$page_y" x2="$candidate_x" y2="$((page_y + page_h))" class="probe"/>

<text x="$left_x" y="235">$range_start</text>
<text x="$right_x" y="235">$range_end / next page start</text>

<text x="$slab_x" y="255">$slab_cache start=$slab_start off=$slab_off end_off=$slab_end_off</text>
<text x="$candidate_x" y="275" fill="#c00">probe=$candidate page_off=$candidate_off_hex object_off=$ptr_offset</text>
</svg>
EOF
