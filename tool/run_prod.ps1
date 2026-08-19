#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
Set-Location -LiteralPath $Root
$args = @('--release', '--dart-define-from-file=tool/supabase_vercel.json') + $args
& flutter run @args
