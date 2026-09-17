#!/usr/bin/env python3
"""Build and verify the native AloeSend release APP on Linux."""
import os, pathlib, json, re, subprocess, zipfile, io, hashlib, time
ROOT=pathlib.Path(__file__).resolve().parent.parent
PROJECT=ROOT/'arkui/AloeSend'
TOOLS=pathlib.Path(os.environ.get('OHOS_COMMAND_LINE_TOOLS',str(pathlib.Path.home()/'command-line-tools')))
env=os.environ.copy()
env['JAVA_HOME']=env.get('JAVA_HOME',str(pathlib.Path.home()/'jdk-21'))
env['DEVECO_SDK_HOME']=str(TOOLS/'sdk');env['DEVECO_NODE_HOME']=str(TOOLS/'tool/node')
env['PATH']=f"{TOOLS}/tool/node/bin:{env['JAVA_HOME']}/bin:{TOOLS}/bin:"+env['PATH']
def run(*args,**kwargs):return subprocess.run([str(a) for a in args],check=True,env=env,**kwargs)
def load(path):return json.loads(re.sub(r',\s*([}\]])',r'\1',path.read_text(encoding='utf-8-sig')))
signing=load(ROOT/'.signing/release.json');material=signing['signing']['material']
for key in ['storeFile','profile','certpath']:material[key]=str(ROOT/material[key])
profile=json.loads(subprocess.check_output(['openssl','cms','-verify','-inform','DER','-in',material['profile'],'-noverify'],stderr=subprocess.DEVNULL))
app=load(PROJECT/'AppScope/app.json5')['app']
assert profile['type']=='release' and profile['bundle-info']['bundle-name']==app['bundleName']
def fingerprint(pem):
 return hashlib.sha256(subprocess.check_output(['openssl','x509','-outform','DER'],input=pem)).hexdigest()
def chain_fingerprints(data):
 return [fingerprint(pem) for pem in re.findall(b'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----',data,re.S)]
expected=fingerprint(profile['bundle-info']['distribution-certificate'].encode())
assert expected in chain_fingerprints(pathlib.Path(material['certpath']).read_bytes())
profile_path=PROJECT/'build-profile.json5';original=profile_path.read_bytes();config=load(profile_path)
config['app']['signingConfigs']=[signing['signing']]
product=next(p for p in config['app']['products'] if p['name']=='default')
for key in ['signingConfig','compatibleSdkVersion','runtimeOS']:product[key]=signing['product'][key]
start=time.time()
try:
 profile_path.write_text(json.dumps(config,indent=2,ensure_ascii=False)+'\n')
 run(TOOLS/'bin/ohpm','install','--all',cwd=PROJECT)
 run(TOOLS/'bin/hvigorw','assembleApp','--mode','project','-p','product=default','-p','buildMode=release','--no-daemon',cwd=PROJECT)
 outputs=list((PROJECT/'build/outputs/default').glob('*-signed.app'))
 assert outputs,'No signed APP produced'
 package=max(outputs,key=lambda p:p.stat().st_mtime);assert package.stat().st_mtime>=start
 with zipfile.ZipFile(package) as z:
  haps=[n for n in z.namelist() if n.endswith('.hap')];assert haps
  for name in haps:
   with zipfile.ZipFile(io.BytesIO(z.read(name))) as hap:
    module=json.loads(hap.read('module.json'));metadata=module['app']
    assert not metadata.get('debug',False)
    for key in ['bundleName','versionCode','versionName']:assert metadata[key]==app[key]
    permissions={p['name'] for p in module['module'].get('requestPermissions',[])}
    assert 'ohos.permission.READ_PASTEBOARD' not in permissions
    assert {'ohos.permission.INTERNET','ohos.permission.FILE_ACCESS_PERSIST'}<=permissions
 reportdir=ROOT/'arkui/artifacts/release';reportdir.mkdir(parents=True,exist_ok=True)
 for path in [package,*list((PROJECT/'entry/build/default/outputs/default').glob('*-signed.hap'))]:
  cert=reportdir/(path.suffix[1:]+'-verified.cer');provision=reportdir/(path.suffix[1:]+'-verified.p7b')
  run('java','-jar',TOOLS/'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar','verify-app','-inFile',path,'-outCertChain',cert,'-outProfile',provision)
  assert expected in chain_fingerprints(cert.read_bytes())
 target=reportdir/f"AloeSend-{app['versionName']}-release-signed.app"
 target.write_bytes(package.read_bytes())
 report={'artifact':str(target),'versionName':app['versionName'],'versionCode':app['versionCode'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'signerSha256':expected,'buildMode':'release','sdk':str(TOOLS.resolve())}
 (reportdir/'linux-build-report.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
finally:profile_path.write_bytes(original)
