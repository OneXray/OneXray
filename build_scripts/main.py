#!/usr/bin/env python3

import os

import typer

from app.flutter import FlutterBuilder

app = typer.Typer()


def build_scripts_dir():
    file_dir = os.path.dirname(__file__)
    dir_path = os.path.abspath(file_dir)
    return dir_path


@app.command()
def build(
    project: str,
    system: str,
):
    builder = FlutterBuilder(project, system, build_scripts_dir())
    builder.build()


if __name__ == "__main__":
    app()
