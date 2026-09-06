param(
  [string]$NodeHeaders = 'E:/source/node-18.20.5/src',
  [string]$Mingw = 'C:/mingw/bin',
  [string]$Cmake = 'E:/Qt/Tools/CMake_64/bin/cmake.exe'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath "$NodeHeaders/node_api.h")) { throw 'Pass -NodeHeaders pointing to the Node.js src directory containing node_api.h.' }
$output = Join-Path $PSScriptRoot 'logs/native-host'
New-Item -ItemType Directory -Force $output | Out-Null
& "$Mingw/dlltool.exe" --dllname node.exe --def "$PSScriptRoot/tests/native/node.def" --output-lib "$output/libnode.a"
if ($LASTEXITCODE) { throw 'Node import library generation failed' }
& $Cmake -S "$PSScriptRoot/tests/native" -B $output -G 'MinGW Makefiles' "-DCMAKE_C_COMPILER=$Mingw/gcc.exe" "-DCMAKE_CXX_COMPILER=$Mingw/g++.exe" "-DCMAKE_MAKE_PROGRAM=$Mingw/mingw32-make.exe" "-DNODE_HEADERS=$NodeHeaders"
if ($LASTEXITCODE) { throw 'Native test configuration failed' }
& $Cmake --build $output -j 8
if ($LASTEXITCODE) { throw 'Native test build failed' }
