import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/play_verify.dart';

// A throwaway 2048-bit key made with openssl for this test; the signature
// is `openssl dgst -sha1 -sign` of [data], exactly what Play does.
const pub = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmIm2ohJVz8NHbC/prDYOaJ68Quy2dpiul1Xk2nflbrildG+FDBIok4gkQ435hazDc0XfTDWCrJhXQHaRUTMpAo6+6ruO5BrvJTKSAlSPTaMWNa8fh3DgTEYOzXzE2UO27b6YKVUngWKBTxEvXVYLn+PrwY8arBouCMtRsatlDJx7OdCF1ZoNOj/goQUxThV5Vsk2TiSNAzA3ZJ7QAM/vmwK4MsqIZC5cCZLEfFP2N/iOJRXSvxVSPzKWzN8Y+529LHpzlGtt2NuZwSdtk51HAavX1b4RVjlWB592XZAnqgtWRkmfs6EkMFQrpmW1GnuTGBRUHPno0OxQqU5j32uGZwIDAQAB';
const sig = 'T2TnV0X9Y8tzgJfjWldADWePnu5WNN/1klZt7yZBiSQI7fM4x9JwLNb+rPhS7fy0C+hVhb0y2yM2Psl5XiAZPenacODZldqU+d+xTkvRahtqZwSNHFgjKncO57p81aONWLwYayTtCiZacuqbd21SsX4/xI92ebszQhCWAgvtpaksmaIwjZyoMCD/sB8f1Xks3UCwyT3Eq1nrEcQyzM9vWYcQ/ylzogji1I2OyA6CXx4fdyDIiHRuWhE2/mk7m4GuK+2ojCu/zMgYd5Xvmq+4NOLUCQXofSKkfBKJnIL0prpeebySX/1j56gdTL2CI/STtDkQMPqTLw8p+Omj4CqInQ==';
const data = r'{"orderId":"GPA.3301-1234-5678-90123","packageName":"com.trungsmail.kiemhiep","productId":"kh_noads","purchaseTime":1763300000000,"purchaseState":0,"purchaseToken":"abc.def","quantity":1,"acknowledged":false}';

void main() {
  final v = PlayVerifier.fromBase64(pub)!;

  test('accepts a real SHA1withRSA signature', () {
    expect(v.verify(data, sig), isTrue);
  });

  test('rejects tampered data, bogus or empty signatures', () {
    expect(v.verify(data.replaceFirst('kh_noads', 'kh_month'), sig), isFalse);
    expect(v.verify(data, ''), isFalse);
    expect(v.verify(data, 'Zm9vYmFy'), isFalse);
    final b = base64.decode(sig)..[100] ^= 1;
    expect(v.verify(data, base64.encode(b)), isFalse);
  });

  test('bad keys give no verifier', () {
    expect(PlayVerifier.fromBase64(''), isNull);
    expect(PlayVerifier.fromBase64('not a key'), isNull);
    expect(PlayVerifier.fromBase64(pub.substring(0, 100)), isNull);
  });

  test('the shipped Play licence key is present and parses', () {
    expect(playLicenseKey, isNotEmpty, reason: 'paste the key from Play Console → Licensing');
    expect(PlayVerifier.fromBase64(playLicenseKey), isNotNull);
  });
}
