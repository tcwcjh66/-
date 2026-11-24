# -*- coding: utf-8 -*-
"""cap sync 之后把本地 Swift 插件类名注册进 Capacitor 配置（否则 JS 侧找不到 HealthBridge）"""
import json
import os

candidates = [
    "ios/App/App/capacitor.config.json",
    "ios/App/capacitor.config.json",
]

for path in candidates:
    if not os.path.exists(path):
        continue
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
    classes = cfg.setdefault("packageClassList", [])
    if "HealthBridgePlugin" not in classes:
        classes.append("HealthBridgePlugin")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    print("registered HealthBridgePlugin ->", path)

print("done")
