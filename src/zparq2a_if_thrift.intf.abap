"! <p class="shorttext synchronized">Parquet: Thrift Compact Protocol definitions</p>
"! Wire types of the Thrift Compact Protocol and the representation of fields
"! that a struct codec does not model. Such fields are kept as raw bytes, so
"! re-encoding a decoded struct gives the original bytes.
INTERFACE zparq2a_if_thrift
  PUBLIC.

  CONSTANTS:
    "! Compact Protocol wire types; a field header carries a boolean value as
    "! bool_true or bool_false
    BEGIN OF c_type,
      stop       TYPE i VALUE 0,
      bool_true  TYPE i VALUE 1,
      bool_false TYPE i VALUE 2,
      byte       TYPE i VALUE 3,
      i16        TYPE i VALUE 4,
      i32        TYPE i VALUE 5,
      i64        TYPE i VALUE 6,
      double     TYPE i VALUE 7,
      binary     TYPE i VALUE 8,
      list       TYPE i VALUE 9,
      set        TYPE i VALUE 10,
      map        TYPE i VALUE 11,
      struct     TYPE i VALUE 12,
      uuid       TYPE i VALUE 13,
    END OF c_type.

  "! An empty struct: only the stop byte
  CONSTANTS empty_struct TYPE x LENGTH 1 VALUE '00'.

  TYPES:
    "! A field kept as it was read
    BEGIN OF ty_field,
      id    TYPE i,
      "! Wire type; for a boolean, bool_true or bool_false, with no value bytes
      type  TYPE i,
      "! The encoded value, without the field header
      value TYPE xstring,
    END OF ty_field,
    "! Fields in the order they were read
    ty_fields TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY,
    ty_ids    TYPE STANDARD TABLE OF i WITH EMPTY KEY,
    "! A union whose members are empty structs (TimeUnit, ColumnOrder, ...)
    BEGIN OF ty_union,
      "! Field id of the member that is set; 0 if none
      member TYPE i,
      "! The member's encoded struct; empty means an empty struct
      value  TYPE xstring,
    END OF ty_union,
    ty_unions TYPE STANDARD TABLE OF ty_union WITH EMPTY KEY,
    BEGIN OF ty_list_header,
      element_type TYPE i,
      size         TYPE i,
    END OF ty_list_header.

ENDINTERFACE.
