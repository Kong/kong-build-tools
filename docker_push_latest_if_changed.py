#!/usr/bin/env python3.6
import argparse
import hashlib
import subprocess
from typing import NamedTuple
from typing import Optional
from typing import Sequence
from typing import Tuple
from urllib.parse import urlparse


class Image(NamedTuple):
    host: str
    name: str
    tag: str
    uri: str


class ImageKey(NamedTuple):
    commands_hash: str
    packages_hash: str


class ImageNotFoundError(ValueError):
    pass


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--source', required=True,
        help=(
            'Local image to be considered for pushing. '
            'For example `--source docker.example.com/img-name:2017.01.05`.'
        ),
    )
    parser.add_argument(
        '--target',
        help=(
            'Target remote image to push if the docker image is changed. '
            'If omitted, the image will be $repository:latest of the '
            '`--source` image.'
        ),
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help="Run command, but don't actually push or tag images.",
    )
    arguments = parser.parse_args(argv)

    source_image = _get_image(arguments.source)
    _validate_source(source_image)

    target_image = _get_sanitized_target(arguments.target, source_image)

    _docker_push_latest_if_changed(
        source_image.uri,
        target_image.uri,
        is_dry_run=arguments.dry_run,
    )
    return 0


def _get_image(uri: str) -> Image:
    parse_result = urlparse(f'fakescheme://{uri}')
    if not parse_result.path:
        raise ValueError(f'Image uri {uri} is malformed.')
    name_tag_partition = parse_result.path.strip('/').rpartition(':')
    if name_tag_partition[0]:
        name, _, tag = name_tag_partition
    else:
        name = name_tag_partition[2]
        tag = ''
    host = parse_result.netloc
    return Image(host=host, name=name, tag=tag, uri=uri)


def _validate_source(source_image: Image) -> None:
    if not source_image.tag:
        raise ValueError(
            f'The source image {source_image.uri} does not have a tag! '
            'You must include a tag in the source parameter.'
        )
    try:
        subprocess.check_output(('docker', 'inspect', source_image.uri))
    except subprocess.CalledProcessError as e:
        raise ImageNotFoundError(
            f'The image {source_image.uri} was not found'
        ) from e


def _get_sanitized_target(target: str, source_image: Image) -> Image:
    if target:
        target_image = _get_image(target)
    else:
        default_target = f'{source_image.host}/{source_image.name}:latest'
        print('Target was not given, so using default "{default_target}"')
        target_image = _get_image(f'{default_target}')
    if source_image == target_image:
        raise ValueError(
            f'The source ({source_image.uri}) and target {target_image.uri} '
            'repo:tags cannot be the same.'
        )
    return target_image


def _docker_push_latest_if_changed(
    source: str,
    target: str,
    *,
    is_dry_run: bool
) -> None:
    print('Pushing source image')
    _push_image(source, is_dry_run=is_dry_run)
    try:
        print('Pulling target image...')
        _pull_image(target)
    except ImageNotFoundError:
        print(
            f'Target image {target} was not found in the registry. '
            'Going to attempt to tag and push the target image anyway.'
        )
        _tag_image(source, target, is_dry_run=is_dry_run)
        _push_image(target, is_dry_run=is_dry_run)
    else:
        if _has_image_changed(source, target):
            print('Image has changed. Pushing a new image.')
            _tag_image(source, target, is_dry_run=is_dry_run)
            _push_image(target, is_dry_run=is_dry_run)
        else:
            print('Image has NOT changed. Keeping the old target.')


def _pull_image(image_uri: str) -> None:
    pull_command = ('docker', 'pull', image_uri)
    try:
        _check_output_and_print(pull_command)
    except subprocess.CalledProcessError as e:
        raise ImageNotFoundError(f'The image {image_uri} was not found') from e


def _tag_image(source: str, target: str, *, is_dry_run: bool) -> None:
    print(f'Tagging image {source} as {target}')
    tag_command: Tuple[str, ...] = ('docker', 'tag', source, target)
    if is_dry_run:
        tag_command = ('#',) + tag_command
        print('Image was not actually tagged since this is a dry run')
        print(' '.join(tag_command))
    else:
        _check_output_and_print(tag_command)


def _push_image(image_uri: str, *, is_dry_run: bool) -> None:
    print(f'Pushing image {image_uri} ...')
    push_command: Tuple[str, ...] = ('docker', 'push', image_uri)
    if is_dry_run:
        push_command = ('#',) + push_command
        print('Image was not actually pushed since this is a dry run')
        print(' '.join(push_command))
    else:
        _check_output_and_print(push_command)


def _has_image_changed(source: str, target: str) -> bool:
    source_key = _get_image_key(source)
    target_key = _get_image_key(target)
    print(f'Source key: {source_key}')
    print(f'Target key: {target_key}')
    return source_key != target_key


def _get_image_key(image_uri: str) -> ImageKey:
    return ImageKey(
        commands_hash=_get_commands_hash(image_uri),
        packages_hash=_get_packages_hash(image_uri),
    )


def _get_commands_hash(image_uri: str) -> str:
    image_commands = _check_output_and_print((
        'docker',
        'history',
        '--no-trunc',
        '--format',
        '{{.CreatedBy}}',
        image_uri,
    ))
    print(f'Docker commands for {image_uri}:\n{image_commands}')
    return _get_digest(image_commands.encode())


def _get_packages_hash(image_uri: str) -> str:
    packages = _run_in_image(image_uri, ('dpkg', '-l'))
    print(f'Packages for {image_uri}:\n{packages}')
    return _get_digest(packages.encode())


def _get_digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def _run_in_image(image_uri: str, command: Tuple[str, ...]) -> str:
    run_command = (
        'docker',
        'run',
        '--rm',
        '--net=none',
        '--user=nobody',
        image_uri,
        *command,
    )
    return _check_output_and_print(run_command)


def _check_output_and_print(command: Tuple[str, ...]) -> str:
    print(' '.join(command))
    output = subprocess.check_output(command, encoding='utf-8')
    return output


if __name__ == '__main__':
    exit(main())
