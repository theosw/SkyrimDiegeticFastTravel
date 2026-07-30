from __future__ import annotations

from dataclasses import dataclass
import re

_FORM_RE = re.compile(r"^(?P<plugin>[^|]+)\|0x(?P<form>[0-9a-fA-F]{1,8})$")


@dataclass(frozen=True)
class FormRef:
    plugin: str
    form_id: int

    @classmethod
    def parse(cls, value: str) -> "FormRef":
        match = _FORM_RE.fullmatch(value.strip())
        if not match:
            raise ValueError(f"invalid form reference: {value!r}")
        return cls(match.group("plugin"), int(match.group("form"), 16))

    def canonical(self) -> str:
        return f"{self.plugin}|0x{self.form_id:06X}"

    def jcontainers(self) -> str:
        return f"__formData|{self.plugin}|0x{self.form_id:06X}"


def canonical_form(value: str | None) -> str | None:
    if value is None:
        return None
    return FormRef.parse(value).canonical()


def jcontainers_form(value: str | None) -> str | None:
    if value is None:
        return None
    return FormRef.parse(value).jcontainers()

