#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

ASEPRITE = os.environ.get('ASEPRITE', 'aseprite')
TILED = os.environ.get('TILED', 'tiled')

BASE_DIRECTORY = os.path.join(os.curdir, 'assets')

ASEPRITE_ARGS = ['--sheet-pack', '--shape-padding', '1', '--trim',
                 '--merge-duplicates', '--format', 'json-array', '--list-tags']

artifacts: list[str] = []
dry_run: bool = False


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, *kwargs)


def needs_update(src_path: str, dst_path: str) -> bool:
    # first, determine if out_path is out of date
    has_mtime = False
    if os.path.exists(dst_path):
        has_mtime = True
        out_mtime = os.path.getmtime(dst_path)
    
    if has_mtime:
        return os.path.getmtime(src_path) > out_mtime
    else:
        return True


def copy_file(src_path: str, dst_path: str) -> bool:
    src_path = os.path.normpath(src_path)
    dst_path = os.path.normpath(dst_path)

    artifacts.append(dst_path)
    if not dry_run and needs_update(src_path, dst_path):
        eprint(f"[CPY] {src_path} => {dst_path}")
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.copy(src_path, dst_path)
    
    return True


def process_tmx(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.splitext(dst_path)[0] + '.lua'
    
    artifacts.append(dst_path)
    if dry_run or not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    eprint(f'[TMX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-map', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True


def process_tsx(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.splitext(dst_path)[0] + '.lua'

    artifacts.append(dst_path)
    if dry_run or not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    eprint(f'[TSX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-tileset', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True


def process_ase(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    dst_json_path = os.path.splitext(dst_path)[0] + '.json'
    dst_png_path = os.path.splitext(dst_path)[0] + '.png'

    artifacts.append(dst_json_path)
    artifacts.append(dst_png_path)
    if dry_run or not needs_update(src_path, dst_json_path): return True

    src_path = os.path.normpath(src_path)
    dst_json_path = os.path.normpath(dst_json_path)
    dst_png_path = os.path.normpath(dst_png_path)

    eprint(f'[ASE] {src_path} => {dst_json_path}')
    os.makedirs(os.path.dirname(dst_json_path), exist_ok=True)
    ase = subprocess.run([ASEPRITE,
                          '-b', src_path,
                          '--data', dst_json_path,
                          '--sheet', dst_png_path] + ASEPRITE_ARGS)
    if ase.returncode != 0:
        return False
    
    return True


def scan_directory(dirpath: str) -> bool:
    succ = True
    src_dir = os.path.normpath(os.path.join('assets', dirpath))
    dst_dir = os.path.normpath(os.path.join('app', 'res', dirpath))

    if not os.path.exists(src_dir): return succ
    for basename in sorted(os.listdir(src_dir)):
        if basename and basename[0] == '.':
            continue
            
        path = os.path.join(src_dir, basename)

        if os.path.isdir(path):
            if basename != 'noexport':
                if not scan_directory(os.path.join(dirpath, basename)):
                    succ = False
        else:
            dst_path = os.path.join(dst_dir, basename)
            (_, fileext) = os.path.splitext(basename)

            match fileext:
                case '.ase' | '.aseprite':
                    if not process_ase(path, dst_path):
                        succ = False
                case '.tmx':
                    if not process_tmx(path, dst_path):
                        succ = False
                case '.tsx':
                    if not process_tsx(path, dst_path):
                        succ = False
                case _:
                    if not copy_file(path, dst_path):
                        succ = False

    return succ


def update_gitignore() -> bool:
    gitignore_path = 'app/res/.gitignore'
    
    # collect list of artifact paths relative to app/res
    new_files: list[str] = []
    for artifact in artifacts:
        rel_path = os.path.normpath(os.path.relpath(artifact, 'app/res'))
        new_files.append(rel_path.replace('\\', '/'))

    # parse pre-existing gitignore
    if os.path.exists(gitignore_path):
        with open(gitignore_path, 'r') as f:
            while True:
                line = f.readline()
                if not line: # EOF
                    break
                
                line = line.strip()

                # skip if line is empty
                if not line:
                    continue
                # skip if line is a comment
                if line[0] == '#':
                    continue
                # error on negation or wildcards
                if line[0] == '!' or '*' in line:
                    eprint("error: .gitignore contains a negation or wildcard", file=sys.stderr)
                    sys.exit(1)
                
                if line == '.gitignore':
                    continue

                # if a file will no longer exist in the .gitignore, it will be
                # deleted.
                if not line in new_files:
                    eprint(f"Prune {line}", file=sys.stderr)
                    os.remove(os.path.join('app/res', line))

    # create .gitignore for artifacts
    with open(gitignore_path, 'w') as f:
        f.write("# this is autogenerated. do not edit!\n")
        f.write(".gitignore\n")
        for path in new_files:
            f.write(path)
            f.write('\n')
    
    return True


def main():
    global dry_run
    
    for i in range(1, len(sys.argv)):
        if sys.argv[i] == '--dry-run':
            dry_run = True
    
    s = False
    while True:
        if not scan_directory('.'):
            break

        s = True
        break

    if dry_run:
        for artifact in artifacts:
            rel_path = os.path.normpath(os.path.relpath(artifact, 'app/res'))
            sys.stdout.write(rel_path.replace('\\', '/'))
            sys.stdout.write('\n')
    else:
        if not update_gitignore():
            s = False

    if not s: sys.exit(1)


if __name__ == '__main__': main()