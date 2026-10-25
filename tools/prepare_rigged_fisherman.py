"""Keep the downloaded rig/skin intact; give game clips and joints stable names."""
from pathlib import Path
import json
import struct

project = Path(__file__).resolve().parents[1]
source = project.parent / 'retopology/ultralow/mesh2motion/current_rig_tpose_12_animations_20261025.glb'
target = project / 'actors/player/models/fisherman_rigged.glb'
data = source.read_bytes()
size = struct.unpack_from('<I', data, 12)[0]
document = json.loads(data[20:20 + size])
names = {'Hips': 'pelvis', 'Spine': 'spine_01', 'Spine1': 'spine_02', 'Spine2': 'spine_03', 'Neck': 'neck_01', 'Head': 'head', 'Head_end': 'head_leaf'}
for side, suffix in [('Left', 'l'), ('Right', 'r')]:
    for original, canonical in [('Shoulder', 'clavicle'), ('Arm', 'upperarm'), ('ForeArm', 'lowerarm'), ('Hand', 'hand'), ('Hand_end', 'hand_leaf'), ('UpLeg', 'thigh'), ('Leg', 'calf'), ('Foot', 'foot'), ('ToeBase', 'ball'), ('ToeBase_end', 'ball_leaf')]:
        names[side + original] = canonical + '_' + suffix
for node in document['nodes']:
    node['name'] = names.get(node.get('name'), node.get('name', 'Node'))
for animation in document['animations']:
    animation['name'] = animation['name'].removesuffix('_RT')
encoded = json.dumps(document, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
remainder = data[20 + size:]
target.write_bytes(struct.pack('<III', 0x46546C67, 2, 20 + len(encoded) + len(remainder)) + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + remainder)
print(target)
