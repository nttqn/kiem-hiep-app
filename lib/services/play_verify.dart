import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The app's Google Play licence key (Play Console → Kiếm Hiệp →
/// Monetisation setup → Licensing): base64 X.509 SubjectPublicKeyInfo of
/// the RSA key Google signs every purchase with. Public by design.
const playLicenseKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu/ib7eW7P9Z10q+J3cVs+ZQpi2DuFPsEBxBSIS4xx5Fw1r1U0SzWo+EboJhOCs7IK+Wcwbp3vDVkxYGBKkyCkWOyEpjj7tveMf5F05M7wHX9GmArvytqmJzDJxQ3OK5us1W5s9QbVq56wWbs1a4wBpRKd62y1r8jpS7MIKRZeG9Kv4hmmazp6qMwTehjQ/dfK14ucVfRlFo8HmqVDBYcTqjySlYcJep25H0OW+xUhRR2LB4iVPc6CsEMpItbxNAyuvJxogew+lP6PZ6VpMvMhlqxCL44n0iz7bcv+rlfodoHyrAmeGjLuRm3VBSc/Iyn/UWJYhneBiCXtCoyKZeFewIDAQAB';

/// Checks a Google Play purchase signature on the phone (1.16.1).
///
/// Play signs each purchase's `originalJson` with SHA1withRSA. A faked
/// purchase (Lucky Patcher and the like) carries a missing or bogus
/// signature, so it fails here. Pure Dart: [BigInt] modPow + SHA-1.
class PlayVerifier {
  PlayVerifier._(this._n, this._e, this._k);

  final BigInt _n, _e;

  /// Modulus length in bytes.
  final int _k;

  /// Null when [base64Key] is empty or not an RSA public key.
  static PlayVerifier? fromBase64(String base64Key) {
    if (base64Key.trim().isEmpty) return null;
    try {
      final der = base64.decode(base64Key.replaceAll(RegExp(r'\s'), ''));
      final r = _Der(der);
      // SubjectPublicKeyInfo ::= SEQUENCE { AlgorithmIdentifier, BIT STRING }
      final spki = _Der(r.read(0x30));
      spki.read(0x30); // rsaEncryption OID (+ NULL); not checked
      final bits = spki.read(0x03);
      if (bits.isEmpty || bits[0] != 0) return null;
      // RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
      final rsa = _Der(_Der(bits.sublist(1)).read(0x30));
      final n = _toBig(rsa.read(0x02));
      final e = _toBig(rsa.read(0x02));
      if (n.bitLength < 1024 || e <= BigInt.one) return null;
      return PlayVerifier._(n, e, (n.bitLength + 7) ~/ 8);
    } catch (_) {
      return null;
    }
  }

  /// DigestInfo prefix for SHA-1 (RFC 8017 §9.2 note 1).
  static const _sha1Prefix = [0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14];

  /// True only when [signatureB64] is Play's RSASSA-PKCS1-v1_5 SHA-1
  /// signature of exactly [signedData].
  bool verify(String signedData, String signatureB64) {
    try {
      final sig = base64.decode(signatureB64.trim());
      if (sig.length != _k) return false;
      final s = _toBig(sig);
      if (s >= _n) return false;
      final m = s.modPow(_e, _n);
      final em = _toBytes(m, _k);
      final hash = sha1.convert(utf8.encode(signedData)).bytes;
      final tLen = _sha1Prefix.length + hash.length;
      // EM = 0x00 0x01 FF…FF 0x00 || DigestInfo, at least 8 bytes of FF.
      if (_k < tLen + 11) return false;
      final psEnd = _k - tLen - 1;
      if (em[0] != 0 || em[1] != 1 || em[psEnd] != 0) return false;
      for (var i = 2; i < psEnd; i++) {
        if (em[i] != 0xff) return false;
      }
      final t = [..._sha1Prefix, ...hash];
      for (var i = 0; i < tLen; i++) {
        if (em[psEnd + 1 + i] != t[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static BigInt _toBig(List<int> bytes) {
    var r = BigInt.zero;
    for (final b in bytes) {
      r = (r << 8) | BigInt.from(b);
    }
    return r;
  }

  static Uint8List _toBytes(BigInt v, int len) {
    final out = Uint8List(len);
    final mask = BigInt.from(0xff);
    for (var i = len - 1; i >= 0; i--) {
      out[i] = (v & mask).toInt();
      v = v >> 8;
    }
    return out;
  }
}

/// Just enough DER to walk a public key: tag, length, content.
class _Der {
  _Der(this._b);
  final List<int> _b;
  int _i = 0;

  List<int> read(int tag) {
    if (_b[_i++] != tag) throw const FormatException('der tag');
    var len = _b[_i++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      if (n == 0 || n > 4) throw const FormatException('der length');
      len = 0;
      for (var j = 0; j < n; j++) {
        len = (len << 8) | _b[_i++];
      }
    }
    if (_i + len > _b.length) throw const FormatException('der overrun');
    final out = _b.sublist(_i, _i + len);
    _i += len;
    return out;
  }
}
