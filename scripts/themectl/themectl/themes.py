"""Theme metadata loading/parsing."""

from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
from typing import Any, Iterator, Mapping


@dataclass(slots=True)
class Theme:
    name: str
    slug: str
    display_name: str
    wallpapers: list[Path]
    raw: Mapping[str, Any] = field(repr=False)
    kind: str | None = None

    def section(self, name: str) -> Mapping[str, Any]:
        value = self.raw.get(name)
        if isinstance(value, Mapping):
            return value
        return {}

    @property
    def nvim_colorscheme(self) -> str | None:
        return self.section("nvim").get("colorscheme")

    @property
    def vscode_theme(self) -> str | None:
        return self.section("vscode").get("theme")

    @property
    def vscode_extension(self) -> str | None:
        return self.section("vscode").get("extension")

    @property
    def cursor_theme(self) -> str | None:
        return self.section("cursor").get("theme")


@dataclass(slots=True)
class ThemeRepository:
    themes: list[Theme]
    _index: dict[str, Theme] = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self._index = {theme.slug: theme for theme in self.themes}
        self._index.update({theme.name.lower(): theme for theme in self.themes})
        self._index.update({theme.display_name.lower(): theme for theme in self.themes})

    def get(self, query: str) -> Theme | None:
        key = query.lower()
        return self._index.get(key)

    def __iter__(self) -> Iterator[Theme]:
        return iter(self.themes)


def _coerce_slug(entry: Mapping[str, Any]) -> str:
    if "slug" in entry:
        return str(entry["slug"]).lower()
    name = str(entry.get("name", "")).strip()
    return name.lower().replace(" ", "-")


def load_theme_metadata(path: Path) -> ThemeRepository:
    if not path.exists():
        return ThemeRepository([])

    data = json.loads(path.read_text())

    if isinstance(data, Mapping) and "themes" in data:
        items = data["themes"]
    elif isinstance(data, Mapping):
        items = data.values()
    else:
        items = data

    result: list[Theme] = []
    for entry in items:
        if not isinstance(entry, Mapping):
            continue
        name = str(entry.get("displayName") or entry.get("name") or "").strip()
        raw_name = str(entry.get("name") or name)
        if not name:
            continue
        slug = _coerce_slug(entry)
        wallpapers = []
        single = entry.get("wallpaper")
        if isinstance(single, str):
            wallpapers.append(Path(single).expanduser())
        for wp in entry.get("wallpapers", []) or []:
            try:
                wallpapers.append(Path(wp).expanduser())
            except TypeError:
                continue
        result.append(
            Theme(
                name=raw_name,
                slug=slug,
                display_name=name,
                wallpapers=wallpapers,
                raw=entry,
                kind=entry.get("kind"),
            )
        )
    ordered = sorted(result, key=lambda t: t.display_name.lower())
    return ThemeRepository(ordered)
