unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtDlgs;

type
  TArrayOfString = array of string;

  TRecordOfSubroutine = record
    Subroutine: TArrayOfString;
    subroutine_name: string;
  end;

  TArrayOfSubroutine = array of TRecordOfSubroutine;

  TVariable = record
    variable: string;
    count: integer;
  end;

  TArrayVariables = array of TVariable;
  TArrayInteger = array of integer;

  TForm_Spen = class(TForm)
    OpenTextFileDialog_Load_Code: TOpenTextFileDialog;
    Button_Load: TButton;
    Memo_Code_From_File: TMemo;
    Button_Check: TButton;
    Memo_Found_Variables: TMemo;
    Memo_Original_Code: TMemo;
    procedure Button_LoadClick(Sender: TObject);
    procedure Button_CheckClick(Sender: TObject);
    function create_array_to_analyze: TArrayOfString;
    procedure output_variables(variables_found: TArrayVariables;
      name_subroutine: string; count_of_previous_variables,
      count_global_variables: integer);
    function find_variables(code_to_analyze: TArrayOfSubroutine)
      : TArrayVariables;
    procedure count_spen_of_program(variables_found: TArrayVariables);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form_Spen: TForm_Spen;

implementation

{$R *.dfm}

function TForm_Spen.create_array_to_analyze: TArrayOfString;
const
  comment_open = '/*';
  comment_short = '//';
  comment_close = '*/';
var
  code_to_analyze: TArrayOfString;
  lines_in_code, i, lines_added, comment_line: integer;
  line_to_analyze: string;
begin
  lines_in_code := Memo_Code_From_File.Lines.count;
  lines_added := 1;
  setlength(code_to_analyze, lines_added);
  i := 0;
  while i < lines_in_code - 1 do
  begin
    if Memo_Code_From_File.Lines[i] <> '' then
    begin
      line_to_analyze := Memo_Code_From_File.Lines[i];
      comment_line := pos(comment_short, line_to_analyze);
      if comment_line <> 0 then
        delete(line_to_analyze, comment_line, length(line_to_analyze));
      comment_line := pos(comment_open, line_to_analyze);
      if comment_line <> 0 then
      begin
        if line_to_analyze[comment_line - 2] <> '' then
        begin
          delete(line_to_analyze, comment_line, length(line_to_analyze));
          setlength(code_to_analyze, lines_added);
          code_to_analyze[lines_added - 1] := line_to_analyze;
          inc(lines_added);
        end;
        comment_line := pos(comment_close, line_to_analyze);
        while comment_line = 0 do
        begin
          inc(i);
          line_to_analyze := Memo_Code_From_File.Lines[i];
          comment_line := pos(comment_close, line_to_analyze);
        end;
      end
      else
      begin
        setlength(code_to_analyze, lines_added);
        code_to_analyze[lines_added - 1] := line_to_analyze;
        inc(lines_added);

      end;
    end;
    inc(i);
  end;
  result := code_to_analyze;
end;

function find_doubles(found_variables: TArrayVariables;
  variable_to_search_for: string; count_of_global_variable,
  count_previous_variables: integer): integer;
var
  i, length_array: integer;
begin
  length_array := length(found_variables);
  i := count_previous_variables;
  for i := count_previous_variables to length_array - 1 do
    if found_variables[i].variable = variable_to_search_for then
      break;
  if i = length_array then
    i := -1;
  result := i;
end;

function test_line_to_be_variable(line_to_test: string): string;
const
  delimeters: set of char = ['(', ')', '[', ']', '<', ',', '.', '+', '-',
    ':', ';'];
  alphabet: set of char = ['A' .. 'Z', 'a' .. 'z', '_'];
var
  i: integer;
  new_string: string;
begin
  new_string := line_to_test[1];
  for i := 2 to length(line_to_test) do
  begin
    if line_to_test[i] in alphabet then
      new_string := new_string + line_to_test[i]
    else
      break;
  end;
  result := new_string;
end;

function include_new_variable(found_variables: TArrayVariables;
  new_variable: string; count_global_variables, count_previous_variables
  : integer): TArrayVariables;
var
  j, place_of_found_variable: integer;
  new_variable_after_test: string;
begin
  j := length(found_variables);
  new_variable_after_test := test_line_to_be_variable(new_variable);
  if j = 0 then
  begin
    setlength(found_variables, 1);
    found_variables[j].variable := test_line_to_be_variable
      (new_variable_after_test);
    found_variables[j].count := 1;
  end
  else
  begin
    place_of_found_variable := find_doubles(found_variables,
      new_variable_after_test, count_global_variables,
      count_previous_variables);
    if place_of_found_variable = -1 then
    begin
      inc(j);
      setlength(found_variables, j);
      found_variables[j - 1].variable := test_line_to_be_variable
        (new_variable_after_test);
      found_variables[j - 1].count := 1;
    end
    else
    begin
      found_variables[place_of_found_variable].count :=
        found_variables[place_of_found_variable].count + 1;
    end;
  end;
  result := found_variables;
end;

function find_delimiters(line_to_test: string): integer;
const
  delimeters: set of char = ['(', ')', '[', ']', '<'];
  alphabet: set of char = ['A' .. 'Z', 'a' .. 'z'];
var
  j, place_of_variable: integer;
begin
  place_of_variable := pos('$', line_to_test);
  if (line_to_test[place_of_variable - 1] in delimeters) then
  begin
    result := place_of_variable - 1;
  end
  else
  begin
    for j := place_of_variable to length(line_to_test) do
      if line_to_test[j] in delimeters then
        break;
    result := j;
  end;
end;

Function look_for_variables_in_line(line_to_analyze: string;
  variable_place_in_line: integer; found_variables: TArrayVariables;
  count_global_variables, count_previous_variables: integer): TArrayVariables;
var
  copy_string: string;
  place_of_delimiter, place_of_string_delimeter: integer;
begin
  while variable_place_in_line <> 0 do
  begin
    place_of_delimiter := find_delimiters(line_to_analyze);
    if place_of_delimiter <> 0 then
    begin
      if place_of_delimiter < variable_place_in_line then
      begin
        copy_string := copy(line_to_analyze, variable_place_in_line,
          length(line_to_analyze) - place_of_delimiter);
        copy_string := test_line_to_be_variable(copy_string);
      end
      else
      begin
        copy_string := copy(line_to_analyze, variable_place_in_line,
          place_of_delimiter - variable_place_in_line);
        copy_string := test_line_to_be_variable(copy_string);
      end;
      if copy_string <> '' then
        found_variables := include_new_variable(found_variables, copy_string,
          count_global_variables, count_previous_variables);
      if variable_place_in_line > 1 then
        delete(line_to_analyze, 1, variable_place_in_line + 1)
      else
        delete(line_to_analyze, variable_place_in_line, place_of_delimiter);
      variable_place_in_line := pos('$', line_to_analyze);
    end
    else
    begin
      found_variables := include_new_variable(found_variables, line_to_analyze,
        count_global_variables, count_previous_variables);
      variable_place_in_line := 0;
    end;
  end;
  result := found_variables;
end;

procedure TForm_Spen.output_variables(variables_found: TArrayVariables;
  name_subroutine: string; count_of_previous_variables, count_global_variables
  : integer);
var
  i, amount_of_unique_variables, all_spen: integer;
begin
  amount_of_unique_variables := length(variables_found);
  if count_of_previous_variables = 0 then
    amount_of_unique_variables := count_global_variables;
  Memo_Found_Variables.Lines.Add('������������: ' + name_subroutine);
  for i := count_of_previous_variables to amount_of_unique_variables - 1 do
  begin
    Memo_Found_Variables.Lines.Add('���������� ' + variables_found[i].variable +
      ' ����� ���� ������ ' + inttostr(variables_found[i].count - 1));
  end;
end;

function add_to_global_variables(global_variable_found: string;
  found_variables: TArrayVariables; count_global: integer): TArrayVariables;
var
  i: integer;
begin
  for i := 0 to count_global - 1 do
    if found_variables[i].variable = global_variable_found then
      found_variables[i].count := found_variables[i].count + 1;
  result := found_variables;
end;

function find_global_variable_in_line(line_to_find_in: string;
  global_place: integer): string;
const
  alphabet: set of char = ['A' .. 'Z', 'a' .. 'z', '_'];
var
  i: integer;
  global_variable_found: string;
begin
  global_variable_found := '$';
  for i := global_place to length(line_to_find_in) do
    if line_to_find_in[i] in alphabet then
      global_variable_found := global_variable_found + line_to_find_in[i]
    else
      break;
  result := global_variable_found;
end;

function find_variables_in_subroutine(code_to_analyze: string;
  found_variables: TArrayVariables; count_previous_variables,
  count_global_variables, variable_place: integer): TArrayVariables;
const
  string_global = 'global ';
  string_globals = '$GLOBALS["';
  length_global = 7;
  length_globals = 10;
var
  global_place, globals_array_place: integer;
  global_variable: string;
begin
  global_place := pos(string_global, code_to_analyze);
  globals_array_place := pos(string_globals, code_to_analyze);
  if (global_place = 0) and (globals_array_place = 0) then
    found_variables := look_for_variables_in_line(code_to_analyze,
      variable_place, found_variables, count_global_variables,
      count_previous_variables)
  else
  begin
    if global_place > 0 then
    begin
      while global_place <> 0 do
      begin
        global_variable := find_global_variable_in_line(code_to_analyze,
          global_place + length_global);
        delete(code_to_analyze, global_place,
          length_global + length(global_variable));
        global_place := pos(string_global, code_to_analyze);
        found_variables := add_to_global_variables(global_variable,
          found_variables, count_global_variables);
      end;
    end
    else
    begin
      while globals_array_place <> 0 do
      begin
        global_variable := find_global_variable_in_line(code_to_analyze,
          (globals_array_place + length_globals));
        delete(code_to_analyze, globals_array_place,
          length_globals + length(global_variable));
        globals_array_place := pos(string_globals, code_to_analyze);
        found_variables := add_to_global_variables(global_variable,
          found_variables, count_global_variables);
      end;
    end;
  end;
  result := found_variables;
end;

function TForm_Spen.find_variables(code_to_analyze: TArrayOfSubroutine)
  : TArrayVariables;
const
  symbol_variable = '$';
var
  i, j, variable_place, lines_in_code, count_global_variables,
    count_previous_variables: integer;
  found_variables: TArrayVariables;
begin
  lines_in_code := length(code_to_analyze);
  setlength(found_variables, 0);
  count_global_variables := 0;
  count_previous_variables := 0;
  for i := 0 to lines_in_code - 1 do
  begin
    for j := 0 to length(code_to_analyze[i].Subroutine) - 1 do
    begin
      variable_place := pos(symbol_variable, code_to_analyze[i].Subroutine[j]);
      if variable_place <> 0 then
      begin
        if i >= 1 then
          found_variables := find_variables_in_subroutine
            (code_to_analyze[i].Subroutine[j], found_variables,
            count_previous_variables, count_global_variables, variable_place)
        else
          found_variables := look_for_variables_in_line
            (code_to_analyze[i].Subroutine[j], variable_place, found_variables,
            count_global_variables, count_previous_variables);
        if i = 0 then
          count_global_variables := length(found_variables);
      end;
    end;
    if i > 0 then
      output_variables(found_variables, code_to_analyze[i].subroutine_name,
        count_previous_variables, count_global_variables);
    count_previous_variables := length(found_variables);
  end;
  output_variables(found_variables, code_to_analyze[0].subroutine_name, 0,
    count_global_variables);
  result := found_variables;
end;

function check_name_subroutine(code_line: string): string;
const
  subroutine_name: set of char = ['A' .. 'Z', 'a' .. 'z', ' ', '_'];
var
  name_subroutine: string;
  i: integer;
begin
  name_subroutine := '';
  i := 1;
  while code_line[i] in subroutine_name do
  begin
    name_subroutine := name_subroutine + code_line[i];
    inc(i);
  end;
  result := name_subroutine;
end;

function create_array_of_subroutine_and_global(code_to_analyze: TArrayOfString)
  : TArrayOfSubroutine;
const
  procedure_string = 'procedure ';
  function_string = 'function ';
  brace_open = '{';
  brace_close = '}';
var
  i, j, count_of_subroutines, balance_of_braces, lines_in_global_view,
    position_braces, position_procedure, position_function,
    lines_in_subroutine: integer;
  code_in_subroutine_and_global: TArrayOfSubroutine;
begin
  i := 0;
  count_of_subroutines := 1;
  setlength(code_in_subroutine_and_global, count_of_subroutines);
  balance_of_braces := 0;
  lines_in_global_view := 1;
  position_braces := 0;
  while i < length(code_to_analyze) - 1 do
  begin
    position_procedure := pos(procedure_string, code_to_analyze[i]);
    position_function := pos(function_string, code_to_analyze[i]);
    if (position_procedure <> 0) or (position_function <> 0) then
    begin
      lines_in_subroutine := 1;
      inc(count_of_subroutines);
      position_braces := 0;
      setlength(code_in_subroutine_and_global, count_of_subroutines);
      code_in_subroutine_and_global[count_of_subroutines - 1].subroutine_name :=
        check_name_subroutine(code_to_analyze[i]);
      while position_braces = 0 do
      begin
        position_braces := pos(brace_open, code_to_analyze[i]);
        if position_braces <> 0 then
          inc(balance_of_braces);
        setlength(code_in_subroutine_and_global[count_of_subroutines - 1]
          .Subroutine, lines_in_subroutine);
        code_in_subroutine_and_global[count_of_subroutines - 1].Subroutine
          [lines_in_subroutine - 1] := code_to_analyze[i];
        inc(i);
        inc(lines_in_subroutine);
      end;
      while balance_of_braces <> 0 do
      begin
        for j := 1 to length(code_to_analyze[i]) do
        begin
          if code_to_analyze[i][j] = brace_open then
            inc(balance_of_braces);
          if code_to_analyze[i][j] = brace_close then
            dec(balance_of_braces);
        end;
        setlength(code_in_subroutine_and_global[count_of_subroutines - 1]
          .Subroutine, lines_in_subroutine);
        code_in_subroutine_and_global[count_of_subroutines - 1].Subroutine
          [lines_in_subroutine - 1] := code_to_analyze[i];
        inc(i);
        inc(lines_in_subroutine);
      end;
    end
    else
    begin
      code_in_subroutine_and_global[0].subroutine_name := 'Global';
      setlength(code_in_subroutine_and_global[0].Subroutine,
        lines_in_global_view);
      code_in_subroutine_and_global[0].Subroutine[lines_in_global_view - 1] :=
        code_to_analyze[i];
      inc(lines_in_global_view);
    end;
    inc(i);
  end;
  result := code_in_subroutine_and_global;
end;

procedure TForm_Spen.count_spen_of_program(variables_found: TArrayVariables);
var
  i, all_spen: integer;
begin
  all_spen := 0;
  for i := 0 to length(variables_found) - 1 do
    all_spen := all_spen + variables_found[i].count;
  Memo_Found_Variables.Lines.Add('����� ���� ���������: ' + inttostr(all_spen));
end;

procedure TForm_Spen.Button_CheckClick(Sender: TObject);
var
  lines_in_code: integer;
  code_to_analyze: TArrayOfString;
  code_in_subroutine_and_global: TArrayOfSubroutine;
  variables_found: TArrayVariables;
begin
  lines_in_code := Memo_Code_From_File.Lines.count;
  code_to_analyze := create_array_to_analyze;
  code_in_subroutine_and_global := create_array_of_subroutine_and_global
    (code_to_analyze);
  variables_found := find_variables(code_in_subroutine_and_global);
  count_spen_of_program(variables_found);
end;

procedure TForm_Spen.Button_LoadClick(Sender: TObject);
var
  text_file_name, file_with_needed_code: textfile;
  temporary_for_symbol: ansichar;
begin
  if OpenTextFileDialog_Load_Code.execute then
    assignfile(text_file_name, OpenTextFileDialog_Load_Code.filename);
  reset(text_file_name);
  assignfile(file_with_needed_code, 'output.txt');
  rewrite(file_with_needed_code);
  while not eof(text_file_name) do
  begin
    read(text_file_name, temporary_for_symbol);
    if temporary_for_symbol = '''' then
    begin
      read(text_file_name, temporary_for_symbol);
      while temporary_for_symbol <> '''' do
        read(text_file_name, temporary_for_symbol);
    end;
    write(file_with_needed_code, temporary_for_symbol);
  end;
  closefile(text_file_name);
  closefile(file_with_needed_code);
  Memo_Code_From_File.Lines.LoadFromFile('output.txt');
  Memo_Original_Code.Lines.LoadFromFile(OpenTextFileDialog_Load_Code.filename);
end;

end.
