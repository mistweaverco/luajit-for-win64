# Write lj4w.config if does not exist
$lj4wPath = "$env:APPDATA\LJ4W"
if (-not (Test-Path $lj4wPath)) {
    New-Item -Path $lj4wPath -ItemType Directory
}
$lj4wConfig = "$lj4wPath\lj4w.txt"
if (-not (Test-Path $lj4wConfig)) {
    @"
default.all.interpreter=lj4w
default.lua.interpreter=lua
default.luajit.interpreter=lj4w
lj4w.interpreter="$($MyInvocation.MyCommand.Path)"
"@ | Out-File -FilePath $lj4wConfig
}

# If the LJ4W_INTERPRETER_PATH environmental variable is already set, launch directly
if ($env:LJ4W_INTERPRETER_PATH) {
    Goto launch
}

# If the LJ4W_INTERPRETER environmental variable is already set, find interpreter path and launch
if ($env:LJ4W_INTERPRETER) {
    Goto launch_comment_header
}

# If no arguments/file given, open lj4w command prompt
if ($args.Count -eq 0) {
    Goto lj4w
}

# If argument given is not a file, pass to default interpreter
if (-not (Test-Path $args[0])) {
    Goto default_all_interpreter
}

# Read file header
$LJ4W_INTERPRETER = Get-Content -Path $args[0] -TotalCount 1

# Handle bytecode headers
if ($LJ4W_INTERPRETER[0] -ne [char]27) {
    Goto comment_headers
}
if ($LJ4W_INTERPRETER -like "`eLJ*") {
    Goto default_luajit_interpreter
}
if ($LJ4W_INTERPRETER -like "`eLua*") {
    Goto default_lua_interpreter
}

:comment_headers
# If header is not a comment, launch default interpreter
if (-not ($LJ4W_INTERPRETER -like "--*")) {
    $LJ4W_INTERPRETER = $null
    Goto default_all_interpreter
}

# If header comment is not interpreter parameter, launch default interpreter
if (-not ($LJ4W_INTERPRETER -like "--interpreter: *")) {
    $LJ4W_INTERPRETER = $null
    Goto default_all_interpreter
}

# Clean up interpreter name
$LJ4W_INTERPRETER = $LJ4W_INTERPRETER.Substring(15)
:launch_comment_header

# Check if the header is valid, report error and exit if not
$interpreterLine = Select-String -Pattern "$LJ4W_INTERPRETER.interpreter" -Path $lj4wConfig
if (-not $interpreterLine) {
    Write-Host "No interpreter configured for '$LJ4W_INTERPRETER'"
    exit
}
# Look up path for requested interpreter
$interpreterPath = $interpreterLine -replace ".*=", ""
$env:LJ4W_INTERPRETER_PATH = $interpreterPath
Goto launch

:default_all_interpreter
# Look up path for default interpreter and launch
$defaultInterpreterLine = Select-String -Pattern "default.all.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.all.interpreter' is misconfigured!"
    exit
}
$defaultInterpreter = $defaultInterpreterLine -replace ".*=", ""
$defaultInterpreterLine = Select-String -Pattern "$defaultInterpreter.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.all.interpreter' is misconfigured!"
    exit
}
$env:LJ4W_INTERPRETER = $defaultInterpreter
$env:LJ4W_INTERPRETER_PATH = $defaultInterpreterLine -replace ".*=", ""
Goto launch

:default_luajit_interpreter
# Look up path for default LuaJIT interpreter and launch
$defaultInterpreterLine = Select-String -Pattern "default.luajit.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.luajit.interpreter' is misconfigured!"
    exit
}
$defaultInterpreter = $defaultInterpreterLine -replace ".*=", ""
$defaultInterpreterLine = Select-String -Pattern "$defaultInterpreter.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.luajit.interpreter' is misconfigured!"
    exit
}
$env:LJ4W_INTERPRETER = $defaultInterpreter
$env:LJ4W_INTERPRETER_PATH = $defaultInterpreterLine -replace ".*=", ""
Goto launch

:default_lua_interpreter
# Look up path for default Lua interpreter and launch
$defaultInterpreterLine = Select-String -Pattern "default.lua.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.lua.interpreter' is misconfigured!"
    exit
}
$defaultInterpreter = $defaultInterpreterLine -replace ".*=", ""
$defaultInterpreterLine = Select-String -Pattern "$defaultInterpreter.interpreter" -Path $lj4wConfig
if (-not $defaultInterpreterLine) {
    Write-Host "The 'default.lua.interpreter' is misconfigured!"
    exit
}
$env:LJ4W_INTERPRETER = $defaultInterpreter
$env:LJ4W_INTERPRETER_PATH = $defaultInterpreterLine -replace ".*=", ""
Goto launch

:launch
# Launch appropriate lua implementation
if (Test-Path $env:LJ4W_INTERPRETER_PATH) {
    if ($env:LJ4W_MIXED -eq "true") { Goto clean_mixed }
    if ($env:LJ4W_INTERPRETER_PATH -eq $MyInvocation.MyCommand.Path) { Goto lj4w }
    $host.UI.RawUI.WindowTitle = $env:LJ4W_INTERPRETER_PATH
    & $env:LJ4W_INTERPRETER_PATH @args
    exit
}
# Report error if requested lua implementation is not configured properly
Write-Host "'$env:LJ4W_INTERPRETER' cannot be found at '$env:LJ4W_INTERPRETER_PATH'"
if ($env:LJ4W_MIXED -eq "true") { Goto clean_mixed }
exit

:clean_mixed
$env:LJ4W_INTERPRETER = $null
$env:LJ4W_INTERPRETER_PATH = $null
exit

:lj4w
# Set window title
$host.UI.RawUI.WindowTitle = "LuaJIT For Windows"

# Set base LuaJIT directory (LUADIR)
$LUADIR = (Get-Location).Path

# Set paths
$env:PATH = "$LUADIR\tools\cmd;$LUADIR\tools\PortableGit\mingw64\bin;$LUADIR\tools\PortableGit\usr\bin;$LUADIR\tools\mingw\bin;$LUADIR\lib;$LUADIR\bin;$env:APPDATA\LJ4W\LuaRocks\bin;$env:PATH"
$env:LUA_PATH = "$LUADIR\lua\?.lua;$LUADIR\lua\?\init.lua;$env:APPDATA\LJ4W\LuaRocks\share\lua\5.1\?.lua;$env:APPDATA\LJ4W\LuaRocks\share\lua\5.1\?\init.lua;$env:LUA_PATH"
$env:LUA_CPATH = "$env:APPDATA\LJ4W\LuaRocks\lib\lua\5.1\?.dll;$env:LUA_CPATH"

# If arguments are being sent, pass to LuaJIT and exit
if ($args.Count -gt 0) {
    & "$LUADIR\bin\luajit.exe" @args
    exit
}

# Prepare command prompt environment
$env:APPDATA = "$env:APPDATA\LJ4W"
if (-not (Test-Path "$env:APPDATA\LuaRocks")) {
    New-Item -Path "$env:APPDATA\LuaRocks" -ItemType Directory
}
if (-not (Test-Path "$env:APPDATA\LuaRocks\default-lua-version.lua")) {
    "return '5.1'" | Out-File -FilePath "$env:APPDATA\LuaRocks\default-lua-version.lua"
}
if (-not (Test-Path "$env:APPDATA\LuaRocks\config-5.1.lua")) {
    & luarocks config | Out-File -FilePath "$env:APPDATA\LuaRocks\config-5.1.lua"
}

# Command prompt
Write-Host "***** LuaJIT For Windows *****"
& luajit -v
& luarocks --version
& gcc --version
cmd /k
