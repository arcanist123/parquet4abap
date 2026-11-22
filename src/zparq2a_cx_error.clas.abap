"! <p class="shorttext synchronized">Parquet: error</p>
"! Raised for any problem while reading or writing Parquet data.
CLASS zparq2a_cx_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Human-readable description of the problem
    DATA text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        text     TYPE string OPTIONAL
        previous LIKE previous OPTIONAL.

    METHODS get_text REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS zparq2a_cx_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->text = text.
  ENDMETHOD.

  METHOD get_text.
    result = text.
  ENDMETHOD.

ENDCLASS.
