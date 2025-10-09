#!/usr/bin/env python3
"""Utility per creare un archivio ZIP del progetto iOS."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Crea un archivio ZIP del progetto iOS SwiftUI per facilitare la "
            "condivisione o il download." 
        )
    )
    parser.add_argument(
        "output",
        nargs="?",
        help=(
            "Percorso del file ZIP da generare. Se la cartella di destinazione "
            "esiste, il file verrà chiamato QuestionnaireApp.zip"
        ),
    )
    parser.add_argument(
        "--source",
        default="ios/QuestionnaireApp",
        help="Percorso della cartella del progetto iOS da esportare (default: ios/QuestionnaireApp)",
    )
    return parser.parse_args()


def create_zip(source: Path, destination: Path) -> None:
    if not source.exists():
        raise FileNotFoundError(f"La cartella sorgente {source} non esiste")
    if not source.is_dir():
        raise NotADirectoryError(f"La sorgente {source} deve essere una cartella")

    if destination.exists() and destination.is_dir():
        destination = destination / "QuestionnaireApp.zip"
    elif destination.suffix == "":
        destination = destination.with_suffix(".zip")

    destination.parent.mkdir(parents=True, exist_ok=True)

    base_arcname = source.name
    with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
        for path in source.rglob("*"):
            archive.write(path, Path(base_arcname) / path.relative_to(source))

    print(f"Archivio creato in {destination}")


def main() -> int:
    args = parse_args()
    output_path = Path(args.output) if args.output else Path.cwd() / "QuestionnaireApp.zip"
    try:
        create_zip(Path(args.source).resolve(), output_path.resolve())
    except Exception as exc:  # noqa: BLE001
        print(f"Errore durante la creazione dell'archivio: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
