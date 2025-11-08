import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PKG_ROOT = ROOT / "themectl"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(PKG_ROOT))
