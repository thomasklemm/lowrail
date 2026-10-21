import struct
import tempfile
import unittest
from pathlib import Path

from rps_attribution import analyze


class AttributionTest(unittest.TestCase):
    def test_keepalive_retransmission_and_gc_before_inside_after_rack(self):
        # Explicit milliseconds: first request 10..30, Rack 15..25;
        # second 40..100, Rack 70..80. Its tail is mostly outside Rack.
        packets = []

        def packet(ms, client, sequence, payload):
            source, destination = (40001, 25371) if client else (25371, 40001)
            tcp = struct.pack('!HHI', source, destination, sequence % 2**32) + bytes(4) + b'\x50\x18' + bytes(6)
            ip = b'\x45\x00' + struct.pack('!H', 20 + len(tcp) + len(payload)) + bytes(5) + b'\x06' + bytes(10)
            frame = bytes(12) + b'\x08\x00' + ip + tcp + payload
            packets.append(struct.pack('<IIII', 1, ms * 1_000_000, len(frame), len(frame)) + frame)

        get, response = b'GET /articles/1 HTTP/1.1\r\n', b'HTTP/1.1 200 OK\r\n'
        response_sequence = 2**32 - 10  # Cross the sequence wrap between responses.
        packet(10, True, 100, get)
        packet(30, False, response_sequence, response)
        packet(32, False, response_sequence, response)  # Duplicate must not extend latency.
        packet(40, True, 100 + len(get), get)
        packet(100, False, response_sequence + len(response), response)
        packet(110, False, response_sequence + len(response), response)  # Nor this tail.
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / 'timed.json.pcap').write_bytes(
                struct.pack('<IHHIIII', 0xa1b23c4d, 2, 4, 0, 0, 128, 1) + b''.join(packets))
            (directory / 'gc-tags-42.csv').write_text(
                '# pid=42 request_dropped=0 pause_dropped=0 open_gc=0 request_cpu_ns=1 pause_cpu_ns=2\n'
                'R,0,40001,1015000000,1025000000,15000000,25000000,1,2\n'
                'R,1,40001,1070000000,1080000000,70000000,80000000,2,3\n'
                'G,1012000000,1017000000\n'  # 3ms before, 2ms inside first.
                'G,1075000000,1085000000\n')  # 5ms inside/after second.
            result = analyze(directory, 25371)
            self.assertEqual({}, result['join_problems'])
            self.assertEqual(2, result['all']['requests'])
            self.assertEqual(40, result['all']['wire_ms']['p50'])
            self.assertEqual(2, result['packet_audit']['retransmitted_or_out_of_order_packets'])
            tail = result['wire_p99_tail']
            self.assertEqual(60, tail['wire_ms']['p50'])
            self.assertEqual(10, tail['rack_ms']['p50'])
            self.assertEqual(50, tail['remainder_ms']['p50'])
            self.assertEqual(5, tail['gc_inside_ms']['p50'])
            self.assertEqual(5, tail['gc_after_ms']['p50'])
            self.assertEqual(1, result['all']['gc_before_overlap'])
            self.assertEqual(0, result['clock_max_delta_ns'])
            # A missing record must not silently shift ordinal alignment.
            path = directory / 'gc-tags-42.csv'
            path.write_text(path.read_text().replace(
                'R,0,40001,1015000000,1025000000,15000000,25000000,1,2\n', ''))
            result = analyze(directory, 25371)
            self.assertEqual(0, result['all']['requests'])
            self.assertEqual(2, result['join_problems']['unmatched_wire'])
            self.assertEqual(1, result['join_problems']['unmatched_native'])


if __name__ == '__main__':
    unittest.main()
