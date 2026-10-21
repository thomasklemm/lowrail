#!/usr/bin/env python3
"""Offline HTTP/1.1 keepalive/GC attribution; never changes oha's primary price.

Usage: python3 bench/rps_attribution.py RECEIPT_DIRECTORY > attribution.json
IPv4 loopback Ethernet pcap, no pipelining. Snaplen may truncate content:
wire spans end at the last observed response payload, not a client timestamp.
"""
import bisect
import collections
import csv
import json
import struct
import sys
from pathlib import Path


def quantile(values, p):
    if not values:
        return None
    values = sorted(values)
    position = (len(values) - 1) * p
    low = int(position)
    return values[low] + (values[min(low + 1, len(values) - 1)] - values[low]) * (position - low)


def wire_requests(path, server_port):
    requests, active, sequences = collections.defaultdict(list), {}, {}
    audit = collections.Counter()
    with Path(path).open('rb') as file:
        header = file.read(24)
        endian, scale = {b'\x4d\x3c\xb2\xa1': ('<', 1), b'\xa1\xb2\x3c\x4d': ('>', 1),
                         b'\xd4\xc3\xb2\xa1': ('<', 1000), b'\xa1\xb2\xc3\xd4': ('>', 1000)}[header[:4]]
        assert struct.unpack(endian + 'I', header[20:24])[0] == 1, 'Ethernet required'
        while record := file.read(16):
            assert len(record) == 16, 'truncated pcap record'
            seconds, fraction, captured, original = struct.unpack(endian + 'IIII', record)
            packet = file.read(captured)
            assert len(packet) == captured, 'truncated pcap packet'
            audit['packets'] += 1
            if packet[12:14] != b'\x08\x00' or packet[23] != 6:
                continue
            ip = 14
            assert packet[ip] >> 4 == 4
            assert struct.unpack('!H', packet[ip + 6:ip + 8])[0] & 0x3fff == 0, 'fragmented IP'
            tcp = ip + (packet[ip] & 15) * 4
            source, destination, sequence = struct.unpack('!HHI', packet[tcp:tcp + 8])
            assert server_port in (source, destination)
            client = destination == server_port
            port = source if client else destination
            key = (port, client)
            flags = packet[tcp + 13]
            if client and flags & 2:  # A new connection can reuse a port/sequence range.
                sequences.pop((port, True), None)
                sequences.pop((port, False), None)
                active.pop(port, None)
            payload_offset = tcp + (packet[tcp + 12] >> 4) * 4
            length = struct.unpack('!H', packet[ip + 2:ip + 4])[0] - (payload_offset - ip)
            if length <= 0:
                continue
            previous = sequences.get(key)
            # Relative TCP sequence arithmetic also works across the 32-bit wrap.
            advance = ((sequence - previous + 2**31) % 2**32 - 2**31) if previous is not None else 0
            if advance < 0:
                audit['retransmitted_or_out_of_order_packets'] += 1
                if advance + length <= 0:
                    continue
            if advance > 0:
                audit['sequence_gaps'] += 1
            sequences[key] = (sequence + length) % 2**32
            timestamp = seconds * 1_000_000_000 + fraction * scale
            prefix = packet[payload_offset:]
            if client:
                if prefix.startswith(b'GET '):
                    row = {'port': port, 'wire_start': timestamp, 'wire_end': None, 'http_response': False}
                    requests[port].append(row)
                    active[port] = row
                else:
                    audit['non_get_client_payloads'] += 1
            elif port in active:
                row = active[port]
                row['wire_end'] = timestamp
                row['http_response'] |= prefix.startswith(b'HTTP/1.1 200 ')
            else:
                audit['orphan_response_payloads'] += 1
    return requests, dict(audit)


def native_records(directory):
    requests, pauses, metadata = collections.defaultdict(list), {}, []
    for path in sorted(Path(directory).glob('gc-tags-*.csv')):
        with path.open() as file:
            info = {key: int(value) for key, value in (item.split('=') for item in file.readline()[2:].split())}
            metadata.append(info)
            pid = info['pid']
            pauses[pid] = []
            for row in csv.reader(file):
                values = list(map(int, row[1:]))
                if row[0] == 'R':
                    index, port, start, end, mono_start, mono_end, before, after = values
                    requests[port].append({'pid': pid, 'start': start, 'end': end,
                                           'mono_ns': mono_end - mono_start, 'gc_count_delta': after - before})
                else:
                    assert row[0] == 'G'
                    pauses[pid].append(values)
        pauses[pid].sort()
    for records in requests.values():
        records.sort(key=lambda row: row['start'])
    return requests, pauses, metadata


def overlap(intervals, starts, begin, end):
    if end <= begin:
        return 0
    index = max(0, bisect.bisect_left(starts, begin) - 1)
    total = 0
    while index < len(intervals) and intervals[index][0] < end:
        left, right = intervals[index]
        total += max(0, min(end, right) - max(begin, left))
        index += 1
    return total


def analyze(directory, port):
    wire, packet_audit = wire_requests(Path(directory) / 'timed.json.pcap', port)
    native, pauses, metadata = native_records(directory)
    starts = {pid: [left for left, right in intervals] for pid, intervals in pauses.items()}
    matches, problems = [], collections.Counter()
    for client_port in sorted(wire.keys() | native.keys()):
        left, right = wire.get(client_port, []), native.get(client_port, [])
        if len(left) != len(right):
            # Never shift ordinals or select the alignment giving a desired result.
            problems['count_mismatch_ports'] += 1
            problems['unmatched_wire'] += len(left)
            problems['unmatched_native'] += len(right)
            continue
        for packet, rack in zip(left, right):
            if not packet['http_response'] or packet['wire_end'] is None or rack['end'] == 0:
                problems['unfinished_response'] += 1
                continue
            a, b, c, d = packet['wire_start'], rack['start'], rack['end'], packet['wire_end']
            if not a <= b <= c <= d:
                problems['clock_or_order_mismatch'] += 1
                continue
            delta = abs((c - b) - rack['mono_ns'])
            gc = [overlap(pauses[rack['pid']], starts[rack['pid']], x, y) for x, y in ((a, b), (b, c), (c, d))]
            matches.append({'wire_ms': (d - a) / 1e6, 'rack_ms': (c - b) / 1e6,
                            'remainder_ms': ((b - a) + (d - c)) / 1e6,
                            'gc_before_ms': gc[0] / 1e6, 'gc_inside_ms': gc[1] / 1e6,
                            'gc_after_ms': gc[2] / 1e6, 'clock_delta_ns': delta,
                            'gc_count_delta': rack['gc_count_delta']})
    threshold = quantile([row['wire_ms'] for row in matches], .99)
    tail = [row for row in matches if row['wire_ms'] >= threshold] if threshold is not None else []

    def describe(rows):
        result = {'requests': len(rows)}
        for key in ('wire_ms', 'rack_ms', 'remainder_ms', 'gc_before_ms', 'gc_inside_ms', 'gc_after_ms'):
            result[key] = {label: quantile([row[key] for row in rows], p)
                           for label, p in (('p50', .5), ('p90', .9), ('p99', .99))}
        result['gc_any_overlap'] = sum(any(row[f'gc_{where}_ms'] > 0 for where in ('before', 'inside', 'after')) for row in rows)
        result['gc_inside_overlap'] = sum(row['gc_inside_ms'] > 0 for row in rows)
        result['gc_before_overlap'] = sum(row['gc_before_ms'] > 0 for row in rows)
        result['gc_after_overlap'] = sum(row['gc_after_ms'] > 0 for row in rows)
        result['remainder_exceeds_half_wire'] = sum(row['remainder_ms'] > row['wire_ms'] / 2 for row in rows)
        return result

    return {'packet_audit': packet_audit, 'native_metadata': metadata, 'join_problems': dict(problems),
            'wire_requests': sum(map(len, wire.values())), 'native_requests': sum(map(len, native.values())),
            'clock_max_delta_ns': max((row['clock_delta_ns'] for row in matches), default=None),
            'all': describe(matches), 'wire_p99_tail': describe(tail),
            'gc_overlap': describe([row for row in matches if row['gc_inside_ms'] > 0]),
            'no_gc_overlap': describe([row for row in matches if row['gc_inside_ms'] == 0])}


if __name__ == '__main__':
    root = Path(sys.argv[1])
    config = json.loads((root / 'config.json').read_text())
    report = json.loads((root / 'result.json').read_text())
    result = []
    for row in report['rows']:
        result.append({'round': row['round'], 'arm': row['arm'],
                       **analyze(root / f"{row['round']}-{row['arm']}", config['port'])})
    print(json.dumps(result, indent=2))
