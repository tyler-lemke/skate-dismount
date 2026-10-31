#!/usr/bin/env python3
"""Capture real Godot demo runs, then encode README GIFs. Requires a GUI session.

This helper never edits project source. --demo is the game's built-in automated
player: it charges, pushes, bails on real contact, and spends one crashbreaker.
A new output directory isolates records and movie/log artifacts for each run.
Rendering has NOT been verified in the originating sandbox; use a normal local
terminal and visually review the output before publishing it.
"""
from __future__ import annotations
import argparse
import shlex
import shutil
import subprocess
from pathlib import Path


def execute(command: list[str], log: Path, timeout: int, dry_run: bool) -> None:
    print(shlex.join(command), flush=True)
    if dry_run:
        return
    with log.open('w') as stream:
        try:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=timeout, check=False)
        except subprocess.TimeoutExpired as error:
            raise SystemExit(f'Timed out after {timeout}s; inspect {log}') from error
    if result.returncode:
        raise SystemExit(f'Command exited {result.returncode}; inspect {log}')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True,
                        help='New destination directory; refuses an existing path')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--seconds', type=int, default=20)
    parser.add_argument('--timeout', type=int, default=300, help='Per-command deadline')
    parser.add_argument('--skip-import', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    project, output = args.project.resolve(), args.output.resolve()
    if not (project / 'project.godot').is_file():
        parser.error('--project must contain project.godot')
    if output.exists():
        parser.error('--output already exists; use a new directory')
    if not 5 <= args.seconds <= 60 or args.timeout < 10:
        parser.error('--seconds must be 5..60 and --timeout must be at least 10')
    engine = shutil.which(args.godot)
    ffmpeg = shutil.which(args.ffmpeg)
    if engine is None or ffmpeg is None:
        parser.error('Godot and ffmpeg must exist; pass explicit paths if needed')
    if not args.dry_run:
        output.mkdir(parents=True, exist_ok=False)
    if not args.skip_import:
        execute([engine, '--headless', '--editor', '--import', '--path', str(project),
                 '--log-file', str(output / 'import-engine.log')],
                output / 'import-output.log', args.timeout, args.dry_run)
    fps = 30
    for index, route in enumerate(('civic', 'market', 'port')):
        movie = output / f'{route}.avi'
        execute([engine, '--path', str(project), '--resolution', '1280x800',
                 '--fixed-fps', str(fps), '--disable-vsync',
                 '--write-movie', str(movie), '--quit-after', str(fps * args.seconds),
                 '--log-file', str(output / f'{route}-engine.log'), '--',
                 '--demo', f'--level={index}',
                 f'--records-path={output / (route + "-records.json")}'],
                output / f'{route}-output.log', args.timeout, args.dry_run)
        if not args.dry_run and (not movie.is_file() or movie.stat().st_size < 1024):
            raise SystemExit(f'No usable movie for {route}; inspect its logs')
        execute([ffmpeg, '-nostdin', '-v', 'error', '-n', '-i', str(movie),
                 '-filter_complex',
                 '[0:v]fps=12,scale=800:-1:flags=lanczos,split[a][b];'
                 '[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a',
                 '-loop', '0', str(output / f'{route}.gif')],
                output / f'{route}-encode.log', args.timeout, args.dry_run)
    print('Review all three GIFs for actual gameplay and readable framing before publishing.')


if __name__ == '__main__':
    main()
