Option Explicit

Dim fso, wsh
Set fso = CreateObject("Scripting.FileSystemObject")
Set wsh = CreateObject("WScript.Shell")

Dim MRUBY_ROOT, CONFNAME, MRBC_DEBUG, MRBC_PATH
MRUBY_ROOT = fso.GetAbsolutePathName("..\mruby")
const GEM_LIST_FILE = "gem_list.txt"
If WScript.Arguments.Count > 0 Then
  CONFNAME = WScript.Arguments(0)
Else
  CONFNAME = "host"
End If
If WScript.Arguments.Count > 1 Then
  If InStr(WScript.Arguments(1), "Debug") > 0 Then
    MRBC_DEBUG = "-g"
  Else
    MRBC_DEBUG = ""
  End If
Else
  MRBC_DEBUG = ""
End If
MRBC_PATH = MRUBY_ROOT & "\build\" & CONFNAME & "\bin\mrbc.exe"

Function array_len(ary)
  array_len = 0
  On Error Resume Next
  array_len = UBound(ary) + 1
End Function

Function get_modified_date(filename)
  get_modified_date = DateValue("January 1, 1970")
  On Error Resume Next
  get_modified_date = fso.GetFile(filename).DateLastModified
End Function

Function get_newest_file(files)
  Dim NewFileDate, NewFile, file, fo
  NewFileDate = DateValue("January 1, 1970")
  NewFile = "" 
  For Each file In files
    Set fo = Nothing
    On Error Resume Next
    Set fo = fso.GetFile(file)
    On Error Goto 0
    If Not (fo Is Nothing) Then
      If NewFileDate < fo.DateLastModified Then
        NewFileDate = fo.DateLastModified
        NewFile = file
      End If
    End If
  Next
  get_newest_file = NewFile
End Function

Function should_update(target_filename, src_files)
  If get_modified_date(target_filename) < get_modified_date(get_newest_file(src_files)) Then
    should_update = True
  Else
    should_update = False
  End If
End Function

Sub create_folder(path)
    Dim parent
    parent = fso.GetParentFolderName(path)
    If fso.FolderExists(parent) Then
        If Not fso.FolderExists(path) Then
            fso.CreateFolder path
        End If
    Else
        create_folder parent
        fso.CreateFolder path
    End If
End Sub

Sub make_mrblib_c(filename, rb_files)
  create_folder fso.GetParentFolderName(filename)
  WScript.Echo "creating " & filename & "..."
  wsh.Exec MRBC_PATH & " " & MRBC_DEBUG & " -Bmrblib_irep -o" & filename & " " & Join(rb_files, " ")
End Sub

Sub make_gem_init_c_root(filename, gemdirs)
  Dim ts, dir, gemname, gemname2
  create_folder fso.GetParentFolderName(filename)
  WScript.Echo "creating " & filename & "..."
  Set ts = fso.CreateTextFile(filename, true)
  ts.WriteLine "/*"
  ts.WriteLine " * This file contains a list of all"
  ts.WriteLine " * initializing methods which are"
  ts.WriteLine " * necessary to bootstrap all gems."
  ts.WriteLine " *"
  ts.WriteLine " * IMPORTANT:"
  ts.WriteLine " *   This file was generated!"
  ts.WriteLine " *   All manual changes will get lost."
  ts.WriteLine " */"
  ts.WriteLine ""
  ts.WriteLine "#include ""mruby.h"""
  ts.WriteLine ""
  For Each dir In gemdirs
    gemname2 = Replace(fso.GetFileName(dir), "-", "_")
    ts.WriteLine "void GENERATED_TMP_mrb_" & gemname2 & "_gem_init(mrb_state*);"
    ts.WriteLine "void GENERATED_TMP_mrb_" & gemname2 & "_gem_final(mrb_state*);"
  Next
  ts.WriteLine ""
  ts.WriteLine "static void"
  ts.WriteLine "mrb_final_mrbgems(mrb_state *mrb) {"
  For Each dir In gemdirs
    gemname2 = Replace(fso.GetFileName(dir), "-", "_")
    ts.WriteLine "  GENERATED_TMP_mrb_" & gemname2 & "_gem_final(mrb);"
  Next
  ts.WriteLine "}"
  ts.WriteLine ""
  ts.WriteLine "void"
  ts.WriteLine "mrb_init_mrbgems(mrb_state *mrb) {"
  For Each dir In gemdirs
    gemname2 = Replace(fso.GetFileName(dir), "-", "_")
    ts.WriteLine "  GENERATED_TMP_mrb_" & gemname2 & "_gem_init(mrb);"
  Next
  ts.WriteLine "  mrb_state_atexit(mrb, mrb_final_mrbgems);"
  ts.WriteLine "}"
  ts.Close
End Sub

Sub make_gem_init_c(filename, gemname, c_files, rb_files)
  Dim ts, gemname2, c_count, rb_count
  create_folder fso.GetParentFolderName(filename)
  WScript.Echo "creating " & filename & "..."
  Set ts = fso.CreateTextFile(filename, true)
  gemname2 = Replace(gemname, "-", "_")
  c_count = array_len(c_files)
  rb_count = array_len(rb_files)
  ts.WriteLine "/*"
  ts.WriteLine " * This file is loading the irep"
  ts.WriteLine " * Ruby GEM code."
  ts.WriteLine " *"
  ts.WriteLine " * IMPORTANT:"
  ts.WriteLine " *   This file was generated!"
  ts.WriteLine " *   All manual changes will get lost."
  ts.WriteLine " */"
  ts.WriteLine "#include <stdlib.h>"
  ts.WriteLine "#include ""mruby.h"""
  ts.WriteLine "#include ""mruby/irep.h"""
  If rb_count > 0 Then
    Dim exec
    Set exec = wsh.Exec(MRBC_PATH & " " & MRBC_DEBUG & " -Bgem_mrblib_irep_" & gemname2 & " -o- " & Join(rb_files, " "))
    Do Until exec.StdOut.AtEndOfStream
      ts.WriteLine exec.StdOut.ReadLine
    Loop
  End If
  If c_count > 0 Then
    ts.WriteLine "void mrb_" & gemname2 & "_gem_init(mrb_state *mrb);" 
    ts.WriteLine "void mrb_" & gemname2 & "_gem_final(mrb_state *mrb);"
  End If
  ts.WriteLine ""
  ts.WriteLine "void GENERATED_TMP_mrb_" & gemname2 & "_gem_init(mrb_state *mrb) {"
  ts.WriteLine "  int ai = mrb_gc_arena_save(mrb);"
  If c_count > 0 Then
    ts.WriteLine "  mrb_" & gemname2 & "_gem_init(mrb);"
  End If
  If rb_count > 0 Then
    ts.WriteLine "  mrb_load_irep(mrb, gem_mrblib_irep_" & gemname2 & ");"
    ts.WriteLine "  if (mrb->exc) {"
    ts.WriteLine "    mrb_print_error(mrb);"
    ts.WriteLine "    exit(EXIT_FAILURE);"
    ts.WriteLine "  }"
  End If
  ts.WriteLine "  mrb_gc_arena_restore(mrb, ai);"
  ts.WriteLine "}"
  ts.WriteLine ""
  ts.WriteLine "void GENERATED_TMP_mrb_" & gemname2 & "_gem_final(mrb_state *mrb) {"
  If c_count > 0 Then
    ts.WriteLine "  mrb_" & gemname2 & "_gem_final(mrb);"
  End If
  ts.WriteLine "}"
  ts.Close
End Sub

Sub make_gems_c(filename, gemdirs)
  Dim ts, gemname
  create_folder fso.GetParentFolderName(filename)
  WScript.Echo "creating " & filename & "..."
  Set ts = fso.CreateTextFile(filename, true)
  ts.WriteLine "/*"
  ts.WriteLine " * IMPORTANT:"
  ts.WriteLine " *   This file was generated!"
  ts.WriteLine " *   All manual changes will get lost."
  ts.WriteLine " */"
  ts.WriteLine "#include ""mrblib/mrblib.c"""
  ts.WriteLine "#include ""mrbgems/gem_init.c"""
  For Each dir In gemdirs
    gemname = fso.GetFileName(dir)
    ts.WriteLine "#include ""mrbgems/" & gemname & "/gem_init.c"""
  Next
End Sub

Function get_files(dir, ext)
  Dim files(), file, i
  i = 0
  If fso.FolderExists(dir) Then
    For Each file In fso.GetFolder(dir).Files
      If fso.GetExtensionName(file.Name) = ext Then
        Redim Preserve files(i)
        files(i) = file.path
        i = i + 1
      End If
    Next
  End If
  get_files = files
End Function

Sub check_mrblib()
  Dim mrblib_files, mrblib_c_path
  mrblib_files = get_files(MRUBY_ROOT & "\mrblib", "rb")
  mrblib_c_path = MRUBY_ROOT & "\build\" & CONFNAME & "\mrblib\mrblib.c"
  If should_update(mrblib_c_path, mrblib_files) Then
    make_mrblib_c mrblib_c_path,  mrblib_files
  End If
End Sub

Sub check_gemdir(dir)
  If Not fso.FolderExists(dir) Then
    WScript.Echo "no such directory: " & dir
    Exit Sub
  End If

  Dim gemname, c_files, rb_files, gem_init_c_path
  gemname = fso.GetFileName(dir)
  gem_init_c_path = MRUBY_ROOT & "\build\" & CONFNAME & "\mrbgems\" & gemname & "\gem_init.c"

  c_files = get_files(dir & "\src", "c")
  rb_files = get_files(dir & "\mrblib", "rb")

  If Not fso.FileExists(gem_init_c_path) Then
    make_gem_init_c gem_init_c_path, gemname, c_files, rb_files
  Else
    if should_update(gem_init_c_path, rb_files) Then
      make_gem_init_c gem_init_c_path, gemname, c_files, rb_files
    End If
  End If
End Sub

Function read_gemlist(filename)
  Dim ts, i, list()
  Set ts = fso.OpenTextFile(filename)
  i = 0
  Do Until ts.AtEndOfStream
    Redim Preserve list(i)
    list(i) = ts.ReadLine 
    i = i + 1
  Loop
  ts.Close
  read_gemlist = list
End Function

check_mrblib

Dim dir, gemdirs
gemdirs = read_gemlist(GEM_LIST_FILE)

For Each dir In gemdirs
  check_gemdir MRUBY_ROOT & "\" & dir
Next

Dim gem_init_c_path, gems_c_path
gem_init_c_path = MRUBY_ROOT & "\build\" & CONFNAME & "\mrbgems\gem_init.c"
gems_c_path = MRUBY_ROOT & "\build\src\gems.c"
If should_update(gem_init_c_path, Array(GEM_LIST_FILE)) Then
  make_gem_init_c_root gem_init_c_path, gemdirs
End If
If should_update(gems_c_path, Array(GEM_LIST_FILE)) Then
  make_gems_c gems_c_path, gemdirs
End If
