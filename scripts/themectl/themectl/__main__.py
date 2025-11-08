"""Allow `python -m themectl`."""

from .cli import app


def run() -> None:  # pragma: no cover
    app()


if __name__ == "__main__":  # pragma: no cover
    run()
