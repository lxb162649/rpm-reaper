import os
import re
from collections import defaultdict

with open('logs/repo.list.tmp', 'r') as f:
    rpm_paths = [line.strip() for line in f if line.strip()]

rpm_pattern = re.compile(r'(.+)-([^-]+)-([^-]+)\.(noarch|x86_64|i386|arm|aarch64|ppc64le)\.rpm$')
package_groups = defaultdict(list)

for path in rpm_paths:
    filename = os.path.basename(path)
    match = rpm_pattern.search(filename)
    if match:
        name, version, release, arch = match.groups()
        full_version = f"{version}-{release}"
        package_groups[name].append((full_version, path))

selected_paths = []
used_names = set()  # 用于记录已经处理过的包名
for name, versions in package_groups.items():
    if name in used_names:
        continue
    sorted_versions = sorted(versions, key=lambda x: x[0], reverse=True)
    selected_paths.append(sorted_versions[0][1])
    used_names.add(name)

with open('logs/repo.list', 'w') as f:
    f.write('\n'.join(selected_paths) + '\n')

print(f"已筛选出 {len(selected_paths)} 个最高版本的RPM包")