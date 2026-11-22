CLASS ltcl_benchmark DEFINITION DEFERRED.
CLASS zparq2a_cl_benchmark DEFINITION LOCAL FRIENDS ltcl_benchmark.

CLASS ltcl_benchmark DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS first_rows FOR TESTING.
    METHODS seeds FOR TESTING.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS gzip_round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS other_values_fail FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_benchmark IMPLEMENTATION.

  METHOD first_rows.
    " the values of ROWS( ) in tools/bench/check.py for seed 1
    DATA(rows) = NEW zparq2a_cl_benchmark( 1 )->rows( 4 ).

    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 4 ).
    DATA(first) = rows[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = first-id exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = first-quantity exp = 137682944 ).
    cl_abap_unit_assert=>assert_equals( act = first-price exp = '649504.98' ).
    cl_abap_unit_assert=>assert_equals( act = first-ratio exp = '0.5112106443900665' tol = '1E-15' ).
    cl_abap_unit_assert=>assert_equals( act = first-flag exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = first-name exp = `item 213` ).
    cl_abap_unit_assert=>assert_equals( act = first-day exp = '20310922' ).
    cl_abap_unit_assert=>assert_equals( act = first-note->* exp = `note 1` ).

    DATA(third) = rows[ 3 ].
    cl_abap_unit_assert=>assert_equals( act = third-quantity exp = 5822403940352 ).
    cl_abap_unit_assert=>assert_equals( act = third-price exp = '484860.84' ).
    cl_abap_unit_assert=>assert_equals( act = third-flag exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = third-name exp = `item 7` ).
    cl_abap_unit_assert=>assert_equals( act = third-day exp = '20061106' ).

    DATA(fourth) = rows[ 4 ].
    cl_abap_unit_assert=>assert_equals( act = fourth-day exp = '19990317' ).
    cl_abap_unit_assert=>assert_not_bound( act = fourth-note ).
  ENDMETHOD.

  METHOD seeds.
    DATA(benchmark) = NEW zparq2a_cl_benchmark( 1 ).
    DATA(first) = benchmark->rows( 1 ).
    DATA(next) = benchmark->rows( 1 ).
    cl_abap_unit_assert=>assert_equals( act = next[ 1 ]-id exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = next[ 1 ]-quantity exp = 827617640448 ).

    DATA(negative) = NEW zparq2a_cl_benchmark( -1 )->rows( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = negative[ 1 ]-quantity
      exp = first[ 1 ]-quantity
      msg = 'Seed -1 is seed 1' ).
    DATA(zero) = NEW zparq2a_cl_benchmark( 0 )->rows( 1 ).
    cl_abap_unit_assert=>assert_equals( act = zero[ 1 ]-quantity exp = 68841472 ).
    DATA(wrapped) = NEW zparq2a_cl_benchmark( 2147483646 )->rows( 1 ).
    cl_abap_unit_assert=>assert_equals( act = wrapped[ 1 ]-quantity exp = 68841472 ).
  ENDMETHOD.

  METHOD round_trip.
    DATA(rows) = NEW zparq2a_cl_benchmark( 42 )->rows( 100 ).
    DATA(compressor) = NEW zparq2a_cl_comp_none( ).

    DATA(run) = NEW zparq2a_cl_benchmark( 42 )->run( rows = rows compressor = compressor ).
    cl_abap_unit_assert=>assert_equals( act = run-rows exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = run-bytes exp = xstrlen( run-file ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( run-write_us >= 0 AND run-read_us >= 0 ) ).

    DATA(again) = NEW zparq2a_cl_benchmark( 7 )->run( rows = rows compressor = compressor ).
    cl_abap_unit_assert=>assert_equals( act = again-file exp = run-file msg = 'The same rows give the same file' ).
  ENDMETHOD.

  METHOD gzip_round_trip.
    DATA(rows) = NEW zparq2a_cl_benchmark( 42 )->rows( 100 ).
    DATA(plain) = NEW zparq2a_cl_benchmark( 42 )->run( rows = rows compressor = NEW zparq2a_cl_comp_none( ) ).

    DATA(gzip) = NEW zparq2a_cl_benchmark( 42 )->run( rows = rows compressor = NEW zparq2a_cl_comp_gzip( ) ).
    cl_abap_unit_assert=>assert_equals( act = gzip-rows exp = 100 ).
    cl_abap_unit_assert=>assert_true( xsdbool( gzip-bytes < plain-bytes ) ).
  ENDMETHOD.

  METHOD other_values_fail.
    DATA(rows) = NEW zparq2a_cl_benchmark( 3 )->rows( 8 ).
    zparq2a_cl_benchmark=>compare( expected = rows actual = rows ).

    DATA(other) = rows.
    other[ 5 ]-note = NEW #( `other` ).
    TRY.
        zparq2a_cl_benchmark=>compare( expected = rows actual = other ).
        cl_abap_unit_assert=>fail( 'Another note is not reported' ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.

    other = rows.
    CLEAR other[ 2 ]-note.
    TRY.
        zparq2a_cl_benchmark=>compare( expected = rows actual = other ).
        cl_abap_unit_assert=>fail( 'A missing note is not reported' ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.

    other = rows.
    other[ 8 ]-price = other[ 8 ]-price + '0.01'.
    TRY.
        zparq2a_cl_benchmark=>compare( expected = rows actual = other ).
        cl_abap_unit_assert=>fail( 'Another price is not reported' ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.

    DELETE other INDEX 1.
    TRY.
        zparq2a_cl_benchmark=>compare( expected = rows actual = other ).
        cl_abap_unit_assert=>fail( 'A missing row is not reported' ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
