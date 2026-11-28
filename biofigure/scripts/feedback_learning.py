#!/usr/bin/env python3
"""Local feedback queue and advisory lessons; never render or alter CP gates."""
from __future__ import annotations
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STORE = ROOT / 'atlas' / 'feedback-learning'
SCOPES = {'task', 'template', 'project', 'global'}


def _now():
    return datetime.now(timezone.utc).isoformat()


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _text(value, name):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(name + ' must be a non-empty string')
    return value


def _id(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-f0-9]{32}', value):
        raise ValueError('invalid feedback id')
    return value


def _store(store):
    return Path(store) if store is not None else DEFAULT_STORE


def _read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def _write(path, value, *, exclusive=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix='.', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as output:
            json.dump(value, output, ensure_ascii=False, indent=2)
            output.write('\n')
        if exclusive:
            os.link(temp, path)
        else:
            os.replace(temp, path)
    finally:
        Path(temp).unlink(missing_ok=True)


@contextmanager
def _lock(store):
    store.mkdir(parents=True, exist_ok=True)
    with (store / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def _validate_packet(packet, *, verify_evidence=True):
    if not isinstance(packet, dict):
        raise ValueError('packet must be an object')
    for key in ('user_instruction', 'task_id', 'correction'):
        _text(packet.get(key), key)
    scope = packet.get('scope')
    if scope not in SCOPES:
        raise ValueError('scope must be task, template, project or global')
    if scope != 'global':
        _text(packet.get('scope_key'), 'scope_key')
    if scope == 'task' and packet['scope_key'] != packet['task_id']:
        raise ValueError('task scope_key must equal task_id')
    if scope == 'project' and not Path(packet['scope_key']).is_absolute():
        raise ValueError('project scope_key must be an absolute project path')
    if scope == 'global':
        intent = _text(packet.get('long_term_intent'), 'long_term_intent')
        if intent not in packet['user_instruction']:
            raise ValueError('global long_term_intent must quote the user instruction')
    if 'figure_family' in packet:
        family = _text(packet['figure_family'], 'figure_family')
        if not re.fullmatch(r'[a-z][a-z0-9-]*', family):
            raise ValueError('figure_family must use the normalized BioFigure family identifier')
    evidence = packet.get('evidence', [])
    if not isinstance(evidence, list):
        raise ValueError('evidence must be a list')
    for item in evidence:
        if not isinstance(item, dict):
            raise ValueError('evidence entry must be an object')
        path = Path(_text(item.get('path'), 'evidence.path'))
        _text(item.get('role'), 'evidence.role')
        if not path.is_absolute() or not path.is_file():
            raise ValueError('evidence must bind an existing absolute file path')
        if not re.fullmatch(r'[a-f0-9]{64}', str(item.get('sha256', ''))):
            raise ValueError('evidence SHA-256 is required')
        if verify_evidence and item.get('sha256') != _sha(path):
            raise ValueError('evidence SHA-256 mismatch: ' + str(path))


def enqueue(packet, store=None, *, identifier=None):
    """Record one correction. Pending packets never affect future figures."""
    _validate_packet(packet, verify_evidence=False)
    packet = json.loads(json.dumps(packet))
    record = dict(schema_version=1, id=_id(identifier) if identifier else uuid.uuid4().hex, created_at=_now(),
                  packet=packet, packet_sha256=_digest(packet))
    path = _store(store) / 'packets' / (record['id'] + '.json')
    try:
        _write(path, record, exclusive=True)
    except FileExistsError:
        existing = _read(path)
        if not identifier or existing['packet_sha256'] != record['packet_sha256']:
            raise
        return existing
    return record


def _packet(store, identifier, *, verify_evidence=True):
    record = _read(store / 'packets' / (_id(identifier) + '.json'))
    if record.get('id') != identifier or record.get('packet_sha256') != _digest(record['packet']):
        raise ValueError('feedback packet changed')
    _validate_packet(record['packet'], verify_evidence=verify_evidence)
    return record


def _validate_lesson(lesson, packet):
    if not isinstance(lesson, dict):
        raise ValueError('lesson must be an object')
    if set(lesson) != {'summary', 'applicability', 'validation', 'user_acceptance', 'acceptance_evidence'}:
        raise ValueError('lesson requires only summary, applicability, validation, user_acceptance and acceptance_evidence')
    for key in ('summary', 'applicability', 'validation'):
        _text(lesson.get(key), key)
        if '```' in lesson[key] or '\x00' in lesson[key]:
            raise ValueError('lessons contain plain text advice only, not executable code blocks')
    if type(lesson['user_acceptance']) is not bool:
        raise ValueError('user_acceptance must be a boolean')
    evidence = lesson['acceptance_evidence']
    if not isinstance(evidence, dict) or set(evidence) != {'quote', 'source'}:
        raise ValueError('acceptance_evidence requires user quote and conversation/message source')
    _text(evidence.get('quote'), 'acceptance_evidence.quote')
    _text(evidence.get('source'), 'acceptance_evidence.source')
    if not lesson['user_acceptance'] and packet['scope'] == 'global' and evidence['quote'] != packet['long_term_intent']:
        raise ValueError('global acceptance evidence must quote the explicit long-term intent')
    if not lesson['user_acceptance'] and packet['scope'] != 'global':
        raise ValueError('pending: a successful render is not user acceptance')


def publish(identifier, lesson, store=None):
    """Activate reviewed advice only; never overwrite an existing lesson."""
    store = _store(store)
    with _lock(store):
        packet = _packet(store, identifier)
        if packet['packet'].get('signal') in ('star', 'unstar'):
            raise ValueError('A gallery star is a reference preference, not a publishable design lesson')
        _validate_lesson(lesson, packet['packet'])
        path = store / 'lessons' / (identifier + '.json')
        if path.exists():
            raise ValueError('lesson already published; enqueue a new correction for a revision')
        record = dict(schema_version=1, id=identifier, status='active', published_at=_now(),
                      packet_sha256=packet['packet_sha256'], lesson=json.loads(json.dumps(lesson)))
        _write(path, record, exclusive=True)
        return record


def retire(identifier, reason, store=None):
    store = _store(store)
    _text(reason, 'reason')
    with _lock(store):
        path = store / 'lessons' / (_id(identifier) + '.json')
        record = _read(path)
        if record.get('status') != 'active':
            raise ValueError('only active lessons can be retired')
        record.update(status='retired', retired_at=_now(), retirement_reason=reason)
        _write(path, record)
        return record


def list_records(store=None):
    store = _store(store)
    rows = []
    for path in sorted((store / 'packets').glob('*.json')):
        packet = _read(path)
        lesson_path = store / 'lessons' / (packet['id'] + '.json')
        rows.append(dict(id=packet['id'], scope=packet['packet']['scope'],
                         scope_key=packet['packet'].get('scope_key'),
                         status=_read(lesson_path)['status'] if lesson_path.exists() else 'pending'))
    return rows


def _matches(packet, request):
    if packet.get('figure_family') and packet['figure_family'] != request.get('figure_family'):
        return False
    scope, key = packet['scope'], packet.get('scope_key')
    if scope == 'global':
        return True
    if scope == 'task':
        return key == request.get('task_id')
    if scope == 'template':
        return key in {request.get(name) for name in ('case_id', 'learned_method_id', 'reusable_case_id',
                                                      'pattern_id', 'selected_method_case_id')
                       if isinstance(request.get(name), str)}
    for name in ('project', 'project_root', 'project_path'):
        path = request.get(name)
        if isinstance(path, str) and Path(path).is_absolute() and Path(path).resolve() == Path(key).resolve():
            return True
    return False


def retrieve(request, store=None):
    """Read at most five applicable active lessons. Corrupt advice is skipped."""
    store = _store(store)
    if not isinstance(request, dict):
        raise ValueError('request must be an object')
    results = []
    for path in sorted((store / 'lessons').glob('*.json'), reverse=True):
        try:
            record = _read(path)
            if record.get('status') != 'active':
                continue
            packet = _packet(store, record['id'], verify_evidence=False)
            if packet['packet_sha256'] != record['packet_sha256']:
                continue
            _validate_lesson(record['lesson'], packet['packet'])
            if not _matches(packet['packet'], request):
                continue
            results.append(dict(id=record['id'], scope=packet['packet']['scope'],
                                scope_key=packet['packet'].get('scope_key'), advisory=True,
                                figure_family=packet['packet'].get('figure_family'),
                                evidence=packet['packet'].get('evidence', []),
                                published_at=record['published_at'], **record['lesson']))
        except (OSError, ValueError, KeyError, TypeError):
            continue
    priority = {'task': 0, 'template': 1, 'project': 2, 'global': 3}
    results.sort(key=lambda item: (item['published_at'], item['id']), reverse=True)
    results.sort(key=lambda item: (priority[item['scope']], not bool(item['figure_family'])))
    return results[:5]


def consume_gallery(profile_db, store=None):
    """Advance a per-profile cursor through distinct, unscored gallery signals."""
    from personal_style import gallery_changes
    store = _store(store)
    with _lock(store):
        initial = gallery_changes(profile_db, 0)
        profile = initial['profile']
        if profile is None:
            return dict(profile=None, processed=0, cursor=0, more=False, packets=[])
        cursor_file = store / 'gallery-cursors' / (profile + '.json')
        cursor = _read(cursor_file)['cursor'] if cursor_file.exists() else 0
        page = gallery_changes(profile_db, cursor)
        packets = []
        for event in page['events']:
            identifier = uuid.uuid5(uuid.NAMESPACE_URL, f"biofigure:gallery:{profile}:{event['seq']}").hex
            task_id = 'gallery-' + identifier
            signal = event['kind']
            instruction = event['instruction'] or (
                'Explicitly starred this gallery reference' if signal == 'star' else 'Removed this gallery star'
            )
            packet = dict(user_instruction=instruction, task_id=task_id, scope='task', scope_key=task_id,
                          correction=instruction, signal=signal, gallery_event=event)
            families = {ref['family'] for ref in event['references'] if ref['family']}
            if len(families) == 1:
                family = next(iter(families))
                if re.fullmatch(r'[a-z][a-z0-9-]*', family):
                    packet['figure_family'] = family
            packets.append(enqueue(packet, store, identifier=identifier)['id'])
        if packets:
            _write(cursor_file, {'cursor': page['next']})
        return dict(profile=profile, processed=len(packets), cursor=page['next'], more=page['more'], packets=packets)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('enqueue', 'list', 'publish', 'retrieve', 'retire', 'consume-gallery'):
        item = sub.add_parser(name)
        item.add_argument('--store', type=Path)
        if name == 'consume-gallery':
            item.add_argument('--gallery', type=Path)
        if name == 'enqueue':
            item.add_argument('--packet', type=Path, required=True)
        if name in ('publish', 'retire'):
            item.add_argument('--id', required=True)
        if name == 'publish':
            item.add_argument('--lesson', type=Path, required=True)
        if name == 'retire':
            item.add_argument('--reason', required=True)
        if name == 'retrieve':
            item.add_argument('--case-id')
            item.add_argument('--project')
            item.add_argument('--family')
    args = parser.parse_args()
    try:
        if args.command == 'enqueue':
            result = enqueue(_read(args.packet), args.store)
        elif args.command == 'publish':
            result = publish(args.id, _read(args.lesson), args.store)
        elif args.command == 'retire':
            result = retire(args.id, args.reason, args.store)
        elif args.command == 'list':
            result = list_records(args.store)
        elif args.command == 'consume-gallery':
            from personal_style import default_path
            result = consume_gallery(args.gallery or default_path(), args.store)
        else:
            result = retrieve(dict(case_id=args.case_id, project=args.project, figure_family=args.family), args.store)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, str(exc) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
