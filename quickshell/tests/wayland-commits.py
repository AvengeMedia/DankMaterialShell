import collections
import re
import sys

log = open(sys.argv[1]).read().splitlines()
stamp = re.compile(r"^\[(\d+):(\d+):(\d+)\.(\d+)\]")


def seconds(line):
    match = stamp.match(line)
    if not match:
        return None
    hours, minutes, whole, fraction = (int(part) for part in match.groups())
    return hours * 3600 + minutes * 60 + whole + fraction / 10 ** len(match.group(4))


surfaces = {}
for line in log:
    match = re.search(r'get_layer_surface\(new id zwlr_layer_surface_v1#\d+, wl_surface#(\d+), [^,]*, \d+, "([^"]+)"\)', line)
    if match:
        surfaces[match.group(2)] = match.group(1)
start = min(t for t in (seconds(line) for line in log) if t is not None)
print("layer surfaces:", surfaces)
for namespace, surface in surfaces.items():
    events = collections.defaultdict(list)
    for line in log:
        at = seconds(line)
        if at is None or f"wl_surface#{surface}." not in line:
            continue
        events[re.search(r"wl_surface#\d+\.(\w+)\(", line).group(1)].append(at - start)
    print(f"\n== {namespace} wl_surface#{surface}")
    for kind, times in sorted(events.items()):
        buckets = collections.Counter(int(t) for t in times)
        print(f"  {kind:<24} total {len(times):4}  per-second {dict(sorted(buckets.items()))}")
