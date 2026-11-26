#!/usr/bin/env python3
"""把 project.yml 裁成「只有主 App」的版本。

免费签名装带扩展的包容易整包失败：Widget / Watch 扩展各自要一个 App ID，
证书额度不够或者扩展签名不过，主 App 也一起装不上。
这个脚本删掉两个扩展 target 和主 target 对它们的依赖，让 CI 出一个能装的瘦包。

用法（CI 里）：
    python3 scripts/lite_project.py
会直接改写 project.yml；工作区是临时 checkout，改坏了不影响仓库。
"""

import re
import sys

PATH = "project.yml"

DEPS_BLOCK = """    dependencies:
      - target: TianCaiWeiWatch
      - target: TianCaiWeiWidget
"""


def main() -> int:
    with open(PATH, encoding="utf-8") as f:
        src = f.read()

    if "TianCaiWeiWatch:" not in src or "TianCaiWeiWidget:" not in src:
        print("project.yml 里已经找不到扩展 target，可能已经裁过了")
        return 0

    # 两个扩展 target 是文件末尾的两块，直接截到 Watch 之前
    idx = src.find("\n  TianCaiWeiWatch:")
    if idx < 0:
        print("找不到 TianCaiWeiWatch 块，放弃")
        return 1
    src = src[:idx] + "\n"

    if DEPS_BLOCK in src:
        src = src.replace(DEPS_BLOCK, "")
    else:
        # 兜底：逐行删 target 依赖
        src = re.sub(r"\n\s+- target: TianCaiWei(Watch|Widget)", "", src)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(src)

    print("已裁成 lite：只剩主 App target")
    print("剩余 target 行：")
    for line in src.splitlines():
        if re.match(r"^  [A-Za-z].*:$", line):
            print("  " + line.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
