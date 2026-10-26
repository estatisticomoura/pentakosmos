#!/usr/bin/env python3
"""Assina um APK (ja alinhado) com o APK Signature Scheme v2, sem o Android SDK.

Uso:
  python3 tools/assinar_apk.py nova-chave chave.pem          # cria chave RSA + certificado
  python3 tools/assinar_apk.py assinar chave.pem entrada.apk saida.apk

A mesma chave precisa ser usada em todas as versoes; senao o Android recusa
atualizar o app instalado. Guarde chave.pem fora do repositorio.
Requer: pip install cryptography
"""
import datetime
import hashlib
import struct
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID

CHUNK = 1 << 20
SIG_RSA_SHA256 = 0x0103
V2_ID = 0x7109871A
MAGIC = b"APK Sig Block 42"


def lp(b):
    return struct.pack("<I", len(b)) + b


def new_key(path):
    key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Pentakosmos"),
                      x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Caio Moura Quina")])
    now = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=365 * 40))
            .sign(key, hashes.SHA256()))
    with open(path, "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                  serialization.NoEncryption()))
        f.write(cert.public_bytes(serialization.Encoding.PEM))


def load(path):
    data = open(path, "rb").read()
    key = serialization.load_pem_private_key(data, None)
    cert = x509.load_pem_x509_certificate(data[data.index(b"-----BEGIN CERTIFICATE"):])
    return key, cert


def digest(sections):
    chunks = []
    for s in sections:
        for i in range(0, len(s), CHUNK):
            c = s[i:i + CHUNK]
            chunks.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(chunks)) + b"".join(chunks)).digest()


def sign(keypath, src, dst):
    key, cert = load(keypath)
    apk = open(src, "rb").read()
    eocd = apk.rfind(b"PK\x05\x06")
    cd_off, = struct.unpack("<I", apk[eocd + 16:eocd + 20])
    if apk[cd_off - 16:cd_off] == MAGIC:
        sys.exit("o APK ja tem bloco de assinatura")
    entries, cd, end = apk[:cd_off], apk[cd_off:eocd], apk[eocd:]
    dg = digest([entries, cd, end])
    der = cert.public_bytes(serialization.Encoding.DER)
    signed = lp(lp(struct.pack("<I", SIG_RSA_SHA256) + lp(dg))) + lp(lp(der)) + lp(b"")
    sig = key.sign(signed, padding.PKCS1v15(), hashes.SHA256())
    pub = key.public_key().public_bytes(serialization.Encoding.DER,
                                        serialization.PublicFormat.SubjectPublicKeyInfo)
    signer = lp(signed) + lp(lp(struct.pack("<I", SIG_RSA_SHA256) + lp(sig))) + lp(pub)
    value = lp(lp(signer))
    pair = struct.pack("<Q", 4 + len(value)) + struct.pack("<I", V2_ID) + value
    size = len(pair) + 8 + 16
    block = struct.pack("<Q", size) + pair + struct.pack("<Q", size) + MAGIC
    new_end = end[:16] + struct.pack("<I", cd_off + len(block)) + end[20:]
    with open(dst, "wb") as f:
        f.write(entries + block + cd + new_end)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "nova-chave":
        new_key(sys.argv[2])
    elif len(sys.argv) == 5 and sys.argv[1] == "assinar":
        sign(*sys.argv[2:])
    else:
        sys.exit(__doc__)
