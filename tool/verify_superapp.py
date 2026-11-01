from pathlib import Path
import argparse,hashlib,json,plistlib,struct
ROOT=Path(__file__).resolve().parents[1]
MODELS={'assets/models/yamnet.tflite':'10c95ea3eb9a7bb4cb8bddf6feb023250381008177ac162ce169694d05c317de','ios/HealthResources/research-sleep.onnx':'ccc3c94646cab11d53fab9d2bedae8c777c3c5ec3f0926a421c35fe44c46400c'}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name,digest in MODELS.items():assert sha(ROOT/name)==digest,name
for name in ('CareHealthKit','CryptoResearchKit'):
    source=ROOT/'ios/SuperModules/Sources'/name
    assert source.is_dir() and not any('@main ' in p.read_text(encoding='utf-8') for p in source.rglob('*.swift'))
    assert ('SuperCareBridge' if name=='CareHealthKit' else 'SuperCryptoBridge') in ''.join(p.read_text(encoding='utf-8') for p in source.glob('Super*Bridge.swift'))
main=(ROOT/'lib/main.dart').read_text(encoding='utf-8')
assert "label: '온케어'" in main and "label: '투자'" in main
assert "app.caresuite/native" in (ROOT/'lib/native_modules.dart').read_text()
info=plistlib.loads((ROOT/'ios/Runner/Info.plist').read_bytes())
assert info['CFBundleDisplayName']=='Care Suite'
assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['caresuite-care']
assert 'NSHealthShareUsageDescription' in info
for folder in ('lib','ios/SuperModules','ios/HealthWidgets','ios/Runner','assets'):
    for path in (ROOT/folder).rglob('*'):
        assert path.name not in ('build-config.json','.env','signing-store'),path
        assert path.suffix not in ('.p12','.jks','.mobileprovision','.keystore'),path
parser=argparse.ArgumentParser();parser.add_argument('--app',type=Path);args=parser.parse_args()
if args.app:
    app=args.app;meta=plistlib.loads((app/'Info.plist').read_bytes());assert meta['CFBundleIdentifier']=='app.caresuite.super'
    assert meta['CFBundleShortVersionString']=='0.1.1' and meta['CFBundleVersion']=='2'
    binary=(app/meta['CFBundleExecutable']).read_bytes();magic,cpu=struct.unpack('<II',binary[:8]);assert magic==0xfeedfacf and cpu==0x100000c
    assert b'SuperCareRoot' in binary and b'SuperCryptoRoot' in binary,'Native modules missing from executable'
    assert sha(app/'research-sleep.onnx')==MODELS['ios/HealthResources/research-sleep.onnx']
    model=app/'Frameworks/App.framework/flutter_assets/assets/models/yamnet.tflite';assert sha(model)==MODELS['assets/models/yamnet.tflite']
    ids={plistlib.loads((p/'Info.plist').read_bytes())['CFBundleIdentifier'] for p in (app/'PlugIns').glob('*.appex')}
    assert {'app.caresuite.super.healthlive','app.caresuite.super.barklive'}<=ids
print(json.dumps({'source_structure_verified':True,'models_hash_verified':True,'native_device_payload_verified':bool(args.app),'physical_device_tested':False}))
