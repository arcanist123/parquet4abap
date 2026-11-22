REPORT zparq2a_benchmark.

* Writes and reads a generated table with ZPARQ2A_CL_BENCHMARK and prints one
* line per run, as KEY=VALUE pairs: the rows, the file size in bytes and the
* write and read times in microseconds. P_FILE keeps the file of the last run.

PARAMETERS p_rows TYPE i DEFAULT 10000.
PARAMETERS p_seed TYPE i DEFAULT 1.
PARAMETERS p_runs TYPE i DEFAULT 5.
PARAMETERS p_gzip AS CHECKBOX.
PARAMETERS p_file TYPE string LOWER CASE.

DATA compressor TYPE REF TO zparq2a_if_compressor.
DATA benchmark TYPE REF TO zparq2a_cl_benchmark.
DATA rows TYPE zparq2a_cl_benchmark=>ty_rows.
DATA run TYPE zparq2a_cl_benchmark=>ty_run.
DATA codec TYPE string.
DATA pass TYPE i.
DATA message TYPE string.
DATA error TYPE REF TO zparq2a_cx_error.

START-OF-SELECTION.
  TRY.
      IF p_gzip = abap_true.
        compressor = NEW zparq2a_cl_comp_gzip( ).
        codec = `gzip`.
      ELSE.
        compressor = NEW zparq2a_cl_comp_none( ).
        codec = `none`.
      ENDIF.
      benchmark = NEW #( p_seed ).
      rows = benchmark->rows( p_rows ).
      DO p_runs TIMES.
        pass = sy-index.
        run = benchmark->run( rows = rows compressor = compressor ).
        WRITE / |run={ pass } codec={ codec } rows={ run-rows } bytes={ run-bytes } | &&
                |write_us={ run-write_us } read_us={ run-read_us }|.
      ENDDO.
    CATCH zparq2a_cx_error INTO error.
      WRITE / |error={ error->get_text( ) }|.
  ENDTRY.

  IF p_file IS NOT INITIAL AND run-file IS NOT INITIAL.
    OPEN DATASET p_file FOR OUTPUT IN BINARY MODE MESSAGE message.
    IF sy-subrc = 0.
      TRANSFER run-file TO p_file.
      CLOSE DATASET p_file.
    ELSE.
      WRITE / |error={ message }|.
    ENDIF.
  ENDIF.
